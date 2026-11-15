class_name BrickDefs
extends RefCounted
## Catalog of brick parts, colors and shared materials.
## Units: 1 stud = STUD world units; heights are measured in plates (1 brick = 3 plates).

const STUD := 0.8
const PLATE_H := 0.32
const BRICK_PLATES := 3

## size = footprint in studs at rotation 0 (x = along world X, y = along world Z).
const PARTS := {
	"brick_1x1": {"name": "1x1 Brick", "size": Vector2i(1, 1), "plates": 3, "shape": "box"},
	"brick_1x2": {"name": "1x2 Brick", "size": Vector2i(2, 1), "plates": 3, "shape": "box"},
	"brick_1x4": {"name": "1x4 Brick", "size": Vector2i(4, 1), "plates": 3, "shape": "box"},
	"brick_2x2": {"name": "2x2 Brick", "size": Vector2i(2, 2), "plates": 3, "shape": "box"},
	"brick_2x4": {"name": "2x4 Brick", "size": Vector2i(4, 2), "plates": 3, "shape": "box"},
	"plate_1x2": {"name": "1x2 Plate", "size": Vector2i(2, 1), "plates": 1, "shape": "box"},
	"plate_2x2": {"name": "2x2 Plate", "size": Vector2i(2, 2), "plates": 1, "shape": "box"},
	"plate_2x4": {"name": "2x4 Plate", "size": Vector2i(4, 2), "plates": 1, "shape": "box"},
	"slope_2x2": {"name": "2x2 Slope", "size": Vector2i(2, 2), "plates": 3, "shape": "slope"},
}

const COLORS := {
	"white": Color(0.90, 0.90, 0.87),
	"red": Color(0.79, 0.10, 0.09),
	"dark_red": Color(0.45, 0.06, 0.07),
	"blue": Color(0.05, 0.34, 0.75),
	"yellow": Color(0.98, 0.78, 0.05),
	"green": Color(0.16, 0.55, 0.20),
	"tan": Color(0.86, 0.76, 0.55),
	"brown": Color(0.42, 0.25, 0.13),
	"dark_gray": Color(0.35, 0.36, 0.38),
	"black": Color(0.10, 0.10, 0.11),
	"orange": Color(0.96, 0.48, 0.07),
	"trans_blue": Color(0.55, 0.82, 1.0, 0.55),
}

const COLOR_NAMES := {
	"white": "White", "red": "Red", "dark_red": "Dark Red", "blue": "Blue",
	"yellow": "Yellow", "green": "Green", "tan": "Tan", "brown": "Brown",
	"dark_gray": "Dark Gray", "black": "Black", "orange": "Orange",
	"trans_blue": "Clear Blue",
}

static var _materials := {}


static func part(id: String) -> Dictionary:
	return PARTS[id]


static func part_name(id: String) -> String:
	return PARTS[id]["name"]


static func color_label(color_id: String) -> String:
	return COLOR_NAMES.get(color_id, color_id)


static func footprint(id: String, rot: int) -> Vector2i:
	var s: Vector2i = PARTS[id]["size"]
	return Vector2i(s.y, s.x) if rot % 2 == 1 else s


static func plates(id: String) -> int:
	return PARTS[id]["plates"]


static func height(id: String) -> float:
	return plates(id) * PLATE_H


## True when two rotations of the same part produce the same placed result.
static func rot_equivalent(id: String, a: int, b: int) -> bool:
	var p: Dictionary = PARTS[id]
	if p["shape"] == "slope":
		return posmod(a, 4) == posmod(b, 4)
	var s: Vector2i = p["size"]
	if s.x == s.y:
		return true
	return posmod(a, 2) == posmod(b, 2)


static func color(color_id: String) -> Color:
	return COLORS.get(color_id, Color.MAGENTA)


static func material(color_id: String) -> StandardMaterial3D:
	if _materials.has(color_id):
		return _materials[color_id]
	var m := StandardMaterial3D.new()
	var c := color(color_id)
	m.albedo_color = c
	m.roughness = 0.42
	m.metallic_specular = 0.45
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.08
	_materials[color_id] = m
	return m
