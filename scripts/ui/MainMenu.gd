class_name MainMenu
extends Control
## Title screen shown over a turntable of the finished set. On first launch it asks who is
## building (Kids or Grown-ups); afterwards it shows the set card and the current mode.

signal play_pressed
signal mode_chosen(mode: String)
signal switch_mode_pressed

var _set_label: Label
var _panel: PanelContainer
var _main_col: VBoxContainer
var _picker_col: VBoxContainer
var _mode_btn: Button
var _shop_btn: Button
var _free_btn: Button


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
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	_panel.add_child(outer)

	var logo := HBoxContainer.new()
	logo.add_theme_constant_override("separation", 4)
	outer.add_child(logo)
	var palette := [Color(0.79, 0.10, 0.09), Color(0.98, 0.78, 0.05), Color(0.05, 0.34, 0.75), Color(0.16, 0.55, 0.20)]
	for c in palette:
		var r := ColorRect.new()
		r.color = c
		r.custom_minimum_size = Vector2(28, 16)
		logo.add_child(r)
	outer.add_child(UiTheme.label("BRICK BUILDER", 52))

	_build_main(outer)
	_build_picker(outer)
	outer.add_child(UiTheme.label("Prototype v0.2", 14, Color(UiTheme.INK, 0.45)))


func _build_main(parent: Control) -> void:
	_main_col = VBoxContainer.new()
	_main_col.add_theme_constant_override("separation", 14)
	parent.add_child(_main_col)
	_main_col.add_child(UiTheme.label("Build sets brick by brick, just like on the table.", 18, Color(UiTheme.INK, 0.7)))

	var card := PanelContainer.new()
	var cs := UiTheme.panel_style(Color(0.93, 0.95, 1.0), 16, 14)
	cs.shadow_size = 0
	card.add_theme_stylebox_override("panel", cs)
	_main_col.add_child(card)
	var ccol := VBoxContainer.new()
	ccol.add_theme_constant_override("separation", 10)
	card.add_child(ccol)
	ccol.add_child(UiTheme.label("SET #001", 14, Color(UiTheme.INK, 0.55)))
	_set_label = UiTheme.label("", 28)
	ccol.add_child(_set_label)
	var play := Button.new()
	play.text = "Open the box!"
	play.add_theme_font_size_override("font_size", 28)
	play.pressed.connect(func(): play_pressed.emit())
	ccol.add_child(play)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_main_col.add_child(row)
	_free_btn = Button.new()
	_free_btn.text = "Free Build (soon)"
	_free_btn.disabled = true
	row.add_child(_free_btn)
	_shop_btn = Button.new()
	_shop_btn.text = "Set packs (soon)"
	_shop_btn.disabled = true
	row.add_child(_shop_btn)

	_mode_btn = Button.new()
	_mode_btn.add_theme_font_size_override("font_size", 16)
	_mode_btn.add_theme_stylebox_override("normal", UiTheme.button_style(Color(0.92, 0.92, 0.92), Color(0.7, 0.7, 0.7)))
	_mode_btn.pressed.connect(func(): switch_mode_pressed.emit())
	_main_col.add_child(_mode_btn)


func _build_picker(parent: Control) -> void:
	_picker_col = VBoxContainer.new()
	_picker_col.add_theme_constant_override("separation", 14)
	_picker_col.visible = false
	parent.add_child(_picker_col)
	_picker_col.add_child(UiTheme.label("Who is building today?", 26))
	var kids := _big_choice("Kids", "Ages 6-12. Glowing guide, easy snapping.\nFree, with no ads and no shop.", Color(0.98, 0.78, 0.05))
	kids.pressed.connect(func(): mode_chosen.emit("kids"))
	_picker_col.add_child(kids)
	var adult := _big_choice("Grown-ups", "Bigger sets, booklet building, exact placement.\nTurn pieces yourself.", Color(0.55, 0.75, 1.0))
	adult.pressed.connect(func(): mode_chosen.emit("adult"))
	_picker_col.add_child(adult)


func _big_choice(title: String, body: String, c: Color) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [title, body]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(440, 0)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_stylebox_override("normal", UiTheme.button_style(c, c.darkened(0.25)))
	b.add_theme_stylebox_override("hover", UiTheme.button_style(c.lightened(0.15), c.darkened(0.25)))
	return b


func set_set_info(set_name: String, piece_count: int, bag_count: int) -> void:
	_set_label.text = "%s\n%d pieces - %d bags" % [set_name, piece_count, bag_count]


## Shows either the first-launch mode picker or the normal menu for the given mode.
func show_for(first_run: bool, mode: String) -> void:
	_picker_col.visible = first_run
	_main_col.visible = not first_run
	_shop_btn.visible = mode == "adult"
	_mode_btn.text = "Kids mode  -  switch to Grown-ups" if mode == "kids" else "Grown-ups mode  -  switch to Kids"
