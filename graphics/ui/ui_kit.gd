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

## A pixel look for the same kit, opted into per call with `pixel`. Text is
## Silkscreen at a multiple of its native 8px, borders are square and a whole
## number of PIXELs wide, and nothing is antialiased, so a screen built this way
## reads as the same pixel art as the title and the world. The title's settings
## use it; the rest of the interface does not yet.
const PIXEL_FONT := preload("res://graphics/assets/fonts/Silkscreen-Regular.ttf")
const PIXEL := 2
const PIXEL_TEXT := 16

static func style(bg: Color, border: Color, width: int = 1, radius: int = 3,
		pixel: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width * PIXEL if pixel else width)
	s.set_corner_radius_all(0 if pixel else radius)
	s.anti_aliasing = not pixel
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

static func button(text: String, accent: Color = ACCENT, pixel: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", style(PANEL, Color(accent.r, accent.g, accent.b, 0.5), 1, 3, pixel))
	b.add_theme_stylebox_override("hover", style(Color(accent.r, accent.g, accent.b, 0.22), accent, 1, 3, pixel))
	b.add_theme_stylebox_override("pressed", style(Color(accent.r, accent.g, accent.b, 0.35), accent, 1, 3, pixel))
	b.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), accent, 1, 3, pixel))
	b.add_theme_stylebox_override("disabled", style(Color(0.1, 0.1, 0.12), Color(0.25, 0.27, 0.3), 1, 3, pixel))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.46))
	if pixel:
		b.add_theme_font_override("font", PIXEL_FONT)
	b.add_theme_font_size_override("font_size", PIXEL_TEXT if pixel else 13)
	return b

## A button layered over a running game. It never takes keyboard focus, so the
## keys the player is playing with keep reaching the game after they click one:
## a focusable button swallows SPACE as "press me again" and TAB as "move to
## the next button", which costs the player a jump or the assembly screen.
## Menus use `button` — there, keyboard and gamepad navigation is the point.
static func overlay_button(text: String, accent: Color = ACCENT, pixel: bool = false) -> Button:
	var b := button(text, accent, pixel)
	b.focus_mode = Control.FOCUS_NONE
	return b

## The cooldown state a skill slot shows, drawn over the card and shared by
## every screen that lists slots so they cannot drift apart.
## `PixelDraw.cooldown` is this same wipe on the pixel grid, for the screens
## drawn that way; what it means is described here.
##
## `progress` runs 0 → 1 as the skill recovers. The grey sheet covers what is
## left of the wait and its upper edge is the clock hand: it starts at the top
## of the card and slides to the bottom, leaving the card clear when it lands.
## `flash` fades 1 → 0 just after it lands and brightens the card's edge, so a
## skill coming back announces itself to a player who is watching the fight
## rather than the bar.
static func draw_cooldown(c: CanvasItem, rect: Rect2, progress: float, flash: float,
		border: Color) -> void:
	var p := clampf(progress, 0.0, 1.0)
	if p < 1.0:
		var top := rect.position.y + rect.size.y * p
		c.draw_rect(Rect2(rect.position.x, top, rect.size.x, rect.end.y - top),
			Color(0.55, 0.58, 0.65, 0.55))
		# A lit edge on the sheet, so the slide reads even on a short cooldown.
		c.draw_line(Vector2(rect.position.x, top), Vector2(rect.end.x, top),
			Color(0.85, 0.9, 1.0, 0.75), 1.0)
	var f := clampf(flash, 0.0, 1.0)
	c.draw_rect(rect, border.lerp(Color(1, 1, 1), f * 0.85), false, 1.5 + 2.5 * f)

