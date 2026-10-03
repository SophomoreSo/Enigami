class_name HideoutCity
extends HideoutScenery

## The hideout as a floor of some tower in a city that never gets dry.
## One wall of it is glass, and the city is out there in the rain — three
## depths of towers with their windows lit, signs on the nearest of them, a
## train going by; the rest is what a room like this is fitted with: ducts and
## tube lights, a rack of weapons, a counter with somebody behind it, and the
## gate in a bay of its own, under the board that shows where it goes.
##
## One of the hideout's looks (`HideoutThemes`), on the ground they all stand
## on (`HideoutScenery`): everything is placed in pixels of the buffer the
## world is drawn into, drawn once or drawn again as it moves, and reads the
## room without changing it.

## --- where things are, in buffer pixels of the room -------------------------
## The glass: from under the ceiling's run of pipes down to the sill, and from
## the pillar on the left wall across to the one the gate's bay starts at.
const GLASS_TOP := 48
const SILL := 224
const GLASS_LEFT := 30
const GLASS_RIGHT := 430
## The far side of the pillar between the glass and the gate's bay.
const BAY_LEFT := 440
## How far a depth of the city may slide as the player walks the room, and so
## how far past the glass each is drawn. The pillars are what hide the ends.
const SLIDE := 7
## The line the train runs on, out between the middle towers and the near.
const RAIL := 198
## The posts between the panes, by their left edges. What is out in the city to
## be read is put clear of them, however far its depth slides.
const POSTS := [108, 189, 270, 351]
## Where the tube lights hang, by their middles. Clear of the top left, where
## the readout is.
const TUBES := [196, 328, 470, 590]
## The board over the gate's bay, by how far left of the gate its left edge
## is, and the fan beside it, by how far right its middle.
const BOARD := 94
const FAN := 15
## The signs on the nearest towers: where each board's top-left is and how big
## it is, what it says, whether its letters run down it or across, the light it
## is in, and which letter of it is on its way out and how often it shows — a
## `gone` one goes dark where another only stutters.
const SIGNS := [
	{"at": Vector2i(220, 82), "size": Vector2i(20, 40), "says": "국수", "down": true,
		"light": "pink", "weak": 1, "every": 9.0, "gone": false},
	{"at": Vector2i(42, 78), "size": Vector2i(44, 12), "says": "ENIGAMI", "down": false,
		"light": "cyan", "weak": -1, "every": 0.0, "gone": false},
	{"at": Vector2i(378, 118), "size": Vector2i(20, 58), "says": "노래방", "down": true,
		"light": "amber", "weak": 1, "every": 5.0, "gone": true},
]
## And the screens beside them: one running its bars, one selling something
## round.
const SCREENS := [
	{"at": Vector2i(128, 155), "size": Vector2i(28, 16)},
	{"at": Vector2i(403, 125), "size": Vector2i(18, 22)},
]

## Back to front. The ones that move are drawn again REDRAWS times a second;
## the rest once.
var _far: Layer
var _beams: Layer
var _mid: Layer
var _traffic: Layer
var _near: Layer
var _signs: Layer
var _rain: Layer
var _wall: Layer
var _wall_life: Layer
var _fittings: Layer
var _life: Layer

## The towers of each depth, left to right: `{x, w, top, tone, lit, seed, mast, step}`.
var _far_towers: Array = []
var _mid_towers: Array = []
var _near_towers: Array = []
## Windows among the middle towers that somebody is still up behind:
## `{x, y, col, every, from}`.
var _winks: Array = []
## The rain: `{x, y, speed}`, where each streak is when the clock is at nothing.
var _drops: Array = []
## The beads of it on the glass: `{x, y, tail}`, and the few that are running,
## `{x, y, speed}`.
var _beads: Array = []
var _runs: Array = []

func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC17E
	_far_towers = _raise(rng, 150, 196, 8, 20)
	_mid_towers = _raise(rng, 104, 180, 14, 30)
	# Two that go up past all the rest, thin, with a light on top.
	for spire in [[160, 7, 74], [306, 9, 84]]:
		_mid_towers.append({"x": spire[0], "w": spire[1], "top": spire[2], "tone": 3, "lit": 0.3,
			"seed": rng.randi(), "mast": true, "step": true})
	_near_towers = _stand_near(rng)
	for i in 14:
		var t: Dictionary = _mid_towers[rng.randi() % _mid_towers.size()]
		@warning_ignore("integer_division")
		var cols := maxi(1, (int(t["w"]) - 3) / 3)
		@warning_ignore("integer_division")
		var rows := maxi(1, (SILL - int(t["top"]) - 6) / 4)
		_winks.append({"x": int(t["x"]) + 2 + (rng.randi() % cols) * 3,
			"y": int(t["top"]) + 3 + (rng.randi() % rows) * 4,
			"col": Style.CITY_LIGHTS[rng.randi() % Style.CITY_LIGHTS.size()],
			"every": rng.randf_range(5.0, 14.0), "from": rng.randf_range(0.0, 14.0)})
	var wide := GLASS_RIGHT - GLASS_LEFT + 2 * SLIDE
	for i in 110:
		_drops.append({"x": rng.randi_range(0, wide), "y": rng.randi_range(0, SILL - GLASS_TOP),
			"speed": rng.randf_range(210.0, 300.0)})
	for i in 70:
		_beads.append({"x": rng.randi_range(GLASS_LEFT, GLASS_RIGHT - 1),
			"y": rng.randi_range(GLASS_TOP + 4, SILL - 2), "tail": rng.randi_range(0, 3)})
	for i in 7:
		_runs.append({"x": rng.randi_range(GLASS_LEFT + 2, GLASS_RIGHT - 3),
			"y": rng.randi_range(0, SILL - GLASS_TOP), "speed": rng.randf_range(5.0, 13.0)})
	_far = still(_paint_far)
	_beams = moving(_paint_beams)
	_mid = still(_paint_mid)
	_traffic = moving(_paint_traffic)
	_near = still(_paint_near)
	_signs = moving(_paint_signs)
	_rain = moving(_paint_rain)
	_wall = still(_paint_wall)
	_wall_life = moving(_paint_wall_life)
	_fittings = still(_paint_fittings)
	_life = moving(_paint_life)

## The city slides a little against the glass as the player walks the room,
## the near towers furthest: whole pixels of the buffer, and never more than
## SLIDE of them.
func _slide(across: float) -> void:
	_far.position.x = slid(across, 2.0)
	_beams.position.x = _far.position.x
	_mid.position.x = slid(across, 4.0)
	_traffic.position.x = _mid.position.x
	_near.position.x = slid(across, float(SLIDE))
	_signs.position.x = _near.position.x

## --- the city ---------------------------------------------------------------

## A depth of towers across the glass, side by side.
func _raise(rng: RandomNumberGenerator, highest: int, lowest: int, narrow: int, wide: int) -> Array:
	var out: Array = []
	var x := GLASS_LEFT - SLIDE
	while x < GLASS_RIGHT + SLIDE:
		var w := rng.randi_range(narrow, wide)
		out.append({"x": x, "w": w, "top": rng.randi_range(highest, lowest),
			"tone": rng.randi() % Style.CITY_LIGHTS.size(), "lit": rng.randf_range(0.10, 0.42),
			"seed": rng.randi(), "mast": rng.randf() < 0.3, "step": rng.randf() < 0.4})
		x += w + (rng.randi_range(0, 3) if rng.randf() < 0.5 else 0)
	return out

