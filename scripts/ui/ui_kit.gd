class_name UiKit
extends RefCounted

## Small helpers so every screen shares one look without a theme resource file.

const BG := Color(0.055, 0.06, 0.08)
const PANEL := Color(0.09, 0.10, 0.13)
const LINE := Color(0.28, 0.38, 0.48)
const TEXT := Color(0.86, 0.9, 0.96)
const DIM := Color(0.55, 0.62, 0.70)
const ACCENT := Color(0.45, 0.85, 1.0)
const GOOD := Color(0.45, 0.95, 0.7)
const WARN := Color(0.98, 0.72, 0.38)
const BAD := Color(0.95, 0.45, 0.45)

static func style(bg: Color, border: Color, width: int = 1, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

static func button(text: String, accent: Color = ACCENT) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", style(PANEL, Color(accent.r, accent.g, accent.b, 0.5)))
	b.add_theme_stylebox_override("hover", style(Color(accent.r, accent.g, accent.b, 0.22), accent))
	b.add_theme_stylebox_override("pressed", style(Color(accent.r, accent.g, accent.b, 0.35), accent))
	b.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), accent))
	b.add_theme_stylebox_override("disabled", style(Color(0.1, 0.1, 0.12), Color(0.25, 0.27, 0.3)))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.46))
	b.add_theme_font_size_override("font_size", 13)
	return b

static func label(text: String, size: int = 13, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	return l

static func panel(color: Color = PANEL, border: Color = Color(0.22, 0.3, 0.38)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(color, border))
	return p

static func title(text: String, size: int = 22) -> Label:
	var l := label(text, size, Color(0.9, 0.95, 1.0))
	return l

## A Control parented to a CanvasLayer does not inherit the viewport rect, so
## full-screen screens have to be sized explicitly (and kept in sync on resize).
static func fill_screen(c: Control) -> void:
	# Top-left anchors, explicit size: full-rect anchors refuse a direct resize.
	c.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	c.position = Vector2.ZERO
	c.size = c.get_viewport_rect().size

static func sync_screen(c: Control) -> void:
	var want := c.get_viewport_rect().size
	if c.size != want:
		c.size = want

static func spacer(h: int = 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

static func hline() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.25, 0.32, 0.4, 0.7)
	r.custom_minimum_size = Vector2(0, 1)
	return r
