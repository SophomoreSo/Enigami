class_name TitleScreen
extends Control

signal start_requested()
signal sandbox_requested()

## The save slot picked on the way in, 1..SAVE_SLOTS, or -1 until one is.
##
## Picking one opens it — `GameState.load_slot` — so by the time
## `start_requested` goes out, the profile being played is that slot's. Read it
## from the handler if you need the number; the screen is freed straight after.
var save_slot: int = -1

## One drawing, grown from a seed at boot: a circuit board, with the seal of the
## game stamped over it and light running the traces.
##
## The board is generated rather than painted, and that is the whole reason the
## light works. A pulse is a slice of a trace's own polyline taken by arc
## length, so it turns every corner the copper turns. Over a picture it would
## have to be faked.
##
## Everything is laid out against DESIGN. The viewport is fixed at that size by
## `canvas_items` stretch, so the window can be any size without the board
## having to regrow.

const SERIF := preload("res://graphics/assets/fonts/PlayfairDisplay-Variable.ttf")
const PIXEL := preload("res://graphics/assets/fonts/Silkscreen-Regular.ttf")

const DESIGN := Vector2(1280, 720)
const GRID := 8.0            ## the board snaps to this
const CHAMFER := 4.0         ## corners are cut at 45°, the way copper is
const SEAL := Vector2(640, 262)
const SEAL_R := 206.0
const MENU_TOP := 538.0
const SAVE_SLOT_TOP := 556.0 ## the slot chooser sits lower, under its heading
const SAVE_SLOTS := GameState.SAVE_SLOTS

## How long an armed trashcan stays armed. Throwing a profile away cannot be
## undone, so the first press only arms it and a second one inside this is what
## does it — long enough to mean it, short enough not to be left loaded.
const ARM_TIME := 3.0

## The slot column is wider than the main menu's. A row carries three things
## across it — the name, a full date and time, and the can — and at the menu's
## own 400 they sat shoulder to shoulder with the focus mark in the date.
const SAVE_SLOT_WIDTH := 480.0
const SETTLE_TOP := 452.0    ## where the board starts sinking into black

## The seal and the wordmark are drawn at this fraction of the screen and
## blitted back with nearest filtering. The copper is all axis-aligned and
## already reads as pixels; curves and serifs do not, and drawing them small
## and magnifying them is the only thing that puts them on the same grid.
const SEAL_SCALE := 0.5

## Read off the reference: a near-black ground, blue and violet copper, and one
## warm cream that only the seal and the wordmark are allowed to use.
const GROUND := Color(0.0, 0.047, 0.051)
const PLATE := Color(0.012, 0.043, 0.063)
const COPPER := [
	Color(0.043, 0.161, 0.251), Color(0.055, 0.145, 0.224),
	Color(0.094, 0.184, 0.290), Color(0.141, 0.290, 0.463),
	Color(0.220, 0.190, 0.380), Color(0.400, 0.320, 0.580),
	Color(0.560, 0.440, 0.700),
]
const CREAM := Color(1.0, 0.85, 0.72)
const HALO := Color(0.78, 0.86, 0.95)    ## the stipple: pale, not cyan
const SPARK := Color(0.62, 0.94, 1.0)
const MENU_INK := Color(0.41, 0.61, 0.95)
## An armed trashcan, and the DELETE? in the row beside it.
const WARN_INK := Color(0.96, 0.45, 0.42)

enum { PAD, VIA, CHIP, CAP, RES, DOTS }

var _t: float = 0.0
var _traces: Array = []      ## {pts, len, col, w}
var _parts: Array = []       ## {p, kind, col, d, s}
var _halo: Array = []        ## four alpha buckets of dot segments
var _pulses: Array = []      ## {i, t, v, len}
var _rng := RandomNumberGenerator.new()

var _board: SubViewport
var _seal_view: SubViewport
var _seal_painter: Node2D
var _menu_font: FontVariation
var _menu_root: VBoxContainer
var _save_slot_root: VBoxContainer
var _buttons: Array = []
var _start_button: Button
var _settings_button: Button
var _first_save_slot: Button
## The settings, and the two pages behind them, one per button: the volumes and
## the language on one, the rebinding list on the other. The settings themselves
## are nothing but the way to them, and only ever one of the three is up. Each
## is a scroll around its panel, so a page too long for the screen can still be
## reached — see `_settings_page`.
var _settings: UiKit.ScreenFrame
var _general: UiKit.ScreenFrame
var _controls: UiKit.ScreenFrame
## One entry per slot: {"n", "pick", "stamp", "bin"}.
var _slot_rows: Array = []
## The slot whose trashcan is armed, or -1, and how long it stays that way.
var _armed_slot: int = -1
var _armed_left: float = 0.0

## Paints the copper once, into `_board`. Nothing on the board moves — the
## light that runs it is drawn live, over the top — and repainting ~7000
## static primitives every frame cost more than the whole rest of the screen
## put together (26 ms a frame on an M1 Max, against 2 ms baked).
class BoardPainter extends Node2D:
	var screen: TitleScreen
	func _draw() -> void:
		screen._paint_copper(self)

## Repaints the seal every frame at SEAL_SCALE. The seal breathes and its rune
## bands turn, so unlike the board this one cannot be baked — but at half
## resolution it is a couple of hundred primitives over a quarter of the
## pixels, which costs less than drawing it full-size once.
class SealPainter extends Node2D:
	var screen: TitleScreen
	func _draw() -> void:
		var breath := screen._breath()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(SEAL_SCALE, SEAL_SCALE))
		screen._paint_seal(self, breath)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		screen._paint_wordmark(self, breath, SEAL_SCALE)

