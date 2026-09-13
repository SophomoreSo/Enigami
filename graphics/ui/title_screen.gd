class_name TitleScreen
extends Control

signal start_requested()
signal sandbox_requested()

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
const SETTLE_TOP := 452.0    ## where the board starts sinking into black

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

enum { PAD, VIA, CHIP, CAP, RES, DOTS }

var _t: float = 0.0
var _traces: Array = []      ## {pts, len, col, w}
var _parts: Array = []       ## {p, kind, col, d, s}
var _halo: Array = []        ## four alpha buckets of dot segments
var _pulses: Array = []      ## {i, t, v, len}
var _rng := RandomNumberGenerator.new()

var _board: SubViewport
var _menu_font: FontVariation
var _menu_root: VBoxContainer
var _buttons: Array = []
var _settings: Control

## Paints the copper once, into `_board`. Nothing on the board moves — the
## light that runs it is drawn live, over the top — and repainting ~7000
## static primitives every frame cost more than the whole rest of the screen
## put together (26 ms a frame on an M1 Max, against 2 ms baked).
class BoardPainter extends Node2D:
	var screen: TitleScreen
	func _draw() -> void:
		screen._paint_copper(self)

func _ready() -> void:
	UiKit.fill_screen(self)
	_rng.randomize()
	_menu_font = FontVariation.new()
	_menu_font.base_font = PIXEL
	_menu_font.spacing_glyph = 3
	_build_board()
	_build_menu()
	_build_settings()
	Audio.play_music()

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
	_menu_root = VBoxContainer.new()
	_menu_root.position = Vector2(SEAL.x - 200.0, MENU_TOP)
	_menu_root.custom_minimum_size = Vector2(400, 0)
	_menu_root.add_theme_constant_override("separation", 2)
	add_child(_menu_root)

	var start := _menu_button("START")
	start.pressed.connect(func() -> void: start_requested.emit())
	var sandbox := _menu_button("SANDBOX")
	sandbox.pressed.connect(func() -> void: sandbox_requested.emit())
	var settings := _menu_button("SETTINGS")
	settings.pressed.connect(_toggle_settings)
	var quit := _menu_button("QUIT")
	quit.pressed.connect(func() -> void: get_tree().quit())
	start.grab_focus()

## No chrome at all: the menu is text that brightens, and the marks flanking it
## are drawn by `_draw_focus_marks` so a gamepad player can see where they are.
func _menu_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxEmpty.new()
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, box)
	b.add_theme_font_override("font", _menu_font)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", MENU_INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	_menu_root.add_child(b)
	_buttons.append(b)
	return b

func _build_settings() -> void:
	# The panel keeps its full height inside a scroll that fits the screen: the
	# rebinding list is long enough to run off the bottom on its own.
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(560, 0)
	_settings = UiKit.screen_scroll(panel, Vector2(349, 56), 582.0)
	_settings.visible = false
	add_child(_settings)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UiKit.label("SETTINGS", 15, UiKit.ACCENT))
	v.add_child(UiKit.hline())
	v.add_child(_slider("Music", Audio.music_volume, func(val: float) -> void: Audio.set_music_volume(val)))
	v.add_child(_slider("Sound", Audio.sfx_volume, func(val: float) -> void:
		Audio.set_sfx_volume(val)
		Audio.play("ui")))
	v.add_child(UiKit.spacer(6))
	v.add_child(UiKit.label("Aim with the mouse, or the right stick on a gamepad.", 11, UiKit.DIM))
	v.add_child(UiKit.label("Gamepad: left stick moves, A jumps, B dashes, triggers fire slots 1-2.", 11, UiKit.DIM))
	v.add_child(UiKit.spacer(6))
	v.add_child(ControlsPanel.new())
	v.add_child(UiKit.spacer(8))
	var rb := UiKit.button("WIPE PROFILE", UiKit.BAD)
	rb.pressed.connect(func() -> void:
		GameState.reset_profile()
		Audio.play("deny"))
	v.add_child(rb)
	v.add_child(UiKit.spacer(4))
	var back := UiKit.button("BACK")
	back.pressed.connect(_toggle_settings)
	v.add_child(back)

