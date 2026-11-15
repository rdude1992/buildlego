class_name DragPlacer
extends RefCounted
## Turns a finger/mouse position into a stud-grid anchor on the model.


## Returns {"ok": bool, "anchor": Vector2i} for a part held at screen_pos.
static func anchor_from_screen(camera: Camera3D, screen_pos: Vector2, part_id: String,
		rot: int, grid: StudGrid) -> Dictionary:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var point: Vector3
	var space := camera.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 300.0))
	if not hit.is_empty():
		point = hit["position"]
		var n: Vector3 = hit["normal"]
		if absf(n.y) < 0.5:
			# Pointing at the side of a brick: place in the neighbouring column.
			point += n * BrickDefs.STUD * 0.5
	else:
		var p = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
		if p == null:
			return {"ok": false}
		point = p
	var s := BrickDefs.STUD
	var bounds_w := grid.width * s
	var bounds_d := grid.depth * s
	var margin := s * 2.0
	if point.x < -margin or point.z < -margin or point.x > bounds_w + margin or point.z > bounds_d + margin:
		return {"ok": false}
	var fp := BrickDefs.footprint(part_id, rot)
	var anchor := Vector2i(roundi(point.x / s - fp.x * 0.5), roundi(point.z / s - fp.y * 0.5))
	return {"ok": true, "anchor": grid.clamp_anchor(part_id, anchor, rot)}