func _ready() -> void:
	UiKit.fill_screen(self)
	# Nothing this screen blits wants smoothing: the board goes down 1:1 and
	# the seal is magnified on purpose.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.randomize()
	_menu_font = FontVariation.new()
	_menu_font.base_font = PIXEL
	_menu_font.spacing_glyph = 3
	_build_board()
	_build_seal_view()
	_build_menu()
	_build_save_slots()
	_build_settings()
	_build_general()
	_build_controls()
	Loc.language_changed.connect(_relanguage)
	Audio.play_music()

func _breath() -> float:
	return 0.5 + 0.5 * sin(_t * 0.7)

func _build_seal_view() -> void:
	_seal_view = SubViewport.new()
	_seal_view.size = Vector2i(DESIGN * SEAL_SCALE)
	_seal_view.transparent_bg = true
	_seal_view.disable_3d = true
	_seal_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_seal_painter = SealPainter.new()
	(_seal_painter as SealPainter).screen = self
	_seal_view.add_child(_seal_painter)
	add_child(_seal_view)

## --- the board --------------------------------------------------------------
## Seeded, so the board is the same board every boot: it is the game's face, not
## a different sketch each time you look at it.
func _build_board() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x1D0CE
	for i in 380:
		_grow_trace(rng)
	_build_halo(rng)
	for i in 16:
		var pu := {"i": 0, "t": 0.0, "v": 0.0, "len": 0.0}
		_respawn(pu)
		pu["t"] = rng.randf()
		_pulses.append(pu)
	_bake_board()

func _bake_board() -> void:
	_board = SubViewport.new()
	_board.size = Vector2i(DESIGN)
	_board.transparent_bg = true
	_board.disable_3d = true
	# UPDATE_ONCE draws a single frame and then switches itself off, which is
	# exactly the life of this texture: painted at boot, blitted thereafter.
	_board.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := BoardPainter.new()
	painter.screen = self
	_board.add_child(painter)
	add_child(_board)

const AXES := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]

func _grow_trace(rng: RandomNumberGenerator) -> void:
	var p := Vector2.ZERO
	# The board is thinned where the menu will sit rather than masked there
	# afterwards, so the copper that does survive still runs whole traces.
	for tries in 6:
		p = Vector2(snappedf(rng.randf_range(-40.0, DESIGN.x + 40.0), GRID),
			snappedf(rng.randf_range(-40.0, DESIGN.y + 40.0), GRID))
		var away := Vector2((p.x - SEAL.x) / 330.0, (p.y - 600.0) / 150.0).length()
		if away > 1.0 or rng.randf() < away * 0.35:
			break
	var dir: Vector2 = AXES[rng.randi() % 4]
	var raw := PackedVector2Array([p])
	for leg in rng.randi_range(2, 7):
		var run := float(rng.randi_range(2, 11)) * GRID
		var q := p + dir * run
		if q.x < -48.0 or q.x > DESIGN.x + 48.0 or q.y < -48.0 or q.y > DESIGN.y + 48.0:
			break
		p = q
		raw.append(p)
		dir = Vector2(dir.y, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0)
	if raw.size() < 2:
		return

	# Most copper is dim blue; a quarter of it carries the violet, and a very
	# few runs the pale. Without that spread the board reads as one flat
	# texture rather than as layers of a board.
	var roll := rng.randf()
	var ci := rng.randi() % 3
	if roll > 0.95:
		ci = 6
	elif roll > 0.70:
		ci = 4 + rng.randi() % 2
	elif roll > 0.55:
		ci = 3
	var col: Color = COPPER[ci]
	var pts := _chamfer(raw)
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	if total < 24.0:
		return
	_traces.append({"pts": pts, "len": total, "col": col,
		"w": 1.5 if rng.randf() < 0.72 else 2.5})
	_place_parts(rng, raw, col)

