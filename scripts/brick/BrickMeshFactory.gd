class_name BrickMeshFactory
extends RefCounted
## Builds brick meshes procedurally (body + studs) so the game needs no external 3D assets.
## Brick meshes are centred on X/Z with their bottom at y = 0.

const STUD_RADIUS := 0.24
const STUD_HEIGHT := 0.17
const STUD_SEGMENTS := 18
const GAP := 0.012 # small inset so neighbouring bricks show a seam

static var _cache := {}


static func get_mesh(part_id: String) -> ArrayMesh:
	if _cache.has(part_id):
		return _cache[part_id]
	var p := BrickDefs.part(part_id)
	var size: Vector2i = p["size"]
	var mesh: ArrayMesh
	if p["shape"] == "slope":
		mesh = _build_slope(size, BrickDefs.height(part_id))
	else:
		mesh = _build_box_brick(size, BrickDefs.height(part_id))
	_cache[part_id] = mesh
	return mesh


## Baseplate with its top surface at y = 0 and its corner at the origin.
static func build_baseplate(w: int, d: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := BrickDefs.STUD
	_add_box(st, Vector3(0, -0.12, 0), Vector3(w * s, 0, d * s))
	for i in w:
		for j in d:
			_add_stud(st, Vector3((i + 0.5) * s, 0, (j + 0.5) * s))
	return st.commit()


static func _build_box_brick(size: Vector2i, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := BrickDefs.STUD
	var hw := size.x * s * 0.5
	var hd := size.y * s * 0.5
	_add_box(st, Vector3(-hw + GAP, 0, -hd + GAP), Vector3(hw - GAP, h, hd - GAP))
	for i in size.x:
		for j in size.y:
			_add_stud(st, Vector3(-hw + (i + 0.5) * s, h, -hd + (j + 0.5) * s))
	return st.commit()


## Slope at rotation 0: one flat row of studs at the back (-Z), descending toward +Z.
static func _build_slope(size: Vector2i, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := BrickDefs.STUD
	var x0 := -size.x * s * 0.5 + GAP
	var x1 := size.x * s * 0.5 - GAP
	var z0 := -size.y * s * 0.5 + GAP
	var z1 := size.y * s * 0.5 - GAP
	var zr := z0 + s - GAP # end of the flat stud row
	var lip := 0.14
	# bottom
	_add_quad(st, Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3.DOWN)
	# back
	_add_quad(st, Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, h, z0), Vector3(x0, h, z0), Vector3.FORWARD)
	# flat top row
	_add_quad(st, Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, zr), Vector3(x0, h, zr), Vector3.UP)
	# slope face
	var slope_n := Vector3(0, z1 - zr, h - lip).normalized()
	_add_quad(st, Vector3(x0, h, zr), Vector3(x1, h, zr), Vector3(x1, lip, z1), Vector3(x0, lip, z1), slope_n)
	# front lip
	_add_quad(st, Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, lip, z1), Vector3(x0, lip, z1), Vector3.BACK)
	# sides (convex pentagons)
	for x in [x0, x1]:
		var n := Vector3.LEFT if x == x0 else Vector3.RIGHT
		var pts := [
			Vector3(x, 0, z0), Vector3(x, 0, z1), Vector3(x, lip, z1),
			Vector3(x, h, zr), Vector3(x, h, z0),
		]
		for k in range(1, pts.size() - 1):
			_add_tri(st, pts[0], pts[k], pts[k + 1], n)
	var hw := size.x * s * 0.5
	for i in size.x:
		_add_stud(st, Vector3(-hw + (i + 0.5) * s, h, z0 - GAP + 0.5 * s))
	return st.commit()


# --- geometry helpers -------------------------------------------------------
# Godot treats clockwise triangles as front faces; these helpers fix winding from the normal.

static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)


static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_add_tri(st, a, b, c, n)
	_add_tri(st, a, c, d, n)


static func _add_box(st: SurfaceTool, lo: Vector3, hi: Vector3) -> void:
	var p := [
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
	]
	_add_quad(st, p[0], p[1], p[2], p[3], Vector3.FORWARD) # -Z
	_add_quad(st, p[4], p[5], p[6], p[7], Vector3.BACK) # +Z
	_add_quad(st, p[0], p[4], p[7], p[3], Vector3.LEFT)
	_add_quad(st, p[1], p[5], p[6], p[2], Vector3.RIGHT)
	_add_quad(st, p[3], p[2], p[6], p[7], Vector3.UP)
	_add_quad(st, p[0], p[1], p[5], p[4], Vector3.DOWN)


static func _add_stud(st: SurfaceTool, base: Vector3) -> void:
	var top := base + Vector3(0, STUD_HEIGHT, 0)
	for i in STUD_SEGMENTS:
		var a0 := TAU * i / STUD_SEGMENTS
		var a1 := TAU * (i + 1) / STUD_SEGMENTS
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := base + d0 * STUD_RADIUS
		var b1 := base + d1 * STUD_RADIUS
		var t0 := top + d0 * STUD_RADIUS
		var t1 := top + d1 * STUD_RADIUS
		# side (smooth normals)
		var fn := (d0 + d1).normalized()
		var tris := [[b0, b1, t1, d0, d1, d1], [b0, t1, t0, d0, d1, d0]]
		for tr in tris:
			var va: Vector3 = tr[0]
			var vb: Vector3 = tr[1]
			var vc: Vector3 = tr[2]
			var na: Vector3 = tr[3]
			var nb: Vector3 = tr[4]
			var nc: Vector3 = tr[5]
			if (vb - va).cross(vc - va).dot(fn) > 0.0:
				st.set_normal(na); st.add_vertex(va)
				st.set_normal(nc); st.add_vertex(vc)
				st.set_normal(nb); st.add_vertex(vb)
			else:
				st.set_normal(na); st.add_vertex(va)
				st.set_normal(nb); st.add_vertex(vb)
				st.set_normal(nc); st.add_vertex(vc)
		# cap
		_add_tri(st, top, t0, t1, Vector3.UP)
