class_name HideoutKeep
extends HideoutScenery

## The hideout as the hall of a keep, on a winter night. Three tall windows
## look out over the wall-walk at the mountains, a castle on a crag and the
## moon, with the snow coming down; inside it is torches on the piers, banners
## between them, a rack of arms, a stall with somebody hooded behind it and a
## cat on its barrel, and the gate as an arch of stone in a bay of its own,
## under the map that shows where it goes.
##
## One of the hideout's looks (`HideoutThemes`), on the ground they all stand
## on (`HideoutScenery`): everything is placed in pixels of the buffer the
## world is drawn into, drawn once or drawn again as it moves, and reads the
## room without changing it.

## --- where things are, in buffer pixels of the room -------------------------
## The underside of the timber overhead, and the ledge along the wall that the
## stations' signs hang from.
const BEAM := 40
const LEDGE := 224
## The windows, by their middles: how wide each is, where its sill is, where
## its arch starts to close and how far above that it comes to its point.
const WINDOWS := [96, 224, 352]
const WIDE := 52
const FOOT := 204
const SPRING := 116
const RISE := 45
## The piers between them, by their middles, and how high on each its torch
## burns. The first is the one against the left wall, and half of one.
const PIERS := [160, 288, 416]
const TORCHES := [22, 160, 288, 416]
const TORCH := 148
## Where the gate's bay starts: past the last pier.
const BAY_LEFT := 424
## How far the nearest thing out of the windows may slide as the player walks
## the room, and the stretch of the outdoors that is drawn: wider than the
## windows by that much either end, and hidden by the wall everywhere else.
const SLIDE := 6
const VIEW_LEFT := 62
const VIEW_RIGHT := 392
const VIEW_TOP := 66
## How far a shaft of moonlight leans as it comes down: pixels across for one
## down.
const LEAN := 0.35
## The banners, by their left edges, and whose colours each is in.
const BANNERS := [[130, 0], [176, 0], [258, 1], [304, 1], [386, 0]]
## The moon, where it hangs in the middle window.
const MOON_AT := Vector2i(233, 101)
## The line of the far mountains and of the nearer hills, as the points each
## runs through.
const PEAKS := [[62, 170], [80, 152], [92, 160], [110, 126], [128, 158], [150, 172], [176, 150], [196, 166],
	[212, 134], [226, 152], [242, 142], [262, 170], [284, 152], [306, 166], [330, 130], [346, 152], [362, 140],
	[376, 150], [392, 164]]
const HILLS := [[62, 186], [90, 178], [120, 190], [150, 180], [190, 192], [230, 184], [270, 194],
	[310, 182], [334, 168], [352, 160], [368, 172], [392, 186]]
## The map on the wall: the rooms of it, on a grid.
const ROOMS := [
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(3, 1), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(3, 3), Vector2i(2, 3),
	Vector2i(5, 1), Vector2i(6, 1), Vector2i(1, 3), Vector2i(5, 3), Vector2i(2, 4), Vector2i(6, 0),
]

## --- its colours --------------------------------------------------------------
const STONE := Color(0.205, 0.195, 0.24)
const STONE_LIT := Color(0.265, 0.25, 0.30)
const MORTAR := Color(0.12, 0.115, 0.15)
const UNDERWALL := Color(0.15, 0.142, 0.18)
const PIER := Color(0.275, 0.26, 0.305)
const PIER_LIT := Color(0.375, 0.355, 0.40)
const PIER_DARK := Color(0.165, 0.155, 0.195)
const TIMBER := Color(0.225, 0.14, 0.09)
const TIMBER_LIT := Color(0.35, 0.23, 0.145)
const TIMBER_DARK := Color(0.105, 0.068, 0.05)
const IRON := Color(0.085, 0.09, 0.115)
const IRON_LIT := Color(0.24, 0.25, 0.30)
const STEEL := Color(0.60, 0.65, 0.75)
const STEEL_LIT := Color(0.90, 0.94, 1.0)
const GOLD := Color(0.93, 0.72, 0.30)
const CRIMSON := Color(0.55, 0.10, 0.14)
const NAVY := Color(0.13, 0.19, 0.42)
const CREAM := Color(0.80, 0.74, 0.60)
const PARCHMENT := Color(0.72, 0.63, 0.46)
const INK := Color(0.30, 0.20, 0.13)
const CLOAK := Color(0.13, 0.20, 0.19)
## Firelight on stone, and a flame from its edge to its heart.
const FIRE := Color(1.0, 0.56, 0.18)
const FLAME_OUT := Color(0.92, 0.28, 0.10)
const FLAME_MID := Color(1.0, 0.62, 0.16)
const FLAME_CORE := Color(1.0, 0.93, 0.58)
## The night, from overhead down to the glow behind the mountains.
const SKY := [
	Color(0.025, 0.035, 0.10),
	Color(0.03, 0.045, 0.125),
	Color(0.04, 0.058, 0.152),
	Color(0.05, 0.074, 0.182),
	Color(0.062, 0.092, 0.214),
	Color(0.078, 0.114, 0.248),
	Color(0.098, 0.14, 0.284),
	Color(0.122, 0.17, 0.322),
	Color(0.152, 0.204, 0.362),
	Color(0.19, 0.244, 0.404),
]
const MOON := Color(0.95, 0.94, 0.84)
const MOON_SHADE := Color(0.80, 0.82, 0.78)
const PEAK := Color(0.19, 0.25, 0.42)
const HILL := Color(0.10, 0.13, 0.25)
const OUTWALL := Color(0.05, 0.055, 0.10)
const SNOW := Color(0.84, 0.90, 1.0)
const SNOW_FAR := Color(0.52, 0.61, 0.80)
const MOONLIGHT := Color(0.56, 0.70, 1.0)
## The gate's light: when it would take you, and when it would not.
const OPEN := Color(0.35, 1.0, 0.62)
const SHUT := Color(1.0, 0.27, 0.24)

## Back to front. `_heavens` is what moves in the sky, and slides with it;
## `_out` is everything else that moves out there, and is not slid: what it
## draws on a depth it draws where that depth has got to.
var _sky: Layer
var _heavens: Layer
var _peaks: Layer
var _hills: Layer
var _near: Layer
var _out: Layer
var _wall: Layer
var _wall_life: Layer
var _fittings: Layer
var _life: Layer

## The stars: `{x, y, a}`, and the few that twinkle, `{x, y, every, from}`.
var _stars: Array = []
var _twinkles: Array = []
## The snow: `{pane, x, y, speed, sway}`, a window's own flakes, each where it
## is when the clock is at nothing.
var _flakes: Array = []
## The dust in the moonlight: `{pane, along, across, speed, phase}`.
var _motes: Array = []

func _build() -> void:
	plate = Color(0.105, 0.07, 0.055)
	ink = Color(0.66, 0.52, 0.30)
	ink_lit = Color(1.0, 0.86, 0.50)
	ink_shut = Color(0.92, 0.42, 0.34)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x6EE9
	for i in 80:
		_stars.append({"x": rng.randi_range(VIEW_LEFT, VIEW_RIGHT - 1), "y": rng.randi_range(VIEW_TOP, 164),
			"a": rng.randf_range(0.25, 0.9)})
	for i in 10:
		_twinkles.append({"x": rng.randi_range(VIEW_LEFT, VIEW_RIGHT - 1), "y": rng.randi_range(VIEW_TOP + 6, 150),
			"every": rng.randf_range(1.6, 4.2), "from": rng.randf_range(0.0, 4.0)})
	for pane in WINDOWS.size():
		for i in 24:
			_flakes.append({"pane": pane, "x": rng.randi_range(0, WIDE - 1), "y": rng.randi_range(0, FOOT - VIEW_TOP),
				"speed": rng.randf_range(11.0, 26.0), "sway": rng.randf_range(0.0, TAU)})
		for i in 5:
			_motes.append({"pane": pane, "along": rng.randf(), "across": rng.randf(),
				"speed": rng.randf_range(0.006, 0.016), "phase": rng.randf_range(0.0, TAU)})
	_sky = still(_paint_sky)
	_heavens = moving(_paint_heavens)
	_peaks = still(_paint_peaks)
	_hills = still(_paint_hills)
	_near = still(_paint_near)
	_out = moving(_paint_out)
	_wall = still(_paint_wall)
	_wall_life = moving(_paint_wall_life)
	_fittings = still(_paint_fittings)
	_life = moving(_paint_life)

## What is out of the windows slides a little as the player walks the room,
## the wall-walk under them furthest and the sky hardly at all: whole pixels
## of the buffer, and never more than SLIDE of them.
func _slide(across: float) -> void:
	_sky.position.x = slid(across, 1.0)
	_heavens.position.x = _sky.position.x
	_peaks.position.x = slid(across, 2.0)
	_hills.position.x = slid(across, 3.0)
	_near.position.x = slid(across, float(SLIDE))