func _slider(name: String, value: float, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UiKit.label(name, 12)
	l.custom_minimum_size = Vector2(70, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(240, 20)
	s.value_changed.connect(cb)
	h.add_child(s)
	return h

func _toggle_settings() -> void:
	_settings.visible = not _settings.visible
	_menu_root.visible = not _settings.visible
	if not _settings.visible and not _buttons.is_empty():
		_buttons[2].grab_focus()
	Audio.play("ui")

func _unhandled_input(event: InputEvent) -> void:
	if _settings != null and _settings.visible and event.is_action_pressed("ui_cancel"):
		_toggle_settings()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_t += delta
	for pu in _pulses:
		pu["t"] += float(pu["v"]) * delta
		if pu["t"] > 1.0:
			_respawn(pu)
	queue_redraw()

## --- drawing ----------------------------------------------------------------
func _draw() -> void:
	var breath := 0.5 + 0.5 * sin(_t * 0.7)
	draw_rect(Rect2(Vector2.ZERO, size), GROUND)
	if _board != null:
		draw_texture(_board.get_texture(), Vector2.ZERO)
	_draw_pulses()
	_draw_settle()
	_draw_seal(breath)
	_draw_wordmark(breath)
	_draw_focus_marks()
	_draw_records()
	_draw_glass()

func _paint_copper(c: CanvasItem) -> void:
	for tr in _traces:
		c.draw_polyline(tr["pts"], tr["col"], tr["w"])
	for pt in _parts:
		_paint_part(c, pt)

func _paint_part(c: CanvasItem, pt: Dictionary) -> void:
	var p: Vector2 = pt["p"]
	var col: Color = pt["col"]
	var d: Vector2 = pt["d"]
	var n := Vector2(-d.y, d.x)
	match int(pt["kind"]):
		PAD:
			c.draw_circle(p, 4.0, col)
			c.draw_circle(p, 1.5, GROUND)
		VIA:
			c.draw_arc(p, 4.5, 0.0, TAU, 10, col, 1.0)
		CHIP:
			var s: Vector2 = pt["s"]
			var r := Rect2(p - s * 0.5, s)
			c.draw_rect(r, Color(col.r, col.g, col.b, 0.22))
			c.draw_rect(r, col, false, 1.0)
			var pins := maxi(int(s.x / 6.0), 1)
			for i in pins:
				var x := r.position.x + 3.0 + float(i) * 6.0
				c.draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y - 3.0), col, 1.0)
				c.draw_line(Vector2(x, r.end.y), Vector2(x, r.end.y + 3.0), col, 1.0)
		CAP:
			for k in 3:
				var o := d * (float(k) * 3.0 - 3.0)
				c.draw_line(p + o - n * 7.0, p + o + n * 7.0, col, 1.0)
		RES:
			c.draw_rect(Rect2(p - d * 7.0 - n * 3.0, d * 14.0 + n * 6.0).abs(), col, false, 1.0)
			c.draw_line(p - n * 3.0, p + n * 3.0, col, 1.0)
		DOTS:
			for gx in 3:
				for gy in 4:
					c.draw_rect(Rect2(p + d * float(gx) * 4.0 + n * float(gy) * 4.0,
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

func _draw_seal(breath: float) -> void:
	var c := SEAL
	var r := SEAL_R

	for i in _halo.size():
		var pts: PackedVector2Array = _halo[i]
		if pts.is_empty():
			continue
		var a := (0.07 + 0.12 * float(i)) * (0.72 + 0.28 * breath)
		draw_multiline(pts, Color(HALO.r, HALO.g, HALO.b, a), 2.0)

	# The bloom around the rim: concentric arcs fading outward, which is as
	# close to a soft glow as a line renderer gets. It wants to be wide and
	# weak — a few bright rings read as a target, not as light.
	for i in 26:
		var k := float(i) / 26.0
		draw_arc(c, r + 1.0 + k * 44.0, 0.0, TAU, 96,
			Color(CREAM.r, CREAM.g, CREAM.b,
				(1.0 - k) * (1.0 - k) * 0.16 * (0.62 + 0.38 * breath)), 3.0)

	draw_circle(c, r - 1.0, PLATE)
	draw_arc(c, r, 0.0, TAU, 180, Color(CREAM.r, CREAM.g, CREAM.b, 0.82 + 0.18 * breath), 2.5)
	draw_arc(c, r - 6.0, 0.0, TAU, 160, Color(CREAM.r, CREAM.g, CREAM.b, 0.26), 1.0)

	var ink := Color(0.32, 0.44, 0.70, 0.88)
	var dim := Color(0.26, 0.36, 0.60, 0.62)
	var faint := Color(0.23, 0.32, 0.56, 0.44)
	for k in [0.93, 0.855, 0.835, 0.755, 0.47, 0.45]:
		draw_arc(c, r * k, 0.0, TAU, 128, faint if k < 0.5 else dim, 1.0)

	# The rune band turns about once every two minutes — under the threshold
	# where you would call it spinning, over the one where the seal looks dead.
	var rot := _t * 0.05
	for i in 98:
		var a := rot + TAU * float(i) / 98.0
		var d := Vector2(cos(a), sin(a))
		if i % 7 == 0:
			draw_line(c + d * (r * 0.862), c + d * (r * 0.925), ink, 1.5)
			draw_rect(Rect2(c + d * (r * 0.90) - Vector2(1.5, 1.5), Vector2(3, 3)), ink)
		else:
			draw_line(c + d * (r * 0.868), c + d * (r * 0.90 + (6.0 if i % 2 == 0 else 2.0)),
				dim, 1.0)
	# A finer band inside it, turning the other way.
	for i in 60:
		var a := -rot * 1.6 + TAU * float(i) / 60.0
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * (r * 0.775), c + d * (r * 0.80), faint, 1.0)

	# Two heptagrams, the inner one turned against the outer, with spokes
	# carrying the outer's points out to the rune band.
	var vp: Array = []
	for i in 7:
		var a := -PI * 0.5 + TAU * float(i) / 7.0
		vp.append(c + Vector2(cos(a), sin(a)) * (r * 0.70))
	for i in 7:
		draw_line(vp[i], vp[(i + 3) % 7], ink, 1.0)
		draw_circle(vp[i], 3.0, Color(0.45, 0.60, 0.88, 0.85))
		draw_arc(vp[i], 6.0, 0.0, TAU, 10, dim, 1.0)
		var d: Vector2 = (vp[i] - c).normalized()
		draw_line(c + d * (r * 0.70), c + d * (r * 0.835), faint, 1.0)
	var ip: Array = []
	for i in 7:
		var a := PI * 0.5 + TAU * (float(i) + 0.5) / 7.0
		ip.append(c + Vector2(cos(a), sin(a)) * (r * 0.45))
	for i in 7:
		draw_line(ip[i], ip[(i + 2) % 7], faint, 1.0)

	# The plate the wordmark sits against, and the chamber under it.
	draw_rect(Rect2(c - Vector2(r * 0.54, r * 0.28), Vector2(r * 1.08, r * 0.56)), dim, false, 1.0)
	draw_rect(Rect2(c - Vector2(r * 0.50, r * 0.24), Vector2(r * 1.00, r * 0.48)), faint, false, 1.0)
	for i in 3:
		var a := PI * 0.5 + TAU * float(i) / 3.0
		var b := PI * 0.5 + TAU * float(i + 1) / 3.0
		draw_line(c + Vector2(cos(a), sin(a)) * (r * 0.56),
			c + Vector2(cos(b), sin(b)) * (r * 0.56), dim, 1.0)
	# The lower half of the seal is the half the wordmark does not cover, so it
	# carries the detail: a graduated band, and the core hung at the bottom.
	for i in 46:
		var a := PI * 0.12 + PI * 0.76 * (float(i) / 45.0)
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * (r * 0.615), c + d * (r * 0.615 + (7.0 if i % 5 == 0 else 3.0)),
			dim if i % 5 == 0 else faint, 1.0)
	draw_arc(c, r * 0.615, PI * 0.10, PI * 0.90, 64, faint, 1.0)

	var core := c + Vector2(0, r * 0.50)
	draw_arc(core, 14.0, 0.0, TAU, 18, ink, 1.0)
	draw_arc(core, 9.0, 0.0, TAU, 14, dim, 1.0)
	draw_circle(core, 3.0, Color(0.50, 0.66, 0.92, 0.85))
	for i in 6:
		var a := TAU * float(i) / 6.0 - rot * 2.0
		var d := Vector2(cos(a), sin(a))
		draw_line(core + d * 14.0, core + d * 21.0, dim, 1.0)
	_diamond(core, 26.0, faint)

	_draw_pendant(c + Vector2(0, r), breath)

