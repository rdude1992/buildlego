class_name Profile
extends RefCounted
## The player's saved settings: Kids or Adult mode and preferred help level.
## Stored as JSON in the app's private storage (user://).

const PATH := "user://profile.json"

static var data := {}


static func load_profile() -> void:
	data = {"mode": "", "guidance": {}}
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			data.merge(parsed, true)


static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


static func is_first_run() -> bool:
	return data.get("mode", "") == ""


static func mode() -> String:
	var m: String = data.get("mode", "")
	return m if m != "" else "kids"


static func is_kids() -> bool:
	return mode() == "kids"


static func set_mode(m: String) -> void:
	data["mode"] = m
	save()


static func guidance() -> String:
	var g: Dictionary = data.get("guidance", {})
	return g.get(mode(), "guided" if is_kids() else "booklet")


static func set_guidance(g: String) -> void:
	if not data.has("guidance") or not data["guidance"] is Dictionary:
		data["guidance"] = {}
	data["guidance"][mode()] = g
	save()
