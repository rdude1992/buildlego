class_name BoxScreen
extends Control
## The physical-kit ritual: the set box (swipe to cut the tape), then numbered bags that are
## opened one at a time. Also shown between bags ("Bag 1 done - open bag 2").

signal tape_cut
signal bag_open_requested(bag_index: int)
signal guidance_changed(guidance: String)
signal back_pressed

const BOX_W := 560.0
const BOX_H := 400.0

var _dim: ColorRect
var _box_holder: Control
var _box_panel: PanelContainer
var _preview_holder: Control
var _set_label: Label
var _info_label: Label
var _age_label: Label
var _tape: Control
var _tape_cut: ColorRect
var _tape_hint: Label
var _drag_from := -1.0
var _cut_done := false
var _options_row: HBoxContainer
var _guided_btn: Button
var _booklet_btn: Button
var _back_btn: Button
var _bags_panel: VBoxContainer
var _bags_title: Label
var _bags_row: HBoxContainer
var _bag_widgets: Array = []
var _sfx: Sfx


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.10, 0.12, 0.18, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	_build_box(col)
	_build_options(col)
	_build_bags(col)


func set_sfx(s: Sfx) -> void:
	_sfx = s


func _build_box(parent: Control) -> void:
	_box_holder = Control.new()
	_box_holder.custom_minimum_size = Vector2(BOX_W, BOX_H)
	_box_holder.pivot_offset = Vector2(BOX_W, BOX_H) * 0.5
	_box_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_box_holder)

	_box_panel = PanelContainer.new()
	_box_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := UiTheme.panel_style(Color(0.80, 0.12, 0.10), 10, 0)
	sb.content_margin_bottom = 22
	sb.border_width_bottom = 14
	sb.border_color = Color(0.98, 0.78, 0.05)
	sb.shadow_size = 18
	_box_panel.add_theme_stylebox_override("panel", sb)
	_box_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_holder.add_child(_box_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_panel.add_child(col)

	var band := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.98, 0.78, 0.05)
	bs.corner_radius_top_left = 10
	bs.corner_radius_top_right = 10
	bs.set_content_margin_all(8)
	band.add_theme_stylebox_override("panel", bs)
	col.add_child(band)
	var brow := HBoxContainer.new()
	band.add_child(brow)
	brow.add_child(UiTheme.label("  BRICK BUILDER", 18, UiTheme.INK))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(sp)
	_age_label = UiTheme.label("6+", 20, Color.WHITE)
	var age := PanelContainer.new()
	var ag := StyleBoxFlat.new()
	ag.bg_color = Color(0.05, 0.34, 0.75)
	ag.set_corner_radius_all(8)
	ag.content_margin_left = 10
	ag.content_margin_right = 10
	age.add_theme_stylebox_override("panel", ag)
	age.add_child(_age_label)
	brow.add_child(age)

	_set_label = UiTheme.label("", 34, Color.WHITE)
	_set_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label.add_theme_constant_override("outline_size", 6)
	_set_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	col.add_child(_set_label)
	_preview_holder = CenterContainer.new()
	_preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_preview_holder)
	_info_label = UiTheme.label("", 18, Color(1, 1, 1, 0.9))
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_info_label)

	# Packing tape across the box. Swipe along it to cut it open.
	_tape = Control.new()
	_tape.anchor_left = 0.0
	_tape.anchor_right = 1.0
	_tape.offset_top = -10
	_tape.offset_bottom = 46
	_tape.offset_left = -24
	_tape.offset_right = 24
	_tape.mouse_filter = Control.MOUSE_FILTER_STOP
	_tape.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_box_holder.add_child(_tape)
	var tape_body := ColorRect.new()
	tape_body.color = Color(0.93, 0.86, 0.66, 0.82)
	tape_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tape_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tape.add_child(tape_body)
	_tape_cut = ColorRect.new()
	_tape_cut.color = Color(0.25, 0.18, 0.08, 0.85)
	_tape_cut.anchor_top = 0.5
	_tape_cut.anchor_bottom = 0.5
	_tape_cut.offset_top = -2
	_tape_cut.offset_bottom = 2
	_tape_cut.size.x = 0
	_tape_cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tape.add_child(_tape_cut)
	_tape_hint = UiTheme.label("Swipe along the tape to open  >>>", 20, Color(0.35, 0.25, 0.10))
	_tape_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tape_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tape_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tape_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tape.add_child(_tape_hint)
	_tape.gui_input.connect(_on_tape_input)


