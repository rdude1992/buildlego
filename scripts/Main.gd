extends Node3D
## Game root: 3D world, profile (Kids / Grown-ups), and the flow
## menu -> box (cut the tape) -> bags (tear one open) -> build -> next bag ... -> complete.

const SET_PATH := "res://sets/house_01.json"
## On touchscreens the held piece is shown above the finger so the finger doesn't hide it.
const TOUCH_LIFT := 80.0
const SORT_MODES := ["loose", "color", "type"]

var camera: OrbitCamera
var build: GuidedBuild
var hud: Hud
var menu: MainMenu
var box_screen: BoxScreen
var gate: ParentalGate
var sfx: Sfx
var confetti: CPUParticles3D
var mode := "menu" # menu | box | build
var sort_mode := "color"
var pending_rot := 0 # Grown-ups: orientation of the next piece picked up


func _ready() -> void:
	Profile.load_profile()
	sfx = Sfx.new()
	add_child(sfx)
	_setup_world()
	build = GuidedBuild.new()
	add_child(build)
	build.camera = camera
	build.load_set(SET_PATH)
	camera.set_home(build.model_center + Vector3(0, -0.6, 0), 0.5, 0.62, build.model_size * 1.9)
	_setup_confetti()
	_setup_ui()
	build.step_changed.connect(_on_step_changed)
	build.feedback.connect(func(text, good): hud.toast(text, good))
	build.set_completed.connect(_on_completed)
	build.bag_opened.connect(_on_bag_opened)
	build.bag_finished.connect(_on_bag_finished)
	build.placed.connect(_on_placed)
	show_menu()
	_run_automation.call_deferred()


func _setup_world() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.60, 0.92)
	sky_mat.sky_horizon_color = Color(0.80, 0.88, 0.97)
	sky_mat.ground_horizon_color = Color(0.80, 0.88, 0.97)
	sky_mat.ground_bottom_color = Color(0.55, 0.62, 0.70)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.83, 0.92)
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -40, 0)
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = 0.25
	add_child(fill)

	camera = OrbitCamera.new()
	camera.fov = 45
	add_child(camera)


func _setup_confetti() -> void:
	confetti = CPUParticles3D.new()
	confetti.emitting = false
	confetti.one_shot = true
	confetti.amount = 160
	confetti.lifetime = 3.0
	confetti.explosiveness = 0.9
	confetti.direction = Vector3.UP
	confetti.spread = 50.0
	confetti.initial_velocity_min = 5.0
	confetti.initial_velocity_max = 9.0
	confetti.gravity = Vector3(0, -9.0, 0)
	confetti.angular_velocity_min = -300
	confetti.angular_velocity_max = 300
	var m := BoxMesh.new()
	m.size = Vector3(0.16, 0.06, 0.16)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	confetti.mesh = m
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	g.colors = PackedColorArray([Color(0.79, 0.10, 0.09), Color(0.98, 0.78, 0.05), Color(0.05, 0.34, 0.75), Color(0.16, 0.55, 0.20)])
	confetti.color_initial_ramp = g
	confetti.position = build.model_center + Vector3(0, 2.0, 0)
	add_child(confetti)


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	layer.add_child(root)

	hud = Hud.new()
	root.add_child(hud)
	hud.menu_pressed.connect(show_menu)
	hud.hint_pressed.connect(_on_hint)
	hud.reset_view_pressed.connect(func(): camera.reset_view())
	hud.rebuild_pressed.connect(open_box)
	hud.part_picked.connect(_on_part_picked)
	hud.turn_pressed.connect(_on_turn)
	hud.sort_pressed.connect(_on_sort)

	menu = MainMenu.new()
	root.add_child(menu)
	menu.set_set_info(build.set_name, build.steps.size(), build.bag_count())
	menu.play_pressed.connect(open_box)
	menu.mode_chosen.connect(func(m):
		Profile.set_mode(m)
		sfx.play("tap")
		show_menu())
	menu.switch_mode_pressed.connect(_on_switch_mode)

	box_screen = BoxScreen.new()
	root.add_child(box_screen)
	box_screen.visible = false
	box_screen.set_sfx(sfx)
	box_screen.back_pressed.connect(show_menu)
	box_screen.guidance_changed.connect(func(g):
		Profile.set_guidance(g)
		sfx.play("tap"))
	box_screen.tape_cut.connect(func(): box_screen.show_bags(0, build.bag_count(), "Open bag 1"))
	box_screen.bag_open_requested.connect(_on_bag_open_requested)

	gate = ParentalGate.new()
	root.add_child(gate)
	gate.passed.connect(func():
		Profile.set_mode("adult")
		show_menu())

	camera.is_ui_point = func(p: Vector2) -> bool:
		return box_screen.visible or gate.visible or hud.is_point_over_ui(p) \
			or (menu.visible and menu._panel.get_global_rect().has_point(p))