## The charm hanging off the bottom of the seal, and the one place the menu and
## the seal touch.
func _draw_pendant(top: Vector2, breath: float) -> void:
	var glow := Color(SPARK.r, SPARK.g, SPARK.b, 0.30 + 0.35 * breath)
	draw_line(top, top + Vector2(0, 28), Color(CREAM.r, CREAM.g, CREAM.b, 0.55), 1.0)
	var node := top + Vector2(0, 34)
	for i in 4:
		draw_circle(node, 5.0 + float(i) * 3.0, Color(glow.r, glow.g, glow.b, glow.a * 0.14))
	draw_arc(node, 5.0, 0.0, TAU, 12, Color(CREAM.r, CREAM.g, CREAM.b, 0.85), 1.5)
	_diamond(node + Vector2(0, 15), 7.0, Color(SPARK.r, SPARK.g, SPARK.b, 0.75 + 0.25 * breath))

func _diamond(p: Vector2, r: float, col: Color) -> void:
	draw_polyline(PackedVector2Array([
		p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r),
		p + Vector2(-r, 0), p + Vector2(0, -r)]), col, 1.5)

func _draw_wordmark(breath: float) -> void:
	var s := "Enigami"
	var px := 142
	var w := SERIF.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := Vector2(SEAL.x - w * 0.5, SEAL.y + 46.0)
	for i in 8:
		var a := TAU * float(i) / 8.0
		draw_string(SERIF, at + Vector2(cos(a), sin(a)) * 5.0, s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, px,
			Color(CREAM.r, CREAM.g, CREAM.b, 0.05 + 0.035 * breath))
	draw_string(SERIF, at + Vector2(3, 4), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
		Color(0.0, 0.055, 0.11, 0.85))
	draw_string(SERIF, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, CREAM)