func _build_options(parent: Control) -> void:
	_options_row = HBoxContainer.new()
	_options_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_options_row.add_theme_constant_override("separation", 12)
	parent.add_child(_options_row)
	_back_btn = Button.new()
	_back_btn.text = "< Back"
	_back_btn.pressed.connect(func(): back_pressed.emit())
	_options_row.add_child(_back_btn)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(24, 0)
	_options_row.add_child(gap)
	_options_row.add_child(UiTheme.label("Help:", 22, Color.WHITE))
	var group := ButtonGroup.new()
	_guided_btn = Button.new()
	_guided_btn.text = "Glowing guide"
	_guided_btn.toggle_mode = true
	_guided_btn.button_group = group
	_guided_btn.pressed.connect(func(): guidance_changed.emit("guided"))
	_options_row.add_child(_guided_btn)
	_booklet_btn = Button.new()
	_booklet_btn.text = "Booklet only"
	_booklet_btn.toggle_mode = true
	_booklet_btn.button_group = group
	_booklet_btn.pressed.connect(func(): guidance_changed.emit("booklet"))
	_options_row.add_child(_booklet_btn)
	for b in [_guided_btn, _booklet_btn]:
		var on := UiTheme.button_style(Color(0.20, 0.70, 0.30), Color(0.12, 0.5, 0.2))
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("normal", UiTheme.button_style(Color(0.92, 0.92, 0.92), Color(0.7, 0.7, 0.7)))
		b.add_theme_color_override("font_pressed_color", Color.WHITE)


func _build_bags(parent: Control) -> void:
	_bags_panel = VBoxContainer.new()
	_bags_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_bags_panel.add_theme_constant_override("separation", 14)
	_bags_panel.visible = false
	parent.add_child(_bags_panel)
	_bags_title = UiTheme.label("", 32, Color.WHITE)
	_bags_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bags_title.add_theme_constant_override("outline_size", 6)
	_bags_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	_bags_panel.add_child(_bags_title)
	_bags_row = HBoxContainer.new()
	_bags_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_bags_row.add_theme_constant_override("separation", 18)
	_bags_panel.add_child(_bags_row)


# --- public ------------------------------------------------------------------

## Shows the closed box for a set.
func show_box(set_name: String, steps: Array, bag_count: int, kids: bool, guidance: String) -> void:
	visible = true
	_cut_done = false
	_box_holder.visible = true
	_box_holder.scale = Vector2.ONE
	_box_holder.modulate = Color.WHITE
	_box_holder.position.y = 0
	_tape.visible = true
	_tape_cut.size.x = 0
	_tape_hint.text = "Swipe along the tape to open  >>>"
	_options_row.visible = true
	_bags_panel.visible = false
	_set_label.text = set_name
	_age_label.text = "6+" if kids else "13+"
	_info_label.text = "%d pieces  -  %d numbered bags" % [steps.size(), bag_count]
	_guided_btn.button_pressed = guidance == "guided"
	_booklet_btn.button_pressed = guidance != "guided"
	for c in _preview_holder.get_children():
		c.queue_free()
	var art := ModelPreview.new()
	art.zoom = 0.6
	art.setup(steps, Vector2i(500, 230))
	art.show_steps(steps.size())
	art.spin = true
	_preview_holder.add_child(art)