# --- flow --------------------------------------------------------------------

func show_menu() -> void:
	mode = "menu"
	build.cancel_hold()
	build.show_completed()
	hud.visible = false
	box_screen.visible = false
	menu.visible = true
	menu.show_for(Profile.is_first_run(), Profile.mode())
	camera.reset_view()
	camera.h_offset = -3.2 # keep the model clear of the menu panel
	camera.auto_rotate = true


func _on_switch_mode() -> void:
	if Profile.is_kids():
		gate.ask() # leaving Kids mode needs a grown-up
	else:
		Profile.set_mode("kids")
		show_menu()


## Shows the closed box on an empty table.
func open_box() -> void:
	mode = "box"
	build.cancel_hold()
	build.restart()
	menu.visible = false
	hud.visible = false
	camera.h_offset = 0.0
	camera.reset_view()
	camera.auto_rotate = true
	box_screen.show_box(build.set_name, build.steps, build.bag_count(), Profile.is_kids(), Profile.guidance())


func _apply_rules() -> void:
	var kids := Profile.is_kids()
	build.guidance = Profile.guidance()
	build.snap_tolerance = 1 if kids else 0
	build.auto_rotate = kids
	sort_mode = "color" if kids else "loose"
	pending_rot = 0
	hud.begin_build(build.set_name, build.steps, kids, build.guidance)
	hud.set_sort_label(sort_mode)
	hud.set_turn_label(pending_rot)


func _on_bag_open_requested(_i: int) -> void:
	if mode != "build":
		mode = "build"
		_apply_rules()
		camera.auto_rotate = false
		camera.reset_view()
	hud.visible = true
	build.open_next_bag()


func _on_bag_opened(i: int) -> void:
	sfx.play("spill", 0.0, false)
	_refresh_table(true)
	hud.toast("Bag %d is open!" % (i + 1), true)


func _on_bag_finished(i: int) -> void:
	sfx.play("fanfare", -8.0, false)
	await get_tree().create_timer(0.8).timeout
	if mode == "build" and build.needs_bag():
		box_screen.show_bags(i + 1, build.bag_count(), "Bag %d done! Open bag %d" % [i + 1, i + 2])


func _bag_text() -> String:
	if build.bag_index < 0:
		return ""
	return "Bag %d / %d" % [build.bag_index + 1, build.bag_count()]


func _on_step_changed(index: int, total: int) -> void:
	if mode != "build":
		return
	hud.show_step(index, total, build.current_step(), _bag_text())
	_refresh_table(false)


func _refresh_table(spill: bool) -> void:
	var items := build.table_items(sort_mode)
	var n := 0
	for it in items:
		n += it["count"]
	var header := "TABLE  -  %d %s from bag %d. Drag the right piece onto the model." % [n, "piece" if n == 1 else "pieces", build.bag_index + 1]
	hud.show_table(items, header, spill)


func _on_placed(good: bool) -> void:
	if good:
		sfx.play("click")
		Sfx.buzz(18)
	else:
		sfx.play("thud")
		Sfx.buzz(60)


func _on_completed() -> void:
	camera.auto_rotate = true
	confetti.restart()
	confetti.emitting = true
	sfx.play("fanfare", 0.0, false)


func _on_hint() -> void:
	build.hint()
	var s := build.current_step()
	if not s.is_empty():
		hud.pulse_card(s["part"], s["color"])
		hud.toast("Find the %s %s on the table" % [BrickDefs.color_label(s["color"]), BrickDefs.part_name(s["part"])], true)


func _on_turn() -> void:
	sfx.play("tap")
	if build.is_holding():
		build.rotate_held()
		pending_rot = build.held_rotation()
	else:
		pending_rot = (pending_rot + 1) % 4
	hud.set_turn_label(pending_rot)


func _on_sort() -> void:
	sort_mode = SORT_MODES[(SORT_MODES.find(sort_mode) + 1) % SORT_MODES.size()]
	hud.set_sort_label(sort_mode)
	sfx.play("tap")
	_refresh_table(false)


# --- dragging a piece from the table -----------------------------------------

func _on_part_picked(part_id: String, color_id: String) -> void:
	if mode != "build" or box_screen.visible:
		return
	build.begin_hold(part_id, color_id, 0 if Profile.is_kids() else pending_rot)
	camera.input_enabled = false
	sfx.play("tap", -6.0)


