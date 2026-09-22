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
## reads as the same pixel art as the title and the world. Everything uses it
## now: the menus — the title's settings and the pause menu, which are the same
## rows twice — the hideout's panels, and the screens that draw themselves
## rather than being built out of Controls, which is the assembly screen, the
## bench readout and the raid HUD (see `PixelDraw`).
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
	b.add_theme_font_size_override("font_size", Loc.text_size(text, PIXEL_TEXT) if pixel else 13)
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
		# Silkscreen only draws clean at multiples of its native 8px, and a
		# language writing in a face of its own only at multiples of that.
		l.add_theme_font_override("font", PIXEL_FONT)
		size = Loc.text_size(text, maxi(PIXEL_TEXT, snappedi(size, 8)))
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

## A panel that fits the screen with its page pinned at both ends: a head, a
## foot, and between them the rows — the one part of it that scrolls.
##
## Every menu here is that shape: a title, a list, and the way out of it. Built
## as one column inside a scroll, which is what they all were, a list long
## enough to need a bar takes the title off the top of the screen and the way
## out off the bottom, and nothing on the screen says either is there. Pinning
## the ends is also what keeps a menu that grows — two new rebindable actions
## were enough, once — from pushing its own ABANDON RAID button out of the
## viewport.
class ScreenFrame extends PanelContainer:
	var content_width := 668.0
	## How much of the screen the frame leaves alone: it hangs no higher than
	## `top_margin` and stops `bottom_margin` short of the bottom. Between those
	## it is as tall as what it holds, and no taller — a short page sits in the
	## middle of the screen rather than filling it.
	var top_margin := 40.0
	var bottom_margin := 28.0
	## The three boxes a page is made of, ready to fill the moment the frame is
	## made. `head` and `foot` are pinned; `rows` is what scrolls between them.
	var head: VBoxContainer
	var rows: VBoxContainer
	var foot: VBoxContainer
	## The scroll `rows` sits in, for anything that needs to drive it.
	var body: ScrollContainer

	func _init() -> void:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		add_child(v)
		head = _box()
		v.add_child(head)
		rows = _box()
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body = ScrollContainer.new()
		body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# So a row reached by keyboard or gamepad is scrolled to rather than
		# focused somewhere off the top of the box.
		body.follow_focus = true
		body.add_child(rows)
		UiKit.pixel_scroll(body)
		v.add_child(body)
		foot = _box()
		v.add_child(foot)

	func _box() -> VBoxContainer:
		var b := VBoxContainer.new()
		b.add_theme_constant_override("separation", 8)
		return b

	func _ready() -> void:
		# Top-left anchors, explicit size: full-rect anchors refuse a direct
		# resize, and a Control under a CanvasLayer inherits no rect to fill.
		set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_fit()

	func _process(_delta: float) -> void:
		_fit()

	func _fit() -> void:
		var vp := get_viewport_rect().size
		var room := maxf(vp.y - top_margin - bottom_margin, 160.0)
		size = Vector2(content_width, minf(_wanted_height(), room))
		# Whole pixels, or the pixel face lands between two of them.
		position = Vector2(floorf((vp.x - size.x) * 0.5),
			maxf(floorf((vp.y - size.y) * 0.5), top_margin))

	## How tall the frame would be with nothing scrolled, so a page the screen
	## has room for is shown whole and only a longer one grows a bar. A
	## ScrollContainer asks for no height of its own — that is what makes it a
	## scroll — so the rows in it are measured and counted back in.
	func _wanted_height() -> float:
		return get_combined_minimum_size().y \
			+ rows.get_combined_minimum_size().y - body.get_combined_minimum_size().y

## A frame in the middle of the screen, `width` wide, with its `head`, `rows`
## and `foot` waiting to be filled.
static func screen_frame(width: float, top: float, bottom: float,
		pixel: bool = false) -> ScreenFrame:
	var f := ScreenFrame.new()
	f.content_width = width
	f.top_margin = top
	f.bottom_margin = bottom
	f.add_theme_stylebox_override("panel",
		style(PANEL, Color(0.22, 0.3, 0.38), 1, 3, pixel))
	return f

## Marks a button as the answer already in force: unpressable, because it is
## what is already set, but lit rather than greyed — a button greyed the way an
## unavailable one is greyed reads as the one you cannot have rather than the
## one you have.
static func mark_chosen(b: Button) -> void:
	b.disabled = true
	b.add_theme_color_override("font_disabled_color", ACCENT)

## How wide the name of a setting is given, so every row on a page lines its
## answers up in the same column. Wide enough for the longest of them in the
## pixel face, which runs up to twice as wide as the one the menus used to be
## written in.
const SETTING_LABEL_W := 160.0

## A setting answered by picking one of a few words: the name, then a button
## each, with the answer in force accented and unpressable. It is the shape the
## language row has always had, made once here because the title's settings and
## the pause menu both carry these rows and a setting that looked like two
## different things in the two screens would read as two settings.
##
## No tick and no box: a disabled accented button says which answer is in force
## without a second widget to theme, and every answer stays a thing you can
## reach with a gamepad.
class ChoiceRow extends HBoxContainer:
	## Called with the index picked. Set through `UiKit.choice_row`.
	var on_pick: Callable
	var _name := ""
	var _options: PackedStringArray = PackedStringArray()
	var _picked := 0

	func setup(name: String, options: PackedStringArray, picked: int, cb: Callable) -> void:
		_name = name
		_options = options
		_picked = picked
		on_pick = cb
		add_theme_constant_override("separation", 8)
		_build(false)

	## What the row is showing. Set it to follow a setting changed somewhere
	## else; picking a button calls this on the way through.
	func show_picked(i: int) -> void:
		if i == _picked:
			return
		_picked = i
		# The button just pressed is about to be freed by its own press, and the
		# one that takes its place is disabled and cannot hold focus. So the
		# keyboard is handed to the next answer along rather than dropped on the
		# floor — otherwise one press ends gamepad navigation of the page.
		_build(_holds_focus())

	func _holds_focus() -> bool:
		if not is_inside_tree():
			return false
		var focused: Control = get_viewport().gui_get_focus_owner()
		return focused != null and is_ancestor_of(focused)

	func _build(refocus: bool) -> void:
		for c in get_children():
			remove_child(c)
			c.queue_free()
		var l := UiKit.label(_name, 16, UiKit.TEXT, true)
		l.custom_minimum_size = Vector2(UiKit.SETTING_LABEL_W, 0)
		add_child(l)
		var first: Button = null
		for i in _options.size():
			var in_force: bool = i == _picked
			var b := UiKit.button(_options[i], UiKit.ACCENT if in_force else UiKit.DIM, true)
			if in_force:
				UiKit.mark_chosen(b)
			b.pressed.connect(func() -> void:
				Audio.play("ui")
				show_picked(i)
				if on_pick.is_valid():
					on_pick.call(i))
			add_child(b)
			if first == null and not in_force:
				first = b
		if refocus and first != null:
			first.grab_focus()

## A `ChoiceRow`, set up. `picked` is the index of the answer in force and
## `on_pick` is handed the index of the one pressed.
static func choice_row(name: String, options: PackedStringArray, picked: int,
		on_pick: Callable) -> ChoiceRow:
	var r := ChoiceRow.new()
	r.setup(name, options, picked, on_pick)
	return r

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