## Shows the row of bags; `next` is the one that can be opened now.
func show_bags(next: int, bag_count: int, title: String) -> void:
	visible = true
	_box_holder.visible = false
	_options_row.visible = false
	_bags_panel.visible = true
	_bags_title.text = title
	for w in _bag_widgets:
		w.queue_free()
	_bag_widgets.clear()
	for i in bag_count:
		var w := _make_bag(i, next)
		_bags_row.add_child(w)
		_bag_widgets.append(w)
	if next < _bag_widgets.size():
		var w: Control = _bag_widgets[next]
		var tw := w.create_tween().set_loops()
		tw.tween_property(w, "scale", Vector2(1.06, 1.06), 0.5)
		tw.tween_property(w, "scale", Vector2.ONE, 0.5)


func _make_bag(i: int, next: int) -> Control:
	var w := PanelContainer.new()
	w.custom_minimum_size = Vector2(130, 170)
	w.pivot_offset = Vector2(65, 85)
	var sb := StyleBoxFlat.new()
	var state := "done" if i < next else ("open" if i == next else "locked")
	sb.bg_color = Color(1, 1, 1, 0.75) if state == "open" else Color(1, 1, 1, 0.3)
	sb.border_color = Color(1, 1, 1, 0.95)
	sb.set_border_width_all(3)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 22
	sb.corner_radius_bottom_right = 22
	sb.set_content_margin_all(10)
	w.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.add_child(col)
	var num := UiTheme.label(str(i + 1), 64, UiTheme.INK if state == "open" else Color(1, 1, 1, 0.8))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(num)
	var sub_text: String = {"done": "Built", "open": "Tap to tear", "locked": "Later"}[state]
	var sub := UiTheme.label(sub_text, 16, UiTheme.INK if state == "open" else Color(1, 1, 1, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	if state == "open":
		w.mouse_filter = Control.MOUSE_FILTER_STOP
		w.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		w.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_tear(w, i))
	else:
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return w


func _tear(w: Control, i: int) -> void:
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _sfx:
		_sfx.play("rip", 0.0, false)
	Sfx.buzz(40)
	var tw := create_tween()
	for k in 4:
		tw.tween_property(w, "rotation", 0.08 if k % 2 == 0 else -0.08, 0.05)
	tw.tween_property(w, "rotation", 0.0, 0.04)
	tw.tween_property(w, "scale", Vector2(1.35, 0.6), 0.12)
	tw.parallel().tween_property(w, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func():
		visible = false
		bag_open_requested.emit(i))


# --- tape cutting ---------------------------------------------------------------

func _on_tape_input(ev: InputEvent) -> void:
	if _cut_done:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_drag_from = ev.position.x
		else:
			_drag_from = -1.0
			if _tape_cut.size.x < _tape.size.x * 0.6:
				_tape_cut.size.x = 0
				_tape_hint.text = "Swipe all the way along the tape  >>>"
	elif ev is InputEventMouseMotion and _drag_from >= 0.0:
		var from := minf(_drag_from, ev.position.x)
		var to := maxf(_drag_from, ev.position.x)
		_tape_cut.position.x = from
		_tape_cut.size.x = to - from
		if _tape_cut.size.x >= _tape.size.x * 0.6:
			cut_tape()


## Opens the box (also used by automation).
func cut_tape() -> void:
	if _cut_done:
		return
	_cut_done = true
	if _sfx:
		_sfx.play("tape", 0.0, false)
	Sfx.buzz(30)
	_tape_cut.position.x = 0
	_tape_cut.size.x = _tape.size.x
	var tw := create_tween()
	tw.tween_property(_tape, "modulate:a", 0.0, 0.2)
	tw.tween_property(_box_holder, "scale", Vector2(1.05, 1.05), 0.12)
	tw.tween_property(_box_holder, "position:y", _box_holder.position.y - 500.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_box_holder, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): tape_cut.emit())