func _draw_focus_marks() -> void:
	if _menu_root == null or not _menu_root.visible:
		return
	var f := get_viewport().gui_get_focus_owner()
	if f == null or not _buttons.has(f):
		return
	var r := (f as Control).get_global_rect()
	r.position -= global_position
	var y := r.position.y + r.size.y * 0.5
	var beat := 0.55 + 0.45 * sin(_t * 4.0)
	var col := Color(SPARK.r, SPARK.g, SPARK.b, beat)
	_diamond(Vector2(r.position.x + 8.0, y), 4.0, col)
	_diamond(Vector2(r.end.x - 8.0, y), 4.0, col)

func _draw_records() -> void:
	if _settings != null and _settings.visible:
		return
	var rec: Dictionary = GameState.records
	var line := "RAIDS %d   ESCAPED %d   LOST %d   KILLS %d   BEST HAUL %d" % [
		rec["raids"], rec["escapes"], rec["deaths"], rec["kills"], rec["best_haul"]]
	var w := _menu_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(_menu_font, Vector2(SEAL.x - w * 0.5, 708.0), line,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.30, 0.42, 0.62, 0.75))

## Scanlines and a vignette, to sit the whole thing behind glass.
func _draw_glass() -> void:
	for y in range(0, int(size.y), 4):
		draw_rect(Rect2(0, float(y), size.x, 1), Color(0, 0, 0, 0.055))
	for i in 46:
		var k := float(i) / 46.0
		draw_rect(Rect2(Vector2(i, i), size - Vector2(i, i) * 2.0),
			Color(0, 0.02, 0.03, 0.055 * (1.0 - k)), false, 1.0)
