class_name StudGrid
extends RefCounted
## Height map over the baseplate. Bricks rest on the highest stud under their footprint,
## which is how physical bricks stack. Cells: x/z in studs, y in plates.

var width: int
var depth: int
var _heights := PackedInt32Array()


func _init(w: int, d: int) -> void:
	width = w
	depth = d
	reset()


func reset() -> void:
	_heights.resize(width * depth)
	_heights.fill(0)


func top_at(x: int, z: int) -> int:
	if x < 0 or z < 0 or x >= width or z >= depth:
		return 0
	return _heights[z * width + x]


func clamp_anchor(part_id: String, anchor: Vector2i, rot: int) -> Vector2i:
	var fp := BrickDefs.footprint(part_id, rot)
	return Vector2i(clampi(anchor.x, 0, width - fp.x), clampi(anchor.y, 0, depth - fp.y))


## Plate level a part would come to rest at when dropped at the given anchor.
func rest_level(part_id: String, anchor: Vector2i, rot: int) -> int:
	var fp := BrickDefs.footprint(part_id, rot)
	var level := 0
	for i in fp.x:
		for j in fp.y:
			level = maxi(level, top_at(anchor.x + i, anchor.y + j))
	return level


func occupy(part_id: String, cell: Vector3i, rot: int) -> void:
	var fp := BrickDefs.footprint(part_id, rot)
	var top := cell.y + BrickDefs.plates(part_id)
	for i in fp.x:
		for j in fp.y:
			var x := cell.x + i
			var z := cell.z + j
			if x >= 0 and z >= 0 and x < width and z < depth:
				_heights[z * width + x] = maxi(_heights[z * width + x], top)


## World position of a part's origin (footprint centre, bottom face) for a grid cell.
static func cell_to_world(part_id: String, cell: Vector3i, rot: int) -> Vector3:
	var fp := BrickDefs.footprint(part_id, rot)
	var s := BrickDefs.STUD
	return Vector3((cell.x + fp.x * 0.5) * s, cell.y * BrickDefs.PLATE_H, (cell.z + fp.y * 0.5) * s)
