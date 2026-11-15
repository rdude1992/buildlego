class_name Brick
extends Node3D
## A brick placed on the model. Has a collider so the player's finger ray can land on it.

var part_id := ""
var color_id := ""
var cell := Vector3i.ZERO
var rot := 0
var mesh_instance: MeshInstance3D


func setup(p_part: String, p_color: String, p_cell: Vector3i, p_rot: int) -> void:
	part_id = p_part
	color_id = p_color
	cell = p_cell
	rot = p_rot
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = BrickMeshFactory.get_mesh(part_id)
	mesh_instance.material_override = BrickDefs.material(color_id)
	add_child(mesh_instance)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var size: Vector2i = BrickDefs.part(part_id)["size"]
	var h := BrickDefs.height(part_id)
	box.size = Vector3(size.x * BrickDefs.STUD, h, size.y * BrickDefs.STUD)
	shape.shape = box
	shape.position.y = h * 0.5
	body.add_child(shape)
	add_child(body)

	position = StudGrid.cell_to_world(part_id, cell, rot)
	rotation.y = rot * PI * 0.5
