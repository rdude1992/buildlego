class_name MainMenu
extends Control
## Title screen shown over a turntable of the finished set.

signal play_pressed

var _set_label: Label
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 48)
	add_child(margin)
	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, 26, 28))
	margin.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)

	var logo := HBoxContainer.new()
	logo.add_theme_constant_override("separation", 4)
	col.add_child(logo)
	var palette := [Color(0.79, 0.10, 0.09), Color(0.98, 0.78, 0.05), Color(0.05, 0.34, 0.75), Color(0.16, 0.55, 0.20)]
	for c in palette:
		var r := ColorRect.new()
		r.color = c
		r.custom_minimum_size = Vector2(28, 16)
		logo.add_child(r)

	col.add_child(UiTheme.label("BRICK BUILDER", 52))
	col.add_child(UiTheme.label("Build sets brick by brick, just like on the table.", 18, Color(UiTheme.INK, 0.7)))

	var card := PanelContainer.new()
	var cs := UiTheme.panel_style(Color(0.93, 0.95, 1.0), 16, 14)
	cs.shadow_size = 0
	card.add_theme_stylebox_override("panel", cs)
	col.add_child(card)
	var ccol := VBoxContainer.new()
	ccol.add_theme_constant_override("separation", 10)
	card.add_child(ccol)
	ccol.add_child(UiTheme.label("SET #001", 14, Color(UiTheme.INK, 0.55)))
	_set_label = UiTheme.label("", 28)
	ccol.add_child(_set_label)
	var play := Button.new()
	play.text = "Build it!"
	play.add_theme_font_size_override("font_size", 28)
	play.pressed.connect(func(): play_pressed.emit())
	ccol.add_child(play)

	var free := Button.new()
	free.text = "Free Build  (coming soon)"
	free.disabled = true
	col.add_child(free)
	col.add_child(UiTheme.label("Prototype v0.1", 14, Color(UiTheme.INK, 0.45)))


func set_set_info(set_name: String, step_count: int) -> void:
	_set_label.text = "%s  -  %d steps" % [set_name, step_count]
