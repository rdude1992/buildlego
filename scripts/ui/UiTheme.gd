class_name UiTheme
extends RefCounted
## Shared look for all screens: rounded, chunky, toy-like.

const INK := Color(0.13, 0.14, 0.18)
const PAPER := Color(1, 1, 1, 0.94)
const ACCENT := Color(0.98, 0.78, 0.05) # yellow
const ACCENT_DARK := Color(0.85, 0.62, 0.0)
const GOOD := Color(0.20, 0.70, 0.30)
const BAD := Color(0.86, 0.22, 0.20)


static func panel_style(bg: Color = PAPER, radius: int = 18, pad: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	sb.border_width_bottom = 5
	sb.border_color = border
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	return sb


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.45))
	t.set_stylebox("normal", "Button", button_style(ACCENT, ACCENT_DARK))
	t.set_stylebox("hover", "Button", button_style(ACCENT.lightened(0.15), ACCENT_DARK))
	var pressed := button_style(ACCENT_DARK, ACCENT_DARK.darkened(0.2))
	pressed.border_width_bottom = 1
	pressed.content_margin_top = 12
	pressed.content_margin_bottom = 6
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", button_style(Color(0.8, 0.8, 0.8), Color(0.65, 0.65, 0.65)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", panel_style())
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.12)
	bar_bg.set_corner_radius_all(8)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GOOD
	bar_fill.set_corner_radius_all(8)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_font_size("font_size", "ProgressBar", 14)
	return t


static func label(text: String, size: int = 22, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
