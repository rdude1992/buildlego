class_name GuidedBuild
extends Node3D
## Step-by-step set building, organised in numbered bags like a physical kit.
## Shows a ghost brick (Guided) or nothing (Booklet) for the current step, keeps the
## loose pieces of the opened bags "on the table", and validates the piece the player drops.

signal step_changed(index: int, total: int)
signal bag_finished(bag_index: int)
signal bag_opened(bag_index: int)
signal set_completed
signal feedback(text: String, good: bool)
signal placed(good: bool)

const HOVER_LIFT := 0.25

var set_name := ""
var set_id := ""
var steps: Array = [] # [{part, color, cell: Vector3i, rot}]
var bags: Array = [] # step count per bag
var current := 0
var grid: StudGrid
var camera: Camera3D
var model_center := Vector3.ZERO
var model_size := 8.0

## Rules, set from the profile before a build.
var guidance := "guided" # "guided" | "booklet"
var snap_tolerance := 1 # studs the right piece may be off and still snap in
var auto_rotate := true # right piece near its spot turns itself to fit

## Pieces lying on the table: "part|color" -> count.
var table := {}
var bag_index := -1 # last opened bag (-1 = none yet)

var _placed: Array = []
var _baseplate: Node3D
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _held: MeshInstance3D
var _held_mat: StandardMaterial3D
var _held_part := ""
var _held_color := ""
var _held_rot := 0
var _held_cell := Vector3i.ZERO
var _held_has_spot := false
var _holding := false
var _time := 0.0
var _hint := 0.0
var _peek := 0.0 # seconds the ghost stays visible in Booklet mode after a hint


func load_set(path: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(data is Dictionary, "Could not parse set file %s" % path)
	set_name = data["name"]
	set_id = data.get("id", path.get_file().get_basename())
	steps.clear()
	for s in data["steps"]:
		var c: Array = s["cell"]
		steps.append({
			"part": s["part"], "color": s["color"],
			"cell": Vector3i(int(c[0]), int(c[1]), int(c[2])), "rot": int(s.get("rot", 0)),
		})
	bags = []
	for b in data.get("bags", [steps.size()]):
		bags.append(int(b))
	var total := 0
	for b in bags:
		total += b
	if total != steps.size():
		push_error("Set %s: bags cover %d steps but the set has %d" % [set_id, total, steps.size()])
		bags = [steps.size()]
	var bp: Dictionary = data.get("baseplate", {"w": 16, "d": 16, "color": "green"})
	grid = StudGrid.new(int(bp["w"]), int(bp["d"]))
	_validate_steps()
	_build_baseplate(bp)
	_compute_bounds()
	_build_ghost_and_held()


## Every step must rest exactly where gravity would put it, otherwise it is unbuildable.
func _validate_steps() -> void:
	for i in steps.size():
		var s: Dictionary = steps[i]
		var c: Vector3i = s["cell"]
		var rest := grid.rest_level(s["part"], Vector2i(c.x, c.z), s["rot"])
		if rest != c.y:
			push_error("Set step %d (%s) has y=%d but would rest at y=%d" % [i + 1, s["part"], c.y, rest])
		grid.occupy(s["part"], c, s["rot"])
	grid.reset()


func _build_baseplate(bp: Dictionary) -> void:
	_baseplate = Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = BrickMeshFactory.build_baseplate(grid.width, grid.depth)
	mi.material_override = BrickDefs.material(bp.get("color", "green"))
	_baseplate.add_child(mi)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(grid.width * BrickDefs.STUD, 0.12, grid.depth * BrickDefs.STUD)
	shape.shape = box
	shape.position = Vector3(box.size.x * 0.5, -0.06, box.size.z * 0.5)
	body.add_child(shape)
	_baseplate.add_child(body)
	add_child(_baseplate)


func _compute_bounds() -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for s in steps:
		var c: Vector3i = s["cell"]
		var fp := BrickDefs.footprint(s["part"], s["rot"])
		var a := Vector3(c.x * BrickDefs.STUD, c.y * BrickDefs.PLATE_H, c.z * BrickDefs.STUD)
		var b := a + Vector3(fp.x * BrickDefs.STUD, BrickDefs.height(s["part"]), fp.y * BrickDefs.STUD)
		lo = lo.min(a)
		hi = hi.max(b)
	model_center = (lo + hi) * 0.5
	model_size = (hi - lo).length()


func _build_ghost_and_held() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost = MeshInstance3D.new()
	_ghost.material_override = _ghost_mat
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)

	_held_mat = StandardMaterial3D.new()
	_held_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_held_mat.roughness = 0.3
	_held = MeshInstance3D.new()
	_held.material_override = _held_mat
	_held.visible = false
	add_child(_held)


# --- bags --------------------------------------------------------------------

func bag_count() -> int:
	return bags.size()


func bag_start(i: int) -> int:
	var n := 0
	for k in i:
		n += bags[k]
	return n


func bag_end(i: int) -> int:
	return bag_start(i) + bags[i]


func bag_of_step(step: int) -> int:
	for i in bags.size():
		if step < bag_end(i):
			return i
	return bags.size() - 1


