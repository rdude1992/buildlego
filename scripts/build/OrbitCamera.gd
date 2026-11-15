class_name OrbitCamera
extends Camera3D
## Orbit camera. Touch: one finger rotates, two fingers pinch-zoom and pan.
## Mouse: left-drag rotates, right/middle-drag pans, wheel zooms.

var target := Vector3.ZERO
var yaw := 0.55
var pitch := 0.55
var distance := 14.0
var min_distance := 5.0
var max_distance := 30.0
var auto_rotate := false
var input_enabled := true
## Returns true when a screen point is covered by UI; such touches are ignored.
var is_ui_point: Callable = func(_p: Vector2) -> bool: return false

var _home := {}
var _touches := {} # index -> position
var _ignored_touches := {}
var _mouse_orbit := false
var _mouse_pan := false
var _pinch_dist := 0.0
var _pinch_mid := Vector2.ZERO


func set_home(p_target: Vector3, p_yaw: float, p_pitch: float, p_distance: float) -> void:
	_home = {"target": p_target, "yaw": p_yaw, "pitch": p_pitch, "distance": p_distance}
	reset_view()


func reset_view() -> void:
	if _home.is_empty():
		return
	target = _home["target"]
	yaw = _home["yaw"]
	pitch = _home["pitch"]
	distance = _home["distance"]
	_apply()


func _process(delta: float) -> void:
	if auto_rotate:
		yaw += delta * 0.25
	_apply()


func _apply() -> void:
	pitch = clampf(pitch, 0.08, 1.45)
	distance = clampf(distance, min_distance, max_distance)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	position = target + dir * distance
	look_at(target, Vector3.UP)


func _orbit(rel: Vector2) -> void:
	yaw -= rel.x * 0.008
	pitch += rel.y * 0.006


func _pan(rel: Vector2) -> void:
	var right := global_transform.basis.x
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var k := distance * 0.0015
	target += (-right * rel.x + fwd * rel.y) * k


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		if event is InputEventScreenTouch and not event.pressed:
			_touches.erase(event.index)
			_ignored_touches.erase(event.index)
		_mouse_orbit = false
		_mouse_pan = false
		return
	# Touch (real touchscreens). Emulated mouse events from touch are ignored below.
	if event is InputEventScreenTouch:
		if event.pressed:
			if is_ui_point.call(event.position):
				_ignored_touches[event.index] = true
				return
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
			_ignored_touches.erase(event.index)
		_pinch_dist = 0.0
		return
	if event is InputEventScreenDrag:
		if _ignored_touches.has(event.index) or not _touches.has(event.index):
			return
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_orbit(event.relative)
		elif _touches.size() >= 2:
			var pts: Array = _touches.values()
			var a: Vector2 = pts[0]
			var b: Vector2 = pts[1]
			var dist := a.distance_to(b)
			var mid := (a + b) * 0.5
			if _pinch_dist > 0.0:
				distance *= _pinch_dist / maxf(dist, 1.0)
				_pan(mid - _pinch_mid)
			_pinch_dist = dist
			_pinch_mid = mid
		return

	if event.device == -1: # mouse emulated from touch
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_mouse_orbit = event.pressed
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_mouse_pan = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				distance *= 0.9
			MOUSE_BUTTON_WHEEL_DOWN:
				distance *= 1.1
	elif event is InputEventMouseMotion:
		if _mouse_orbit:
			_orbit(event.relative)
		elif _mouse_pan:
			_pan(event.relative)