## A right-angle corner in copper is cut at 45°, never square.
func _chamfer(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var a := pts[i - 1]
		var b := pts[i]
		var c := pts[i + 1]
		var d1 := b - a
		var d2 := c - b
		var cut := minf(CHAMFER, minf(d1.length(), d2.length()) * 0.45)
		out.append(b - d1.normalized() * cut)
		out.append(b + d2.normalized() * cut)
	out.append(pts[pts.size() - 1])
	return out

func _place_parts(rng: RandomNumberGenerator, raw: PackedVector2Array, col: Color) -> void:
	for e in [raw[0], raw[raw.size() - 1]]:
		_parts.append({"p": e, "kind": PAD if rng.randf() < 0.6 else VIA,
			"col": col, "d": Vector2.RIGHT, "s": Vector2.ZERO})
	for i in range(raw.size() - 1):
		if rng.randf() > 0.5:
			continue
		var a := raw[i]
		var b := raw[i + 1]
		var d := (b - a).normalized()
		var p := a.lerp(b, rng.randf_range(0.25, 0.75)).snapped(Vector2(GRID, GRID) * 0.5)
		var roll := rng.randf()
		if roll < 0.3:
			_parts.append({"p": p, "kind": CHIP, "col": col, "d": d,
				"s": Vector2(float(rng.randi_range(3, 7)) * 6.0, float(rng.randi_range(2, 4)) * 6.0)})
		elif roll < 0.6:
			_parts.append({"p": p, "kind": CAP, "col": col, "d": d, "s": Vector2.ZERO})
		elif roll < 0.85:
			_parts.append({"p": p, "kind": RES, "col": col, "d": d, "s": Vector2.ZERO})
		else:
			_parts.append({"p": p, "kind": DOTS, "col": col, "d": d, "s": Vector2.ZERO})

## The stipple around the seal, bucketed by alpha so the whole halo costs four
## draw calls instead of two thousand.
func _build_halo(rng: RandomNumberGenerator) -> void:
	var buckets := [PackedVector2Array(), PackedVector2Array(),
		PackedVector2Array(), PackedVector2Array()]
	for i in 9000:
		var a := rng.randf() * TAU
		var k := rng.randf()
		if rng.randf() > pow(1.0 - k, 2.3):
			continue
		var out := rng.randf() < 0.72
		var r := SEAL_R + (2.0 + k * 24.0) if out else SEAL_R - (3.0 + k * 18.0)
		var p := (SEAL + Vector2(cos(a), sin(a)) * r).snapped(Vector2(2, 2))
		var b := clampi(int((1.0 - k) * 4.0), 0, 3)
		buckets[b].append(p)
		buckets[b].append(p + Vector2(2, 0))
	_halo = buckets

func _respawn(pu: Dictionary) -> void:
	if _traces.is_empty():
		return
	var i := _rng.randi() % _traces.size()
	pu["i"] = i
	pu["t"] = -_rng.randf() * 0.9          # a beat of dark before it runs again
	pu["v"] = _rng.randf_range(110.0, 260.0) / maxf(float(_traces[i]["len"]), 40.0)
	pu["len"] = _rng.randf_range(30.0, 96.0)

## The piece of `pts` lying between arc lengths `a` and `b`.
func _arc_slice(pts: PackedVector2Array, a: float, b: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if b <= 0.0 or pts.size() < 2:
		return out
	a = maxf(a, 0.0)
	var walked := 0.0
	for i in range(pts.size() - 1):
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var seg := p0.distance_to(p1)
		if seg <= 0.001:
			continue
		if walked + seg >= a and walked <= b:
			var f0 := clampf((a - walked) / seg, 0.0, 1.0)
			var f1 := clampf((b - walked) / seg, 0.0, 1.0)
			if out.is_empty():
				out.append(p0.lerp(p1, f0))
			out.append(p0.lerp(p1, f1))
		walked += seg
		if walked > b:
			break
	return out

## --- the menu ---------------------------------------------------------------
func _build_menu() -> void:
	_menu_root = _column(MENU_TOP)
	_start_button = _menu_button(Loc.t("menu.title.start"), _menu_root)
	_start_button.pressed.connect(_show_save_slots)
	var sandbox := _menu_button(Loc.t("menu.title.sandbox"), _menu_root)
	sandbox.pressed.connect(func() -> void: sandbox_requested.emit())
	_settings_button = _menu_button(Loc.t("menu.title.settings"), _menu_root)
	_settings_button.pressed.connect(_toggle_settings)
	var quit := _menu_button(Loc.t("menu.title.quit"), _menu_root)
	quit.pressed.connect(func() -> void: get_tree().quit())
	_start_button.grab_focus()

## START asks which save slot before it hands over. Each row says which slot it
## is, when that profile was last written, and offers a way to throw it away.
## Picking one opens it, so what `start_requested` hands on is that profile.
func _build_save_slots() -> void:
	_save_slot_root = _column(SAVE_SLOT_TOP, SAVE_SLOT_WIDTH)
	_save_slot_root.visible = false
	_slot_rows.clear()
	for i in SAVE_SLOTS:
		var row := _slot_row(i + 1)
		_slot_rows.append(row)
		if i == 0:
			_first_save_slot = row["pick"]
	var back := _menu_button(Loc.t("menu.title.back"), _save_slot_root)
	back.add_theme_font_size_override("font_size", Loc.text_size(back.text, 16))
	back.pressed.connect(_hide_save_slots)
	_refresh_slots()

## One slot: its name on the left, when it was last saved on the right, and a
## trashcan past that. A row rather than a single button because the can has to
## be reachable on its own — by the mouse, and by the pad moving right onto it.
func _slot_row(n: int) -> Dictionary:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(SAVE_SLOT_WIDTH, 0)
	h.add_theme_constant_override("separation", 0)
	_save_slot_root.add_child(h)

	# Sized to its own name rather than stretched across the row, so the marks
	# `_draw_focus_marks` sets either side of the focused control land against
	# SLOT 1 the way they do against every other line on this screen. Stretched,
	# the right-hand one sat in the middle of the date.
	var pick := _bare_button(Loc.t("menu.title.slot", [n]), 24)
	pick.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pick.pressed.connect(func() -> void:
		save_slot = n
		GameState.load_slot(n)
		start_requested.emit())
	h.add_child(pick)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(gap)

	var stamp := Label.new()
	stamp.add_theme_font_override("font", _menu_font)
	stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(stamp)

	# No text of its own: the can is drawn over it by `_draw_slot_bins`, the way
	# everything else on this screen is drawn rather than dropped in as an image.
	var bin := _bare_button("", 16)
	bin.custom_minimum_size = Vector2(40, 28)
	bin.pressed.connect(_bin_pressed.bind(n))
	h.add_child(bin)
	return {"n": n, "pick": pick, "stamp": stamp, "bin": bin}

## What a slot's row says on the right.
##
## The stamp is the local date and time in a numeric form that reads the same in
## every language, so there is no sentence in it to translate — only the two
## words around it, for a slot with nothing in it and for one being thrown away.
func _slot_stamp(n: int) -> String:
	if _armed_slot == n:
		return Loc.t("menu.title.slot_delete")
	var at := int(GameState.slot_info(n).get("saved_at", 0))
	if at <= 0:
		return Loc.t("menu.title.slot_empty")
	var local := at + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	return "%04d-%02d-%02d %02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"]]