## How far a depth has slid, in pixels of the buffer.
func _off(depth: Layer) -> int:
	return int(round(depth.position.x / S))

## --- the windows' own shape ---------------------------------------------------

## Half the width of a window's opening on `row`, or nothing where there is no
## opening: straight up from the sill, then closing to a point, each side the
## arc of a circle struck from the other.
static func _half(row: int) -> int:
	if row >= FOOT or row < SPRING - RISE:
		return 0
	if row >= SPRING:
		return WIDE / 2
	var up := float(SPRING - row)
	return maxi(int(floor(sqrt(float(WIDE * WIDE) - up * up) - WIDE * 0.5 + 0.5)), 0)

## A box of the wall, with the windows left out of it: the wall is what hides
## everything out there but what the windows show.
static func _stone(c: CanvasItem, x: int, y: int, w: int, h: int, col: Color) -> void:
	var row := y
	while row < y + h:
		var half := _half(row)
		var run := 1
		while row + run < y + h and _half(row + run) == half:
			run += 1
		if half == 0:
			box(c, x, row, w, run, col)
		else:
			var at := x
			for cx: int in WINDOWS:
				box(c, at, row, mini(cx - half, x + w) - at, run, col)
				at = maxi(at, cx + half)
			box(c, at, row, x + w - at, run, col)
		row += run

## A box of something out there, cut off where the drawn stretch of it ends.
static func _out_there(c: CanvasItem, x: int, y: int, w: int, h: int, col: Color) -> void:
	var from := maxi(x, VIEW_LEFT)
	box(c, from, y, mini(x + w, VIEW_RIGHT) - from, h, col)

## How high a line through `points` stands at `x`.
static func _height(points: Array, x: int) -> int:
	for i in range(1, points.size()):
		var a: Array = points[i - 1]
		var b: Array = points[i]
		if x <= int(b[0]):
			var along := float(x - int(a[0])) / float(maxi(int(b[0]) - int(a[0]), 1))
			return int(round(lerpf(float(a[1]), float(b[1]), clampf(along, 0.0, 1.0))))
	return int(points[points.size() - 1][1])

## --- out of the windows -------------------------------------------------------

func _paint_sky(c: CanvasItem) -> void:
	bands(c, VIEW_LEFT, VIEW_TOP, VIEW_RIGHT - VIEW_LEFT, FOOT - VIEW_TOP, SKY)
	for s in _stars:
		box(c, int(s["x"]), int(s["y"]), 1, 1, Color(0.82, 0.88, 1.0, float(s["a"])))
	# The moon, with the cold round it, and what can be made out on its face.
	disc(c, MOON_AT.x, MOON_AT.y, 20, faded(MOON, 0.05))
	disc(c, MOON_AT.x, MOON_AT.y, 16, faded(MOON, 0.09))
	disc(c, MOON_AT.x, MOON_AT.y, 13, MOON)
	disc(c, MOON_AT.x - 4, MOON_AT.y - 3, 3, MOON_SHADE)
	disc(c, MOON_AT.x + 5, MOON_AT.y + 3, 2, MOON_SHADE)
	box(c, MOON_AT.x + 2, MOON_AT.y - 8, 3, 2, MOON_SHADE)
	box(c, MOON_AT.x - 7, MOON_AT.y + 6, 3, 2, MOON_SHADE)
	box(c, MOON_AT.x + 7, MOON_AT.y - 3, 2, 2, MOON_SHADE)

## What moves in the sky: a star going in and out, a cloud going over, and
## now and then a star that falls.
func _paint_heavens(c: CanvasItem) -> void:
	for s in _twinkles:
		if fmod(_t + float(s["from"]), float(s["every"])) < float(s["every"]) * 0.5:
			box(c, int(s["x"]), int(s["y"]), 1, 1, Color(1.0, 1.0, 1.0, 0.95))
	var span := VIEW_RIGHT - VIEW_LEFT
	for cloud in [[92, 2.2, 0.0, 70], [118, 1.4, 150.0, 96], [80, 3.1, 260.0, 52], [134, 1.8, 60.0, 80]]:
		var w: int = cloud[3]
		var x := VIEW_RIGHT - int(fmod(_t * float(cloud[1]) + float(cloud[2]), float(span + w)))
		var y: int = cloud[0]
		var mist := Color(0.58, 0.66, 0.88, 0.13)
		_out_there(c, x, y, w, 2, mist)
		_out_there(c, x + 8, y - 2, w - 22, 2, mist)
		_out_there(c, x + 14, y + 2, w - 30, 2, mist)
	var fall := fmod(_t, 17.0)
	if fall < 0.5:
		var along := fall / 0.5
		for k in 4:
			_out_there(c, 300 - int(along * 60.0) + k * 3, 78 + int(along * 26.0) - k, 2, 1,
				Color(1.0, 1.0, 1.0, (0.9 - k * 0.2) * (1.0 - along)))

func _paint_peaks(c: CanvasItem) -> void:
	for x in range(VIEW_LEFT, VIEW_RIGHT):
		var top := _height(PEAKS, x) + (x * 7 + (x * x) % 5) % 3 - 1
		box(c, x, top, 1, FOOT - top, PEAK)
		# Snow on whatever of it stands high enough, ragged at its foot.
		var snow := clampi((168 - top) * 6 / 10 + (2 if x % 5 < 2 else 0) - (x * 3) % 2, 0, 20)
		box(c, x, top, 1, snow, SNOW_FAR)
		box(c, x, top, 1, mini(snow, 2), SNOW_FAR.lightened(0.25))
	# The cold lying in the valleys.
	for k in 3:
		box(c, VIEW_LEFT, FOOT - 24 + k * 8, VIEW_RIGHT - VIEW_LEFT, 8, faded(SKY[9], 0.10 + 0.05 * k))

func _paint_hills(c: CanvasItem) -> void:
	for x in range(VIEW_LEFT, VIEW_RIGHT):
		var top := _height(HILLS, x) + (x * 5 + (x * x) % 3) % 2
		box(c, x, top, 1, FOOT - top, HILL)
	# Pines along the top of them, but not on the crag.
	var dark := HILL.darkened(0.3)
	for x in range(VIEW_LEFT + 1, VIEW_RIGHT - 5, 5):
		if x > 324 and x < 376:
			continue
		var foot := _height(HILLS, x + 2) + 2
		stamp(c, x, foot - 6 - (x * 7) % 3, [
			"..#..",
			".###.",
			"..#..",
			".###.",
			"#####",
			"..#..",
			"..#..",
			"..#..",
		], dark)
	# And on the crag, somebody else's castle: a keep between two towers, with
	# a wall round it, and a few of its windows lit.
	var far := HILL.darkened(0.42)
	box(c, 330, 156, 44, 10, far)
	for x in range(330, 374, 6):
		box(c, x, 154, 3, 2, far)
	box(c, 346, 138, 12, 24, far)
	for x in [346, 351, 356]:
		box(c, x, 136, 2, 2, far)
	box(c, 338, 146, 7, 16, far)
	stamp(c, 338, 142, ["...#...", "..###..", ".#####.", "#######"], far)
	box(c, 359, 142, 7, 20, far)
	stamp(c, 359, 138, ["...#...", "..###..", ".#####.", "#######"], far)
	box(c, 352, 128, 1, 8, far)
	box(c, 353, 128, 3, 2, CRIMSON.lightened(0.1))
	# The moon on the side of it that faces the moon, and the snow on its roofs.
	var rim := HILL.lightened(0.16)
	box(c, 346, 138, 1, 18, rim)
	box(c, 338, 146, 1, 10, rim)
	box(c, 359, 142, 1, 14, rim)
	box(c, 330, 156, 44, 1, rim)
	stamp(c, 338, 142, ["...#...", "..#....", ".#.....", "#......"], SNOW_FAR)
	stamp(c, 359, 138, ["...#...", "..#....", ".#.....", "#......"], SNOW_FAR)
	for x in range(330, 374, 6):
		box(c, x, 153, 3, 1, SNOW_FAR)
	for x in [346, 351, 356]:
		box(c, x, 135, 2, 1, SNOW_FAR)
	for win in [[349, 146], [354, 152], [341, 152], [362, 148], [351, 158], [366, 159], [334, 160]]:
		box(c, win[0], win[1], 1, 2, FLAME_MID)