## True when the current step's bag has not been opened yet (the player must open it).
func needs_bag() -> bool:
	return not is_complete() and bag_of_step(current) > bag_index


## Tears open the next bag: its pieces (plus one spare) land on the table.
func open_next_bag() -> void:
	if bag_index >= bags.size() - 1:
		return
	bag_index += 1
	var smallest := {}
	for i in range(bag_start(bag_index), bag_end(bag_index)):
		var s: Dictionary = steps[i]
		_table_add(s["part"], s["color"], 1)
		var vol: int = BrickDefs.part(s["part"])["size"].x * BrickDefs.part(s["part"])["size"].y * BrickDefs.plates(s["part"])
		if smallest.is_empty() or vol < smallest["vol"]:
			smallest = {"vol": vol, "part": s["part"], "color": s["color"]}
	if not smallest.is_empty():
		_table_add(smallest["part"], smallest["color"], 1) # a spare, like real kits
	bag_opened.emit(bag_index)
	_update_ghost()
	step_changed.emit(current, steps.size())


func _table_add(part_id: String, color_id: String, n: int) -> void:
	var key := "%s|%s" % [part_id, color_id]
	table[key] = int(table.get(key, 0)) + n
	if table[key] <= 0:
		table.erase(key)


## Pieces on the table for the tray: [{part, color, count}].
## sort: "color" | "type" | "loose" (a stable shuffle, like a spilled bag).
func table_items(sort := "color") -> Array:
	var items := []
	for key in table:
		var p: PackedStringArray = key.split("|")
		items.append({"part": p[0], "color": p[1], "count": table[key]})
	match sort:
		"type":
			items.sort_custom(func(a, b): return a["part"] + a["color"] < b["part"] + b["color"])
		"loose":
			items.sort_custom(func(a, b): return hash(a["part"] + a["color"] + str(bag_index)) < hash(b["part"] + b["color"] + str(bag_index)))
		_:
			items.sort_custom(func(a, b): return a["color"] + a["part"] < b["color"] + b["part"])
	return items


# --- flow ------------------------------------------------------------------

func restart() -> void:
	_clear_bricks()
	current = 0
	bag_index = -1
	table.clear()
	_update_ghost()
	step_changed.emit(current, steps.size())


## Places every brick instantly (used for the menu showcase and the finished model).
func show_completed() -> void:
	_clear_bricks()
	for s in steps:
		_place(s, false)
	current = steps.size()
	_update_ghost()


func is_complete() -> bool:
	return current >= steps.size()


func current_step() -> Dictionary:
	return {} if is_complete() else steps[current]


func hint() -> void:
	_hint = 1.0
	if guidance != "guided":
		_peek = 2.5
		_update_ghost()


func _clear_bricks() -> void:
	for b in _placed:
		b.queue_free()
	_placed.clear()
	grid.reset()