func _hold_point(pos: Vector2, from_touch: bool) -> Vector2:
	return pos - Vector2(0, TOUCH_LIFT) if from_touch else pos


func _input(event: InputEvent) -> void:
	if not build or not build.is_holding():
		return
	# Grown-ups: tap with a second finger while dragging to turn the piece.
	if event is InputEventScreenTouch and event.pressed and event.index > 0:
		_on_turn()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		if hud.is_point_over_ui(event.position):
			build.hide_preview()
		else:
			build.update_hold(_hold_point(event.position, event.device == -1))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if hud.is_point_over_ui(event.position):
			build.cancel_hold() # dropped back on the table
		else:
			build.end_hold(_hold_point(event.position, event.device == -1))
		camera.input_enabled = true
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_on_turn()


# --- automation for screenshots / smoke tests (only with user args) ----------
# godot -- --shot=out.png --scene=menu|picker|box|bags|build|done [--mode=kids|adult]
#          [--guidance=guided|booklet] [--steps=N] [--drag] [--hold] [--wrong] [--frames=N]

func _run_automation() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.is_empty():
		return
	# Never touch the saved profile from automation.
	Profile.data = {"mode": args.get("mode", "kids"), "guidance": {}}
	if args.has("guidance"):
		Profile.data["guidance"][Profile.mode()] = args["guidance"]
	var scene: String = args.get("scene", "menu")
	match scene:
		"picker":
			Profile.data["mode"] = ""
			show_menu()
		"menu":
			show_menu()
		"box":
			open_box()
		"bags":
			open_box()
			await _wait_frames(3)
			box_screen.cut_tape()
			await _wait_frames(40)
		_:
			open_box()
			await _wait_frames(3)
			box_screen.visible = false
			_on_bag_open_requested(0)
			for i in int(args.get("steps", "0")):
				build.auto_place_current()
			if scene == "done":
				while not build.is_complete():
					build.auto_place_current()
	if args.has("drag") and mode == "build" and not build.is_complete():
		await _wait_frames(30)
		await _simulate_drag(args.has("hold"))
	if args.has("wrong"):
		await _wait_frames(30)
		await _simulate_wrong_drop()
	await _wait_frames(int(args.get("frames", "45")))
	if args.has("shot"):
		var img := get_viewport().get_texture().get_image()
		img.save_png(args["shot"])
		print("Saved screenshot: ", args["shot"])
	if args.has("report"):
		print("REPORT step=%d/%d bag=%d needs_bag=%s complete=%s table=%s" % [build.current, build.steps.size(),
			build.bag_index + 1, build.needs_bag(), build.is_complete(), build.table])
	get_tree().quit()


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _send_mouse(pos: Vector2, pressed_state: int) -> void:
	# pressed_state: 1 = press, 0 = release, -1 = motion
	if pressed_state == -1:
		var m := InputEventMouseMotion.new()
		m.position = pos
		m.global_position = pos
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
	else:
		var b := InputEventMouseButton.new()
		b.position = pos
		b.global_position = pos
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed_state == 1
		Input.parse_input_event(b)
	await get_tree().process_frame


## Drags the correct piece from the table to its spot, like a player would.
func _simulate_drag(hold: bool) -> void:
	var s := build.current_step()
	if not Profile.is_kids():
		pending_rot = s["rot"]
		if OS.get_cmdline_user_args().has("--wrongrot"):
			pending_rot = (s["rot"] + 1) % 4
		hud.set_turn_label(pending_rot)
	var start := hud.card_rect(s["part"], s["color"]).get_center()
	await _wait_frames(2)
	start = hud.card_rect(s["part"], s["color"]).get_center()
	# Aim at the surface the brick will rest on, where a player's finger would be.
	var end := camera.unproject_position(StudGrid.cell_to_world(s["part"], s["cell"], s["rot"]))
	await _send_mouse(start, 1)
	for i in 20:
		await _send_mouse(start.lerp(end, (i + 1) / 20.0), -1)
	if hold:
		return
	await _send_mouse(end, 0)


func _simulate_wrong_drop() -> void:
	var s := build.current_step()
	for key in hud.card_keys():
		if key != "%s|%s" % [s["part"], s["color"]]:
			var p: PackedStringArray = key.split("|")
			var start := hud.card_rect(p[0], p[1]).get_center()
			var end := camera.unproject_position(StudGrid.cell_to_world(s["part"], s["cell"], s["rot"]))
			await _send_mouse(start, 1)
			for i in 10:
				await _send_mouse(start.lerp(end, (i + 1) / 10.0), -1)
			await _send_mouse(end, 0)
			return
