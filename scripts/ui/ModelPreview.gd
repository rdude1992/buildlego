class_name ModelPreview
extends SubViewportContainer
## A small 3D render of (part of) a set in its own world. Used for the box art and for the
## instruction-booklet picture of each step (model so far + the new piece with an arrow).

var spin := false
## < 1 frames the model tighter.
var zoom := 0.8
var _vp: SubViewport
var _root: Node3D
var _cam: Camera3D
var _arrow: MeshInstance3D
var _steps: Array = []
var _shown := 0
var _center := Vector3.ZERO
var _radius := 5.0
var _yaw := 0.5
var _pitch := 0.62
var _time := 0.0
var _arrow_base := Vector3.ZERO


func setup(steps: Array, px_size: Vector2i, bg := Color(0, 0, 0, 0)) -> void:
	_steps = steps
	stretch = true
	custom_minimum_size = px_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = bg.a == 0.0
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = px_size
	add_child(_vp)

	_root = Node3D.new()
	_vp.add_child(_root)
	_cam = Camera3D.new()
	_cam.fov = 32
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR if bg.a == 0.0 else Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.84, 0.92)
	env.ambient_light_energy = 0.75
	_cam.environment = env
	_vp.add_child(_cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -40, 0)
	light.light_energy = 0.95
	_vp.add_child(light)

	_arrow = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.32
	cone.height = 0.6
	_arrow.mesh = cone
	_arrow.rotation_degrees = Vector3(180, 0, 0) # point down
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(1.0, 0.75, 0.0)
	am.emission_enabled = true
	am.emission = Color(1.0, 0.6, 0.0)
	am.emission_energy_multiplier = 0.6
	_arrow.material_override = am
	_arrow.visible = false
	_vp.add_child(_arrow)

	# Frame the whole finished model so pictures keep the same scale step to step.
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for s in steps:
		var p := StudGrid.cell_to_world(s["part"], s["cell"], s["rot"])
		var fp := BrickDefs.footprint(s["part"], s["rot"])
		var half := Vector3(fp.x, 0, fp.y) * BrickDefs.STUD * 0.5
		lo = lo.min(p - half)
		hi = hi.max(p + half + Vector3(0, BrickDefs.height(s["part"]), 0))
	_center = (lo + hi) * 0.5
	_radius = (hi - lo).length() * 0.5 + 0.4
	_update_camera()


## Shows steps [0, count). When `highlight` is true, the last of them gets an arrow.
func show_steps(count: int, highlight := false) -> void:
	if count < _shown:
		for c in _root.get_children():
			c.queue_free()
		_shown = 0
	while _shown < count and _shown < _steps.size():
		var s: Dictionary = _steps[_shown]
		var mi := MeshInstance3D.new()
		mi.mesh = BrickMeshFactory.get_mesh(s["part"])
		mi.material_override = BrickDefs.material(s["color"])
		mi.position = StudGrid.cell_to_world(s["part"], s["cell"], s["rot"])
		mi.rotation.y = s["rot"] * PI * 0.5
		_root.add_child(mi)
		_shown += 1
	_arrow.visible = highlight and count > 0
	if _arrow.visible:
		var s: Dictionary = _steps[count - 1]
		_arrow_base = StudGrid.cell_to_world(s["part"], s["cell"], s["rot"]) + Vector3(0, BrickDefs.height(s["part"]) + 0.75, 0)
		_arrow.position = _arrow_base


func _update_camera() -> void:
	var dist := _radius / tan(deg_to_rad(_cam.fov * 0.5)) * zoom
	var dir := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	_cam.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), _center + dir * dist)


func _process(delta: float) -> void:
	_time += delta
	if spin and _cam:
		_yaw += delta * 0.35
		_update_camera()
	if _arrow and _arrow.visible:
		_arrow.position = _arrow_base + Vector3(0, 0.12 * sin(_time * 5.0), 0)