## The keep's own wall-walk, under the windows, and the turret at the end of
## it: the nearest thing out there, with the snow lying on all of it.
func _paint_near(c: CanvasItem) -> void:
	box(c, VIEW_LEFT, 196, VIEW_RIGHT - VIEW_LEFT, FOOT - 196, OUTWALL)
	for x in range(VIEW_LEFT, VIEW_RIGHT - 6, 12):
		box(c, x, 190, 7, 6, OUTWALL)
		box(c, x, 189, 7, 1, SNOW)
		box(c, x + 1, 188, 4 + (x / 12) % 2, 1, SNOW)
		box(c, x + 7, 195, 5, 1, SNOW)
	# The turret.
	box(c, 76, 150, 16, 46, OUTWALL)
	box(c, 76, 150, 1, 46, OUTWALL.lightened(0.10))
	box(c, 74, 144, 20, 6, OUTWALL)
	box(c, 74, 143, 20, 1, SNOW)
	for k in 27:
		var w := 2 + k * 20 / 26
		box(c, 84 - w / 2, 117 + k, w, 1, OUTWALL.lightened(0.04))
		if k < 22:
			box(c, 84 - w / 2, 117 + k, 1 + k / 8, 1, SNOW)
	box(c, 84, 104, 1, 13, OUTWALL.lightened(0.32))
	box(c, 83, 160, 2, 6, FLAME_MID)
	box(c, 83, 178, 2, 5, FLAME_MID.darkened(0.3))
	# A fire basket for whoever has the watch.
	box(c, 366, 176, 1, 14, OUTWALL.lightened(0.08))
	box(c, 363, 173, 7, 3, OUTWALL.lightened(0.08))

## What moves out there: the pennant on the turret, the watch's fire, a window
## of the castle going dark and coming on again, and the snow.
func _paint_out(c: CanvasItem) -> void:
	var near := _off(_near)
	var hills := _off(_hills)
	for k in 9:
		var wave := int(round(sin(_t * 5.0 - k * 0.9) * (0.3 + k * 0.16)))
		box(c, 85 + near + k, 105 + wave, 1, 4 - k / 3, CRIMSON.lightened(0.12))
	var f := flicker(_t, 11)
	box(c, 364 + near, 171, 5, 2, FLAME_OUT)
	box(c, 365 + near, 172 - int(f * 4.0), 3, int(f * 4.0), FLAME_MID)
	box(c, 366 + near, 171, 1, 2, FLAME_CORE)
	box(c, 358 + near, 166, 17, 12, faded(FIRE, 0.07 * f))
	for win in [[349, 146, 7.0, 0.0], [362, 148, 11.0, 4.0]]:
		if fmod(_t + float(win[3]), float(win[2])) < float(win[2]) * 0.6:
			box(c, int(win[0]) + hills, int(win[1]), 1, 2, FLAME_CORE)
	var tall := FOOT - VIEW_TOP
	for flake in _flakes:
		var cx: int = WINDOWS[flake["pane"]]
		var y := VIEW_TOP + int(float(flake["y"]) + float(flake["speed"]) * _t) % tall
		var x := posmod(int(flake["x"]) + int(round(sin(_t * 0.8 + float(flake["sway"])) * 3.0 - _t * 3.0)), WIDE)
		box(c, cx - WIDE / 2 + x, y, 1, 1, faded(SNOW, 0.5 + 0.4 * float(int(flake["x"]) % 3) / 2.0))

## --- the hall ---------------------------------------------------------------

func _paint_wall(c: CanvasItem) -> void:
	_paint_masonry(c)
	_paint_windows(c)
	_paint_ceiling(c)
	_paint_banners(c)
	_paint_under_ledge(c)
	_paint_bay(c)
	_paint_piers(c)
	_paint_firelight(c)
	_paint_floor(c)
	_paint_shafts(c)

## What stands against the wall.
func _paint_fittings(c: CanvasItem) -> void:
	_paint_bench(c)
	_paint_arms(c, _at["weapons"])
	_paint_stall(c, _at["shop"])
	_paint_gate(c, _at["gate"])

