class_name Hud
extends Control
## In-build screen: top bar, instruction-booklet callout, parts tray, toasts, completion panel.

signal menu_pressed
signal hint_pressed
signal reset_view_pressed
signal part_picked(part_id: String, color_id: String)
signal rebuild_pressed

var _title: Label
var _step_label: Label
var _progress: ProgressBar
var _booklet_step: Label
var _booklet_preview_holder: Control
var _booklet_name: Label
var _tray_box: HBoxContainer
var _tray_panel: PanelContainer
var _top_bar: PanelContainer
var _booklet: PanelContainer
var _side: VBoxContainer
var _toast: Label
var _toast_tween: Tween
var _done_panel: PanelContainer
var _done_title: Label
var _cards := {}
var _pulse_key := ""
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_bar()
	_build_booklet()
	_build_side_buttons()
	_build_tray()
	_build_toast()
	_build_done_panel()


func _build_top_bar() -> void:
	_top_bar = PanelContainer.new()
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.offset_left = 12
	_top_bar.offset_right = -12
	_top_bar.offset_top = 10
	_top_bar.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, 18, 8))
	add_child(_top_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_top_bar.add_child(row)
	var back := Button.new()
	back.text = "< Menu"
	back.pressed.connect(func(): menu_pressed.emit())
	row.add_child(back)
	_title = UiTheme.label("", 26)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_step_label = UiTheme.label("", 22)
	_step_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_step_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(220, 22)
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress.show_percentage = false
	row.add_child(_progress)


func _build_booklet() -> void:
	_booklet = PanelContainer.new()
	_booklet.position = Vector2(12, 92)
	_booklet.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.99, 0.97, 0.90, 0.95), 16, 12))
	add_child(_booklet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_booklet.add_child(col)
	_booklet_step = UiTheme.label("1", 46)
	col.add_child(_booklet_step)
	var callout := PanelContainer.new()
	var cs := UiTheme.panel_style(Color(0.85, 0.93, 1.0), 10, 6)
	cs.shadow_size = 0
	callout.add_theme_stylebox_override("panel", cs)
	col.add_child(callout)
	var crow := HBoxContainer.new()
	callout.add_child(crow)
	crow.add_child(UiTheme.label("1x", 24))
	_booklet_preview_holder = Control.new()
	_booklet_preview_holder.custom_minimum_size = Vector2(130, 100)
	crow.add_child(_booklet_preview_holder)
	_booklet_name = UiTheme.label("", 16, Color(UiTheme.INK, 0.75))
	col.add_child(_booklet_name)


func _build_side_buttons() -> void:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_right", 14)
	add_child(m)
	_side = VBoxContainer.new()
	_side.size_flags_horizontal = Control.SIZE_SHRINK_END
	_side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_side.add_theme_constant_override("separation", 12)
	m.add_child(_side)
	var hint := Button.new()
	hint.text = "Hint"
	hint.pressed.connect(func(): hint_pressed.emit())
	_side.add_child(hint)
	var reset := Button.new()
	reset.text = "Re-center"
	reset.pressed.connect(func(): reset_view_pressed.emit())
	_side.add_child(reset)


func _build_tray() -> void:
	_tray_panel = PanelContainer.new()
	_tray_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.20, 0.22, 0.28, 0.88), 20, 10))
	_bottom_holder(10).add_child(_tray_panel)
	var col := VBoxContainer.new()
	_tray_panel.add_child(col)
	var hdr := UiTheme.label("PARTS BAG  -  drag the right piece onto the glowing spot", 15, Color(1, 1, 1, 0.8))
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hdr)
	_tray_box = HBoxContainer.new()
	_tray_box.add_theme_constant_override("separation", 10)
	_tray_box.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_tray_box)


## Full-screen, click-through container that centres its child along the bottom edge.
func _bottom_holder(bottom_margin: int) -> Control:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_bottom", bottom_margin)
	add_child(m)
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_END
	m.add_child(c)
	return c


func _build_toast() -> void:
	_toast = UiTheme.label("", 26, Color.WHITE)
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 96
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_toast.modulate.a = 0.0
	add_child(_toast)


func _build_done_panel() -> void:
	_done_panel = PanelContainer.new()
	_done_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, 22, 20))
	_done_panel.visible = false
	_bottom_holder(24).add_child(_done_panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	_done_panel.add_child(col)
	_done_title = UiTheme.label("Set complete!", 34)
	_done_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_done_title)
	var sub := UiTheme.label("Spin it around and admire your build.", 18, Color(UiTheme.INK, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var again := Button.new()
	again.text = "Build again"
	again.pressed.connect(func(): rebuild_pressed.emit())
	row.add_child(again)
	var menu := Button.new()
	menu.text = "Main menu"
	menu.pressed.connect(func(): menu_pressed.emit())
	row.add_child(menu)


# --- updates -----------------------------------------------------------------

func set_title(t: String) -> void:
	_title.text = t


func show_step(index: int, total: int, step: Dictionary, bag: Array) -> void:
	var done := step.is_empty()
	_step_label.text = "Step %d / %d" % [mini(index + 1, total), total]
	_progress.max_value = total
	_progress.value = index
	_booklet.visible = not done
	_tray_panel.visible = not done
	_side.visible = not done
	_done_panel.visible = done
	if done:
		_step_label.text = "Complete!"
		return
	_booklet_step.text = str(index + 1)
	_booklet_name.text = "%s %s" % [BrickDefs.color_label(step["color"]), BrickDefs.part_name(step["part"])]
	for c in _booklet_preview_holder.get_children():
		c.queue_free()
	var pv := PartPreview.new()
	pv.setup(step["part"], step["color"], Vector2i(130, 100))
	_booklet_preview_holder.add_child(pv)
	_rebuild_tray(bag)


func _rebuild_tray(bag: Array) -> void:
	for c in _tray_box.get_children():
		c.queue_free()
	_cards.clear()
	_pulse_key = ""
	for item in bag:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(1, 1, 1, 0.95), 14, 6))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_DRAG
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 0)
		card.add_child(col)
		var pv := PartPreview.new()
		pv.setup(item["part"], item["color"], Vector2i(124, 86))
		col.add_child(pv)
		var lbl := UiTheme.label("%s  x%d" % [BrickDefs.part_name(item["part"]).replace(" Brick", "").replace(" Plate", " plate").replace(" Slope", " slope"), item["count"]], 16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(lbl)
		var part_id: String = item["part"]
		var color_id: String = item["color"]
		card.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				part_picked.emit(part_id, color_id)
				card.accept_event())
		_tray_box.add_child(card)
		_cards["%s|%s" % [part_id, color_id]] = card


func pulse_card(part_id: String, color_id: String) -> void:
	_pulse_key = "%s|%s" % [part_id, color_id]
	_time = 0.0


func _process(delta: float) -> void:
	_time += delta
	for key in _cards:
		var card: Control = _cards[key]
		if not is_instance_valid(card):
			continue
		if key == _pulse_key and _time < 2.5:
			var k := 0.5 + 0.5 * sin(_time * 12.0)
			card.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.9, 0.3), k)
		else:
			card.modulate = Color.WHITE


func toast(text: String, good: bool) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75) if good else Color(1.0, 0.82, 0.78))
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2 if good else 2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


## True if a screen point is over an interactive HUD element (used to stop camera orbiting).
func is_point_over_ui(p: Vector2) -> bool:
	if not visible:
		return false
	for c in [_top_bar, _booklet, _side, _tray_panel, _done_panel]:
		if c.visible and c.get_global_rect().has_point(p):
			return true
	return false