static func label(text: String, size: int = 13, color: Color = TEXT, pixel: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	if pixel:
		# Silkscreen only draws clean at multiples of its native 8px.
		l.add_theme_font_override("font", PIXEL_FONT)
		size = maxi(PIXEL_TEXT, snappedi(size, 8))
	l.add_theme_font_size_override("font_size", size)
	return l

static func panel(color: Color = PANEL, border: Color = Color(0.22, 0.3, 0.38),
		pixel: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(color, border, 1, 3, pixel))
	return p

static func title(text: String, size: int = 22, pixel: bool = false) -> Label:
	return label(text, size, Color(0.9, 0.95, 1.0), pixel)

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

## A column that always fits the screen, scrolling whatever will not.
##
## The menus here are built as a VBox at a fixed position, which quietly grows
## off the bottom as soon as a row is added: two new rebindable actions were
## enough to push the ABANDON RAID button out of the pause menu entirely, with
## nothing on screen to say it was there. Keeping the height tied to the
## viewport means that cannot happen again, on any window size.
class ScreenScroll extends ScrollContainer:
	var top_left := Vector2(430, 40)
	var content_width := 470.0
	var bottom_margin := 28.0

	func _ready() -> void:
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_fit()

	func _process(_delta: float) -> void:
		_fit()

	func _fit() -> void:
		position = top_left
		var vp := get_viewport_rect().size
		size = Vector2(content_width, maxf(vp.y - top_left.y - bottom_margin, 120.0))

static func screen_scroll(content: Control, at: Vector2, width: float) -> ScrollContainer:
	var sc := ScreenScroll.new()
	sc.top_left = at
	sc.content_width = width
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc

static func spacer(h: int = 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

static func hline(pixel: bool = false) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.25, 0.32, 0.4, 0.7)
	r.custom_minimum_size = Vector2(0, PIXEL if pixel else 1)
	return r

## A slider in the pixel look: a flat track whose filled part is the accent, and
## a square knob in place of the theme's round one.
static func pixel_slider(s: Slider) -> void:
	s.add_theme_stylebox_override("slider", _pixel_box(LINE, PIXEL))
	s.add_theme_stylebox_override("grabber_area", _pixel_box(ACCENT, PIXEL))
	s.add_theme_stylebox_override("grabber_area_highlight", _pixel_box(ACCENT, PIXEL))
	s.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), ACCENT, 1, 0, true))
	s.add_theme_icon_override("grabber", _pixel_knob(TEXT))
	s.add_theme_icon_override("grabber_highlight", _pixel_knob(Color.WHITE))
	s.add_theme_icon_override("grabber_disabled", _pixel_knob(DIM))

## A scroll container in the pixel look: flat, square bars four PIXELs wide, and
## a square focus border in place of the theme's rounded one, which the
## container draws through an internal panel of its own.
static func pixel_scroll(sc: ScrollContainer) -> void:
	sc.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), ACCENT, 1, 0, true))
	for bar: ScrollBar in [sc.get_v_scroll_bar(), sc.get_h_scroll_bar()]:
		bar.add_theme_stylebox_override("scroll", _pixel_box(PANEL, PIXEL * 2))
		bar.add_theme_stylebox_override("scroll_focus", _pixel_box(PANEL, PIXEL * 2))
		bar.add_theme_stylebox_override("grabber", _pixel_box(LINE, PIXEL * 2))
		bar.add_theme_stylebox_override("grabber_highlight", _pixel_box(ACCENT, PIXEL * 2))
		bar.add_theme_stylebox_override("grabber_pressed", _pixel_box(ACCENT, PIXEL * 2))

## A flat, borderless, unsmoothed box. Its margins are what give a slider track
## or a scrollbar its thickness.
static func _pixel_box(bg: Color, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.anti_aliasing = false
	s.set_content_margin_all(margin)
	return s

## The slider knob: a block of `fill` inside a one-PIXEL dark border.
static func _pixel_knob(fill: Color) -> ImageTexture:
	var img := Image.create_empty(PIXEL * 6, PIXEL * 8, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	img.fill_rect(Rect2i(PIXEL, PIXEL, PIXEL * 4, PIXEL * 6), fill)
	return ImageTexture.create_from_image(img)