## The wall over the ledge: dressed stone in courses, a block lighter here and
## darker there.
func _paint_masonry(c: CanvasItem) -> void:
	_stone(c, LEFT, BEAM, RIGHT - LEFT, LEDGE - BEAM, STONE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x57A6
	var course := 0
	for y in range(BEAM, LEDGE, 12):
		var tall := mini(12, LEDGE - y)
		var x := LEFT - (12 if course % 2 == 1 else 0)
		while x < RIGHT:
			var from := maxi(x, LEFT)
			var roll := rng.randf()
			if roll < 0.22:
				_stone(c, from, y, mini(x + 24, RIGHT) - from, tall, STONE.lerp(STONE_LIT, 0.5))
			elif roll < 0.40:
				_stone(c, from, y, mini(x + 24, RIGHT) - from, tall, STONE.darkened(0.12))
			x += 24
		_stone(c, LEFT, y, RIGHT - LEFT, 1, STONE.lerp(STONE_LIT, 0.6))
		x = LEFT - (12 if course % 2 == 1 else 0)
		while x < RIGHT:
			if x > LEFT:
				_stone(c, x, y, 1, tall, MORTAR)
			x += 24
		_stone(c, LEFT, y + tall - 1, RIGHT - LEFT, 1, MORTAR)
		course += 1

## Each window's frame, sill and bars, the snow on the ledge outside it, and
## what light the glass itself catches.
func _paint_windows(c: CanvasItem) -> void:
	for cx: int in WINDOWS:
		var first := true
		for row in range(SPRING - RISE, SPRING):
			var half := _half(row)
			if half == 0:
				continue
			if first:
				box(c, cx - 2, row - 3, 4, 3, PIER_LIT)
				first = false
			box(c, cx - half - 2, row, 2, 1, PIER_LIT)
			box(c, cx + half, row, 2, 1, PIER)
		box(c, cx - WIDE / 2 - 2, SPRING, 2, FOOT - SPRING, PIER_LIT)
		box(c, cx + WIDE / 2, SPRING, 2, FOOT - SPRING, PIER)
		# The glass: a sheen down each light of it, and frost in its corners.
		for k in 12:
			box(c, cx - 21 + k, SPRING + 10 + k * 4, 6, 4, Color(0.80, 0.90, 1.0, 0.035))
			box(c, cx + 5 + k, SPRING + 4 + k * 4, 4, 4, Color(0.80, 0.90, 1.0, 0.035))
		box(c, cx - WIDE / 2, FOOT - 3, WIDE, 3, SNOW.darkened(0.08))
		box(c, cx - 21, FOOT - 4, 11, 1, SNOW)
		box(c, cx + 5, FOOT - 4, 15, 1, SNOW)
		box(c, cx - WIDE / 2, FOOT - 6, 3, 3, faded(SNOW, 0.5))
		box(c, cx + WIDE / 2 - 3, FOOT - 6, 3, 3, faded(SNOW, 0.5))
		# The stone bars: one up the middle, one across where the arch springs.
		box(c, cx - 1, SPRING - RISE + 6, 2, FOOT - SPRING + RISE - 6, PIER_DARK)
		box(c, cx - WIDE / 2, SPRING, WIDE, 2, PIER_DARK)
		for y in [146, 175]:
			box(c, cx - WIDE / 2, y, WIDE, 1, Color(0.03, 0.04, 0.07, 0.6))
		# The sill.
		box(c, cx - 31, FOOT, 62, 4, PIER)
		box(c, cx - 31, FOOT, 62, 1, PIER_LIT)
		box(c, cx - 29, FOOT + 4, 58, 2, MORTAR)

## Overhead: joists end on, with the dark between them, and the great beam
## they sit on, strapped with iron.
func _paint_ceiling(c: CanvasItem) -> void:
	box(c, LEFT, TOP, RIGHT - LEFT, BEAM - TOP, TIMBER_DARK.darkened(0.35))
	for x in range(LEFT + 14, RIGHT - 10, 38):
		box(c, x, TOP, 10, 14, TIMBER)
		box(c, x, TOP, 1, 14, TIMBER_LIT)
		box(c, x + 9, TOP, 1, 14, TIMBER_DARK)
		box(c, x, TOP + 13, 10, 1, TIMBER_DARK)
		box(c, x + 3, TOP + 3, 4, 1, TIMBER_DARK)
		box(c, x + 2, TOP + 7, 5, 1, TIMBER_DARK)
	box(c, LEFT, 30, RIGHT - LEFT, 10, TIMBER)
	box(c, LEFT, 30, RIGHT - LEFT, 1, TIMBER_LIT)
	box(c, LEFT, 39, RIGHT - LEFT, 1, TIMBER_DARK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xBEA3
	for i in 46:
		box(c, rng.randi_range(LEFT, RIGHT - 24), rng.randi_range(32, 37), rng.randi_range(6, 22), 1,
			TIMBER.darkened(0.22))
	for x in range(LEFT + 32, RIGHT - 4, 76):
		box(c, x, 30, 4, 10, IRON)
		box(c, x, 30, 1, 10, IRON_LIT)
		box(c, x + 2, 32, 1, 1, IRON_LIT)
		box(c, x + 2, 37, 1, 1, IRON_LIT)

## The banners between the windows and the piers, each on its rod: the keep's
## colours on some, somebody else's on the rest.
func _paint_banners(c: CanvasItem) -> void:
	for banner in BANNERS:
		var x: int = banner[0]
		var field: Color = CRIMSON if int(banner[1]) == 0 else NAVY
		box(c, x - 3, 54, 20, 2, IRON_LIT.darkened(0.2))
		box(c, x - 4, 53, 1, 4, IRON_LIT)
		box(c, x + 17, 53, 1, 4, IRON_LIT)
		box(c, x, 56, 14, 60, field)
		for k in 10:
			var w := 7 - k * 7 / 10
			box(c, x, 116 + k, w, 1, field)
			box(c, x + 14 - w, 116 + k, w, 1, field)
		box(c, x, 56, 1, 66, field.lightened(0.12))
		box(c, x + 4, 57, 1, 59, field.darkened(0.22))
		box(c, x + 10, 57, 1, 59, field.darkened(0.22))
		box(c, x + 13, 56, 1, 66, field.darkened(0.3))
		box(c, x + 1, 59, 12, 1, GOLD.darkened(0.15))
		box(c, x + 1, 112, 12, 1, GOLD.darkened(0.15))
		stamp(c, x + 3, 76, [
			"...##...",
			"..####..",
			".##..##.",
			"##....##",
			".##..##.",
			"..####..",
			"...##...",
		], GOLD)
		box(c, x + 6, 79, 2, 1, GOLD)
		box(c, x + 6, 90, 2, 8, GOLD.darkened(0.15))
		box(c, x + 4, 94, 6, 1, GOLD.darkened(0.15))

## The ledge the signs hang from, and the wall under it, which the stations
## stand against: bigger stone, in the dark, and what a wall like it collects.
func _paint_under_ledge(c: CanvasItem) -> void:
	box(c, LEFT, LEDGE + 5, RIGHT - LEFT, FLOOR - LEDGE - 5, UNDERWALL)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x0DD5
	var course := 0
	for y in range(LEDGE + 7, FLOOR - 8, 18):
		var tall := mini(18, FLOOR - 8 - y)
		var x := LEFT - (18 if course % 2 == 1 else 0)
		while x < RIGHT:
			var from := maxi(x, LEFT)
			var roll := rng.randf()
			if roll < 0.25:
				box(c, from, y, mini(x + 36, RIGHT) - from, tall, UNDERWALL.lightened(0.035))
			elif roll < 0.45:
				box(c, from, y, mini(x + 36, RIGHT) - from, tall, UNDERWALL.darkened(0.14))
			if x > LEFT:
				box(c, x, y, 1, tall, MORTAR.darkened(0.2))
			x += 36
		box(c, LEFT, y + tall - 1, RIGHT - LEFT, 1, MORTAR.darkened(0.2))
		course += 1
	box(c, LEFT, FLOOR - 8, RIGHT - LEFT, 8, UNDERWALL.darkened(0.2))
	box(c, LEFT, FLOOR - 8, RIGHT - LEFT, 1, MORTAR)
	box(c, LEFT, LEDGE, RIGHT - LEFT, 5, PIER)
	box(c, LEFT, LEDGE, RIGHT - LEFT, 1, PIER_LIT)
	box(c, LEFT, LEDGE + 5, RIGHT - LEFT, 2, MORTAR.darkened(0.3))
	# Notices, nailed up.
	box(c, 30, 244, 36, 34, TIMBER_DARK)
	box(c, 30, 244, 36, 1, TIMBER)
	box(c, 33, 247, 15, 20, PARCHMENT)
	disc(c, 40, 254, 3, INK)
	box(c, 37, 258, 7, 3, INK)
	for y in [262, 264]:
		box(c, 35, y, 11 - (y % 4) * 2, 1, INK)
	box(c, 51, 248, 12, 11, PARCHMENT.darkened(0.12))
	for y in [250, 252, 254]:
		box(c, 53, y, 8 - (y % 3), 1, INK)
	box(c, 57, 256, 2, 2, CRIMSON)
	box(c, 50, 262, 14, 13, PARCHMENT.darkened(0.05))
	line(c, 52, 271, 56, 265, INK)
	line(c, 56, 265, 59, 269, INK)
	line(c, 59, 269, 62, 264, INK)
	# A mouse's way in.
	stamp(c, 250, FLOOR - 13, [".###.", "#####", "#####", "#####", "#####"], Color(0.02, 0.02, 0.03))

## The gate's bay: the same wall, with the map of where the gate goes hung on
## it, arms on show, and a ring of candles overhead.
func _paint_bay(c: CanvasItem) -> void:
	# The map: cloth, with a border, a fringe, and the rooms inked on it. The
	# way through them is `_paint_wall_life`'s.
	box(c, 441, 74, 74, 2, IRON_LIT.darkened(0.2))
	box(c, 440, 73, 1, 4, IRON_LIT)
	box(c, 515, 73, 1, 4, IRON_LIT)
	box(c, 446, 76, 64, 72, CRIMSON.darkened(0.12))
	box(c, 446, 76, 1, 72, CRIMSON.lightened(0.08))
	box(c, 449, 79, 58, 66, PARCHMENT)
	box(c, 449, 79, 58, 1, GOLD.darkened(0.1))
	box(c, 449, 144, 58, 1, GOLD.darkened(0.1))
	box(c, 449, 79, 1, 66, GOLD.darkened(0.1))
	box(c, 506, 79, 1, 66, GOLD.darkened(0.1))
	for k in 16:
		box(c, 447 + k * 4, 148, 2, 3, GOLD.darkened(0.15))
	for fold in [466, 488]:
		box(c, fold, 80, 1, 64, PARCHMENT.darkened(0.10))
	var x := 452
	var y := 88
	for r: Vector2i in ROOMS:
		for step in [Vector2i(1, 0), Vector2i(0, 1)]:
			if ROOMS.has(r + step):
				if step.x == 1:
					box(c, x + r.x * 8 + 6, y + r.y * 7 + 2, 2, 1, INK)
				else:
					box(c, x + r.x * 8 + 2, y + r.y * 7 + 5, 2, 2, INK)
	for r: Vector2i in ROOMS:
		box(c, x + r.x * 8, y + r.y * 7, 6, 5, INK)
		box(c, x + r.x * 8 + 1, y + r.y * 7 + 1, 4, 3, PARCHMENT.darkened(0.16))
	box(c, x + 1, y + 15, 4, 3, Color(0.26, 0.48, 0.26))
	box(c, x + 49, y + 1, 4, 3, CRIMSON)
	box(c, x + 17, y + 29, 4, 3, GOLD.darkened(0.2))
	# Which way is north, and a line to say whose map it is.
	stamp(c, 494, 126, ["..#..", "..#..", "#####", "..#..", "..#.."], INK)
	box(c, 496, 124, 1, 2, CRIMSON)
	for row in [[454, 130, 26], [454, 134, 18], [454, 138, 22]]:
		box(c, row[0], row[1], row[2], 1, INK.lightened(0.25))
	# Arms on show: two swords crossed behind a shield.
	line(c, 584, 104, 608, 132, STEEL)
	line(c, 608, 104, 584, 132, STEEL)
	box(c, 583, 130, 4, 1, GOLD)
	box(c, 606, 130, 4, 1, GOLD)
	disc(c, 596, 118, 9, CRIMSON)
	disc(c, 596, 118, 9, GOLD, 8)
	box(c, 595, 110, 2, 17, GOLD)
	box(c, 588, 117, 17, 2, GOLD)
	disc(c, 596, 118, 2, GOLD.lightened(0.2))
	# The ring of candles, on its chains. Their flames are `_paint_wall_life`'s.
	var g: Vector2i = _at["gate"]
	box(c, g.x, BEAM, 1, 10, IRON_LIT.lightened(0.1))
	line(c, g.x, 50, g.x - 18, 60, IRON_LIT.lightened(0.1))
	line(c, g.x, 50, g.x + 18, 60, IRON_LIT.lightened(0.1))
	box(c, g.x - 22, 61, 45, 3, IRON_LIT.darkened(0.25))
	box(c, g.x - 22, 61, 45, 1, IRON_LIT.lightened(0.15))
	box(c, g.x - 23, 58, 1, 5, IRON_LIT)
	box(c, g.x + 23, 58, 1, 5, IRON_LIT)
	for k in 5:
		box(c, g.x - 20 + k * 9, 60, 4, 1, IRON_LIT.lightened(0.15))
	for k in 5:
		box(c, g.x - 19 + k * 9, 56, 2, 5, CREAM)
		box(c, g.x - 19 + k * 9, 56, 1, 5, CREAM.lightened(0.15))
	# A chest of whatever came back from the last time.
	box(c, 456, FLOOR - 13, 24, 13, TIMBER)
	box(c, 455, FLOOR - 18, 26, 6, TIMBER_LIT.darkened(0.15))
	box(c, 455, FLOOR - 18, 26, 1, TIMBER_LIT)
	for band in [459, 474]:
		box(c, band, FLOOR - 18, 2, 18, IRON_LIT.darkened(0.3))
	box(c, 466, FLOOR - 13, 3, 4, GOLD)
	box(c, 456, FLOOR - 1, 24, 1, TIMBER_DARK)

## The piers, floor to ceiling, each with its capital, its foot, and the iron
## its torch stands in. The fire is `_paint_wall_life`'s.
func _paint_piers(c: CanvasItem) -> void:
	box(c, LEFT, BEAM, 8, FLOOR - BEAM, PIER)
	box(c, LEFT + 7, BEAM, 1, FLOOR - BEAM, PIER_DARK)
	for y in range(BEAM + 16, FLOOR, 18):
		box(c, LEFT, y, 8, 1, MORTAR)
	for cx: int in PIERS:
		box(c, cx - 8, BEAM, 16, FLOOR - BEAM, PIER)
		box(c, cx - 8, BEAM, 1, FLOOR - BEAM, PIER_LIT)
		box(c, cx + 6, BEAM, 2, FLOOR - BEAM, PIER_DARK)
		for y in range(BEAM + 16, FLOOR - 10, 18):
			box(c, cx - 8, y, 16, 1, MORTAR)
		box(c, cx - 11, BEAM, 22, 3, PIER_LIT)
		box(c, cx - 10, BEAM + 3, 20, 3, PIER)
		box(c, cx - 10, BEAM + 6, 20, 1, PIER_DARK)
		box(c, cx - 10, FLOOR - 10, 20, 4, PIER)
		box(c, cx - 10, FLOOR - 10, 20, 1, PIER_LIT)
		box(c, cx - 11, FLOOR - 6, 22, 6, PIER)
		box(c, cx - 11, FLOOR - 6, 22, 1, PIER_LIT)
	for x: int in TORCHES:
		box(c, x - 3, TORCH + 12, 6, 2, IRON_LIT.darkened(0.25))
		box(c, x - 2, TORCH + 6, 4, 6, IRON)
		box(c, x - 2, TORCH + 6, 1, 6, IRON_LIT)
		box(c, x - 1, TORCH, 2, 8, TIMBER_LIT)
		box(c, x - 2, TORCH - 2, 4, 4, Color(0.20, 0.14, 0.10))

## What the fires throw on the stone round them, as it lies when they are
## steady. How it comes and goes is `_paint_wall_life`'s.
func _paint_firelight(c: CanvasItem) -> void:
	for x: int in TORCHES:
		glow(c, x, TORCH - 4, 34, faded(FIRE, 0.06))
		glow(c, x, TORCH - 4, 25, faded(FIRE, 0.07))
		glow(c, x, TORCH - 4, 15, faded(FIRE, 0.09))
		glow(c, x, TORCH - 4, 7, faded(FIRE, 0.10))
	var g: Vector2i = _at["gate"]
	glow(c, g.x, 56, 30, faded(FIRE, 0.04))
	glow(c, g.x, 56, 18, faded(FIRE, 0.05))

## The floor: flagstones, with the fires' light on their edge under each, and
## a rug laid in front of the stall and another before the gate.
func _paint_floor(c: CanvasItem) -> void:
	var flag := Color(0.17, 0.165, 0.20)
	box(c, LEFT, FLOOR, RIGHT - LEFT, UNDER - FLOOR, flag)
	box(c, LEFT, FLOOR, RIGHT - LEFT, 1, PIER_LIT.darkened(0.1))
	box(c, LEFT, FLOOR + 1, RIGHT - LEFT, 1, flag.darkened(0.2))
	box(c, LEFT, FLOOR + 8, RIGHT - LEFT, 1, MORTAR)
	var x := LEFT + 22
	var k := 0
	while x < RIGHT:
		box(c, x, FLOOR + 2, 1, 6, MORTAR)
		box(c, x - 15, FLOOR + 9, 1, 7, MORTAR)
		x += 30 + (k % 3) * 5
		k += 1
	for torch: int in TORCHES:
		var from := maxi(torch - 26, LEFT)
		box(c, from, FLOOR, mini(torch + 26, RIGHT) - from, 1, PIER_LIT.lerp(FIRE, 0.4))
		box(c, from + 6, FLOOR + 1, mini(torch + 20, RIGHT) - from - 6, 1, flag.lerp(FIRE, 0.12))
	var shop: Vector2i = _at["shop"]
	var g: Vector2i = _at["gate"]
	for rug in [[shop.x - 44, 88], [g.x - 40, 80]]:
		box(c, rug[0], FLOOR, rug[1], 2, CRIMSON)
		box(c, rug[0], FLOOR + 2, rug[1], 1, CRIMSON.darkened(0.3))
		box(c, int(rug[0]) + 3, FLOOR + 1, int(rug[1]) - 6, 1, GOLD.darkened(0.2))
		for end in [int(rug[0]) - 2, int(rug[0]) + int(rug[1])]:
			box(c, end, FLOOR, 2, 1, GOLD)
			box(c, end, FLOOR + 1, 1, 2, GOLD.darkened(0.2))

## The moon, coming in at each window and down through the hall's dust to the
## floor.
func _paint_shafts(c: CanvasItem) -> void:
	for cx: int in WINDOWS:
		for k in 19:
			var y := FOOT + 6 + k * 6
			var x := cx - WIDE / 2 + int(float(y - SPRING) * LEAN)
			var thin := 1.0 - float(k) / 30.0
			box(c, x, y, WIDE, mini(6, FLOOR - y), faded(MOONLIGHT, 0.055 * thin))
			box(c, x + 12, y, WIDE - 24, mini(6, FLOOR - y), faded(MOONLIGHT, 0.04 * thin))
		var lands := cx - WIDE / 2 + int(float(FLOOR - SPRING) * LEAN)
		box(c, lands, FLOOR, WIDE, 1, PIER_LIT.lerp(MOONLIGHT, 0.45))
		for k in 5:
			box(c, lands + 4 + k * 2, FLOOR + 3 + k * 2, WIDE - 8 - k * 4, 1, faded(MOONLIGHT, 0.10 * (1.0 - k / 5.0)))

## --- what stands against the wall --------------------------------------------

## Somewhere to sit, with what was left on it. The candle's flame is
## `_paint_life`'s.
func _paint_bench(c: CanvasItem) -> void:
	var x := 184
	box(c, x, FLOOR - 13, 46, 3, TIMBER_LIT.darkened(0.1))
	box(c, x, FLOOR - 13, 46, 1, TIMBER_LIT.lightened(0.1))
	box(c, x + 3, FLOOR - 10, 3, 10, TIMBER)
	box(c, x + 40, FLOOR - 10, 3, 10, TIMBER)
	box(c, x + 6, FLOOR - 6, 34, 2, TIMBER_DARK)
	# A mug, a book, and the stub of a candle.
	box(c, x + 6, FLOOR - 18, 4, 5, STEEL.darkened(0.35))
	box(c, x + 10, FLOOR - 17, 1, 3, STEEL.darkened(0.35))
	box(c, x + 6, FLOOR - 18, 4, 1, STEEL.darkened(0.1))
	box(c, x + 17, FLOOR - 16, 10, 3, NAVY)
	box(c, x + 17, FLOOR - 14, 10, 1, CREAM)
	box(c, x + 34, FLOOR - 17, 2, 4, CREAM)

## The arms: a rack of what there is to carry, an old harness on its stand
## beside it. What catches the light on them is `_paint_life`'s.
func _paint_arms(c: CanvasItem, at: Vector2i) -> void:
	var x := at.x - 26
	var y := at.y
	# The harness: a helm and a breastplate on a post.
	var post := x - 15
	box(c, post, y - 40, 1, 40, TIMBER)
	box(c, post - 5, y - 2, 11, 2, TIMBER_DARK)
	box(c, post - 5, y - 34, 11, 13, STEEL.darkened(0.25))
	box(c, post - 5, y - 34, 2, 13, STEEL)
	box(c, post, y - 33, 1, 12, STEEL.darkened(0.45))
	box(c, post - 7, y - 35, 4, 4, STEEL.darkened(0.1))
	box(c, post + 4, y - 35, 4, 4, STEEL.darkened(0.3))
	box(c, post - 4, y - 21, 9, 3, STEEL.darkened(0.4))
	stamp(c, post - 4, y - 46, [
		"..#####..",
		".#######.",
		"#########",
		"#########",
		"#########",
		"#########",
		".#######.",
		"..#####..",
		"...###...",
	], STEEL.darkened(0.2))
	box(c, post - 3, y - 42, 7, 1, Color(0.03, 0.03, 0.05))
	box(c, post, y - 42, 1, 4, Color(0.03, 0.03, 0.05))
	box(c, post - 3, y - 45, 2, 2, STEEL)
	stamp(c, post - 1, y - 51, ["..##.", ".###.", "####.", ".##..", "..#.."], CRIMSON.lightened(0.1))
	# The rack.
	box(c, x, y - 56, 3, 56, TIMBER)
	box(c, x + 49, y - 56, 3, 56, TIMBER)
	box(c, x, y - 56, 1, 56, TIMBER_LIT)
	box(c, x + 49, y - 56, 1, 56, TIMBER_LIT)
	box(c, x - 2, y - 2, 7, 2, TIMBER_DARK)
	box(c, x + 47, y - 2, 7, 2, TIMBER_DARK)
	box(c, x - 1, y - 53, 54, 3, TIMBER)
	box(c, x - 1, y - 53, 54, 1, TIMBER_LIT)
	box(c, x, y - 21, 52, 3, TIMBER)
	box(c, x, y - 21, 52, 1, TIMBER_LIT)
	box(c, x, y - 6, 52, 2, TIMBER_DARK)
	# A sword.
	box(c, x + 8, y - 47, 2, 30, STEEL)
	box(c, x + 8, y - 47, 1, 30, STEEL_LIT)
	box(c, x + 8, y - 49, 1, 2, STEEL_LIT)
	box(c, x + 5, y - 17, 8, 1, GOLD)
	box(c, x + 8, y - 16, 2, 7, Color(0.36, 0.22, 0.14))
	box(c, x + 8, y - 9, 2, 2, GOLD)
	# An axe.
	box(c, x + 18, y - 50, 1, 44, TIMBER_LIT)
	stamp(c, x + 15, y - 50, [
		".##.##.",
		"###.###",
		"###.###",
		"###.###",
		"###.###",
		".##.##.",
	], STEEL)
	box(c, x + 15, y - 49, 1, 4, STEEL_LIT)
	# A spear, which stands taller than the rack.
	box(c, x + 27, y - 60, 1, 54, TIMBER_LIT)
	stamp(c, x + 25, y - 66, ["..#..", ".###.", ".###.", ".###.", "..#..", "..#.."], STEEL)
	box(c, x + 27, y - 66, 1, 4, STEEL_LIT)
	box(c, x + 26, y - 59, 3, 2, CRIMSON.lightened(0.1))
	# A staff, with whatever that is in the end of it.
	box(c, x + 36, y - 46, 1, 40, Color(0.40, 0.29, 0.45))
	stamp(c, x + 34, y - 53, [".###.", "#...#", "#...#", "#...#", ".#.#.", "..#.."], Color(0.40, 0.29, 0.45))
	# And a shield, hung on the end of it.
	disc(c, x + 45, y - 36, 6, CRIMSON)
	disc(c, x + 45, y - 36, 6, GOLD.darkened(0.1), 5)
	box(c, x + 44, y - 41, 2, 11, GOLD.darkened(0.1))
	box(c, x + 44, y - 37, 2, 2, STEEL_LIT)

## The stall: shelves of what there is to buy under an awning, the counter,
## a barrel and a sack beside it, and a pot of something on its fire. Whoever
## keeps it, the cat, and what burns are `_paint_life`'s.
func _paint_stall(c: CanvasItem, at: Vector2i) -> void:
	var x := at.x - 32
	var y := at.y
	# The shelves behind.
	box(c, x + 4, y - 58, 56, 38, TIMBER_DARK)
	box(c, x + 6, y - 56, 52, 36, TIMBER_DARK.darkened(0.45))
	var brews := [Color(0.85, 0.22, 0.26), Color(0.26, 0.56, 0.95), Color(0.36, 0.84, 0.44),
		Color(0.70, 0.40, 0.95), Color(0.96, 0.70, 0.26)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5407
	for shelf in 3:
		var sy := y - 46 + shelf * 12
		box(c, x + 6, sy, 52, 1, TIMBER_LIT.darkened(0.15))
		var gx := x + 8
		while gx < x + 54:
			var gw := rng.randi_range(3, 4)
			var gh := rng.randi_range(3, 6)
			var brew: Color = brews[rng.randi() % brews.size()]
			# Not where the keeper stands.
			if not (shelf > 0 and gx > x + 19 and gx < x + 43):
				box(c, gx, sy - gh, gw, gh, brew.darkened(0.3))
				box(c, gx, sy - gh, 1, gh, brew.darkened(0.05))
				box(c, gx + gw / 2, sy - gh - 2, 1, 2, CREAM.darkened(0.3))
			gx += gw + rng.randi_range(1, 3)
	# The awning, on its poles.
	box(c, x - 3, y - 66, 2, 66, TIMBER)
	box(c, x + 65, y - 66, 2, 66, TIMBER)
	box(c, x - 3, y - 66, 1, 66, TIMBER_LIT)
	for k in 12:
		var stripe := CRIMSON if k % 2 == 0 else CREAM
		box(c, x - 4 + k * 6, y - 66, 6, 6, stripe)
		box(c, x - 3 + k * 6, y - 60, 4, 1, stripe)
		box(c, x - 2 + k * 6, y - 59, 2, 1, stripe.darkened(0.15))
	box(c, x - 5, y - 67, 74, 1, TIMBER_LIT)
	# The counter itself, with the stall's cloth over the front of it.
	box(c, x - 1, y - 21, 66, 21, TIMBER_DARK)
	box(c, x - 2, y - 21, 68, 3, TIMBER_LIT)
	box(c, x - 2, y - 21, 68, 1, TIMBER_LIT.lightened(0.12))
	box(c, x, y - 18, 64, 18, TIMBER)
	for gx in range(x + 8, x + 64, 8):
		box(c, gx, y - 17, 1, 17, TIMBER_DARK)
	box(c, at.x - 9, y - 18, 18, 9, CRIMSON)
	for k in 5:
		box(c, at.x - 9 + k * 2, y - 9 + k, 18 - k * 4, 1, CRIMSON)
	box(c, at.x - 9, y - 18, 18, 1, GOLD.darkened(0.15))
	disc(c, at.x, y - 11, 3, GOLD)
	box(c, at.x, y - 13, 1, 5, GOLD.darkened(0.35))
	# The lantern's iron, on its hook.
	box(c, x + 59, y - 60, 1, 5, IRON_LIT)
	box(c, x + 57, y - 55, 5, 1, IRON_LIT)
	box(c, x + 57, y - 47, 5, 1, IRON_LIT)
	box(c, x + 57, y - 54, 1, 7, IRON)
	box(c, x + 61, y - 54, 1, 7, IRON)
	# A barrel, and a sack.
	box(c, x - 22, y - 18, 14, 18, TIMBER)
	box(c, x - 22, y - 18, 14, 1, TIMBER_LIT)
	box(c, x - 22, y - 18, 1, 18, TIMBER_LIT.darkened(0.2))
	for stave in [x - 18, x - 14, x - 11]:
		box(c, stave, y - 17, 1, 17, TIMBER_DARK)
	box(c, x - 22, y - 14, 14, 1, IRON_LIT.darkened(0.2))
	box(c, x - 22, y - 5, 14, 1, IRON_LIT.darkened(0.2))
	stamp(c, x - 35, y - 11, [
		"...###.....",
		"..##.##....",
		"...###.....",
		".#######...",
		"##########.",
		"###########",
		"###########",
		"###########",
		"###########",
		"###########",
		".#########.",
	], Color(0.46, 0.39, 0.28))
	box(c, x - 34, y - 6, 1, 4, Color(0.56, 0.48, 0.35))
	# The cat, on the barrel. Its eyes and its tail are `_paint_life`'s.
	stamp(c, x - 20, y - 28, [
		"#.....#..",
		"##...##..",
		"#######..",
		"#######..",
		"#######..",
		".#####...",
		".######..",
		"########.",
		"########.",
		".######..",
	], Color(0.045, 0.045, 0.06))
	# The pot, on its legs over the fire.
	var px := at.x + 56
	line(c, px - 8, y - 7, px - 11, y - 1, IRON)
	line(c, px + 8, y - 7, px + 11, y - 1, IRON)
	oval(c, px, y - 12, 9, 7, IRON)
	box(c, px - 10, y - 19, 21, 2, IRON_LIT.darkened(0.15))
	box(c, px - 10, y - 19, 21, 1, IRON_LIT)
	box(c, px - 7, y - 12, 1, 5, IRON_LIT.darkened(0.3))
	box(c, px - 5, y - 2, 11, 2, TIMBER_DARK)
	box(c, px - 6, y - 3, 4, 1, TIMBER)

## The gate: an arch of cut stone with its keystone and the signs carved down
## its sides, two steps up to it, and a fire basket either side. What burns,
## what the signs are lit in, and what is in the arch are `_paint_life`'s.
func _paint_gate(c: CanvasItem, g: Vector2i) -> void:
	var cy := g.y - 38
	var arch := PIER.lightened(0.04)
	box(c, g.x - 36, g.y - 3, 72, 3, PIER)
	box(c, g.x - 36, g.y - 3, 72, 1, PIER_LIT)
	box(c, g.x - 31, g.y - 6, 62, 3, PIER)
	box(c, g.x - 31, g.y - 6, 62, 1, PIER_LIT)
	for up in range(0, 30):
		var half := int(floor(sqrt(float(29 * 29 - up * up) + 0.5)))
		box(c, g.x - half, cy - up, half * 2 + 1, 1, arch)
	box(c, g.x - 29, cy, 59, 32, arch)
	box(c, g.x - 29, cy, 1, 32, PIER_LIT)
	box(c, g.x + 28, cy, 1, 32, PIER_DARK)
	# The stones of it: wedges round the top, courses down the sides.
	for deg in [-75, -55, -35, -15, 15, 35, 55, 75]:
		var a := deg_to_rad(float(deg))
		line(c, g.x + int(round(sin(a) * 23.0)), cy - int(round(cos(a) * 23.0)),
			g.x + int(round(sin(a) * 29.0)), cy - int(round(cos(a) * 29.0)), PIER_DARK)
	for k in 4:
		box(c, g.x - 29, cy + 7 + k * 8, 7, 1, PIER_DARK)
		box(c, g.x + 23, cy + 7 + k * 8, 7, 1, PIER_DARK)
	# What is in it: nothing yet.
	for up in range(0, 23):
		var half := int(floor(sqrt(float(22 * 22 - up * up) + 0.5)))
		box(c, g.x - half, cy - up, half * 2 + 1, 1, Color(0.02, 0.02, 0.045))
	box(c, g.x - 22, cy, 45, 32, Color(0.02, 0.02, 0.045))
	# The keystone.
	box(c, g.x - 3, cy - 30, 7, 9, PIER_LIT)
	box(c, g.x - 3, cy - 30, 7, 1, PIER_LIT.lightened(0.1))
	box(c, g.x + 3, cy - 30, 1, 9, PIER)
	# The fire baskets, on their legs.
	for side: int in [-1, 1]:
		var bx := g.x + side * 44
		box(c, bx, g.y - 24, 1, 24, IRON_LIT.darkened(0.3))
		line(c, bx, g.y - 12, bx - 5, g.y - 1, IRON_LIT.darkened(0.3))
		line(c, bx, g.y - 12, bx + 5, g.y - 1, IRON_LIT.darkened(0.3))
		box(c, bx - 5, g.y - 28, 11, 5, IRON)
		box(c, bx - 6, g.y - 29, 13, 1, IRON_LIT)
		for bar in [bx - 3, bx, bx + 3]:
			box(c, bar, g.y - 28, 1, 5, IRON_LIT.darkened(0.2))

## --- what moves, and what is lit --------------------------------------------

## A flame standing on (x, y): `tall` at its fullest, and never the same
## height twice running.
func _flame(c: CanvasItem, x: int, y: int, tall: int, f: float, salt: int) -> void:
	var h := maxi(int(round(float(tall) * (0.5 + 0.5 * f))), 2)
	var lean := int(round(sin(_t * 6.0 + float(salt)) * 0.8))
	var body := h * 6 / 10
	box(c, x - 2, y - body, 5, body, FLAME_OUT)
	box(c, x - 1 + lean, y - h, 3, h - body, FLAME_OUT)
	box(c, x - 1, y - h * 7 / 10, 3, h * 7 / 10, FLAME_MID)
	box(c, x + lean, y - h + 1, 1, 2, FLAME_MID)
	box(c, x, y - h * 4 / 10, 1, h * 4 / 10, FLAME_CORE)

## A spark or two, going up from (x, y) and out.
func _sparks(c: CanvasItem, x: int, y: int, salt: int) -> void:
	for k in 2:
		var up := fmod(_t * (0.9 + 0.3 * k) + float(salt) * 0.37 + k * 0.5, 1.0)
		box(c, x + int(round(sin(up * 9.0 + float(salt + k)) * 3.0)), y - int(up * 18.0), 1, 1,
			faded(FLAME_MID, 1.0 - up))

## The wall's own lights, behind whatever stands against it: the torches, the
## candles over the gate, the dust in the moonlight, and the way through the
## map.
func _paint_wall_life(c: CanvasItem) -> void:
	for i in TORCHES.size():
		var x: int = TORCHES[i]
		var f := flicker(_t, i * 3 + 1)
		_flame(c, x, TORCH - 1, 13, f, i)
		_sparks(c, x, TORCH - 12, i)
		# What it throws, coming and going.
		var a := 0.07 * (f - 0.55)
		var from := maxi(x - 22, LEFT)
		box(c, from, TORCH - 18, x + 22 - from, 28, faded(FIRE, a))
		from = maxi(x - 14, LEFT)
		box(c, from, TORCH - 26, x + 14 - from, 44, faded(FIRE, a))
		from = maxi(x - 9, LEFT)
		box(c, from, TORCH - 13, x + 9 - from, 18, faded(FIRE, a))
	var g: Vector2i = _at["gate"]
	for k in 5:
		var f := flicker(_t, 20 + k * 5)
		var cx := g.x - 19 + k * 9
		box(c, cx, 54 - int(f * 2.0), 2, 2 + int(f * 2.0), FLAME_MID)
		box(c, cx, 54, 1, 2, FLAME_CORE)
		box(c, cx - 2, 49, 6, 8, faded(FIRE, 0.06 * f))
	# The dust, drifting down the moon's light.
	for m in _motes:
		var cx: int = WINDOWS[m["pane"]]
		var along := fmod(float(m["along"]) + _t * float(m["speed"]), 1.0)
		var y := FOOT + 8 + int(along * float(FLOOR - FOOT - 12))
		var x := cx - WIDE / 2 + int(float(y - SPRING) * LEAN) + 4 + int(float(m["across"]) * float(WIDE - 8))
		box(c, x, y, 1, 1, faded(MOONLIGHT.lightened(0.5), 0.22 + 0.2 * sin(_t * 1.3 + float(m["phase"]))))
	# The way through the map, a room at a time, when there is a way.
	if _gate_open():
		var here: Vector2i = ROOMS[int(_t * 1.6) % 14]
		var mx := 452 + here.x * 8
		var my := 88 + here.y * 7
		box(c, mx - 1, my - 1, 8, 1, CRIMSON.lightened(0.15))
		box(c, mx - 1, my + 5, 8, 1, CRIMSON.lightened(0.15))
		box(c, mx - 1, my, 1, 5, CRIMSON.lightened(0.15))
		box(c, mx + 6, my, 1, 5, CRIMSON.lightened(0.15))

func _paint_life(c: CanvasItem) -> void:
	_life_bench(c)
	_life_arms(c, _at["weapons"], float(_lit["weapons"]))
	_life_stall(c, _at["shop"], float(_lit["shop"]))
	_life_gate(c, _at["gate"], float(_lit["gate"]))

func _life_bench(c: CanvasItem) -> void:
	var f := flicker(_t, 40)
	box(c, 218, FLOOR - 19 - int(f * 2.0), 2, 2 + int(f * 2.0), FLAME_MID)
	box(c, 218, FLOOR - 19, 1, 2, FLAME_CORE)
	box(c, 213, FLOOR - 25, 12, 12, faded(FIRE, 0.07 * f))
	# The mouse, which comes out when nobody is by.
	var out := fmod(_t, 13.0)
	if out > 9.0 and absf(_player_x(-999.0) - 250.0) > 60.0:
		var peek := mini(int((out - 9.0) * 4.0), 3) if out < 12.0 else maxi(3 - int((out - 12.0) * 6.0), 0)
		box(c, 251, FLOOR - 3, peek, 3, Color(0.42, 0.38, 0.36))
		if peek >= 3:
			box(c, 253, FLOOR - 2, 1, 1, Color(0.02, 0.02, 0.03))
			box(c, 251, FLOOR - 4, 1, 1, Color(0.52, 0.42, 0.42))

## A glint on an edge: a cross of light, there and gone.
func _glint(c: CanvasItem, x: int, y: int, on: float) -> void:
	if on <= 0.0:
		return
	box(c, x, y - 1, 1, 3, faded(STEEL_LIT, on))
	box(c, x - 1, y, 3, 1, faded(STEEL_LIT, on))

func _life_arms(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var x := at.x - 26
	var y := at.y
	# The end of the staff.
	var pulse := 0.6 + 0.4 * sin(_t * 2.3)
	var gem := Color(0.45, 0.80, 1.0)
	halo(c, x + 35, y - 52, 3, 3, gem, 3, 0.09 * pulse * (0.6 + 0.4 * lit))
	box(c, x + 35, y - 52, 3, 3, gem.lerp(Color.WHITE, 0.5 * pulse))
	# Edges catching the fire, one after another, and more of them for
	# somebody standing here.
	var turn := fmod(_t, 4.0)
	_glint(c, x + 8, y - 44, clampf(1.0 - absf(turn - 0.5) * 4.0, 0.0, 1.0) * (0.5 + 0.5 * lit))
	_glint(c, x + 15, y - 47, clampf(1.0 - absf(turn - 1.7) * 4.0, 0.0, 1.0) * (0.5 + 0.5 * lit))
	_glint(c, x + 27, y - 64, clampf(1.0 - absf(turn - 2.9) * 4.0, 0.0, 1.0) * (0.5 + 0.5 * lit))
	# The rack's rail, gilded when it would answer.
	if lit > 0.0:
		box(c, x - 1, y - 54, 54, 1, faded(GOLD, lit))
		box(c, x - 1, y - 53, 1, 53, faded(GOLD, lit * 0.6))
		box(c, x + 52, y - 53, 1, 53, faded(GOLD, lit * 0.6))

func _life_stall(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var x := at.x - 32
	var y := at.y
	var eyes := clampi(int((_player_x(float(at.x)) - float(at.x)) / 60.0), -2, 2)
	# Whoever keeps the stall: a hood, and two eyes in the dark of it.
	var hx := at.x - 7
	var hy := y - 41
	stamp(c, hx, hy, [
		".....####.....",
		"...########...",
		"..##########..",
		".############.",
		".############.",
		"##############",
		"##############",
		"##############",
		"##############",
		"##############",
		".############.",
		"..##########..",
	], CLOAK)
	box(c, hx + 1, hy + 3, 1, 7, CLOAK.lightened(0.12))
	box(c, hx + 3, hy + 6, 8, 4, Color(0.02, 0.02, 0.03))
	box(c, hx + 4, hy + 5, 6, 1, Color(0.02, 0.02, 0.03))
	box(c, hx - 2, hy + 12, 18, 8, CLOAK)
	box(c, hx - 2, hy + 12, 18, 1, CLOAK.lightened(0.1))
	box(c, hx + 6, hy + 12, 2, 2, GOLD)
	var eye := GOLD.lerp(Color.WHITE, 0.25 + 0.25 * lit)
	if fmod(_t, 4.3) > 4.15:
		box(c, hx + 4 + eyes, hy + 8, 2, 1, eye.darkened(0.3))
		box(c, hx + 8 + eyes, hy + 8, 2, 1, eye.darkened(0.3))
	else:
		box(c, hx + 4 + eyes, hy + 7, 2, 2, eye)
		box(c, hx + 8 + eyes, hy + 7, 2, 2, eye)
	# The lantern, brighter for somebody standing at the counter.
	var f := flicker(_t, 60)
	var on := (0.6 + 0.4 * lit) * f
	box(c, x + 58, y - 54, 3, 7, FLAME_OUT.lerp(FLAME_MID, on))
	box(c, x + 59, y - 52, 1, 4, FLAME_CORE)
	halo(c, x + 57, y - 55, 5, 9, FIRE, 5, 0.09 * on)
	box(c, x - 2, y - 58, 68, 1, faded(FIRE, 0.22 * on))
	for k in 3:
		box(c, x + 28 + k * 4, y - 57 + k * 4, 38 - k * 4, 4, faded(FIRE, 0.045 * on * (1.0 - k / 3.0)))
	if lit > 0.0:
		box(c, x - 2, y - 22, 68, 1, faded(GOLD, lit))
	# The cat: watching, and thinking about it.
	var cat := x - 20
	var green := Color(0.55, 0.95, 0.45)
	if fmod(_t + 1.7, 5.1) < 4.9:
		box(c, cat + 1 + maxi(eyes, 0) / 2, y - 25, 2, 1, green)
		box(c, cat + 4 + maxi(eyes, 0) / 2, y - 25, 2, 1, green)
	var swish := int(round(sin(_t * 1.7) * 1.4))
	var fur := Color(0.045, 0.045, 0.06)
	box(c, cat + 8, y - 20, 1, 2, fur)
	box(c, cat + 8 + swish, y - 18, 1, 3, fur)
	box(c, cat + 8 + swish * 2, y - 15, 1, 2, fur)
	# The pot: what is in it, turning over, and the fire under it.
	var px := at.x + 56
	var brew := Color(0.40, 0.92, 0.48)
	box(c, px - 8, y - 18, 17, 1, brew.darkened(0.25))
	for k in 3:
		var pop := fmod(_t * (0.7 + 0.2 * k) + k * 0.4, 1.0)
		var bx := px - 6 + (k * 5 + int(_t * (0.7 + 0.2 * k) + k * 0.4) * 3) % 13
		if pop < 0.7:
			box(c, bx, y - 19, 2, 1, brew)
		else:
			box(c, bx, y - 20, 2, 2, brew.lightened(0.3))
	for k in 3:
		var up := fmod(_t * 0.35 + k * 0.33, 1.0)
		box(c, px - 4 + k * 4 + int(round(sin(up * 6.0 + k) * 2.0)), y - 21 - int(up * 16.0), 2, 1,
			faded(brew.lightened(0.4), 0.30 * (1.0 - up)))
	halo(c, px - 8, y - 19, 17, 1, brew, 3, 0.05)
	var burn := flicker(_t, 77)
	_flame(c, px - 2, y - 2, 5, burn, 5)
	_flame(c, px + 2, y - 2, 4, flicker(_t, 78), 6)
	box(c, px - 9, y - 8, 19, 8, faded(FIRE, 0.07 * burn))

func _life_gate(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var cy := at.y - 38
	var open := _gate_open()
	var col := OPEN if open else SHUT
	if open:
		# What is in the arch, when it will take you: light, turning.
		for ring in [[18, 0.035], [12, 0.045]]:
			var r: int = ring[0]
			var a: float = float(ring[1]) + 0.03 * lit
			for up in range(1, r + 1):
				var half := int(floor(sqrt(float(r * r - up * up) + 0.5)))
				box(c, at.x - half, cy - up, half * 2 + 1, 1, faded(col, a))
			box(c, at.x - r, cy, r * 2 + 1, 30, faded(col, a))
		for k in 3:
			var r := 5 + k * 5
			var a := _t * (1.4 - 0.3 * k) + k * 2.1
			for seg in 5:
				var th := a + seg * 0.22
				var dot := faded(col, (0.25 + 0.5 * lit) * (1.0 - seg / 5.0))
				box(c, at.x + int(round(cos(th) * r)), cy + 6 + int(round(sin(th) * r * 1.3)), 2, 2, dot)
				box(c, at.x - int(round(cos(th) * r)), cy + 6 - int(round(sin(th) * r * 1.3)), 2, 2, dot)
		disc(c, at.x, cy + 6, 3, faded(col, 0.35 + 0.4 * lit))
	else:
		# And when it will not: the grille is down.
		var iron := IRON_LIT.darkened(0.15)
		for dx in range(-20, 21, 5):
			var top := cy - int(floor(sqrt(float(22 * 22 - dx * dx))))
			box(c, at.x + dx, top, 1, at.y - 6 - top, iron)
		for bar in [cy - 6, cy + 8, cy + 22]:
			box(c, at.x - 22, bar, 45, 1, iron)
	# The signs down its sides, lit one after another while it is open, and all
	# together, slowly, while it is not.
	for k in 6:
		var on := 0.6 + 0.3 * sin(_t * 2.0)
		if open:
			on = clampf(1.0 - fposmod(fmod(_t * 4.0, 6.0) - float(k), 6.0) / 3.0, 0.25, 1.0)
		var side := -1 if k < 3 else 1
		var rx := at.x + (-28 if side < 0 else 24)
		var ry := cy + 1 + (k % 3) * 9 if side < 0 else cy + 1 + (2 - k % 3) * 9
		stamp(c, rx, ry, RUNES[k], faded(col, on * (0.7 + 0.3 * lit)))
	# The stone in the keystone.
	var beat := 0.7 + 0.3 * sin(_t * 2.0)
	box(c, at.x - 1, cy - 28, 3, 4, col.lerp(Color.WHITE, 0.25 * beat))
	halo(c, at.x - 1, cy - 28, 3, 4, col, 3, 0.10 * beat)
	# The fire baskets: up for a gate that is open, down to embers for one
	# that is not.
	for side: int in [-1, 1]:
		var bx := at.x + side * 44
		var f := flicker(_t, 90 + side)
		box(c, bx - 4, at.y - 30, 9, 2, FLAME_OUT.lerp(FLAME_MID, f))
		if open:
			_flame(c, bx - 2, at.y - 30, 9 + int(3.0 * lit), f, 7 + side)
			_flame(c, bx + 2, at.y - 30, 11 + int(3.0 * lit), flicker(_t, 95 + side), 9 + side)
			_sparks(c, bx, at.y - 38, 30 + side)
			box(c, maxi(bx - 16, LEFT), at.y - 52, mini(bx + 16, RIGHT) - maxi(bx - 16, LEFT), 34,
				faded(FIRE, 0.05 * f))
			box(c, bx - 10, at.y - 46, 21, 22, faded(FIRE, 0.05 * f))
		else:
			box(c, bx - 2, at.y - 31, 5, 1, faded(FLAME_OUT, f))

## The signs carved down the gate's sides.
const RUNES := [
	["#..#", "#.#.", "##..", "#.#.", "#..#"],
	[".##.", "#..#", ".##.", "..#.", ".#.."],
	["#...", "##..", "#.#.", "#..#", "#..."],
	["####", "..#.", ".#..", "#...", "####"],
	["#..#", "#..#", ".##.", "#..#", "#..#"],
	[".#..", "###.", ".#..", ".#.#", ".##."],
]