## Re-reads the slots off disk and puts what they say back on the rows. Cheap
## enough to call on every open and every delete: it is three small files.
func _refresh_slots() -> void:
	for row in _slot_rows:
		var n := int(row["n"])
		var line := _slot_stamp(n)
		var stamp: Label = row["stamp"]
		stamp.text = line
		stamp.add_theme_font_size_override("font_size", Loc.text_size(line, 14))
		stamp.add_theme_color_override("font_color", WARN_INK if _armed_slot == n
			else Color(CREAM.r, CREAM.g, CREAM.b, 0.55))

## Throwing a profile away cannot be undone, so the first press only arms the
## can: the row turns red and says DELETE?, and a second press inside ARM_TIME
## is what actually empties the slot. Anything else lets it lapse.
func _bin_pressed(n: int) -> void:
	if _armed_slot == n:
		_armed_slot = -1
		GameState.delete_slot(n)
		_refresh_slots()
		Audio.play("deny")
		return
	_armed_slot = n
	_armed_left = ARM_TIME
	_refresh_slots()
	Audio.play("ui")

func _disarm() -> void:
	if _armed_slot < 0:
		return
	_armed_slot = -1
	_refresh_slots()

func _column(top: float, width: float = 400.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.position = Vector2(SEAL.x - width * 0.5, top)
	v.custom_minimum_size = Vector2(width, 0)
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	return v

func _show_save_slots() -> void:
	_menu_root.visible = false
	_save_slot_root.visible = true
	# Read off disk each time it opens: a profile saved since the title came up
	# — the game was played and the player came back here — has a newer stamp.
	_armed_slot = -1
	_refresh_slots()
	_first_save_slot.grab_focus()
	Audio.play("ui")

func _hide_save_slots() -> void:
	_disarm()
	_save_slot_root.visible = false
	_menu_root.visible = true
	_start_button.grab_focus()
	Audio.play("ui")

## No chrome at all: the menu is text that brightens, and the marks flanking it
## are drawn by `_draw_focus_marks` so a gamepad player can see where they are.
func _menu_button(text: String, parent: VBoxContainer) -> Button:
	var b := _bare_button(text, 24)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(b)
	return b

## The look, without a home: the slot rows lay their buttons out themselves.
func _bare_button(text: String, px: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	var box := StyleBoxEmpty.new()
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, box)
	b.add_theme_font_override("font", _menu_font)
	b.add_theme_font_size_override("font_size", Loc.text_size(text, px))
	b.add_theme_color_override("font_color", MENU_INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	_buttons.append(b)
	return b

## SETTINGS holds nothing of its own any more: it is two buttons and the way
## back, and every setting lives on the page behind one of them.
func _build_settings() -> void:
	_settings = _settings_page()
	var v := _settings_column(_settings, Loc.t("menu.settings.heading"))
	var to_general := UiKit.button(Loc.t("menu.settings.general"), UiKit.ACCENT, true)
	to_general.pressed.connect(_toggle_general)
	v.add_child(to_general)
	var to_controls := UiKit.button(Loc.t("controls.open"), UiKit.ACCENT, true)
	to_controls.pressed.connect(_toggle_controls)
	v.add_child(to_controls)
	_settings.foot.add_child(UiKit.spacer(8))
	var back := UiKit.button(Loc.t("menu.settings.back"), UiKit.ACCENT, true)
	back.pressed.connect(_toggle_settings)
	_settings.foot.add_child(back)

## The volumes and the language, on the page behind GENERAL SETTINGS.
func _build_general() -> void:
	_general = _settings_page()
	var v := _settings_column(_general, Loc.t("menu.settings.general"))
	v.add_child(_slider(Loc.t("menu.settings.music"), Audio.music_volume,
		func(val: float) -> void: Audio.set_music_volume(val)))
	v.add_child(_slider(Loc.t("menu.settings.sound"), Audio.sfx_volume, func(val: float) -> void:
		Audio.set_sfx_volume(val)
		Audio.play("ui")))
	v.add_child(_language_row())
	_general.foot.add_child(UiKit.spacer(8))
	var back := UiKit.button(Loc.t("menu.settings.back"), UiKit.ACCENT, true)
	back.pressed.connect(_toggle_general)
	_general.foot.add_child(back)

## The rebinding list, on the page behind CONTROL SETTINGS. It is fifteen rows
## of two columns — longer than every other setting put together — and inline
## it left the buttons under it somewhere off the bottom of a long scroll. A
## page of its own, as a sibling scroll rather than a panel swapped into the
## settings, so no page inherits another's scroll position.
func _build_controls() -> void:
	_controls = _settings_page()
	var v := _settings_column(_controls, Loc.t("controls.open"))
	var controls := ControlsPanel.new()
	controls.pixel = true
	v.add_child(controls)
	_controls.foot.add_child(UiKit.spacer(8))
	var back := UiKit.button(Loc.t("controls.back"), UiKit.ACCENT, true)
	back.pressed.connect(_toggle_controls)
	_controls.foot.add_child(back)

## An empty settings page, hidden until its button is pressed: UiKit's pixel
## look, like the menu that opens it. The pixel face runs up to twice as wide as
## the one it replaced, so the panel is wide — 600 holds the controls list's two
## columns, and the frame adds its bar.
##
## Centred, since the pages are three very different heights: SETTINGS is three
## buttons and the rebinding list is fifteen rows, and hung from a common top
## the short ones floated in the upper third of the screen. The rebinding list
## is taller than the room it has either way, so it fills that room from 56 and
## scrolls — its rows do, that is. The heading over them and the way back out
## from under them are pinned to the frame and go nowhere.
func _settings_page() -> UiKit.ScreenFrame:
	var f := UiKit.screen_frame(608.0, 56.0, 28.0, true)
	f.visible = false
	add_child(f)
	return f

## The column a page's rows go in, under a heading and a rule pinned above it.
## What the caller then puts in the page's `foot` is pinned under it.
func _settings_column(page: UiKit.ScreenFrame, heading: String) -> VBoxContainer:
	page.head.add_child(UiKit.label(heading, 24, UiKit.ACCENT, true))
	page.head.add_child(UiKit.hline(true))
	return page.rows

## One button per language, laid out like a slider row: the label on the left
## and the choices beside it. Each language is written in itself, so somebody
## who has landed in the wrong one can still find their way back.
func _language_row() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UiKit.label(Loc.t("menu.settings.language"), 16, UiKit.TEXT, true)
	l.custom_minimum_size = Vector2(80, 0)
	h.add_child(l)
	for lang in Loc.languages():
		var picked: bool = lang == Loc.language
		var b := UiKit.button(Loc.language_name(lang),
			UiKit.ACCENT if picked else UiKit.DIM, true)
		b.disabled = picked
		b.pressed.connect(func() -> void:
			Audio.play("ui")
			Loc.set_language(lang))
		h.add_child(b)
	return h

## The whole menu, in the new language. Everything here is text laid out once
## in `_ready`, so a change of language is a rebuild rather than a refresh —
## and whichever settings page was up is put back open, because that is where
## the switch was just pressed.
func _relanguage(_lang: String) -> void:
	var was_settings: bool = _settings != null and _settings.visible
	var was_general: bool = _general != null and _general.visible
	var was_controls: bool = _controls != null and _controls.visible
	var was_slots: bool = _save_slot_root != null and _save_slot_root.visible
	for old in [_menu_root, _save_slot_root, _settings, _general, _controls]:
		if old != null and is_instance_valid(old):
			remove_child(old)
			old.queue_free()
	_buttons.clear()
	_slot_rows.clear()
	_armed_slot = -1
	_menu_root = null
	_save_slot_root = null
	_settings = null
	_general = null
	_controls = null
	_start_button = null
	_settings_button = null
	_first_save_slot = null
	_build_menu()
	_build_save_slots()
	_build_settings()
	_build_general()
	_build_controls()
	if was_settings or was_general or was_controls:
		_settings.visible = was_settings
		_general.visible = was_general
		_controls.visible = was_controls
		_menu_root.visible = false
	elif was_slots:
		_show_save_slots()

func _slider(name: String, value: float, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UiKit.label(name, 16, UiKit.TEXT, true)
	l.custom_minimum_size = Vector2(80, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(240, 20)
	UiKit.pixel_slider(s)
	s.value_changed.connect(cb)
	h.add_child(s)
	return h

func _toggle_settings() -> void:
	# Settings can only be reached from the main column, so that is the one to
	# put back when it closes.
	_settings.visible = not _settings.visible
	_menu_root.visible = not _settings.visible
	# Leaving the settings leaves the pages behind them as well: reopening them
	# has to land on the settings, not on whichever page was last looked at.
	for page in [_general, _controls]:
		if page != null:
			page.visible = false
	if not _settings.visible and _settings_button != null:
		_settings_button.grab_focus()
	Audio.play("ui")

## The page behind GENERAL SETTINGS, in and out. The settings are the only way
## to it, so they are what comes back.
func _toggle_general() -> void:
	_general.visible = not _general.visible
	_settings.visible = not _general.visible
	Audio.play("ui")

## The page behind CONTROL SETTINGS, the same way.
func _toggle_controls() -> void:
	_controls.visible = not _controls.visible
	_settings.visible = not _controls.visible
	Audio.play("ui")

## Backing out: whichever page is up, then the settings, then the save slots.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _general != null and _general.visible:
		_toggle_general()
		get_viewport().set_input_as_handled()
	elif _controls != null and _controls.visible:
		_toggle_controls()
		get_viewport().set_input_as_handled()
	elif _settings != null and _settings.visible:
		_toggle_settings()
		get_viewport().set_input_as_handled()
	elif _save_slot_root != null and _save_slot_root.visible:
		# One press to call off an armed can, another to leave the list.
		if _armed_slot >= 0:
			_disarm()
		else:
			_hide_save_slots()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_t += delta
	if _armed_slot >= 0:
		_armed_left -= delta
		if _armed_left <= 0.0:
			_disarm()
	for pu in _pulses:
		pu["t"] += float(pu["v"]) * delta
		if pu["t"] > 1.0:
			_respawn(pu)
	if _seal_painter != null:
		_seal_painter.queue_redraw()
	queue_redraw()

## --- drawing ----------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GROUND)
	if _board != null:
		draw_texture(_board.get_texture(), Vector2.ZERO)
	_draw_pulses()
	_draw_settle()
	if _seal_view != null:
		draw_texture_rect(_seal_view.get_texture(), Rect2(Vector2.ZERO, DESIGN), false)
	_draw_focus_marks()
	_draw_save_slot_prompt()
	_draw_slot_bins()
	_draw_glass()

func _paint_copper(cv: CanvasItem) -> void:
	for tr in _traces:
		cv.draw_polyline(tr["pts"], tr["col"], tr["w"])
	for pt in _parts:
		_paint_part(cv, pt)

func _paint_part(cv: CanvasItem, pt: Dictionary) -> void:
	var p: Vector2 = pt["p"]
	var col: Color = pt["col"]
	var d: Vector2 = pt["d"]
	var n := Vector2(-d.y, d.x)
	match int(pt["kind"]):
		PAD:
			cv.draw_circle(p, 4.0, col)
			cv.draw_circle(p, 1.5, GROUND)
		VIA:
			cv.draw_arc(p, 4.5, 0.0, TAU, 10, col, 1.0)
		CHIP:
			var s: Vector2 = pt["s"]
			var r := Rect2(p - s * 0.5, s)
			cv.draw_rect(r, Color(col.r, col.g, col.b, 0.22))
			cv.draw_rect(r, col, false, 1.0)
			var pins := maxi(int(s.x / 6.0), 1)
			for i in pins:
				var x := r.position.x + 3.0 + float(i) * 6.0
				cv.draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y - 3.0), col, 1.0)
				cv.draw_line(Vector2(x, r.end.y), Vector2(x, r.end.y + 3.0), col, 1.0)
		CAP:
			for k in 3:
				var o := d * (float(k) * 3.0 - 3.0)
				cv.draw_line(p + o - n * 7.0, p + o + n * 7.0, col, 1.0)
		RES:
			cv.draw_rect(Rect2(p - d * 7.0 - n * 3.0, d * 14.0 + n * 6.0).abs(), col, false, 1.0)
			cv.draw_line(p - n * 3.0, p + n * 3.0, col, 1.0)
		DOTS:
			for gx in 3:
				for gy in 4:
					cv.draw_rect(Rect2(p + d * float(gx) * 4.0 + n * float(gy) * 4.0,
						Vector2(2, 2)), col)

## The board sinks into black below the seal, so the menu has something to sit
## on. Thinning the copper when it is grown is not enough on its own — what
## survives still crosses the text, and text over a live trace is unreadable at
## any brightness.
func _draw_settle() -> void:
	# Smoothstep, not a power curve: anything that leaves the gradient at a
	# non-zero slope where it starts draws a visible seam across the board.
	for i in int(size.y - SETTLE_TOP):
		var k := clampf(float(i) / 168.0, 0.0, 1.0)
		draw_rect(Rect2(0.0, SETTLE_TOP + float(i), size.x, 1.0),
			Color(GROUND.r, GROUND.g, GROUND.b, 0.55 * k * k * (3.0 - 2.0 * k)))
	# The rest of the darkening is pooled behind the menu rather than spread
	# across the row, so the far corners keep the copper the reference has
	# there and only the text gets a clean ground.
	draw_set_transform(Vector2(SEAL.x, MENU_TOP + 76.0), 0.0, Vector2(3.4, 1.0))
	for i in 26:
		var k := 1.0 - float(i) / 26.0
		draw_circle(Vector2.ZERO, 20.0 + k * 112.0, Color(GROUND.r, GROUND.g, GROUND.b, 0.045))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_pulses() -> void:
	for pu in _pulses:
		var tr: Dictionary = _traces[int(pu["i"])]
		var head: float = float(pu["t"]) * float(tr["len"])
		var tail: float = float(pu["len"])
		for k in 3:
			var a := head - tail * (1.0 - float(k) / 3.0)
			var b := head - tail * (1.0 - float(k + 1) / 3.0)
			var seg := _arc_slice(tr["pts"], a, b)
			if seg.size() >= 2:
				var f := float(k + 1) / 3.0
				draw_polyline(seg, Color(SPARK.r, SPARK.g, SPARK.b, 0.16 + 0.64 * f * f),
					float(tr["w"]) + 0.5)

## Drawn into `_seal_view` at SEAL_SCALE and blitted back at 1/SEAL_SCALE with
## nearest filtering, so every curve here lands on the same coarse grid the
## copper does. Line widths are therefore in half-pixels: 2.0 is one pixel of
## the seal's grid, and anything odd blends across a row instead of filling it.
func _paint_seal(cv: CanvasItem, breath: float) -> void:
	var c := SEAL
	var r := SEAL_R

	for i in _halo.size():
		var pts: PackedVector2Array = _halo[i]
		if pts.is_empty():
			continue
		var a := (0.07 + 0.12 * float(i)) * (0.72 + 0.28 * breath)
		cv.draw_multiline(pts, Color(HALO.r, HALO.g, HALO.b, a), 2.0)

	# The bloom around the rim: concentric arcs fading outward, which is as
	# close to a soft glow as a line renderer gets. It wants to be wide and
	# weak — a few bright rings read as a target, not as light.
	for i in 26:
		var k := float(i) / 26.0
		cv.draw_arc(c, r + 1.0 + k * 44.0, 0.0, TAU, 96,
			Color(CREAM.r, CREAM.g, CREAM.b,
				(1.0 - k) * (1.0 - k) * 0.16 * (0.62 + 0.38 * breath)), 4.0)

	cv.draw_circle(c, r - 1.0, PLATE)
	cv.draw_arc(c, r, 0.0, TAU, 180, Color(CREAM.r, CREAM.g, CREAM.b, 0.82 + 0.18 * breath), 4.0)
	cv.draw_arc(c, r - 8.0, 0.0, TAU, 160, Color(CREAM.r, CREAM.g, CREAM.b, 0.26), 2.0)

	var ink := Color(0.32, 0.44, 0.70, 0.88)
	var dim := Color(0.26, 0.36, 0.60, 0.62)
	var faint := Color(0.23, 0.32, 0.56, 0.44)
	for k in [0.93, 0.855, 0.835, 0.755, 0.47, 0.45]:
		cv.draw_arc(c, r * k, 0.0, TAU, 128, faint if k < 0.5 else dim, 2.0)

	# The rune band turns about once every two minutes — under the threshold
	# where you would call it spinning, over the one where the seal looks dead.
	var rot := _t * 0.05
	for i in 98:
		var a := rot + TAU * float(i) / 98.0
		var d := Vector2(cos(a), sin(a))
		if i % 7 == 0:
			cv.draw_line(c + d * (r * 0.862), c + d * (r * 0.925), ink, 2.0)
			cv.draw_rect(Rect2(c + d * (r * 0.90) - Vector2(2, 2), Vector2(4, 4)), ink)
		else:
			cv.draw_line(c + d * (r * 0.868), c + d * (r * 0.90 + (6.0 if i % 2 == 0 else 2.0)),
				dim, 2.0)
	# A finer band inside it, turning the other way.
	for i in 60:
		var a := -rot * 1.6 + TAU * float(i) / 60.0
		var d := Vector2(cos(a), sin(a))
		cv.draw_line(c + d * (r * 0.775), c + d * (r * 0.80), faint, 2.0)

	# Two heptagrams, the inner one turned against the outer, with spokes
	# carrying the outer's points out to the rune band.
	var vp: Array = []
	for i in 7:
		var a := -PI * 0.5 + TAU * float(i) / 7.0
		vp.append(c + Vector2(cos(a), sin(a)) * (r * 0.70))
	for i in 7:
		cv.draw_line(vp[i], vp[(i + 3) % 7], ink, 2.0)
		cv.draw_circle(vp[i], 4.0, Color(0.45, 0.60, 0.88, 0.85))
		cv.draw_arc(vp[i], 8.0, 0.0, TAU, 10, dim, 2.0)
		var d: Vector2 = (vp[i] - c).normalized()
		cv.draw_line(c + d * (r * 0.70), c + d * (r * 0.835), faint, 2.0)
	var ip: Array = []
	for i in 7:
		var a := PI * 0.5 + TAU * (float(i) + 0.5) / 7.0
		ip.append(c + Vector2(cos(a), sin(a)) * (r * 0.45))
	for i in 7:
		cv.draw_line(ip[i], ip[(i + 2) % 7], faint, 2.0)

	# The plate the wordmark sits against, and the chamber under it.
	cv.draw_rect(Rect2(c - Vector2(r * 0.54, r * 0.28), Vector2(r * 1.08, r * 0.56)), dim, false, 2.0)
	cv.draw_rect(Rect2(c - Vector2(r * 0.50, r * 0.24), Vector2(r * 1.00, r * 0.48)), faint, false, 2.0)
	for i in 3:
		var a := PI * 0.5 + TAU * float(i) / 3.0
		var b := PI * 0.5 + TAU * float(i + 1) / 3.0
		cv.draw_line(c + Vector2(cos(a), sin(a)) * (r * 0.56),
			c + Vector2(cos(b), sin(b)) * (r * 0.56), dim, 2.0)
	# The lower half of the seal is the half the wordmark does not cover, so it
	# carries the detail: a graduated band, and the core hung at the bottom.
	for i in 46:
		var a := PI * 0.12 + PI * 0.76 * (float(i) / 45.0)
		var d := Vector2(cos(a), sin(a))
		cv.draw_line(c + d * (r * 0.615), c + d * (r * 0.615 + (8.0 if i % 5 == 0 else 4.0)),
			dim if i % 5 == 0 else faint, 2.0)
	cv.draw_arc(c, r * 0.615, PI * 0.10, PI * 0.90, 64, faint, 2.0)

	var core := c + Vector2(0, r * 0.50)
	cv.draw_arc(core, 14.0, 0.0, TAU, 18, ink, 2.0)
	cv.draw_arc(core, 9.0, 0.0, TAU, 14, dim, 2.0)
	cv.draw_circle(core, 4.0, Color(0.50, 0.66, 0.92, 0.85))
	for i in 6:
		var a := TAU * float(i) / 6.0 - rot * 2.0
		var d := Vector2(cos(a), sin(a))
		cv.draw_line(core + d * 14.0, core + d * 21.0, dim, 2.0)
	_diamond(cv, core, 26.0, faint)

	_paint_pendant(cv, c + Vector2(0, r), breath)

## The charm hanging off the bottom of the seal, and the one place the menu and
## the seal touch.
func _paint_pendant(cv: CanvasItem, top: Vector2, breath: float) -> void:
	var glow := Color(SPARK.r, SPARK.g, SPARK.b, 0.30 + 0.35 * breath)
	cv.draw_line(top, top + Vector2(0, 28), Color(CREAM.r, CREAM.g, CREAM.b, 0.55), 2.0)
	var node := top + Vector2(0, 34)
	for i in 4:
		cv.draw_circle(node, 5.0 + float(i) * 3.0, Color(glow.r, glow.g, glow.b, glow.a * 0.14))
	cv.draw_arc(node, 6.0, 0.0, TAU, 12, Color(CREAM.r, CREAM.g, CREAM.b, 0.85), 2.0)
	_diamond(cv, node + Vector2(0, 16), 8.0, Color(SPARK.r, SPARK.g, SPARK.b, 0.75 + 0.25 * breath))

func _diamond(cv: CanvasItem, p: Vector2, r: float, col: Color, w: float = 2.0) -> void:
	cv.draw_polyline(PackedVector2Array([
		p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r),
		p + Vector2(-r, 0), p + Vector2(0, -r)]), col, w)

## The wordmark is sized and placed in seal-grid pixels rather than being drawn
## large and scaled down: a glyph rasterised at 142 and squeezed into half the
## room comes back smooth, and smooth is the one thing it must not be.
func _paint_wordmark(cv: CanvasItem, breath: float, s: float) -> void:
	var text := "Enigami"
	var px := int(round(142.0 * s))
	var w := SERIF.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := Vector2(SEAL.x * s - w * 0.5, (SEAL.y + 46.0) * s).round()
	for i in 8:
		var a := TAU * float(i) / 8.0
		cv.draw_string(SERIF, at + (Vector2(cos(a), sin(a)) * 5.0 * s).round(), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, px,
			Color(CREAM.r, CREAM.g, CREAM.b, 0.05 + 0.035 * breath))
	# One grid pixel of offset, not two: at this size a second one stops being
	# a shadow and starts being an emboss.
	cv.draw_string(SERIF, at + Vector2(1, 1), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0.0, 0.055, 0.11, 0.85))
	cv.draw_string(SERIF, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, CREAM)

