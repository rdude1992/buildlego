class_name GuidedBuild
extends Node3D
## Guided set building: loads a set file, shows a ghost brick for the current step,
## and validates the piece the player drags in from the parts tray.

signal step_changed(index: int, total: int)
signal set_completed
signal feedback(text: String, good: bool)

## How many studs off the player may drop the right piece and still have it snap in.
const SNAP_TOLERANCE := 1
const HOVER_LIFT := 0.25

var set_name := ""
var set_id := ""
var steps: Array = [] # [{part, color, cell: Vector3i, rot}]
var current := 0
var grid: StudGrid
var camera: Camera3D
var model_center := Vector3.ZERO
var model_size := 8.0

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
		var a := Vector3(c.x, c.y * BrickDefs.PLATE_H / BrickDefs.STUD, c.z) * BrickDefs.STUD
		var b := a + Vector3(fp.x * BrickDefs.STUD, BrickDefs.height(s["part"]), fp.y * BrickDefs.STUD)
		lo = lo.min(a)
		hi = hi.max(b)
	model_center = (lo + hi) * 0.5
	model_size = (hi - lo).length()


func _build_ghost_and_held() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.no_depth_test = false
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


# --- flow ------------------------------------------------------------------

func restart() -> void:
	_clear_bricks()
	current = 0
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


## Parts "bag" for the tray: distinct pieces needed over the next few steps (always
## including the current one), with how many of each are still needed in that window.
func bag_items(window: int = 8, max_items: int = 5) -> Array:
	var items := []
	var index := {}
	for i in range(current, mini(current + window, steps.size())):
		var s: Dictionary = steps[i]
		var key := "%s|%s" % [s["part"], s["color"]]
		if index.has(key):
			items[index[key]]["count"] += 1
		elif items.size() < max_items:
			index[key] = items.size()
			items.append({"part": s["part"], "color": s["color"], "count": 1})
	items.sort_custom(func(a, b): return a["part"] + a["color"] < b["part"] + b["color"])
	return items


func hint() -> void:
	_hint = 1.0


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
	if is_complete():
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


func begin_hold(part_id: String, color_id: String) -> void:
	_holding = true
	_held_part = part_id
	_held_color = color_id
	_held_rot = 0
	_held_has_spot = false
	_held.mesh = BrickMeshFactory.get_mesh(part_id)
	var c := BrickDefs.color(color_id)
	c.a = minf(c.a, 0.9)
	_held_mat.albedo_color = c
	_held.scale = Vector3.ONE
	_held.visible = false


func update_hold(screen_pos: Vector2) -> void:
	if not _holding:
		return
	var res := DragPlacer.anchor_from_screen(camera, screen_pos, _held_part, _held_rot, grid)
	if not res["ok"]:
		_held_has_spot = false
		_held.visible = false
		return
	var anchor: Vector2i = res["anchor"]
	var rot := _held_rot
	# Magnet: the right piece near the right spot snaps (and turns) into place.
	if not is_complete():
		var s: Dictionary = steps[current]
		var t: Vector3i = s["cell"]
		if _held_part == s["part"] and _held_color == s["color"]:
			var t_fp := BrickDefs.footprint(s["part"], s["rot"])
			var t_center := Vector2(t.x + t_fp.x * 0.5, t.z + t_fp.y * 0.5)
			var fp := BrickDefs.footprint(_held_part, rot)
			var a_center := Vector2(anchor.x + fp.x * 0.5, anchor.y + fp.y * 0.5)
			if absf(a_center.x - t_center.x) <= SNAP_TOLERANCE + 0.5 and absf(a_center.y - t_center.y) <= SNAP_TOLERANCE + 0.5:
				anchor = Vector2i(t.x, t.z)
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


func rotate_held() -> void:
	_held_rot = (_held_rot + 1) % 4


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
		_place(steps[current], true)
		current += 1
		_update_ghost()
		feedback.emit("Click!", true)
		step_changed.emit(current, steps.size())
		if is_complete():
			set_completed.emit()
		return true
	var s: Dictionary = steps[current]
	var msg := "Not there - drop it on the glowing spot."
	if _held_part != s["part"]:
		msg = "That's a %s. This step needs a %s." % [BrickDefs.part_name(_held_part), BrickDefs.part_name(s["part"])]
	elif _held_color != s["color"]:
		msg = "Right shape, wrong color! Look for %s." % BrickDefs.color_label(s["color"])
	feedback.emit(msg, false)
	_reject_animation()
	return false


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


## Debug/automation helper: completes the current step without dragging.
func auto_place_current() -> void:
	if is_complete():
		return
	_place(steps[current], false)
	current += 1
	_update_ghost()
	step_changed.emit(current, steps.size())
	if is_complete():
		set_completed.emit()
