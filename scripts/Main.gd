extends Node3D
## Game root: sets up the 3D world, the guided build, and switches between menu and build.

const SET_PATH := "res://sets/house_01.json"
## On touchscreens the held piece is shown above the finger so the finger doesn't hide it.
const TOUCH_LIFT := 80.0

var camera: OrbitCamera
var build: GuidedBuild
var hud: Hud
var menu: MainMenu
var confetti: CPUParticles3D
var mode := "menu"


func _ready() -> void:
	_setup_world()
	build = GuidedBuild.new()
	add_child(build)
	build.camera = camera
	build.load_set(SET_PATH)
	camera.set_home(build.model_center + Vector3(0, -0.6, 0), 0.5, 0.62, build.model_size * 1.9)
	_setup_confetti()
	_setup_ui()
	build.step_changed.connect(_on_step_changed)
	build.feedback.connect(_on_feedback)
	build.set_completed.connect(_on_completed)
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
	hud.set_title(build.set_name)
	hud.menu_pressed.connect(show_menu)
	hud.hint_pressed.connect(_on_hint)
	hud.reset_view_pressed.connect(func(): camera.reset_view())
	hud.rebuild_pressed.connect(start_build)
	hud.part_picked.connect(_on_part_picked)

	menu = MainMenu.new()
	root.add_child(menu)
	menu.set_set_info(build.set_name, build.steps.size())
	menu.play_pressed.connect(start_build)

	camera.is_ui_point = func(p: Vector2) -> bool:
		return hud.is_point_over_ui(p) or (menu.visible and menu._panel.get_global_rect().has_point(p))


# --- modes -------------------------------------------------------------------

func show_menu() -> void:
	mode = "menu"
	build.cancel_hold()
	build.show_completed()
	hud.visible = false
	menu.visible = true
	camera.reset_view()
	camera.h_offset = -3.2 # keep the model clear of the menu panel
	camera.auto_rotate = true


func start_build() -> void:
	mode = "build"
	menu.visible = false
	hud.visible = true
	camera.auto_rotate = false
	camera.h_offset = 0.0
	camera.reset_view()
	build.restart()


func _on_step_changed(index: int, total: int) -> void:
	hud.show_step(index, total, build.current_step(), build.bag_items())


func _on_feedback(text: String, good: bool) -> void:
	hud.toast(text, good)


func _on_completed() -> void:
	camera.auto_rotate = true
	confetti.restart()
	confetti.emitting = true


func _on_hint() -> void:
	build.hint()
	var s := build.current_step()
	if not s.is_empty():
		hud.pulse_card(s["part"], s["color"])
		hud.toast("Find the %s %s in the bag" % [BrickDefs.color_label(s["color"]), BrickDefs.part_name(s["part"])], true)


# --- dragging a piece from the tray ------------------------------------------

func _on_part_picked(part_id: String, color_id: String) -> void:
	if mode != "build":
		return
	build.begin_hold(part_id, color_id)
	camera.input_enabled = false


func _hold_point(pos: Vector2, from_touch: bool) -> Vector2:
	return pos - Vector2(0, TOUCH_LIFT) if from_touch else pos


func _input(event: InputEvent) -> void:
	if not build or not build.is_holding():
		return
	if event is InputEventMouseMotion:
		if hud.is_point_over_ui(event.position):
			build.hide_preview()
		else:
			build.update_hold(_hold_point(event.position, event.device == -1))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if hud.is_point_over_ui(event.position):
			build.cancel_hold() # dropped back into the bag
		else:
			build.end_hold(_hold_point(event.position, event.device == -1))
		camera.input_enabled = true
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		build.rotate_held()


# --- automation for screenshots / smoke tests (only with user args) ----------
# Usage: godot -- --shot=out.png [--scene=menu|build|done] [--steps=N] [--drag]

func _run_automation() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.is_empty():
		return
	var scene: String = args.get("scene", "menu")
	if scene != "menu":
		start_build()
		for i in int(args.get("steps", "0")):
			build.auto_place_current()
		if scene == "done":
			while not build.is_complete():
				build.auto_place_current()
	if args.has("drag") and not build.is_complete():
		await _wait_frames(5)
		await _simulate_drag()
	if args.has("wrong"):
		await _wait_frames(5)
		await _simulate_wrong_drop()
	await _wait_frames(int(args.get("frames", "45")))
	if args.has("shot"):
		var img := get_viewport().get_texture().get_image()
		img.save_png(args["shot"])
		print("Saved screenshot: ", args["shot"])
	if args.has("report"):
		print("REPORT step=%d/%d complete=%s" % [build.current, build.steps.size(), build.is_complete()])
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


## Drags the correct piece from the tray to the ghost, like a player would, then holds it
## over the target (for the screenshot) and drops it.
func _simulate_drag() -> void:
	var s := build.current_step()
	var card: Control = hud._cards["%s|%s" % [s["part"], s["color"]]]
	var start := card.get_global_rect().get_center()
	var target_world := StudGrid.cell_to_world(s["part"], s["cell"], s["rot"]) + Vector3(0, BrickDefs.height(s["part"]), 0)
	var end := camera.unproject_position(target_world)
	await _send_mouse(start, 1)
	for i in 20:
		await _send_mouse(start.lerp(end, (i + 1) / 20.0), -1)
	if OS.get_cmdline_user_args().has("--hold"):
		return
	await _send_mouse(end, 0)


func _simulate_wrong_drop() -> void:
	var s := build.current_step()
	for key in hud._cards:
		if key != "%s|%s" % [s["part"], s["color"]]:
			var card: Control = hud._cards[key]
			var start := card.get_global_rect().get_center()
			var end := camera.unproject_position(StudGrid.cell_to_world(s["part"], s["cell"], s["rot"]))
			await _send_mouse(start, 1)
			for i in 10:
				await _send_mouse(start.lerp(end, (i + 1) / 10.0), -1)
			await _send_mouse(end, 0)
			return
