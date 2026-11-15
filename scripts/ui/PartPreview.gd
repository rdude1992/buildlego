class_name PartPreview
extends SubViewportContainer
## Small rotating 3D render of a single part, used in the booklet callout and parts tray.

var _pivot: Node3D
var spin := true


func setup(part_id: String, color_id: String, px_size: Vector2i) -> void:
	stretch = true
	custom_minimum_size = px_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = px_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var mesh := MeshInstance3D.new()
	mesh.mesh = BrickMeshFactory.get_mesh(part_id)
	mesh.material_override = BrickDefs.material(color_id)
	var size: Vector2i = BrickDefs.part(part_id)["size"]
	var h := BrickDefs.height(part_id)
	mesh.position.y = -h * 0.5
	var pivot := Node3D.new()
	pivot.add_child(mesh)
	pivot.rotation.y = -0.6
	vp.add_child(pivot)
	_pivot = pivot

	var cam := Camera3D.new()
	var span := maxf(maxf(size.x, size.y) * BrickDefs.STUD, h * 1.6)
	cam.position = Vector3(0, span * 0.9, span * 1.45)
	cam.fov = 40
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	cam.environment = env
	vp.add_child(cam)
	cam.transform = Transform3D(Basis.looking_at(-cam.position, Vector3.UP), cam.position)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 35, 0)
	light.light_energy = 1.1
	vp.add_child(light)


func _process(delta: float) -> void:
	if spin and _pivot:
		_pivot.rotation.y += delta * 0.7