func _place(s: Dictionary, animate: bool) -> void:
	var b := Brick.new()
	b.setup(s["part"], s["color"], s["cell"], s["rot"])
	add_child(b)
	_placed.append(b)
	grid.occupy(s["part"], s["cell"], s["rot"])
	if animate:
		var final_pos := b.position
		b.position += Vector3(0, HOVER_LIFT, 0)
		var tw := create_tween()
		tw.tween_property(b, "position", final_pos, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(b, "scale", Vector3(1.04, 0.94, 1.04), 0.06)
		tw.tween_property(b, "scale", Vector3.ONE, 0.10)


func _update_ghost() -> void:
	if is_complete() or needs_bag() or (guidance != "guided" and _peek <= 0.0):
		_ghost.visible = false
		return
	var s: Dictionary = steps[current]
	_ghost.mesh = BrickMeshFactory.get_mesh(s["part"])
	_ghost.position = StudGrid.cell_to_world(s["part"], s["cell"], s["rot"])
	_ghost.rotation.y = s["rot"] * PI * 0.5
	_ghost.scale = Vector3.ONE * 1.01
	_ghost.visible = true


func _process(delta: float) -> void:
	_time += delta
	_hint = maxf(0.0, _hint - delta * 0.5)
	if _peek > 0.0:
		_peek -= delta
		if _peek <= 0.0:
			_update_ghost()
	if _ghost.visible and not is_complete():
		var c := BrickDefs.color(steps[current]["color"]).lerp(Color.WHITE, 0.35)
		var pulse := 0.5 + 0.5 * sin(_time * (4.0 + _hint * 8.0))
		c.a = 0.28 + 0.22 * pulse + _hint * 0.4
		if _holding and _held_has_spot and _is_on_target():
			c = Color(0.4, 1.0, 0.5, 0.75)
		_ghost_mat.albedo_color = c
		_ghost.scale = Vector3.ONE * (1.01 + _hint * 0.08 * pulse)


# --- holding / dropping a piece ---------------------------------------------

func is_holding() -> bool:
	return _holding


func held_rotation() -> int:
	return _held_rot


func begin_hold(part_id: String, color_id: String, rot: int = 0) -> void:
	_holding = true
	_held_part = part_id
	_held_color = color_id
	_held_rot = rot
	_held_has_spot = false
	_held.mesh = BrickMeshFactory.get_mesh(part_id)
	var c := BrickDefs.color(color_id)
	c.a = minf(c.a, 0.9)
	_held_mat.albedo_color = c
	_held.scale = Vector3.ONE
	_held.visible = false


var _last_hold_pos := Vector2.ZERO


func update_hold(screen_pos: Vector2) -> void:
	if not _holding:
		return
	_last_hold_pos = screen_pos
	var res := DragPlacer.anchor_from_screen(camera, screen_pos, _held_part, _held_rot, grid)
	if not res["ok"]:
		hide_preview()
		return
	var anchor: Vector2i = res["anchor"]
	var rot := _held_rot
	# Magnet: the right piece near the right spot snaps into place (and in Kids mode turns to fit).
	if not is_complete():
		var s: Dictionary = steps[current]
		var t: Vector3i = s["cell"]
		var rot_ok := auto_rotate or BrickDefs.rot_equivalent(_held_part, rot, s["rot"])
		if _held_part == s["part"] and _held_color == s["color"] and rot_ok and snap_tolerance > 0:
			var t_fp := BrickDefs.footprint(s["part"], s["rot"])
			var t_center := Vector2(t.x + t_fp.x * 0.5, t.z + t_fp.y * 0.5)
			var fp := BrickDefs.footprint(_held_part, rot)
			var a_center := Vector2(anchor.x + fp.x * 0.5, anchor.y + fp.y * 0.5)
			if absf(a_center.x - t_center.x) <= snap_tolerance + 0.5 and absf(a_center.y - t_center.y) <= snap_tolerance + 0.5:
				anchor = Vector2i(t.x, t.z)
				if auto_rotate:
					rot = s["rot"]
	_held_rot = rot
	var y := grid.rest_level(_held_part, anchor, rot)
	_held_cell = Vector3i(anchor.x, y, anchor.y)
	_held_has_spot = true
	_held.position = StudGrid.cell_to_world(_held_part, _held_cell, rot) + Vector3(0, HOVER_LIFT, 0)
	_held.rotation.y = rot * PI * 0.5
	_held.visible = true


func hide_preview() -> void:
	_held_has_spot = false
	_held.visible = false


## Turns the piece in hand a quarter turn.
func rotate_held() -> void:
	_held_rot = (_held_rot + 1) % 4
	if _holding and _held_has_spot:
		update_hold(_last_hold_pos)


func cancel_hold() -> void:
	_holding = false
	_held.visible = false


## Returns true if the piece was placed correctly.
func end_hold(screen_pos: Vector2) -> bool:
	if not _holding:
		return false
	update_hold(screen_pos)
	_holding = false
	if not _held_has_spot:
		_held.visible = false
		return false
	if _is_on_target():
		_held.visible = false
		_complete_current(true)
		feedback.emit("Click!", true)
		placed.emit(true)
		return true
	var s: Dictionary = steps[current]
	var msg := "Not there. Look at the %s again." % ("glowing spot" if guidance == "guided" else "booklet picture")
	if _held_part != s["part"]:
		msg = "That's a %s. This step needs a %s." % [BrickDefs.part_name(_held_part), BrickDefs.part_name(s["part"])]
	elif _held_color != s["color"]:
		msg = "Right shape, wrong color! Look for %s." % BrickDefs.color_label(s["color"])
	elif _held_cell == s["cell"] and not BrickDefs.rot_equivalent(_held_part, _held_rot, s["rot"]):
		msg = "Right spot! Now turn the piece to fit."
	feedback.emit(msg, false)
	placed.emit(false)
	_reject_animation()
	return false


func _complete_current(animate: bool) -> void:
	var s: Dictionary = steps[current]
	_place(s, animate)
	_table_add(s["part"], s["color"], -1)
	var finished_bag := bag_of_step(current)
	current += 1
	_peek = 0.0
	_update_ghost()
	step_changed.emit(current, steps.size())
	if is_complete():
		set_completed.emit()
	elif current == bag_end(finished_bag):
		bag_finished.emit(finished_bag)


func _is_on_target() -> bool:
	if is_complete():
		return false
	var s: Dictionary = steps[current]
	return _held_part == s["part"] and _held_color == s["color"] \
		and _held_cell == s["cell"] and BrickDefs.rot_equivalent(_held_part, _held_rot, s["rot"])


func _reject_animation() -> void:
	var tw := create_tween()
	_held_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.8)
	var p := _held.position
	tw.tween_property(_held, "position", p + Vector3(0.15, 0, 0), 0.05)
	tw.tween_property(_held, "position", p - Vector3(0.15, 0, 0), 0.08)
	tw.tween_property(_held, "position", p + Vector3(0, 0.8, 0), 0.25)
	tw.parallel().tween_property(_held, "scale", Vector3.ONE * 0.2, 0.25)
	tw.tween_callback(func(): _held.visible = false)


## Debug/automation helper: completes the current step without dragging (opens bags as needed).
func auto_place_current() -> void:
	if is_complete():
		return
	while needs_bag():
		open_next_bag()
	_complete_current(false)
