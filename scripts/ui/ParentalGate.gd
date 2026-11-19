class_name ParentalGate
extends Control
## A simple grown-ups check (a multiplication question) before leaving Kids mode.

signal passed
signal cancelled

var _question: Label
var _answers: HBoxContainer
var _status: Label
var _rng := RandomNumberGenerator.new()
var _right := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, 22, 28))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	col.add_child(UiTheme.label("Grown-ups only", 32))
	col.add_child(UiTheme.label("Ask a grown-up to answer this to continue.", 18, Color(UiTheme.INK, 0.7)))
	_question = UiTheme.label("", 30)
	col.add_child(_question)
	_answers = HBoxContainer.new()
	_answers.add_theme_constant_override("separation", 12)
	col.add_child(_answers)
	_status = UiTheme.label("", 18, UiTheme.BAD)
	col.add_child(_status)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func():
		visible = false
		cancelled.emit())
	col.add_child(cancel)


func ask() -> void:
	_rng.randomize()
	var a := _rng.randi_range(6, 9)
	var b := _rng.randi_range(6, 9)
	_right = a * b
	_question.text = "What is %d x %d ?" % [a, b]
	_status.text = ""
	for c in _answers.get_children():
		c.queue_free()
	var options := [_right, _right + a, _right - b, _right + 10]
	options.shuffle()
	for o in options:
		var btn := Button.new()
		btn.text = str(o)
		btn.custom_minimum_size = Vector2(90, 0)
		btn.pressed.connect(func():
			if o == _right:
				visible = false
				passed.emit()
			else:
				_status.text = "Not quite. Try again with a grown-up."
				ask())
		_answers.add_child(btn)
	visible = true