## The nearest towers: few, wide and tall, and put where they frame the view
## rather than fill it.
func _stand_near(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for t in [[GLASS_LEFT - SLIDE, 46, 92], [124, 36, 150], [214, 48, 70], [330, 26, 164], [378, 60, 112]]:
		out.append({"x": t[0], "w": t[1], "top": t[2], "tone": rng.randi() % Style.CITY_LIGHTS.size(),
			"lit": rng.randf_range(0.08, 0.2), "seed": rng.randi(), "mast": false, "step": false})
	return out

func _paint_far(c: CanvasItem) -> void:
	# The sky first, since nothing is further off: bands of it, darkest overhead
	# and warming into the haze the city throws up.
	var x := GLASS_LEFT - SLIDE
	var w := GLASS_RIGHT - GLASS_LEFT + 2 * SLIDE
	bands(c, x, GLASS_TOP, w, SILL - GLASS_TOP, Style.CITY_SKY)
	# A moon the haze has got to, low and too big.
	disc(c, 300, 106, 19, faded(Style.CITY_MOON, 0.18))
	disc(c, 300, 106, 17, faded(Style.CITY_MOON, 0.3))
	disc(c, 300, 106, 15, Style.CITY_MOON)
	for y in [98, 104, 109, 113, 116, 119]:
		box(c, 284, y, 33, 1, Style.CITY_SKY[4])
	_paint_towers(c, _far_towers, Style.CITY_FAR, 3, 3, 1, 1, 0.45)
	# The haze lying in the streets between them and everything nearer.
	for k in 4:
		box(c, x, SILL - 26 + k * 6, w, 7, faded(Style.CITY_SKY[7], 0.10 + 0.06 * k))

## Searchlights from somewhere behind the far towers, going round.
func _paint_beams(c: CanvasItem) -> void:
	for b in [[96, 0.23, 0.0], [352, 0.17, 2.0]]:
		var lean := sin(_t * float(b[1]) + float(b[2])) * 0.55
		for k in 30:
			var up := k * 5
			var bx := int(b[0]) + int(tan(lean) * float(up))
			@warning_ignore("integer_division")
			_out_there(c, bx - 1 - k / 6, SILL - 30 - up, 3 + k / 3, 5,
				Color(0.72, 0.62, 1.0, 0.055 * (1.0 - k / 30.0)))

func _paint_mid(c: CanvasItem) -> void:
	_paint_towers(c, _mid_towers, Style.CITY_MID, 3, 4, 1, 2, 0.75)

func _paint_near(c: CanvasItem) -> void:
	# The line the train runs on, on its legs, and the towers in front of it.
	box(c, GLASS_LEFT - SLIDE, RAIL, GLASS_RIGHT - GLASS_LEFT + 2 * SLIDE, 2, Style.CITY_NEAR.lightened(0.05))
	for x in range(GLASS_LEFT + 10, GLASS_RIGHT, 46):
		box(c, x, RAIL + 2, 2, SILL - RAIL, Style.CITY_NEAR.lightened(0.05))
	_paint_towers(c, _near_towers, Style.CITY_NEAR, 5, 5, 2, 2, 0.85)
	# A line of light up the corner of two of them.
	for edge in [[2, Style.NEON_CYAN, 0.55], [0, Style.NEON_PINK, 0.45]]:
		var t: Dictionary = _near_towers[edge[0]]
		box(c, int(t["x"]) + int(t["w"]) - 1, int(t["top"]) + 4, 1, SILL - int(t["top"]) - 4,
			faded(edge[1], float(edge[2])))

## Towers, and their windows: a grid of them `across` by `down` apart, each
## `ww` by `wh`, some lit — most in the tower's own colour of light — and
## `bright` of the way from dark to it.
func _paint_towers(c: CanvasItem, towers: Array, body: Color, across: int, down: int,
		ww: int, wh: int, bright: float) -> void:
	var rng := RandomNumberGenerator.new()
	for t in towers:
		var x: int = t["x"]
		var w: int = t["w"]
		var top: int = t["top"]
		rng.seed = t["seed"]
		box(c, x, top, w, SILL - top, body)
		# The edge the haze catches.
		box(c, x, top, 1, SILL - top, body.lightened(0.06))
		if t["step"]:
			# A narrower storey or two on top of it.
			@warning_ignore("integer_division")
			var inset := maxi(2, w / 5)
			box(c, x + inset, top - 6, w - inset * 2, 6, body)
		elif w > 12 and rng.randf() < 0.6:
			# Or what collects on a roof: a tank, a plant room.
			box(c, x + rng.randi_range(2, w - 8), top - 3, rng.randi_range(3, 6), 3, body)
		if t["mast"]:
			@warning_ignore("integer_division")
			box(c, x + w / 2, top - 14, 1, 14, body)
		var tone: Color = Style.CITY_LIGHTS[t["tone"]]
		var y := top + 3
		while y < SILL - wh:
			# A whole floor in the dark now and then, and one all lit.
			var floor_lit := float(t["lit"]) * (0.0 if rng.randf() < 0.22 else (2.4 if rng.randf() < 0.08 else 1.0))
			var wx := x + 2
			while wx + ww <= x + w - 1:
				if rng.randf() < floor_lit:
					var light: Color = tone if rng.randf() < 0.75 \
						else Style.CITY_LIGHTS[rng.randi() % Style.CITY_LIGHTS.size()]
					box(c, wx, y, ww, wh, body.lerp(light, bright * rng.randf_range(0.45, 1.0)))
				wx += across
			y += down

## What moves out among the middle towers: the lights on their masts, a window
## going dark and another coming on, the train, and whatever is flying tonight.
func _paint_traffic(c: CanvasItem) -> void:
	for t in _mid_towers:
		if t["mast"] and fmod(_t + float(int(t["seed"]) % 7) * 0.3, 1.7) < 0.25:
			@warning_ignore("integer_division")
			box(c, int(t["x"]) + int(t["w"]) / 2, int(t["top"]) - 15, 1, 1, Style.NEON_RED)
	for w in _winks:
		var up := fmod(_t + float(w["from"]), float(w["every"])) < float(w["every"]) * 0.5
		box(c, int(w["x"]), int(w["y"]), 1, 2,
			Style.CITY_MID.lerp(w["col"], 0.7) if up else Style.CITY_MID)
	# The train: a string of lit windows along the rail, every so often.
	var span := GLASS_RIGHT - GLASS_LEFT + 2 * SLIDE
	var into := fmod(_t, 19.0)
	if into < 6.0:
		var head := GLASS_LEFT - SLIDE - 70 + int(into / 6.0 * float(span + 140))
		for car in 4:
			var cx := head - car * 17
			_out_there(c, cx, RAIL - 5, 15, 5, Style.CITY_MID.lightened(0.08))
			for k in 4:
				_out_there(c, cx + 2 + k * 3, RAIL - 4, 2, 2, Style.CITY_LIGHTS[2])
	# Fliers: a white light ahead and a red one behind, slow, at their own heights.
	for f in [[0.0, 86, 9.0, 1], [5.0, 122, 13.0, -1], [11.0, 64, 16.0, 1], [3.0, 142, 11.0, 1]]:
		var along := fmod(_t + float(f[0]), float(f[2])) / float(f[2])
		var fx := GLASS_LEFT - SLIDE + int(along * float(span))
		if int(f[3]) < 0:
			fx = GLASS_LEFT - SLIDE + span - int(along * float(span))
		_out_there(c, fx, int(f[1]), 2, 1, Style.CITY_NEAR)
		_out_there(c, fx + (2 if int(f[3]) > 0 else -1), int(f[1]), 1, 1, Style.CITY_LIGHTS[3])
		_out_there(c, fx + (-1 if int(f[3]) > 0 else 2), int(f[1]), 1, 1, Style.NEON_RED)

## A box of something out in the city, cut off where its depth ends: nothing
## out there may show past the glass.
func _out_there(c: CanvasItem, x: int, y: int, w: int, h: int, col: Color) -> void:
	var from := maxi(x, GLASS_LEFT - SLIDE)
	var to := mini(x + w, GLASS_RIGHT + SLIDE)
	box(c, from, maxi(y, GLASS_TOP), to - from, h - maxi(GLASS_TOP - y, 0), col)

## The signs on the nearest towers, in light: what they say, and the glow of
## it. And the screens, which have nothing to say and say it brightly.
func _paint_signs(c: CanvasItem) -> void:
	var lights := {"pink": Style.NEON_PINK, "cyan": Style.NEON_CYAN, "amber": Style.NEON_AMBER}
	for i in SIGNS.size():
		var board: Dictionary = SIGNS[i]
		var at: Vector2i = board["at"]
		var size: Vector2i = board["size"]
		var says := String(board["says"])
		var light: Color = lights[board["light"]]
		_sign_board(c, at.x, at.y, size.x, size.y)
		if not board["down"]:
			halo(c, at.x + 2, at.y + 2, size.x - 4, size.y - 4, light, 3, 0.09)
			@warning_ignore("integer_division")
			words(c, at.x + size.x / 2, at.y + 2, says, light, 8)
			# The legs it stands on the roof by.
			box(c, at.x + 8, at.y + size.y, 1, 2, Style.CITY_NEAR.lightened(0.14))
			box(c, at.x + size.x - 10, at.y + size.y, 1, 2, Style.CITY_NEAR.lightened(0.14))
			continue
		for k in says.length():
			var lit := light
			if k == int(board["weak"]):
				var on := stutter(_t, float(board["every"]), 3 + i * 4)
				lit = faded(light, (0.3 if on < 1.0 else 1.0) if board["gone"] else on)
			halo(c, at.x + 2, at.y + 3 + k * 18, 16, 16, lit, 3, 0.10 * lit.a)
			@warning_ignore("integer_division")
			words(c, at.x + size.x / 2, at.y + 3 + k * 18, says[k], lit, 16)
	# The bars.
	var bars: Vector2i = SCREENS[0]["at"]
	_screen(c, SCREENS[0], Color(0.03, 0.03, 0.08))
	for k in 6:
		var tall := 2 + int(5.0 + 5.0 * sin(_t * (1.3 + 0.37 * k) + k * 1.9))
		box(c, bars.x + 3 + k * 4, bars.y + 14 - tall, 3, tall, Style.NEON_CYAN if k % 2 == 0 else Style.NEON_PINK)
	# And the something round.
	var ad: Vector2i = SCREENS[1]["at"]
	_screen(c, SCREENS[1], Color(0.05, 0.02, 0.08))
	var beat := 0.5 + 0.5 * sin(_t * 2.2)
	disc(c, ad.x + 9, ad.y + 10, 3 + int(beat * 3.0), faded(Style.NEON_PINK, 0.35 + 0.4 * beat), 2 + int(beat * 2.0))
	disc(c, ad.x + 9, ad.y + 10, 2, Style.NEON_CYAN)
	box(c, ad.x + 4, ad.y + 18, 10, 1, faded(Style.NEON_AMBER, 0.8))

## A screen's frame, and the dark of it before anything is on.
func _screen(c: CanvasItem, screen: Dictionary, dark: Color) -> void:
	var at: Vector2i = screen["at"]
	var size: Vector2i = screen["size"]
	box(c, at.x, at.y, size.x, size.y, Style.CITY_NEAR.lightened(0.12))
	box(c, at.x + 1, at.y + 1, size.x - 2, size.y - 2, dark)

## The dark board a sign's letters stand on, so they read over lit windows.
func _sign_board(c: CanvasItem, x: int, y: int, w: int, h: int) -> void:
	box(c, x, y, w, h, Color(0.02, 0.02, 0.06))
	box(c, x, y, w, 1, Style.CITY_NEAR.lightened(0.14))
	box(c, x, y + h - 1, w, 1, Style.CITY_NEAR.lightened(0.14))

func _paint_rain(c: CanvasItem) -> void:
	var w := GLASS_RIGHT - GLASS_LEFT + 2 * SLIDE
	var h := SILL - GLASS_TOP
	for d in _drops:
		var fall := float(d["y"]) + float(d["speed"]) * _t
		var y := int(fall) % h
		# Blown a little: a pixel across for every three it falls.
		var x := posmod(int(d["x"]) - int(fall / 3.0), w)
		box(c, GLASS_LEFT - SLIDE + x, GLASS_TOP + y, 1, mini(3, h - y), Style.CITY_RAIN)

## --- the room ---------------------------------------------------------------

func _paint_wall(c: CanvasItem) -> void:
	_paint_glazing(c)
	_paint_ceiling(c)
	_paint_bay(c)
	_paint_under_sill(c)
	_paint_floor(c)

## What stands against the wall, in front of the light along its foot.
func _paint_fittings(c: CanvasItem) -> void:
	_paint_bench(c)
	_paint_rack(c, _at["weapons"])
	_paint_counter(c, _at["shop"])
	_paint_gate(c, _at["gate"])

## What holds the glass: a beam along the top, the sill, the posts between the
## panes, and the pillars at either end. And the glass itself, which shows as
## the light sliding across it and the rain beaded on it.
func _paint_glazing(c: CanvasItem) -> void:
	var sheen := Color(0.75, 0.86, 1.0, 0.035)
	for pane in [GLASS_LEFT + 24, GLASS_LEFT + 144, GLASS_LEFT + 230, GLASS_LEFT + 344]:
		for k in 44:
			box(c, pane + 60 - k * 2, GLASS_TOP + k * 4, 9, 4, sheen)
			box(c, pane + 76 - k * 2, GLASS_TOP + k * 4, 3, 4, sheen)
	for b in _beads:
		box(c, int(b["x"]), int(b["y"]), 1, 1, Color(0.78, 0.88, 1.0, 0.30))
		box(c, int(b["x"]), int(b["y"]) - int(b["tail"]), 1, int(b["tail"]), Color(0.78, 0.88, 1.0, 0.10))
	for x in POSTS:
		box(c, x, GLASS_TOP, 3, SILL - GLASS_TOP, Style.HIDEOUT_STEEL)
		box(c, x, GLASS_TOP, 1, SILL - GLASS_TOP, Style.HIDEOUT_STEEL_LIT)
	box(c, GLASS_LEFT, 132, GLASS_RIGHT - GLASS_LEFT, 2, Style.HIDEOUT_STEEL)
	box(c, GLASS_LEFT, 132, GLASS_RIGHT - GLASS_LEFT, 1, Style.HIDEOUT_STEEL_LIT)
	_pillar(c, LEFT, GLASS_LEFT - LEFT)
	_pillar(c, GLASS_RIGHT, BAY_LEFT - GLASS_RIGHT)

## A pillar, floor to ceiling: riveted, with the light on one edge of it.
func _pillar(c: CanvasItem, x: int, w: int) -> void:
	box(c, x, GLASS_TOP, w, FLOOR - GLASS_TOP, Style.HIDEOUT_PILLAR)
	box(c, x, GLASS_TOP, 1, FLOOR - GLASS_TOP, Style.HIDEOUT_STEEL_LIT.darkened(0.25))
	box(c, x + w - 1, GLASS_TOP, 1, FLOOR - GLASS_TOP, Style.HIDEOUT_SHADOW)
	for y in range(GLASS_TOP + 6, FLOOR - 4, 12):
		@warning_ignore("integer_division")
		box(c, x + w / 2, y, 1, 1, Style.HIDEOUT_STEEL_LIT.darkened(0.2))

## Overhead: the duct, the pipes under it, a cable somebody slung from light
## to light, and the tube lights' housings. The light in the tubes is
## `_paint_wall_life`'s, since one of them stutters.
func _paint_ceiling(c: CanvasItem) -> void:
	box(c, LEFT, TOP, RIGHT - LEFT, GLASS_TOP - TOP, Style.HIDEOUT_CEILING)
	# The duct, hung on straps, with a grille in it here and there.
	box(c, LEFT, 20, RIGHT - LEFT, 9, Style.HIDEOUT_STEEL.darkened(0.25))
	box(c, LEFT, 20, RIGHT - LEFT, 1, Style.HIDEOUT_STEEL_LIT.darkened(0.3))
	box(c, LEFT, 28, RIGHT - LEFT, 1, Style.HIDEOUT_SHADOW)
	for x in range(LEFT + 28, RIGHT, 56):
		box(c, x, TOP, 2, 4, Style.HIDEOUT_STEEL)
		box(c, x - 1, 20, 1, 9, Style.HIDEOUT_SHADOW)
	for x in [262, 404, 536]:
		box(c, x, 22, 14, 5, Style.HIDEOUT_SHADOW)
		for k in 4:
			box(c, x + 1 + k * 3, 23, 2, 3, Style.HIDEOUT_STEEL.darkened(0.1))
	# Two pipes under it, one of them somebody painted.
	box(c, LEFT, 33, RIGHT - LEFT, 1, Style.HIDEOUT_PIPE)
	box(c, LEFT, 36, RIGHT - LEFT, 2, Style.HIDEOUT_STEEL)
	box(c, LEFT, 36, RIGHT - LEFT, 1, Style.HIDEOUT_STEEL_LIT.darkened(0.2))
	for x in range(LEFT + 40, RIGHT, 80):
		box(c, x, 32, 2, 7, Style.HIDEOUT_STEEL.darkened(0.2))
	# The beam the glass hangs from, over everything under it.
	box(c, LEFT, GLASS_TOP - 3, RIGHT - LEFT, 4, Style.HIDEOUT_STEEL)
	box(c, LEFT, GLASS_TOP - 3, RIGHT - LEFT, 1, Style.HIDEOUT_STEEL_LIT)
	box(c, LEFT, GLASS_TOP + 1, RIGHT - LEFT, 1, Style.HIDEOUT_SHADOW)
	for i in TUBES.size():
		var x: int = TUBES[i]
		box(c, x - 11, 40, 22, 2, Style.HIDEOUT_STEEL.darkened(0.1))
		box(c, x - 9, 38, 1, 2, Style.HIDEOUT_STEEL)
		box(c, x + 8, 38, 1, 2, Style.HIDEOUT_STEEL)
		# The cable on to the next one, sagging.
		if i + 1 < TUBES.size():
			var far: int = TUBES[i + 1]
			for px in range(x + 11, far - 11, 2):
				var along := float(px - x - 11) / float(far - x - 22)
				box(c, px, 39 + int(round(4.0 * along * (1.0 - along) * 5.0)), 2, 1, Style.HIDEOUT_SHADOW)

## The wall under the sill, which the stations stand against: panelled, with a
## strip of light along its foot, and what a wall like it collects.
func _paint_under_sill(c: CanvasItem) -> void:
	box(c, LEFT, SILL, BAY_LEFT - LEFT, FLOOR - SILL, Style.HIDEOUT_WALL)
	for x in range(LEFT + 8, BAY_LEFT - 8, 40):
		box(c, x, SILL + 8, 1, FLOOR - SILL - 18, Style.HIDEOUT_SHADOW)
		box(c, x + 1, SILL + 8, 1, FLOOR - SILL - 18, Style.HIDEOUT_WALL.lightened(0.05))
	box(c, LEFT, SILL + 60, BAY_LEFT - LEFT, 1, Style.HIDEOUT_SHADOW)
	box(c, LEFT, SILL + 61, BAY_LEFT - LEFT, 1, Style.HIDEOUT_WALL.lightened(0.05))
	# The sill itself, and the dark under its lip.
	box(c, LEFT, SILL, BAY_LEFT - LEFT, 6, Style.HIDEOUT_STEEL)
	box(c, LEFT, SILL, BAY_LEFT - LEFT, 1, Style.HIDEOUT_STEEL_LIT)
	box(c, LEFT, SILL + 6, BAY_LEFT - LEFT, 2, Style.HIDEOUT_SHADOW)
	# The foot of the wall: a kickboard, with the channel the light sits in.
	box(c, LEFT, FLOOR - 10, BAY_LEFT - LEFT, 10, Style.HIDEOUT_CEILING)
	box(c, LEFT, FLOOR - 11, BAY_LEFT - LEFT, 1, Style.HIDEOUT_STEEL)
	# A box of fuses, with its conduit up to the sill.
	box(c, 211, SILL + 8, 2, 22, Style.HIDEOUT_STEEL.darkened(0.15))
	box(c, 205, SILL + 30, 14, 18, Style.HIDEOUT_STEEL)
	box(c, 205, SILL + 30, 14, 1, Style.HIDEOUT_STEEL_LIT)
	box(c, 207, SILL + 33, 10, 12, Style.HIDEOUT_STEEL.darkened(0.3))
	# Something to cool the place, dripping.
	box(c, 398, SILL + 14, 26, 14, Style.HIDEOUT_STEEL)
	box(c, 398, SILL + 14, 26, 1, Style.HIDEOUT_STEEL_LIT)
	for y in [SILL + 18, SILL + 21, SILL + 24]:
		box(c, 401, y, 20, 1, Style.HIDEOUT_SHADOW)
	# Bills, posted.
	box(c, 36, SILL + 22, 18, 26, Color(0.16, 0.06, 0.16))
	box(c, 38, SILL + 24, 14, 12, Style.NEON_PINK.darkened(0.45))
	disc(c, 45, SILL + 30, 3, Style.NEON_AMBER.darkened(0.2))
	for y in [SILL + 39, SILL + 42, SILL + 45]:
		box(c, 38, y, 14 - (y % 3) * 3, 1, Color(0.6, 0.5, 0.62))
	box(c, 58, SILL + 30, 14, 20, Color(0.05, 0.13, 0.16))
	box(c, 60, SILL + 32, 10, 6, Style.NEON_CYAN.darkened(0.5))
	for y in [SILL + 41, SILL + 44, SILL + 47]:
		box(c, 60, y, 8, 1, Color(0.4, 0.6, 0.66))
	# A hand that got to the wall first.
	stamp(c, 232, SILL + 64, [
		"..##......#...##.",
		".#..#....##..#..#",
		".#......#.#..#...",
		".#.##..#..#...##.",
		".#..#.######....#",
		"..###.....#..###.",
	], Style.NEON_VIOLET.darkened(0.25))
	# And a drum of something nobody has opened.
	box(c, 404, FLOOR - 15, 11, 15, Color(0.15, 0.11, 0.10))
	box(c, 404, FLOOR - 15, 11, 1, Color(0.26, 0.20, 0.17))
	box(c, 404, FLOOR - 11, 11, 1, Color(0.08, 0.06, 0.06))
	box(c, 404, FLOOR - 5, 11, 1, Color(0.08, 0.06, 0.06))
	stamp(c, 407, FLOOR - 10, ["..#..", ".###.", "#####", ".###.", "..#.."], Style.NEON_AMBER.darkened(0.3))

## The gate's bay: bare wall, a number, a band of warning along the top, the
## pipes that feed it, and the board over the gate that shows where it goes —
## which hangs on the same two cables as the gate's own sign.
func _paint_bay(c: CanvasItem) -> void:
	var wall := Style.HIDEOUT_WALL.lightened(0.03)
	box(c, BAY_LEFT, GLASS_TOP, RIGHT - BAY_LEFT, FLOOR - GLASS_TOP, wall)
	for y in [118, 190, 262]:
		box(c, BAY_LEFT, y, RIGHT - BAY_LEFT, 1, Style.HIDEOUT_SHADOW)
		box(c, BAY_LEFT, y + 1, RIGHT - BAY_LEFT, 1, wall.lightened(0.05))
	for x in [488, 616]:
		box(c, x, GLASS_TOP + 2, 1, FLOOR - GLASS_TOP - 2, Style.HIDEOUT_SHADOW)
	# Warning, in the colours it always comes in.
	for y in 6:
		box(c, BAY_LEFT, GLASS_TOP + 4 + y, RIGHT - BAY_LEFT, 1, Color(0.06, 0.06, 0.07))
		for x in range(BAY_LEFT - 8 + y, RIGHT, 8):
			var from := maxi(x, BAY_LEFT)
			box(c, from, GLASS_TOP + 4 + y, mini(x + 4, RIGHT) - from, 1, Style.NEON_AMBER.darkened(0.25))
	# Which bay this is.
	stamp(c, 560, 68, [
		".######...######.",
		"##....##.....###.",
		"##....##....####.",
		"##....##......##.",
		"##....##......##.",
		"##....##......##.",
		"##....##......##.",
		"##....##......##.",
		"##....##......##.",
		".######....######",
	], wall.lightened(0.10))
	# Pipes up the near corner, with a wheel to shut them, and one up the far.
	for x in [446, 452]:
		box(c, x, GLASS_TOP + 10, 3, FLOOR - GLASS_TOP - 10, Style.HIDEOUT_STEEL.darkened(0.15))
		box(c, x, GLASS_TOP + 10, 1, FLOOR - GLASS_TOP - 10, Style.HIDEOUT_STEEL_LIT.darkened(0.25))
	for y in range(GLASS_TOP + 30, FLOOR, 52):
		box(c, 444, y, 13, 2, Style.HIDEOUT_STEEL)
	disc(c, 453, 168, 5, Style.NEON_RED.darkened(0.45), 3)
	box(c, 453, 164, 1, 9, Style.NEON_RED.darkened(0.45))
	box(c, 449, 168, 9, 1, Style.NEON_RED.darkened(0.45))
	box(c, 606, GLASS_TOP + 10, 5, FLOOR - GLASS_TOP - 10, Style.HIDEOUT_STEEL.darkened(0.15))
	box(c, 606, GLASS_TOP + 10, 1, FLOOR - GLASS_TOP - 10, Style.HIDEOUT_STEEL_LIT.darkened(0.25))
	for y in range(GLASS_TOP + 20, FLOOR, 44):
		box(c, 604, y, 9, 2, Style.HIDEOUT_STEEL)
	# A notice about the gate, which nobody reads.
	stamp(c, 468, 204, [
		".....#.....",
		"....###....",
		"....###....",
		"...##.##...",
		"...##.##...",
		"..###.###..",
		"..###.###..",
		".#########.",
		".####.####.",
		"###########",
	], Style.NEON_AMBER.darkened(0.3))
	# The cables the gate's sign hangs on, all the way from the ceiling.
	var g: Vector2i = _at["gate"]
	for x in [g.x - 31, g.x + 29]:
		box(c, x, GLASS_TOP + 10, 1, SILL - GLASS_TOP - 10, Style.HIDEOUT_STEEL_LIT.darkened(0.35))
	# The board, beside them.
	var bx := g.x - BOARD
	box(c, bx + 8, GLASS_TOP + 10, 1, 32, Style.HIDEOUT_STEEL_LIT.darkened(0.35))
	box(c, bx + 57, GLASS_TOP + 10, 1, 32, Style.HIDEOUT_STEEL_LIT.darkened(0.35))
	box(c, bx - 1, 89, 68, 54, Style.HIDEOUT_SHADOW)
	box(c, bx, 90, 66, 52, Style.HIDEOUT_STEEL)
	box(c, bx, 90, 66, 1, Style.HIDEOUT_STEEL_LIT)
	box(c, bx + 2, 93, 62, 46, Color(0.02, 0.035, 0.06))
	# And a fan in the wall, to take the air out. Its blades are `_paint_wall_life`'s.
	var fan := Vector2i(g.x + FAN, 152)
	disc(c, fan.x, fan.y, 14, Style.HIDEOUT_SHADOW)
	disc(c, fan.x, fan.y, 13, Style.HIDEOUT_STEEL)
	disc(c, fan.x, fan.y, 13, Style.HIDEOUT_STEEL_LIT.darkened(0.2), 12)
	disc(c, fan.x, fan.y, 11, Color(0.03, 0.05, 0.08))

## The floor: its edge, the deck under it, the warning painted in front of the
## gate, and the light lying on it, since it is wet.
func _paint_floor(c: CanvasItem) -> void:
	box(c, LEFT, FLOOR, RIGHT - LEFT, 16, Color(0.055, 0.065, 0.10))
	box(c, LEFT, FLOOR, RIGHT - LEFT, 1, Style.HIDEOUT_STEEL_LIT)
	box(c, LEFT, FLOOR + 1, RIGHT - LEFT, 1, Style.HIDEOUT_STEEL.darkened(0.2))
	for x in range(LEFT + 20, RIGHT, 40):
		box(c, x, FLOOR + 2, 1, 14, Style.HIDEOUT_SHADOW)
	var g: Vector2i = _at["gate"]
	for k in 11:
		box(c, g.x - 44 + k * 8, FLOOR + 3, 4, 3, Style.NEON_AMBER.darkened(0.3))
		box(c, g.x - 43 + k * 8, FLOOR + 6, 4, 3, Style.NEON_AMBER.darkened(0.3))
	wet(c, LEFT, BAY_LEFT - LEFT, Style.NEON_VIOLET, 0.10)
	wet(c, int(_at["weapons"].x) - 24, 48, Style.NEON_CYAN, 0.12)
	wet(c, int(_at["shop"].x) - 30, 60, Style.NEON_PINK, 0.14)
	wet(c, int(_at["shop"].x) + 40, 22, Style.NEON_PINK, 0.10)
	for x in TUBES:
		wet(c, x - 12, 24, Style.HIDEOUT_TUBE, 0.06)

## --- what stands against the wall --------------------------------------------

## Somewhere to wait.
func _paint_bench(c: CanvasItem) -> void:
	var x := 162
	var seat := Color(0.09, 0.15, 0.19)
	box(c, x, FLOOR - 25, 38, 10, seat)
	box(c, x, FLOOR - 25, 38, 1, seat.lightened(0.14))
	for k in [12, 25]:
		box(c, x + k, FLOOR - 24, 1, 9, Style.HIDEOUT_SHADOW)
	box(c, x - 1, FLOOR - 13, 40, 3, seat.lightened(0.06))
	box(c, x - 1, FLOOR - 13, 40, 1, seat.lightened(0.2))
	for k in [2, 34]:
		box(c, x + k, FLOOR - 10, 2, 10, Style.HIDEOUT_STEEL)

## The rack: a board of pegs with what is for carrying hung on it, the rock,
## which is free, on a shelf of its own, and a screen on an arm for looking a
## graph over. Its lights are `_paint_life`'s.
func _paint_rack(c: CanvasItem, at: Vector2i) -> void:
	var x := at.x - 27
	var y := at.y - 58
	box(c, x - 1, y - 1, 56, 59, Style.HIDEOUT_SHADOW)
	box(c, x, y, 54, 58, Style.HIDEOUT_STEEL_LIT.darkened(0.25))
	box(c, x, y, 54, 1, Style.HIDEOUT_STEEL_LIT.lightened(0.1))
	box(c, x + 2, y + 3, 50, 41, Color(0.04, 0.05, 0.09))
	for py in range(y + 6, y + 42, 4):
		for px in range(x + 5, x + 51, 4):
			box(c, px, py, 1, 1, Color(0.09, 0.115, 0.18))
	# A sword.
	box(c, x + 9, y + 8, 2, 22, Color(0.72, 0.80, 0.90))
	box(c, x + 9, y + 8, 1, 22, Color(0.92, 0.96, 1.0))
	box(c, x + 6, y + 30, 8, 1, Color(0.55, 0.63, 0.78))
	box(c, x + 9, y + 31, 2, 6, Color(0.46, 0.33, 0.24))
	# An axe.
	box(c, x + 22, y + 8, 1, 30, Color(0.50, 0.37, 0.27))
	stamp(c, x + 18, y + 9, [
		".###.",
		"#####",
		"#####",
		"##.##",
		"#...#",
	], Color(0.66, 0.72, 0.82))
	# A staff, with whatever that is in the end of it.
	box(c, x + 33, y + 12, 1, 26, Color(0.46, 0.38, 0.52))
	# The shelf, and the rock.
	box(c, x + 39, y + 30, 11, 1, Style.HIDEOUT_STEEL_LIT)
	stamp(c, x + 41, y + 25, [
		"..###..",
		".#####.",
		"#######",
		"#######",
		".#####.",
	], Color(0.44, 0.46, 0.53))
	box(c, x + 43, y + 26, 2, 1, Color(0.60, 0.62, 0.68))
	# Drawers under it.
	box(c, x + 2, y + 45, 50, 11, Style.HIDEOUT_STEEL.darkened(0.1))
	box(c, x + 26, y + 45, 1, 11, Style.HIDEOUT_SHADOW)
	box(c, x + 11, y + 50, 6, 1, Style.HIDEOUT_STEEL_LIT.lightened(0.1))
	box(c, x + 36, y + 50, 6, 1, Style.HIDEOUT_STEEL_LIT.lightened(0.1))
	box(c, x, y + 56, 54, 2, Style.HIDEOUT_SHADOW)
	# The screen, on its arm.
	box(c, x + 54, y + 20, 5, 1, Style.HIDEOUT_STEEL_LIT.darkened(0.2))
	box(c, x + 58, y + 12, 16, 14, Style.HIDEOUT_STEEL_LIT.darkened(0.25))
	box(c, x + 59, y + 13, 14, 12, Color(0.02, 0.05, 0.08))

## The counter: shelves of what there is to buy, an awning nobody needed
## indoors, a machine that sells the rest, and crates of what has not been
## unpacked. Whoever keeps it is `_paint_life`'s.
func _paint_counter(c: CanvasItem, at: Vector2i) -> void:
	var x := at.x - 32
	var y := at.y
	# Shelves behind.
	box(c, x + 4, y - 58, 56, 40, Style.HIDEOUT_STEEL)
	box(c, x + 6, y - 56, 52, 36, Color(0.035, 0.04, 0.075))
	var goods := [Style.NEON_CYAN, Style.NEON_PINK, Style.NEON_AMBER, Style.NEON_GREEN, Style.NEON_VIOLET]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5407
	for shelf in 3:
		var sy := y - 46 + shelf * 12
		box(c, x + 6, sy, 52, 1, Style.HIDEOUT_STEEL_LIT.darkened(0.2))
		var gx := x + 8
		while gx < x + 54:
			var gw := rng.randi_range(2, 4)
			var gh := rng.randi_range(3, 7)
			# Not where the keeper stands.
			if not (shelf > 0 and gx > x + 20 and gx < x + 42):
				box(c, gx, sy - gh, gw, gh, (goods[rng.randi() % goods.size()] as Color).darkened(rng.randf_range(0.25, 0.5)))
			gx += gw + rng.randi_range(1, 3)
	# The awning.
	for k in 12:
		var stripe := Style.NEON_PINK.darkened(0.3) if k % 2 == 0 else Color(0.14, 0.09, 0.21)
		box(c, x - 4 + k * 6, y - 64, 6, 5, stripe)
		box(c, x - 3 + k * 6, y - 59, 4, 1, stripe)
	box(c, x - 4, y - 65, 72, 1, Style.HIDEOUT_STEEL_LIT)
	# The counter itself.
	box(c, x - 1, y - 21, 66, 21, Style.HIDEOUT_SHADOW)
	box(c, x, y - 20, 64, 3, Style.HIDEOUT_STEEL_LIT.lightened(0.12))
	box(c, x + 2, y - 17, 60, 17, Style.HIDEOUT_STEEL)
	for gx in [x + 16, x + 32, x + 48]:
		box(c, gx, y - 15, 1, 13, Style.HIDEOUT_SHADOW)
	box(c, x + 2, y - 17, 60, 1, Style.HIDEOUT_SHADOW)
	# The machine.
	var mx := x + 72
	box(c, mx - 1, y - 49, 24, 49, Style.HIDEOUT_SHADOW)
	box(c, mx, y - 48, 22, 48, Color(0.08, 0.13, 0.22))
	box(c, mx, y - 48, 22, 1, Style.HIDEOUT_STEEL_LIT)
	box(c, mx, y - 48, 1, 48, Color(0.12, 0.19, 0.31))
	box(c, mx + 2, y - 42, 13, 28, Color(0.03, 0.05, 0.09))
	for row in 4:
		for col in 3:
			box(c, mx + 3 + col * 4, y - 40 + row * 7, 3, 4,
				(goods[(row * 3 + col) % goods.size()] as Color).darkened(0.2))
		box(c, mx + 2, y - 35 + row * 7, 13, 1, Style.HIDEOUT_STEEL.darkened(0.2))
	box(c, mx + 17, y - 40, 3, 8, Color(0.03, 0.05, 0.09))
	box(c, mx + 4, y - 10, 10, 5, Color(0.02, 0.03, 0.05))
	# Crates.
	box(c, x - 22, y - 16, 18, 16, Color(0.14, 0.13, 0.19))
	box(c, x - 22, y - 16, 18, 1, Color(0.24, 0.22, 0.30))
	box(c, x - 14, y - 16, 2, 16, Color(0.09, 0.08, 0.12))
	box(c, x - 19, y - 27, 12, 11, Color(0.12, 0.15, 0.21))
	box(c, x - 19, y - 27, 12, 1, Color(0.22, 0.26, 0.34))
	box(c, x - 16, y - 23, 6, 3, Style.NEON_AMBER.darkened(0.4))

## The gate: a ring of steel in a frame, with a darker lining, and nothing in
## it but what `_paint_life` turns there. The frame's posts come up to either
## end of the gate's sign, which is as good as a lintel.
func _paint_gate(c: CanvasItem, g: Vector2i) -> void:
	var cy := g.y - TALLEST + 30
	for side: int in [-1, 1]:
		var px := g.x + side * 40 - 2
		box(c, px, g.y - 84, 4, 84, Style.HIDEOUT_STEEL)
		box(c, px, g.y - 84, 1, 84, Style.HIDEOUT_STEEL_LIT)
		for k in 5:
			box(c, px, g.y - 22 + k * 4, 4, 2, Style.NEON_AMBER.darkened(0.3))
	box(c, g.x - 38, g.y - 84, 76, 4, Style.HIDEOUT_STEEL.darkened(0.2))
	disc(c, g.x, cy, 31, Style.HIDEOUT_SHADOW)
	disc(c, g.x, cy, 30, Style.HIDEOUT_STEEL_LIT.darkened(0.3))
	disc(c, g.x, cy, 28, Style.HIDEOUT_STEEL_LIT, 27)
	disc(c, g.x, cy, 24, Style.HIDEOUT_STEEL.darkened(0.4))
	disc(c, g.x, cy, 22, Color(0.02, 0.025, 0.05))
	# The step up into it.
	box(c, g.x - 26, g.y - 4, 52, 4, Style.HIDEOUT_STEEL)
	box(c, g.x - 26, g.y - 4, 52, 1, Style.HIDEOUT_STEEL_LIT)

## --- what moves, and what is lit --------------------------------------------

## The wall's own lights, behind whatever stands against it.
func _paint_wall_life(c: CanvasItem) -> void:
	# Rain that has found its way down the glass.
	for r in _runs:
		var y := GLASS_TOP + int(float(r["y"]) + float(r["speed"]) * _t) % (SILL - GLASS_TOP)
		box(c, int(r["x"]), y, 1, 2, Color(0.80, 0.90, 1.0, 0.38))
		box(c, int(r["x"]), maxi(y - 6, GLASS_TOP), 1, mini(6, y - GLASS_TOP), Color(0.80, 0.90, 1.0, 0.10))
	# The tubes: one of them is on its way out.
	for i in TUBES.size():
		var x: int = TUBES[i]
		var on := stutter(_t, 6.5, 5) if i == 1 else 1.0
		var tube := Style.HIDEOUT_TUBE
		box(c, x - 9, 42, 18, 1, faded(tube, 0.35 + 0.65 * on))
		halo(c, x - 9, 42, 18, 1, tube, 5, 0.07 * on)
		# What it throws down the wall.
		for k in 9:
			box(c, x - 10 - k * 2, 44 + k * 8, 20 + k * 4, 8, faded(tube, 0.035 * on * (1.0 - k / 9.0)))
	# The strip along the foot of the wall, breathing.
	var strip := Style.NEON_VIOLET
	var breath := 0.75 + 0.25 * sin(_t * 1.4)
	box(c, LEFT, FLOOR - 12, BAY_LEFT - LEFT, 1, faded(strip, breath))
	for k in 5:
		box(c, LEFT, FLOOR - 11 + k * 2, BAY_LEFT - LEFT, 2, faded(strip, 0.10 * breath * (1.0 - k / 5.0)))
		box(c, LEFT, FLOOR - 14 - k * 2, BAY_LEFT - LEFT, 2, faded(strip, 0.07 * breath * (1.0 - k / 5.0)))
	# The fuse box is alive, and the cooler drips.
	if fmod(_t, 1.2) < 0.6:
		box(c, 209, SILL + 35, 1, 1, Style.NEON_GREEN)
	box(c, 214, SILL + 35, 1, 1, Style.NEON_AMBER)
	var drip := fmod(_t, 2.6)
	if drip < 0.9:
		box(c, 410, SILL + 28 + int(drip * drip * 80.0), 1, 2, Style.CITY_RAIN.lightened(0.2))
	_life_board(c, _at["gate"])

## The board over the gate: the floor it opens onto, as far as anybody has
## mapped it, and somebody's finger going over the way through.
func _life_board(c: CanvasItem, g: Vector2i) -> void:
	var open := _gate_open()
	var left := g.x - BOARD + 2
	var x := left + 4
	var y := 97
	var rooms := [
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(3, 1), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(3, 3), Vector2i(2, 3),
		Vector2i(5, 1), Vector2i(6, 1), Vector2i(1, 3), Vector2i(5, 3), Vector2i(2, 4), Vector2i(6, 0),
	]
	var dim := Color(0.10, 0.20, 0.26) if open else Color(0.22, 0.10, 0.12)
	for r: Vector2i in rooms:
		for step in [Vector2i(1, 0), Vector2i(0, 1)]:
			if rooms.has(r + step):
				if step.x == 1:
					box(c, x + r.x * 8 + 6, y + r.y * 7 + 2, 2, 1, dim)
				else:
					box(c, x + r.x * 8 + 2, y + r.y * 7 + 5, 2, 2, dim)
	for r: Vector2i in rooms:
		box(c, x + r.x * 8, y + r.y * 7, 6, 5, dim)
	box(c, x, y + 14, 6, 5, Style.NEON_GREEN.darkened(0.35))
	box(c, x + 48, y, 6, 5, Style.NEON_RED.darkened(0.3))
	box(c, x + 16, y + 28, 6, 5, Style.NEON_AMBER.darkened(0.3))
	if open:
		# The way through, a room at a time.
		var here: Vector2i = rooms[int(_t * 1.6) % 14]
		box(c, x + here.x * 8 - 1, y + here.y * 7 - 1, 8, 1, Style.NEON_CYAN)
		box(c, x + here.x * 8 - 1, y + here.y * 7 + 5, 8, 1, Style.NEON_CYAN)
		box(c, x + here.x * 8 - 1, y + here.y * 7, 1, 5, Style.NEON_CYAN)
		box(c, x + here.x * 8 + 6, y + here.y * 7, 1, 5, Style.NEON_CYAN)
	# The line of news under it.
	var tick := int(_t * 14.0)
	for k in 12:
		var tx := (k * 9 + 62 - tick % 9) % 62 - 4
		var from := maxi(tx, 0)
		box(c, left + from, 135, mini(tx + 5, 62) - from, 2,
			faded(Style.NEON_CYAN if open else Style.NEON_RED, 0.55))
	halo(c, left, 93, 62, 46, Style.NEON_CYAN if open else Style.NEON_RED, 3, 0.02)
	# The fan, going round, with the light of whatever is behind it.
	var fan := Vector2i(g.x + FAN, 152)
	disc(c, fan.x, fan.y, 10, faded(Style.HIDEOUT_TUBE, 0.16))
	for blade in 3:
		var th := _t * 2.6 + TAU * blade / 3.0
		for r in range(2, 11):
			box(c, fan.x + int(round(cos(th) * r)) - 1, fan.y + int(round(sin(th) * r)) - 1, 2, 2,
				Style.HIDEOUT_STEEL)
	box(c, fan.x - 1, fan.y - 1, 3, 3, Style.HIDEOUT_STEEL_LIT)

func _paint_life(c: CanvasItem) -> void:
	_life_rack(c, _at["weapons"], float(_lit["weapons"]))
	_life_counter(c, _at["shop"], float(_lit["shop"]))
	_life_gate(c, _at["gate"], float(_lit["gate"]))

func _life_rack(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var x := at.x - 27
	var y := at.y - 58
	var cyan := Style.NEON_CYAN
	# The light over the pegs, brighter for somebody standing at it.
	var on := 0.55 + 0.45 * lit
	box(c, x + 3, y + 4, 48, 1, faded(cyan, on))
	for k in 4:
		box(c, x + 3, y + 5 + k * 3, 48, 3, faded(cyan, 0.07 * on * (1.0 - k / 4.0)))
	# The end of the staff.
	var pulse := 0.6 + 0.4 * sin(_t * 2.3)
	halo(c, x + 32, y + 9, 3, 3, cyan, 3, 0.10 * pulse)
	box(c, x + 32, y + 9, 3, 3, cyan.lerp(Color.WHITE, 0.5 * pulse))
	# The graph on the screen: its parts, and what runs between them.
	var nodes := [Vector2i(2, 8), Vector2i(6, 3), Vector2i(11, 8), Vector2i(7, 9)]
	var sx := x + 59
	var sy := y + 13
	for link in [[0, 1], [1, 2], [0, 3], [3, 2]]:
		var a: Vector2i = nodes[link[0]]
		var b: Vector2i = nodes[link[1]]
		for k in 5:
			var p := Vector2(a).lerp(Vector2(b), k / 4.0)
			box(c, sx + int(round(p.x)), sy + int(round(p.y)), 1, 1, faded(cyan, 0.35))
	var hop := int(_t * 2.0) % 4
	for i in nodes.size():
		var n: Vector2i = nodes[i]
		box(c, sx + n.x - 1, sy + n.y - 1, 2, 2, Style.NEON_AMBER if i == hop else cyan)
	# The frame, lit when it would answer.
	if lit > 0.0:
		var edge := faded(cyan, lit)
		box(c, x - 1, y - 1, 56, 1, edge)
		box(c, x - 1, y, 1, 58, edge)
		box(c, x + 54, y, 1, 58, edge)

func _life_counter(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var x := at.x - 32
	var y := at.y
	var pink := Style.NEON_PINK
	# Whoever keeps the counter: a screen for a head, and eyes that follow.
	var eyes := clampi(int((_player_x(float(at.x)) - float(at.x)) / 60.0), -2, 2)
	var hx := at.x - 7
	var hy := y - 38
	box(c, hx + 6, hy - 4, 1, 4, Style.HIDEOUT_STEEL_LIT)
	if fmod(_t, 2.0) < 1.0:
		box(c, hx + 6, hy - 5, 1, 1, Style.NEON_RED)
	box(c, hx, hy, 14, 11, Style.HIDEOUT_STEEL_LIT)
	box(c, hx + 1, hy + 1, 12, 9, Color(0.03, 0.09, 0.11))
	var eye := Style.NEON_CYAN
	if fmod(_t, 4.3) > 4.15:
		box(c, hx + 3 + eyes, hy + 5, 3, 1, eye)
		box(c, hx + 8 + eyes, hy + 5, 3, 1, eye)
	else:
		box(c, hx + 3 + eyes, hy + 3, 3, 3, eye)
		box(c, hx + 8 + eyes, hy + 3, 3, 3, eye)
	box(c, hx + 2, hy + 11, 10, 7, Style.HIDEOUT_STEEL.darkened(0.1))
	box(c, hx + 5, hy + 11, 4, 2, Style.HIDEOUT_SHADOW)
	# The light under the awning, the one under the counter's lip, and the
	# machine's own.
	var on := 0.6 + 0.4 * lit
	box(c, x - 2, y - 58, 68, 1, faded(pink, 0.5 * on))
	for k in 3:
		box(c, x - 2, y - 57 + k * 3, 68, 3, faded(pink, 0.05 * on * (1.0 - k / 3.0)))
	box(c, x + 2, y - 1, 60, 1, faded(pink, on))
	for k in 3:
		box(c, x + 2, y - 4 - k * 3, 60, 3, faded(pink, 0.08 * on * (1.0 - k / 3.0)))
	var mx := x + 72
	var hum := stutter(_t, 11.0, 2)
	box(c, mx + 2, y - 46, 18, 3, faded(pink, 0.85 * hum))
	halo(c, mx + 2, y - 46, 18, 3, pink, 3, 0.07 * hum)
	box(c, mx + 2, y - 42, 13, 28, Color(0.5, 0.8, 1.0, 0.05 * hum))
	box(c, mx + 18, y - 38, 1, 1, Style.NEON_GREEN)
	if fmod(_t, 0.9) < 0.45:
		box(c, mx + 18, y - 35, 1, 1, Style.NEON_AMBER)
	if lit > 0.0:
		box(c, x, y - 21, 64, 1, faded(pink, lit))

func _life_gate(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var cy := at.y - TALLEST + 30
	var open := _gate_open()
	var col := Style.NEON_GREEN if open else Style.NEON_RED
	# What turns inside it, when it will take you; nothing, when it will not.
	if open:
		for k in 3:
			var r := 6 + k * 6
			var a := _t * (1.4 - 0.3 * k) + k * 2.1
			for seg in 5:
				var th := a + seg * 0.22
				var dot := faded(col, (0.25 + 0.5 * lit) * (1.0 - seg / 5.0))
				box(c, at.x + int(round(cos(th) * r)), cy + int(round(sin(th) * r)), 2, 2, dot)
				box(c, at.x - int(round(cos(th) * r)), cy - int(round(sin(th) * r)), 2, 2, dot)
		disc(c, at.x, cy, 3, faded(col, 0.35 + 0.4 * lit))
	# The lamps round the rim: chasing when it is open, all slow red when not.
	for k in 12:
		var th := TAU * k / 12.0 - PI * 0.5
		var on := 0.35 + 0.35 * sin(_t * 2.0)
		if open:
			on = clampf(1.0 - fposmod(fmod(_t * 6.0, 12.0) - float(k), 12.0) / 5.0, 0.15, 1.0)
		var lx := at.x + int(round(cos(th) * 27.0)) - 1
		var ly := cy + int(round(sin(th) * 27.0)) - 1
		box(c, lx - 1, ly - 1, 4, 4, faded(col, on * (0.18 + 0.12 * lit)))
		box(c, lx, ly, 2, 2, faded(col, on))
	wet(c, at.x - 26, 52, col, 0.10 + 0.08 * lit)
	# Chevrons along the wall, walking you to it.
	for k in 4:
		var step := fposmod(_t * 3.0 - float(k), 4.0)
		stamp(c, BAY_LEFT + 22 + k * 9, at.y - 46, [
			"##....",
			".##...",
			"..##..",
			"...##.",
			"..##..",
			".##...",
			"##....",
		], faded(Style.NEON_AMBER, (0.25 if step > 1.0 else 1.0) * (1.0 if open else 0.3)))