func _draw_focus_marks() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f == null or not _buttons.has(f) or not (f as Control).is_visible_in_tree():
		return
	var r := (f as Control).get_global_rect()
	r.position -= global_position
	var y := r.position.y + r.size.y * 0.5
	var beat := 0.55 + 0.45 * sin(_t * 4.0)
	var col := Color(SPARK.r, SPARK.g, SPARK.b, beat)
	_diamond(self, Vector2(r.position.x + 8.0, y), 4.0, col, 1.5)
	_diamond(self, Vector2(r.end.x - 8.0, y), 4.0, col, 1.5)

## The heading over the save slots. Drawn rather than laid out, so the column
## below it keeps the exact spacing the main menu has.
func _draw_save_slot_prompt() -> void:
	if _save_slot_root == null or not _save_slot_root.visible:
		return
	var line := Loc.t("menu.title.select_slot")
	var size := Loc.text_size(line, 16)
	var w := _menu_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_menu_font, Vector2(SEAL.x - w * 0.5, SAVE_SLOT_TOP - 12.0), line,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(CREAM.r, CREAM.g, CREAM.b, 0.7))

## The trashcan at the end of each slot row. Drawn rather than dropped in as an
## image, like everything else here, on a 2-pixel unit so it lands on the same
## grid the copper does. It follows the row it belongs to: ordinary ink, white
## under the cursor or the pad, red once it is armed.
const BIN_UNIT := 2.0

func _draw_slot_bins() -> void:
	if _save_slot_root == null or not _save_slot_root.visible:
		return
	var focused := get_viewport().gui_get_focus_owner()
	for row in _slot_rows:
		var bin: Button = row["bin"]
		var r := bin.get_global_rect()
		r.position -= global_position
		var col := MENU_INK
		if _armed_slot == int(row["n"]):
			col = WARN_INK
		elif focused == bin:
			col = Color.WHITE
		_draw_bin(r.get_center().floor(), col)

func _draw_bin(at: Vector2, col: Color) -> void:
	var u := BIN_UNIT
	# The handle, and the lid across the top of it.
	draw_rect(Rect2(at + Vector2(-2, -7) * u, Vector2(4, 1) * u), col)
	draw_rect(Rect2(at + Vector2(-5, -6) * u, Vector2(10, 1) * u), col)
	# Two walls and a base rather than a filled block, so it reads as a can.
	draw_rect(Rect2(at + Vector2(-4, -4) * u, Vector2(1, 9) * u), col)
	draw_rect(Rect2(at + Vector2(3, -4) * u, Vector2(1, 9) * u), col)
	draw_rect(Rect2(at + Vector2(-4, 5) * u, Vector2(8, 1) * u), col)
	# And the two slots down its face.
	draw_rect(Rect2(at + Vector2(-2, -3) * u, Vector2(1, 7) * u), col)
	draw_rect(Rect2(at + Vector2(1, -3) * u, Vector2(1, 7) * u), col)

## Scanlines and a vignette, to sit the whole thing behind glass.
func _draw_glass() -> void:
	for y in range(0, int(size.y), 4):
		draw_rect(Rect2(0, float(y), size.x, 1), Color(0, 0, 0, 0.055))
	for i in 46:
		var k := float(i) / 46.0
		draw_rect(Rect2(Vector2(i, i), size - Vector2(i, i) * 2.0),
			Color(0, 0.02, 0.03, 0.055 * (1.0 - k)), false, 1.0)
