class_name HideoutOrbit
extends HideoutScenery

## The hideout as a deck of a station in orbit. One wall of it is a window
## onto the world it goes round — the curve of it, its weather, the line where
## its night starts and the sun coming up over its edge — with the station's
## own arm and its panels out in front, somebody on a line working on them,
## and a shuttle going by. Inside it is white hull, light in strips, orange
## where a thing is to be noticed and a trough of green along the foot of the
## wall: a cabinet of arms with a graph turning in the air beside it, a booth
## with a drone behind its counter, and the gate as an iris in a bay of its
## own, under the chart that shows where it goes.
##
## One of the hideout's looks (`HideoutThemes`), on the ground they all stand
## on (`HideoutScenery`): everything is placed in pixels of the buffer the
## world is drawn into, drawn once or drawn again as it moves, and reads the
## room without changing it.

# A picture drawn in whole pixels halves and thirds whole numbers on purpose,
# all the way down.
@warning_ignore_start("integer_division")

## --- where things are, in buffer pixels of the room -------------------------
## The window: from under the beam over it down to the sill, and from the
## pillar on the left wall across to the one the gate's bay starts at. The
## sill is deep, and the stations' signs hang from the underside of it.
const GLASS_TOP := 56
const SILL := 216
const UNDERSILL := 228
const GLASS_LEFT := 30
const GLASS_RIGHT := 430
const BAY_LEFT := 444
## How far the nearest thing outside may slide as the player walks the room,
## and so how far past the window each depth is drawn. The pillars hide the
## ends.
const SLIDE := 6
## The ribs between the panes, by where each meets the sill, and how far each
## leans: one way and then the other.
const RIBS := [110, 190, 270, 350]
const LEAN := 8
## The world below: the middle of it and how big it is, which between them
## say where its edge crosses the window.
const WORLD_AT := Vector2(230.0, 664.0)
const WORLD := 520.0
## Where its night gives way to its day, where on its edge the sun is coming
## up, and where its moon hangs.
const DUSK := 170
const SUNRISE := 392
const MOON_AT := Vector2i(160, 84)
## The station's own arm outside, by the line it runs along and where it ends.
const ARM := 150
const ARM_END := 152
## The lights in the ceiling, by their middles. Clear of the top left, where
## the readout is.
const STRIPS := [204, 328, 470, 586]
## The chart over the gate's bay, by how far left of the gate its left edge is.
const CHART := 94
## The way through, on the chart: the rooms of it, on a grid.
const ROOMS := [
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(3, 1), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(3, 3), Vector2i(2, 3),
	Vector2i(5, 1), Vector2i(6, 1), Vector2i(1, 3), Vector2i(5, 3), Vector2i(2, 4), Vector2i(6, 0),
]

## --- its colours --------------------------------------------------------------
const HULL := Color(0.52, 0.57, 0.65)
const HULL_LIT := Color(0.78, 0.83, 0.90)
const HULL_SHADE := Color(0.35, 0.39, 0.48)
const HULL_DARK := Color(0.16, 0.18, 0.25)
const DECK := Color(0.15, 0.17, 0.23)
const ACCENT := Color(0.97, 0.55, 0.16)
const HOLO := Color(0.36, 0.92, 1.0)
const LIGHT := Color(0.88, 0.97, 1.0)
const SPACE := Color(0.012, 0.014, 0.035)
const OCEAN := Color(0.09, 0.27, 0.60)
const LAND := Color(0.20, 0.44, 0.30)
const SAND := Color(0.60, 0.52, 0.34)
const CLOUD := Color(0.93, 0.97, 1.0)
const AIR := Color(0.42, 0.80, 1.0)
const SUN := Color(1.0, 0.95, 0.80)
const TRUSS := Color(0.60, 0.64, 0.70)
const CELLS := Color(0.09, 0.17, 0.42)
const FOIL := Color(0.86, 0.66, 0.24)
const STEEL := Color(0.62, 0.68, 0.76)
const STEEL_LIT := Color(0.92, 0.96, 1.0)
const LEAF := Color(0.26, 0.62, 0.34)
## The gate's light: when it would take you, and when it would not.
const OPEN := Color(0.32, 1.0, 0.66)
const SHUT := Color(1.0, 0.26, 0.26)

## Back to front. `_traffic` is what moves outside, and is not slid: what it
## draws on a depth it draws where that depth has got to.
var _stars_layer: Layer
var _globe: Layer
var _near: Layer
var _traffic: Layer
var _wall: Layer
var _wall_life: Layer
var _fittings: Layer
var _life: Layer

## The stars, `{x, y, a, tone}`, and the ones that twinkle, `{x, y, every, from}`.
var _stars: Array = []
var _twinkles: Array = []
## The world's weather, as it stands, `{x, y, w, h, a}`; the weather that is
## going somewhere, `{x, y, w, speed}`; its land, the same shape as the first;
## and the lights on its night side, `{x, y}`.
var _clouds: Array = []
var _fronts: Array = []
var _lands: Array = []
var _cities: Array = []

func _build() -> void:
	plate = Color(0.06, 0.08, 0.12)
	ink = Color(0.48, 0.70, 0.84)
	ink_lit = Color(0.62, 0.98, 1.0)
	# Dark, for once: it is written over pale hull, where the other looks
	# write it over a wall in the dark.
	ink_shut = Color(0.72, 0.08, 0.10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x0B17
	var wide := GLASS_RIGHT - GLASS_LEFT + 2 * SLIDE
	for i in 150:
		_stars.append({"x": GLASS_LEFT - SLIDE + rng.randi_range(0, wide - 1), "y": rng.randi_range(GLASS_TOP, SILL - 30),
			"a": rng.randf_range(0.25, 1.0), "tone": rng.randi() % 5})
	for i in 10:
		_twinkles.append({"x": GLASS_LEFT + rng.randi_range(4, wide - 20), "y": rng.randi_range(GLASS_TOP + 4, 130),
			"every": rng.randf_range(1.4, 4.0), "from": rng.randf_range(0.0, 4.0)})
	for i in 5:
		var cx := rng.randi_range(GLASS_LEFT + 150, GLASS_RIGHT - 20)
		var cy := rng.randi_range(168, 206)
		for k in rng.randi_range(9, 15):
			_lands.append({"x": cx + rng.randi_range(-22, 16), "y": cy + rng.randi_range(-9, 9),
				"w": rng.randi_range(5, 18), "h": rng.randi_range(2, 5), "a": 0.0 if rng.randf() < 0.75 else 1.0})
	for i in 17:
		var cx := GLASS_LEFT - SLIDE + rng.randi_range(0, wide - 30)
		var cy := rng.randi_range(152, SILL - 6)
		for k in rng.randi_range(3, 6):
			_clouds.append({"x": cx + rng.randi_range(-10, 12), "y": cy + k * 2 + rng.randi_range(-1, 0),
				"w": rng.randi_range(9, 30), "h": rng.randi_range(1, 2), "a": rng.randf_range(0.5, 0.9)})
	for i in 9:
		_fronts.append({"x": rng.randi_range(0, wide), "y": rng.randi_range(186, SILL - 3),
			"w": rng.randi_range(12, 30), "speed": rng.randf_range(1.2, 2.6)})
	for i in 46:
		_cities.append({"x": GLASS_LEFT - SLIDE + rng.randi_range(0, 110), "y": rng.randi_range(176, SILL - 1)})
	_stars_layer = still(_paint_stars)
	_globe = still(_paint_world)
	_near = still(_paint_near)
	_traffic = moving(_paint_traffic)
	_wall = still(_paint_wall)
	_wall_life = moving(_paint_wall_life)
	_fittings = still(_paint_fittings)
	_life = moving(_paint_life)

## What is outside slides a little against the window as the player walks the
## room, the station's own arm furthest and the stars hardly at all: whole
## pixels of the buffer, and never more than SLIDE of them.
func _slide(across: float) -> void:
	_stars_layer.position.x = slid(across, 1.0)
	_globe.position.x = slid(across, 2.0)
	_near.position.x = slid(across, float(SLIDE))

## How far a depth has slid, in pixels of the buffer.
func _off(depth: Layer) -> int:
	return int(round(depth.position.x / S))

## A box of something outside, cut off where its depth ends: nothing out there
## may show past the window.
static func _out_there(c: CanvasItem, x: int, y: int, w: int, h: int, col: Color) -> void:
	var from := maxi(x, GLASS_LEFT - SLIDE)
	var top := maxi(y, GLASS_TOP)
	box(c, from, top, mini(x + w, GLASS_RIGHT + SLIDE) - from, mini(y + h, SILL) - top, col)

## A disc of the same, a row at a time.
static func _round(c: CanvasItem, cx: int, cy: int, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		var half := int(floor(sqrt(float(r * r - dy * dy) + 0.5)))
		_out_there(c, cx - half, cy + dy, half * 2 + 1, 1, col)

## Where the edge of the world below crosses the column `x`.
static func _limb(x: int) -> int:
	var dx := float(x) - WORLD_AT.x
	return int(round(WORLD_AT.y - sqrt(WORLD * WORLD - dx * dx)))

## A box of something on the world below: nothing of it above the world's edge.
static func _on_world(c: CanvasItem, x: int, y: int, w: int, h: int, col: Color) -> void:
	var top := maxi(maxi(_limb(x), _limb(x + w)) + 4, y)
	_out_there(c, x, top, w, y + h - top, col)

## --- outside ------------------------------------------------------------------

func _paint_stars(c: CanvasItem) -> void:
	var x := GLASS_LEFT - SLIDE
	var w := GLASS_RIGHT - GLASS_LEFT + 2 * SLIDE
	box(c, x, GLASS_TOP, w, SILL - GLASS_TOP, SPACE)
	# What a sky with no air in front of it has in it besides stars.
	var dust := [Color(0.34, 0.20, 0.62), Color(0.16, 0.30, 0.66), Color(0.50, 0.22, 0.48)]
	for k in 26:
		_round(c, x + 20 + k * 15 + _hash(k, 1) % 14, 150 - k * 3 + _hash(k, 2) % 26, 9 + _hash(k, 3) % 12,
			faded(dust[k % 3], 0.035))
	var tones := [Color(1, 1, 1), Color(0.75, 0.86, 1.0), Color(1.0, 0.90, 0.72), Color(1, 1, 1), Color(0.86, 0.80, 1.0)]
	for s in _stars:
		box(c, int(s["x"]), int(s["y"]), 1, 1, faded(tones[s["tone"]], float(s["a"])))
	for big in [[72, 78], [168, 66], [246, 108], [318, 74], [402, 96]]:
		box(c, int(big[0]) - 1, big[1], 3, 1, Color(1, 1, 1, 0.55))
		box(c, big[0], int(big[1]) - 1, 1, 3, Color(1, 1, 1, 0.55))
		box(c, big[0], big[1], 1, 1, Color.WHITE)
	# A moon of the world below, lit from the side the sun is coming up on.
	disc(c, MOON_AT.x, MOON_AT.y, 9, Color(0.60, 0.62, 0.66))
	disc(c, MOON_AT.x - 3, MOON_AT.y - 2, 2, Color(0.45, 0.47, 0.52))
	disc(c, MOON_AT.x + 3, MOON_AT.y + 4, 1, Color(0.45, 0.47, 0.52))
	box(c, MOON_AT.x + 1, MOON_AT.y - 5, 2, 1, Color(0.45, 0.47, 0.52))
	for dy in range(-9, 10):
		var half := int(floor(sqrt(float(81 - dy * dy) + 0.5)))
		var shade := int(floor(sqrt(maxf(float(81 - dy * dy) * 0.42, 0.0))))
		box(c, MOON_AT.x - half, MOON_AT.y + dy, half - shade + 1, 1, Color(0.02, 0.025, 0.05, 0.82))

## Something that is the same for `k` every time and has no pattern to it.
static func _hash(k: int, salt: int) -> int:
	return absi((k * 73856093) ^ ((k + salt) * 19349663) ^ (salt * 83492791)) % 1000

## The world below: its seas, its land, the weather standing over both, the
## air along its edge, its night, and the sun on the way up.
func _paint_world(c: CanvasItem) -> void:
	var from := GLASS_LEFT - SLIDE
	var to := GLASS_RIGHT + SLIDE
	for x in range(from, to):
		var top := _limb(x)
		box(c, x, top - 4, 1, 1, faded(AIR, 0.08))
		box(c, x, top - 3, 1, 1, faded(AIR, 0.16))
		box(c, x, top - 2, 1, 1, faded(AIR, 0.30))
		box(c, x, top - 1, 1, 1, faded(AIR, 0.55))
		box(c, x, top, 1, SILL - top, OCEAN)
		box(c, x, top, 1, 2, AIR.lightened(0.25))
		box(c, x, top + 2, 1, 3, OCEAN.lerp(AIR, 0.45))
		box(c, x, top + 5, 1, 5, OCEAN.lerp(AIR, 0.18))
	# Deeper water, in the bands a sea has from this high up.
	for band in [[176, 60, 190, 3], [188, 150, 150, 2], [198, 40, 120, 3], [206, 220, 170, 2], [182, 300, 110, 2]]:
		_on_world(c, band[1], band[0], band[2], band[3], OCEAN.darkened(0.14))
	for land in _lands:
		_on_world(c, int(land["x"]), int(land["y"]), int(land["w"]), int(land["h"]),
			LAND if float(land["a"]) < 0.5 else SAND)
	for cloud in _clouds:
		_on_world(c, int(cloud["x"]), int(cloud["y"]), int(cloud["w"]), int(cloud["h"]), faded(CLOUD, float(cloud["a"])))
	# A storm, turning.
	for arm in 14:
		var th := arm * 0.55
		var r := 2.0 + arm * 0.9
		_on_world(c, 286 + int(round(cos(th) * r * 1.6)), 196 + int(round(sin(th) * r * 0.55)), 5, 1, faded(CLOUD, 0.85))
	# The night, coming on to the left of the line.
	for k in 26:
		var x := DUSK - k * 6
		_on_world(c, mini(x - 6, from) if k == 25 else x - 6, GLASS_TOP, 6 if k < 25 else x - from, SILL - GLASS_TOP,
			Color(0.0, 0.008, 0.03, minf(0.07 + k * 0.045, 0.9)))
	for city in _cities:
		if int(city["x"]) < DUSK - 50:
			_on_world(c, int(city["x"]), int(city["y"]), 1, 1, Color(1.0, 0.80, 0.42, 0.9))
			if int(city["x"]) % 3 == 0:
				_on_world(c, int(city["x"]) + 1, int(city["y"]), 2, 1, Color(1.0, 0.80, 0.42, 0.5))
	# The sun, just over the edge.
	var sy := _limb(SUNRISE) - 1
	_round(c, SUNRISE, sy, 26, faded(SUN, 0.035))
	_round(c, SUNRISE, sy, 17, faded(SUN, 0.06))
	_round(c, SUNRISE, sy, 9, faded(SUN, 0.12))
	_out_there(c, SUNRISE - 46, sy, 92, 1, faded(SUN, 0.35))
	_out_there(c, SUNRISE - 24, sy - 1, 48, 3, faded(SUN, 0.22))
	_round(c, SUNRISE, sy, 3, Color.WHITE)

## The station's own, outside: the arm with its panels and its dish, and the
## end of another module in at the right.
func _paint_near(c: CanvasItem) -> void:
	var from := GLASS_LEFT - SLIDE
	# The arm: two rails and the bracing between them.
	_out_there(c, from, ARM - 3, ARM_END - from, 1, TRUSS)
	_out_there(c, from, ARM + 3, ARM_END - from, 1, TRUSS.darkened(0.25))
	for x in range(from, ARM_END - 6, 7):
		line(c, x, ARM + 3, x + 6, ARM - 3, TRUSS.darkened(0.15))
		_out_there(c, x, ARM - 3, 1, 7, TRUSS.darkened(0.3))
	_out_there(c, ARM_END - 3, ARM - 5, 4, 11, TRUSS.lightened(0.15))
	# The panels, hung under it in their frames.
	for px in [40, 74, 108]:
		_out_there(c, px + 13, ARM + 4, 2, 6, TRUSS.darkened(0.2))
		_out_there(c, px - 1, ARM + 9, 30, 44, FOIL.darkened(0.25))
		_out_there(c, px, ARM + 10, 28, 42, CELLS)
		for gx in range(px + 7, px + 28, 7):
			_out_there(c, gx, ARM + 10, 1, 42, CELLS.lightened(0.16))
		for gy in range(ARM + 20, ARM + 52, 10):
			_out_there(c, px, gy, 28, 1, CELLS.lightened(0.16))
		for k in 9:
			_out_there(c, px + 2 + k * 2, ARM + 12 + k * 3, 7, 3, Color(0.55, 0.75, 1.0, 0.10))
	# The dish, on top.
	_out_there(c, 66, ARM - 12, 1, 9, TRUSS)
	for k in 7:
		@warning_ignore("integer_division")
		_out_there(c, 59 + k, ARM - 20 + absi(k - 3) * 2 / 3 + k, 14 - k * 2, 1, TRUSS.lightened(0.2 - 0.05 * k))
	_out_there(c, 66, ARM - 24, 1, 5, TRUSS.lightened(0.2))
	# The module: a drum of hull with its ports lit, and the band round it.
	var mx := GLASS_RIGHT - 44
	for dy in range(-12, 13):
		var half := int(floor(sqrt(float(144 - dy * dy) + 0.5)))
		@warning_ignore("integer_division")
		_out_there(c, mx - half / 2, 96 + dy, GLASS_RIGHT + SLIDE - mx + half / 2, 1,
			HULL.lerp(HULL_DARK, clampf((float(dy) + 4.0) / 16.0, 0.0, 0.8)))
	_out_there(c, mx + 4, 84, GLASS_RIGHT + SLIDE - mx - 4, 1, HULL_LIT)
	_out_there(c, mx + 12, 85, 3, 23, ACCENT.darkened(0.15))
	for port in [mx + 22, mx + 32, mx + 42]:
		_out_there(c, port, 92, 4, 4, Color(1.0, 0.84, 0.50))
	_out_there(c, mx + 6, 70, 1, 14, TRUSS)
	_out_there(c, mx + 4, 74, 5, 1, TRUSS)

## What moves outside: a star going in and out, the weather going round, the
## sun's flare, the lights on the arm, whoever is out there on a line, and a
## shuttle going by.
func _paint_traffic(c: CanvasItem) -> void:
	var far := _off(_stars_layer)
	var below := _off(_globe)
	var near := _off(_near)
	for s in _twinkles:
		if fmod(_t + float(s["from"]), float(s["every"])) < float(s["every"]) * 0.5:
			_out_there(c, int(s["x"]) + far, int(s["y"]), 1, 1, Color.WHITE)
	var span := GLASS_RIGHT - GLASS_LEFT + 2 * SLIDE
	for front in _fronts:
		var w: int = front["w"]
		var x := GLASS_LEFT - SLIDE - w + int(fmod(float(front["x"]) + _t * float(front["speed"]), float(span + w)))
		_on_world(c, x + below, int(front["y"]), w, 1, faded(CLOUD, 0.55))
		_on_world(c, x + 4 + below, int(front["y"]) + 1, w - 9, 1, faded(CLOUD, 0.4))
	var sy := _limb(SUNRISE) - 1
	var flare := 0.5 + 0.5 * sin(_t * 0.9)
	_out_there(c, SUNRISE + below - 30 - int(flare * 22.0), sy, 60 + int(flare * 44.0), 1, faded(SUN, 0.20 + 0.15 * flare))
	_out_there(c, SUNRISE + below, sy - 6 - int(flare * 4.0), 1, 13 + int(flare * 8.0), faded(SUN, 0.35))
	# The lights on the arm and on the module.
	if fmod(_t, 1.6) < 0.2:
		_out_there(c, ARM_END - 2 + near, ARM - 7, 2, 2, SHUT)
		_out_there(c, ARM_END - 3 + near, ARM - 8, 4, 4, faded(SHUT, 0.3))
	if fmod(_t + 0.8, 1.6) < 0.2:
		_out_there(c, GLASS_RIGHT - 38 + near, 69, 2, 2, OPEN)
	# Somebody out on a line, with the work light on.
	var drift := sin(_t * 0.5)
	var ax := ARM_END + 16 + near + int(round(drift * 3.0))
	var ay := ARM - 22 + int(round(cos(_t * 0.37) * 2.0))
	line(c, ARM_END - 1 + near, ARM - 4, ax + 2, ay + 8, Color(0.75, 0.78, 0.84, 0.7))
	stamp(c, ax, ay, [
		".###.",
		"#####",
		"#####",
		".###.",
		"#####",
		"#####",
		".#.#.",
		".#.#.",
	], Color(0.90, 0.92, 0.95))
	box(c, ax + 1, ay + 1, 3, 2, FOIL)
	box(c, ax - 1, ay + 4, 1, 3, Color(0.70, 0.73, 0.78))
	box(c, ax + 5, ay + 4, 1, 3, Color(0.70, 0.73, 0.78))
	if fmod(_t, 2.4) < 1.2:
		box(c, ax + 2, ay + 4, 1, 1, SHUT)
	# The shuttle, every so often, on its way round.
	var into := fmod(_t, 27.0)
	if into < 9.0:
		var along := into / 9.0
		var hx := GLASS_LEFT - SLIDE - 24 + int(along * float(span + 48))
		var hy := 126 - int(along * 26.0)
		var burn := flicker(_t, 5)
		_out_there(c, hx - 5 - int(burn * 5.0), hy + 2, 5 + int(burn * 5.0), 1, faded(HOLO, 0.75))
		_out_there(c, hx - 2, hy + 1, 2, 3, Color.WHITE)
		_out_there(c, hx + 4, hy, 8, 1, HULL_LIT)
		_out_there(c, hx, hy + 1, 16, 3, HULL_LIT)
		_out_there(c, hx + 16, hy + 2, 2, 1, HULL_LIT)
		_out_there(c, hx + 2, hy + 4, 11, 1, HULL_SHADE)
		_out_there(c, hx + 12, hy + 1, 3, 1, Color(0.10, 0.20, 0.40))
		_out_there(c, hx + 4, hy + 2, 5, 1, ACCENT)

## --- the deck -----------------------------------------------------------------

func _paint_wall(c: CanvasItem) -> void:
	_paint_glazing(c)
	_paint_ceiling(c)
	_paint_bay(c)
	_paint_under_sill(c)
	_paint_floor(c)

## What stands against the wall.
func _paint_fittings(c: CanvasItem) -> void:
	_paint_crates(c)
	_paint_cabinet(c, _at["weapons"])
	_paint_booth(c, _at["shop"])
	_paint_gate(c, _at["gate"])

## What holds the window: the beam over it, the ribs between the panes, each
## leaning the other way from the last, the pillars at either end, and the
## glass itself, which shows as the light sliding across it.
func _paint_glazing(c: CanvasItem) -> void:
	var sheen := Color(0.80, 0.90, 1.0, 0.03)
	for pane in [GLASS_LEFT + 30, GLASS_LEFT + 150, GLASS_LEFT + 236, GLASS_LEFT + 330]:
		for k in 40:
			box(c, pane + 56 - k * 2, GLASS_TOP + k * 4, 9, 4, sheen)
			box(c, pane + 70 - k * 2, GLASS_TOP + k * 4, 3, 4, sheen)
	var tall := SILL - GLASS_TOP
	for i in RIBS.size():
		var lean := LEAN if i % 2 == 0 else -LEAN
		var row := GLASS_TOP
		while row < SILL:
			@warning_ignore("integer_division")
			var x: int = int(RIBS[i]) + lean - (2 * lean * (row - GLASS_TOP)) / tall
			var run := 1
			@warning_ignore("integer_division")
			while row + run < SILL and int(RIBS[i]) + lean - (2 * lean * (row + run - GLASS_TOP)) / tall == x:
				run += 1
			box(c, x, row, 4, run, HULL)
			box(c, x, row, 1, run, HULL_LIT)
			box(c, x + 3, row, 1, run, HULL_SHADE)
			row += run
	# The panes' corners, rounded off.
	for corner in [GLASS_LEFT, GLASS_RIGHT]:
		for k in 4:
			var w := 4 - k
			box(c, corner if corner == GLASS_LEFT else corner - w, GLASS_TOP + k, w, 1, HULL)
			box(c, corner if corner == GLASS_LEFT else corner - w, SILL - 1 - k, w, 1, HULL)
	_pillar(c, LEFT, GLASS_LEFT - LEFT)
	_pillar(c, GLASS_RIGHT, BAY_LEFT - GLASS_RIGHT)

## A pillar, floor to ceiling: hull, with a band of orange round it and a
## grille low down.
func _pillar(c: CanvasItem, x: int, w: int) -> void:
	box(c, x, GLASS_TOP - 8, w, FLOOR - GLASS_TOP + 8, HULL)
	box(c, x, GLASS_TOP - 8, 1, FLOOR - GLASS_TOP + 8, HULL_LIT)
	box(c, x + w - 1, GLASS_TOP - 8, 1, FLOOR - GLASS_TOP + 8, HULL_SHADE)
	box(c, x + 1, 120, w - 2, 5, ACCENT)
	box(c, x + 1, 125, w - 2, 1, ACCENT.darkened(0.3))
	for y in [96, 150, 262]:
		box(c, x + 1, y, w - 2, 1, HULL_SHADE)
	for k in 4:
		box(c, x + 3, 276 + k * 4, w - 6, 2, HULL_DARK)

## Overhead: hull in panels, a tray of cable, and the housings of the light.
## The light itself is `_paint_wall_life`'s.
func _paint_ceiling(c: CanvasItem) -> void:
	box(c, LEFT, TOP, RIGHT - LEFT, GLASS_TOP - 8 - TOP, HULL_SHADE)
	box(c, LEFT, TOP, RIGHT - LEFT, 6, HULL_DARK)
	for x in range(LEFT + 20, RIGHT - 5, 9):
		box(c, x, TOP + 1, 5, 1, HULL_SHADE.darkened(0.25))
		@warning_ignore("integer_division")
		box(c, x, TOP + 3, 5, 1, ACCENT.darkened(0.45) if (x / 9) % 4 == 0 else HULL_SHADE.darkened(0.25))
	for x in range(LEFT + 50, RIGHT, 76):
		box(c, x, TOP + 6, 1, GLASS_TOP - 14 - TOP, HULL_DARK)
		box(c, x + 1, TOP + 6, 1, GLASS_TOP - 14 - TOP, HULL)
	for x in STRIPS:
		box(c, x - 24, 30, 48, 8, HULL_DARK)
		box(c, x - 25, 29, 50, 1, HULL)
	# The beam over the window, all the way across, with its row of tell-tales.
	box(c, LEFT, GLASS_TOP - 8, RIGHT - LEFT, 8, HULL)
	box(c, LEFT, GLASS_TOP - 8, RIGHT - LEFT, 1, HULL_LIT)
	box(c, LEFT, GLASS_TOP - 1, RIGHT - LEFT, 1, HULL_SHADE)
	box(c, LEFT, GLASS_TOP - 5, RIGHT - LEFT, 2, HULL_DARK)

## The wall under the sill, which the stations stand against: lockers and
## panels, a grille, a red cross on a white door, and along its foot the
## trough the deck's green grows in.
func _paint_under_sill(c: CanvasItem) -> void:
	box(c, LEFT, UNDERSILL, BAY_LEFT - LEFT, FLOOR - UNDERSILL, HULL)
	for x in range(LEFT + 14, BAY_LEFT - 8, 44):
		box(c, x, UNDERSILL + 4, 1, FLOOR - UNDERSILL - 14, HULL_SHADE)
		box(c, x + 1, UNDERSILL + 4, 1, FLOOR - UNDERSILL - 14, HULL_LIT)
	box(c, LEFT, 274, BAY_LEFT - LEFT, 1, HULL_SHADE)
	box(c, LEFT, 275, BAY_LEFT - LEFT, 1, HULL_LIT)
	box(c, LEFT, UNDERSILL + 6, BAY_LEFT - LEFT, 3, ACCENT.darkened(0.12))
	for x in range(LEFT + 30, BAY_LEFT - 20, 88):
		box(c, x, UNDERSILL + 6, 14, 3, HULL_LIT)
	# Handles, down the lockers.
	for x in range(LEFT + 14, BAY_LEFT - 8, 44):
		box(c, x + 36, 250, 2, 8, HULL_DARK)
		box(c, x + 36, 250, 1, 8, HULL_SHADE)
	# A grille.
	box(c, 254, 250, 20, 14, HULL_SHADE)
	for k in 4:
		box(c, 256, 252 + k * 3, 16, 2, HULL_DARK)
	# Where the plasters are kept.
	box(c, 36, 244, 16, 16, HULL_LIT)
	box(c, 42, 246, 4, 12, SHUT.darkened(0.1))
	box(c, 38, 250, 12, 4, SHUT.darkened(0.1))
	# And something to put a fire out with.
	box(c, 60, 246, 6, 16, SHUT.darkened(0.2))
	box(c, 60, 246, 2, 16, SHUT)
	box(c, 61, 243, 4, 3, HULL_DARK)
	box(c, 65, 244, 3, 1, HULL_DARK)
	# The sill itself: deep, with a rail let into the front of it. The
	# tell-tales along that are `_paint_wall_life`'s.
	box(c, LEFT, SILL, RIGHT - LEFT, UNDERSILL - SILL, HULL)
	box(c, LEFT, SILL, RIGHT - LEFT, 1, HULL_LIT)
	box(c, LEFT, SILL + 4, RIGHT - LEFT, 3, HULL_DARK)
	box(c, LEFT, UNDERSILL - 1, RIGHT - LEFT, 1, HULL_SHADE)
	box(c, LEFT, UNDERSILL, RIGHT - LEFT, 2, HULL_SHADE.darkened(0.25))
	# The trough.
	box(c, LEFT, FLOOR - 7, BAY_LEFT - LEFT, 7, HULL_LIT.darkened(0.12))
	box(c, LEFT, FLOOR - 7, BAY_LEFT - LEFT, 1, HULL_LIT)
	box(c, LEFT, FLOOR - 1, BAY_LEFT - LEFT, 1, HULL_SHADE)
	for x in range(LEFT + 40, BAY_LEFT - 8, 44):
		box(c, x, FLOOR - 6, 1, 5, HULL_SHADE)
	for x in range(LEFT + 3, BAY_LEFT - 3, 5):
		if _hash(x, 9) % 3 == 0:
			box(c, x, FLOOR - 9 - _hash(x, 10) % 2, 1, 2 + _hash(x, 10) % 2, LEAF)
			box(c, x + 1, FLOOR - 9, 1, 1, LEAF.lightened(0.2))

## The gate's bay: hull, a number, a band of warning along the top, the chart
## that shows where the gate goes, a port of its own to look out of, and where
## the suits are kept.
func _paint_bay(c: CanvasItem) -> void:
	box(c, BAY_LEFT, GLASS_TOP, RIGHT - BAY_LEFT, FLOOR - GLASS_TOP, HULL)
	for y in [124, 268]:
		box(c, BAY_LEFT, y, RIGHT - BAY_LEFT, 1, HULL_SHADE)
		box(c, BAY_LEFT, y + 1, RIGHT - BAY_LEFT, 1, HULL_LIT)
	for x in [490, 536, 616]:
		box(c, x, GLASS_TOP + 12, 1, SILL - GLASS_TOP - 12, HULL_SHADE)
	# Warning, in the colours it comes in up here.
	for y in 6:
		box(c, BAY_LEFT, GLASS_TOP + 3 + y, RIGHT - BAY_LEFT, 1, HULL_LIT)
		for x in range(BAY_LEFT - 8 + y, RIGHT, 8):
			var from := maxi(x, BAY_LEFT)
			box(c, from, GLASS_TOP + 3 + y, mini(x + 4, RIGHT) - from, 1, ACCENT)
	# Which bay this is.
	stamp(c, 560, 72, [
		".######...######.",
		"##....##.##....##",
		"##....##.......##",
		"##....##......##.",
		"##....##.....##..",
		"##....##....##...",
		"##....##...##....",
		"##....##..##.....",
		"##....##.##......",
		".######..########",
	], HULL_SHADE)
	# The chart's housing. What is on it is `_paint_wall_life`'s.
	var g: Vector2i = _at["gate"]
	var bx := g.x - CHART
	box(c, bx - 2, 88, 70, 58, HULL_SHADE)
	box(c, bx - 1, 89, 68, 56, HULL_LIT)
	box(c, bx + 1, 91, 64, 52, Color(0.015, 0.035, 0.07))
	box(c, bx + 6, 146, 54, 4, HULL_SHADE)
	for k in 6:
		box(c, bx + 9 + k * 8, 147, 5, 2, HULL_DARK if k != 2 else ACCENT)
	# The port: a round of glass, with what is out there in it.
	var px := g.x + 20
	disc(c, px, 152, 15, HULL_SHADE)
	disc(c, px, 152, 14, HULL_LIT)
	disc(c, px, 152, 11, SPACE)
	for star in [[-6, -4], [3, -7], [7, 1], [-2, 2], [-8, 3], [5, -2]]:
		box(c, px + int(star[0]), 152 + int(star[1]), 1, 1, Color(1, 1, 1, 0.8))
	for dy in range(4, 12):
		var half := int(floor(sqrt(float(121 - dy * dy) + 0.5)))
		box(c, px - half, 152 + dy, half * 2 + 1, 1, OCEAN if dy > 5 else AIR.lightened(0.2))
	box(c, px - 5, 160, 6, 1, faded(CLOUD, 0.8))
	box(c, px + 2, 162, 5, 1, faded(CLOUD, 0.6))
	for k in 6:
		var a := TAU * k / 6.0
		box(c, px + int(round(cos(a) * 13.0)), 152 + int(round(sin(a) * 13.0)), 1, 1, HULL_DARK)
	# The suits: a locker each, with a window to see which is in.
	for sx in [450, 470]:
		box(c, sx, UNDERSILL + 6, 18, FLOOR - UNDERSILL - 6, HULL_LIT.darkened(0.08))
		box(c, sx, UNDERSILL + 6, 18, 1, HULL_LIT)
		box(c, sx + 17, UNDERSILL + 6, 1, FLOOR - UNDERSILL - 6, HULL_SHADE)
		box(c, sx + 3, UNDERSILL + 12, 12, 16, HULL_DARK)
		disc(c, sx + 9, UNDERSILL + 20, 5, Color(0.90, 0.92, 0.95))
		box(c, sx + 6, UNDERSILL + 18, 7, 4, FOIL if sx == 450 else Color(0.10, 0.14, 0.24))
		box(c, sx + 3, UNDERSILL + 34, 12, 2, ACCENT.darkened(0.1))
		box(c, sx + 14, UNDERSILL + 48, 2, 8, HULL_DARK)
	box(c, 604, UNDERSILL + 10, 14, 30, HULL_SHADE)
	for k in 6:
		box(c, 606, UNDERSILL + 13 + k * 4, 10, 2, HULL_DARK)

## The deck: plate, with a strip of light along its edge, the warning painted
## in front of the gate, and what it holds of the lights over it.
func _paint_floor(c: CanvasItem) -> void:
	box(c, LEFT, FLOOR, RIGHT - LEFT, UNDER - FLOOR, DECK)
	box(c, LEFT, FLOOR, RIGHT - LEFT, 1, HULL_LIT)
	box(c, LEFT, FLOOR + 1, RIGHT - LEFT, 1, HOLO.darkened(0.25))
	box(c, LEFT, FLOOR + 2, RIGHT - LEFT, 1, DECK.lightened(0.10))
	for x in range(LEFT + 26, RIGHT, 52):
		box(c, x, FLOOR + 3, 1, 13, DECK.darkened(0.35))
		box(c, x + 3, FLOOR + 6, 2, 1, DECK.lightened(0.14))
		box(c, x - 4, FLOOR + 6, 2, 1, DECK.lightened(0.14))
	var g: Vector2i = _at["gate"]
	for k in 11:
		box(c, g.x - 44 + k * 8, FLOOR + 4, 4, 3, ACCENT.darkened(0.15))
		box(c, g.x - 43 + k * 8, FLOOR + 7, 4, 3, ACCENT.darkened(0.15))
	wet(c, int(_at["weapons"].x) - 24, 48, HOLO, 0.10)
	wet(c, int(_at["shop"].x) - 30, 60, ACCENT, 0.10)
	for x in STRIPS:
		wet(c, x - 24, 48, LIGHT, 0.05)

## --- what stands against the wall --------------------------------------------

## What came up on the last shuttle and has not been put away.
func _paint_crates(c: CanvasItem) -> void:
	for crate in [[196, 22, 20, 0], [220, 16, 14, 1], [200, 14, 12, 2]]:
		var x: int = crate[0]
		var w: int = crate[1]
		var h: int = crate[2]
		var y: int = FLOOR - h - (20 if int(crate[3]) == 2 else 0)
		var body: Color = ACCENT.darkened(0.12) if int(crate[3]) != 1 else HULL_LIT.darkened(0.1)
		box(c, x, y, w, h, body)
		box(c, x, y, w, 1, body.lightened(0.2))
		box(c, x + w - 1, y, 1, h, body.darkened(0.3))
		@warning_ignore("integer_division")
		box(c, x + 2, y + h / 2 - 1, w - 4, 2, HULL_LIT if int(crate[3]) != 1 else ACCENT)
		box(c, x + 2, y + 2, 3, 2, HULL_DARK)

## The cabinet: arms behind glass, on their clips, with the light over them
## and the lock beside; and the plinth a graph is thrown up from. What is lit,
## and the graph, are `_paint_life`'s.
func _paint_cabinet(c: CanvasItem, at: Vector2i) -> void:
	var x := at.x - 27
	var y := at.y - 58
	box(c, x - 1, y - 1, 56, 59, HULL_SHADE)
	box(c, x, y, 54, 58, HULL_LIT)
	box(c, x, y, 54, 1, Color.WHITE)
	box(c, x + 53, y, 1, 58, HULL)
	box(c, x + 3, y + 5, 48, 40, Color(0.03, 0.06, 0.11))
	for py in range(y + 9, y + 44, 5):
		box(c, x + 4, py, 46, 1, Color(0.06, 0.10, 0.17))
	# A sword.
	box(c, x + 10, y + 9, 2, 22, STEEL)
	box(c, x + 10, y + 9, 1, 22, STEEL_LIT)
	box(c, x + 7, y + 31, 8, 1, HOLO.darkened(0.3))
	box(c, x + 10, y + 32, 2, 7, HULL_DARK)
	# An axe.
	box(c, x + 22, y + 9, 1, 31, HULL_SHADE)
	stamp(c, x + 18, y + 10, [".###.", "#####", "#####", "##.##", "#...#"], STEEL)
	# A staff, with whatever that is in the end of it.
	box(c, x + 33, y + 13, 1, 27, Color(0.54, 0.46, 0.66))
	# And the rock, which is free, on a shelf of its own.
	box(c, x + 39, y + 31, 11, 1, HULL_LIT)
	stamp(c, x + 41, y + 26, ["..###..", ".#####.", "#######", "#######", ".#####."], Color(0.48, 0.50, 0.56))
	box(c, x + 43, y + 27, 2, 1, Color(0.66, 0.68, 0.74))
	# The clips they hang in.
	for clip in [[x + 9, y + 20], [x + 21, y + 24], [x + 32, y + 26]]:
		box(c, clip[0], clip[1], 4, 1, HULL_SHADE)
	# Under the glass: the drawer, and the band.
	box(c, x + 2, y + 47, 50, 9, HULL)
	box(c, x + 2, y + 47, 50, 1, HULL_SHADE)
	box(c, x + 20, y + 51, 14, 1, HULL_DARK)
	box(c, x + 2, y + 54, 50, 2, ACCENT)
	# The lock.
	box(c, x + 56, y + 16, 7, 12, HULL_SHADE)
	box(c, x + 57, y + 17, 5, 5, Color(0.03, 0.06, 0.11))
	for k in 4:
		@warning_ignore("integer_division")
		box(c, x + 57 + (k % 2) * 3, y + 23 + (k / 2) * 2, 2, 1, HULL_LIT)
	# The plinth.
	var px := at.x + 44
	box(c, px - 7, at.y - 6, 14, 6, HULL_SHADE)
	box(c, px - 7, at.y - 6, 14, 1, HULL_LIT)
	box(c, px - 5, at.y - 8, 10, 2, HULL_DARK)

## The booth: a counter under a hood, shelves of what there is to buy behind
## it, and the printer that makes the rest. Whoever keeps it, and what the
## printer is doing, are `_paint_life`'s.
func _paint_booth(c: CanvasItem, at: Vector2i) -> void:
	var x := at.x - 32
	var y := at.y
	# The back of it, with the shelves.
	box(c, x + 2, y - 58, 60, 40, HULL_SHADE)
	box(c, x + 4, y - 56, 56, 36, Color(0.04, 0.07, 0.12))
	var goods := [HOLO, ACCENT, Color(0.36, 0.86, 0.50), Color(0.90, 0.36, 0.50), LIGHT]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5407
	for shelf in 3:
		var sy := y - 46 + shelf * 12
		box(c, x + 4, sy, 56, 1, HULL)
		var gx := x + 6
		while gx < x + 56:
			var gw := rng.randi_range(3, 4)
			var gh := rng.randi_range(4, 7)
			# Not where the keeper hangs.
			if not (shelf > 0 and gx > x + 20 and gx < x + 42):
				var tone: Color = goods[rng.randi() % goods.size()]
				box(c, gx, sy - gh, gw, gh, HULL_LIT.darkened(0.1))
				box(c, gx, sy - gh + 1, gw, 2, tone.darkened(0.1))
				box(c, gx, sy - gh, gw, 1, HULL_DARK)
			gx += gw + rng.randi_range(1, 3)
	# The hood: a curve of hull, with its band.
	for k in 5:
		box(c, x - 4 + (4 - k), y - 68 + k, 72 - (4 - k) * 2, 1, HULL_LIT)
	box(c, x - 4, y - 63, 72, 4, HULL_LIT)
	box(c, x - 4, y - 61, 72, 2, ACCENT)
	box(c, x - 4, y - 59, 72, 1, HULL_SHADE)
	box(c, x - 3, y - 58, 3, 38, HULL)
	box(c, x + 64, y - 58, 3, 38, HULL)
	# The counter.
	box(c, x - 4, y - 21, 72, 3, HULL_LIT)
	box(c, x - 4, y - 21, 72, 1, Color.WHITE)
	box(c, x - 2, y - 18, 68, 18, HULL)
	box(c, x - 2, y - 18, 68, 1, HULL_SHADE)
	for gx in [x + 14, x + 32, x + 50]:
		box(c, gx, y - 16, 1, 14, HULL_SHADE)
	box(c, x + 2, y - 9, 60, 3, ACCENT)
	box(c, x + 18, y - 9, 28, 3, HULL_LIT)
	# The till, on the end of it.
	box(c, x + 52, y - 28, 10, 7, HULL_SHADE)
	box(c, x + 53, y - 27, 8, 5, Color(0.03, 0.06, 0.11))
	# The printer.
	var mx := x + 74
	box(c, mx - 1, y - 45, 24, 45, HULL_SHADE)
	box(c, mx, y - 44, 22, 44, HULL_LIT.darkened(0.06))
	box(c, mx, y - 44, 22, 1, Color.WHITE)
	box(c, mx + 2, y - 38, 18, 20, Color(0.03, 0.06, 0.11))
	box(c, mx + 2, y - 20, 18, 2, HULL_SHADE)
	box(c, mx + 2, y - 41, 18, 2, ACCENT)
	for k in 3:
		box(c, mx + 4 + k * 5, y - 12, 4, 6, HULL_DARK)
	box(c, mx + 5, y - 19, 12, 1, HULL_DARK)

## The gate: an iris in a ring of hull, in its collar, with a post either side
## carrying the gate's sign. Whether its leaves are shut, and its lamps, are
## `_paint_life`'s.
func _paint_gate(c: CanvasItem, g: Vector2i) -> void:
	var cy := g.y - TALLEST + 30
	for side: int in [-1, 1]:
		var px := g.x + side * 40 - 2
		box(c, px, g.y - 84, 4, 84, HULL)
		box(c, px, g.y - 84, 1, 84, HULL_LIT)
		box(c, px + 3, g.y - 84, 1, 84, HULL_SHADE)
		for k in 5:
			box(c, px, g.y - 22 + k * 4, 4, 2, ACCENT)
	disc(c, g.x, cy, 31, HULL_DARK)
	disc(c, g.x, cy, 30, HULL)
	disc(c, g.x, cy, 30, HULL_LIT, 28)
	disc(c, g.x, cy, 25, HULL_SHADE)
	disc(c, g.x, cy, 23, HULL_DARK)
	disc(c, g.x, cy, 22, Color(0.02, 0.03, 0.055))
	for k in 8:
		var a := TAU * k / 8.0 + 0.39
		box(c, g.x + int(round(cos(a) * 26.5)) - 1, cy + int(round(sin(a) * 26.5)) - 1, 3, 3, HULL_DARK)
	# The step up into it.
	box(c, g.x - 28, g.y - 4, 56, 4, HULL)
	box(c, g.x - 28, g.y - 4, 56, 1, HULL_LIT)
	box(c, g.x - 20, g.y - 2, 40, 1, ACCENT)

## --- what moves, and what is lit --------------------------------------------

## The wall's own lights, behind whatever stands against it: the strips
## overhead, the tell-tales along the beam and the sill, and the chart.
func _paint_wall_life(c: CanvasItem) -> void:
	for i in STRIPS.size():
		var x: int = STRIPS[i]
		var on := 0.92 + 0.08 * sin(_t * 0.9 + i)
		box(c, x - 22, 32, 44, 4, faded(LIGHT, on))
		halo(c, x - 22, 32, 44, 4, LIGHT, 4, 0.05 * on)
		# What it throws down the wall, and no further than the wall goes.
		for k in 8:
			var from := maxi(x - 24 - k * 3, LEFT)
			box(c, from, 38 + k * 9, mini(x + 24 + k * 3, RIGHT) - from, 9, faded(LIGHT, 0.028 * on * (1.0 - k / 8.0)))
	# A light running along the beam, and the sill's keeping time with it.
	var run := int(_t * 22.0)
	for k in 30:
		var bx := LEFT + 6 + k * 20
		@warning_ignore("integer_division")
		var lit := posmod(k - run / 4, 30) < 3
		box(c, bx, GLASS_TOP - 5, 3, 2, HOLO if lit else HOLO.darkened(0.72))
	for k in 30:
		var sx := LEFT + 10 + k * 20
		@warning_ignore("integer_division")
		box(c, sx, SILL + 5, 2, 1, ACCENT if posmod(k + run / 9, 6) == 0 else ACCENT.darkened(0.65))
	_life_chart(c, _at["gate"])

## The chart over the gate: the deck it opens onto, in lines of light, with a
## sweep going over it and the way through being followed.
func _life_chart(c: CanvasItem, g: Vector2i) -> void:
	var open := _gate_open()
	var left := g.x - CHART + 1
	var x := left + 5
	var y := 96
	var lines := HOLO if open else SHUT
	for r: Vector2i in ROOMS:
		for step in [Vector2i(1, 0), Vector2i(0, 1)]:
			if ROOMS.has(r + step):
				if step.x == 1:
					box(c, x + r.x * 8 + 6, y + r.y * 7 + 2, 2, 1, faded(lines, 0.5))
				else:
					box(c, x + r.x * 8 + 2, y + r.y * 7 + 5, 2, 2, faded(lines, 0.5))
	for r: Vector2i in ROOMS:
		var rx := x + r.x * 8
		var ry := y + r.y * 7
		box(c, rx, ry, 6, 1, faded(lines, 0.7))
		box(c, rx, ry + 4, 6, 1, faded(lines, 0.7))
		box(c, rx, ry + 1, 1, 3, faded(lines, 0.7))
		box(c, rx + 5, ry + 1, 1, 3, faded(lines, 0.7))
	box(c, x + 1, y + 15, 4, 3, OPEN.darkened(0.2))
	box(c, x + 49, y + 1, 4, 3, SHUT.darkened(0.1))
	box(c, x + 17, y + 29, 4, 3, ACCENT)
	if open:
		var here: Vector2i = ROOMS[int(_t * 1.6) % 14]
		box(c, x + here.x * 8 + 1, y + here.y * 7 + 1, 4, 3, Color.WHITE)
		halo(c, x + here.x * 8, y + here.y * 7, 6, 5, HOLO, 2, 0.12)
	# The sweep.
	var sweep := int(fmod(_t * 26.0, 64.0))
	box(c, left + sweep, 91, 1, 52, faded(lines, 0.35))
	box(c, left + maxi(sweep - 3, 0), 91, mini(3, sweep), 52, faded(lines, 0.08))
	# And what it has to say for itself, under.
	for k in 4:
		var w := 6 + (k * 7 + int(_t * 0.7)) % 9
		box(c, left + 3 + k * 15, 138, w, 2, faded(lines, 0.6))
	halo(c, left, 91, 64, 52, lines, 3, 0.02)

func _paint_life(c: CanvasItem) -> void:
	_life_cabinet(c, _at["weapons"], float(_lit["weapons"]))
	_life_booth(c, _at["shop"], float(_lit["shop"]))
	_life_gate(c, _at["gate"], float(_lit["gate"]))

func _life_cabinet(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var x := at.x - 27
	var y := at.y - 58
	# The light over the arms, brighter for somebody standing at it.
	var on := 0.55 + 0.45 * lit
	box(c, x + 3, y + 5, 48, 1, faded(LIGHT, on))
	for k in 4:
		box(c, x + 3, y + 6 + k * 3, 48, 3, faded(HOLO, 0.06 * on * (1.0 - k / 4.0)))
	# The end of the staff.
	var pulse := 0.6 + 0.4 * sin(_t * 2.3)
	halo(c, x + 32, y + 10, 3, 3, HOLO, 3, 0.10 * pulse)
	box(c, x + 32, y + 10, 3, 3, HOLO.lerp(Color.WHITE, 0.5 * pulse))
	# The lock: shut, till somebody is standing here.
	box(c, x + 58, y + 18, 3, 3, OPEN if lit > 0.5 else ACCENT)
	# The graph, thrown up over the plinth, and turning.
	var px := at.x + 44
	var top := at.y - 44
	for k in 9:
		@warning_ignore("integer_division")
		box(c, px - 5 - k / 2, at.y - 9 - k * 3, 10 + k, 3, faded(HOLO, 0.035 * (1.0 - k / 11.0) * (0.7 + 0.3 * lit)))
	var nodes: Array = []
	for i in 4:
		var a := _t * 0.9 + TAU * i / 4.0
		nodes.append(Vector2i(px + int(round(cos(a) * 9.0)), top + 10 + int(round(sin(a) * 3.0)) + (i % 2) * 7 - 4))
	for link in [[0, 1], [1, 2], [2, 3], [3, 0]]:
		var a: Vector2i = nodes[link[0]]
		var b: Vector2i = nodes[link[1]]
		for k in 4:
			var p := Vector2(a).lerp(Vector2(b), (k + 0.5) / 4.0)
			box(c, int(round(p.x)), int(round(p.y)), 1, 1, faded(HOLO, 0.45))
	var hop := int(_t * 2.0) % 4
	for i in nodes.size():
		var n: Vector2i = nodes[i]
		box(c, n.x - 1, n.y - 1, 3, 3, ACCENT if i == hop else HOLO)
	box(c, px - 4, at.y - 9, 8, 1, HOLO)
	# The frame, lit when it would answer.
	if lit > 0.0:
		var edge := faded(HOLO, lit)
		box(c, x - 1, y - 1, 56, 1, edge)
		box(c, x - 1, y, 1, 58, edge)
		box(c, x + 54, y, 1, 58, edge)

func _life_booth(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var x := at.x - 32
	var y := at.y
	var eyes := clampi(int((_player_x(float(at.x)) - float(at.x)) / 60.0), -2, 2)
	# Whoever keeps the booth: a ball of hull with one eye, hanging in the air.
	var hy := y - 37 + int(round(sin(_t * 1.8) * 1.5))
	disc(c, at.x, hy, 7, HULL_SHADE)
	disc(c, at.x, hy, 6, HULL_LIT)
	box(c, at.x - 6, hy + 2, 13, 1, ACCENT)
	box(c, at.x, hy - 11, 1, 5, HULL_LIT)
	if fmod(_t, 2.0) < 1.0:
		box(c, at.x, hy - 12, 1, 1, SHUT)
	disc(c, at.x + eyes, hy - 1, 3, Color(0.02, 0.05, 0.09))
	if fmod(_t, 4.3) > 4.15:
		box(c, at.x + eyes - 2, hy - 1, 5, 1, HOLO)
	else:
		disc(c, at.x + eyes, hy - 1, 2, HOLO)
		box(c, at.x + eyes, hy - 2, 1, 1, Color.WHITE)
	# What holds it up.
	var thrust := 0.5 + 0.5 * sin(_t * 9.0)
	box(c, at.x - 2, hy + 8, 5, 1, faded(HOLO, 0.5 + 0.3 * thrust))
	box(c, at.x - 1, hy + 9, 3, 2 + int(thrust * 2.0), faded(HOLO, 0.25))
	# The light under the hood, the one under the counter's lip, and the till.
	var on := 0.6 + 0.4 * lit
	box(c, x - 2, y - 58, 68, 1, faded(LIGHT, 0.7 * on))
	for k in 3:
		box(c, x - 2, y - 57 + k * 3, 68, 3, faded(LIGHT, 0.045 * on * (1.0 - k / 3.0)))
	box(c, x + 54, y - 26, 6, 1, HOLO if int(_t * 3.0) % 2 == 0 else HOLO.darkened(0.4))
	box(c, x + 54, y - 24, 4, 1, faded(HOLO, 0.6))
	if lit > 0.0:
		box(c, x - 4, y - 22, 72, 1, faded(HOLO, lit))
	# The printer, laying something down a line at a time.
	var mx := x + 74
	var pass_ := fmod(_t * 0.5, 1.0)
	var head := mx + 3 + int(absf(fmod(_t * 14.0, 28.0) - 14.0))
	var built := int(fmod(_t * 0.35, 1.0) * 12.0)
	box(c, mx + 6, y - 20 - built, 10, built, HOLO.darkened(0.35))
	box(c, mx + 6, y - 20 - built, 10, 1, HOLO)
	box(c, mx + 2, y - 37, 18, 1, HULL_SHADE)
	box(c, head, y - 36, 3, 2, HULL_LIT)
	box(c, head + 1, y - 34, 1, 14 - built - 2, faded(HOLO, 0.45 + 0.3 * pass_))
	box(c, mx + 18, y - 42, 1, 1, OPEN)
	if fmod(_t, 0.9) < 0.45:
		box(c, mx + 15, y - 42, 1, 1, ACCENT.lightened(0.3))

func _life_gate(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var cy := at.y - TALLEST + 30
	var open := _gate_open()
	var col := OPEN if open else SHUT
	if open:
		# What turns inside it, when it will take you.
		for k in 3:
			var r := 6 + k * 6
			var a := -_t * (1.4 - 0.3 * k) + k * 2.1
			for seg in 5:
				var th := a - seg * 0.22
				var dot := faded(col, (0.25 + 0.5 * lit) * (1.0 - seg / 5.0))
				box(c, at.x + int(round(cos(th) * r)), cy + int(round(sin(th) * r)), 2, 2, dot)
				box(c, at.x - int(round(cos(th) * r)), cy - int(round(sin(th) * r)), 2, 2, dot)
		disc(c, at.x, cy, 3, faded(col, 0.35 + 0.4 * lit))
	else:
		# And its leaves, shut, when it will not.
		disc(c, at.x, cy, 22, HULL_SHADE)
		for k in 8:
			var a := TAU * k / 8.0
			line(c, at.x + int(round(cos(a) * 22.0)), cy + int(round(sin(a) * 22.0)),
				at.x + int(round(cos(a + 1.9) * 4.0)), cy + int(round(sin(a + 1.9) * 4.0)), HULL_DARK)
		disc(c, at.x, cy, 3, HULL_DARK)
		box(c, at.x - 1, cy - 1, 2, 2, faded(col, 0.6 + 0.4 * sin(_t * 2.0)))
	# The lamps round the collar: chasing when it is open, all slow red when
	# not.
	for k in 12:
		var th := TAU * k / 12.0 - PI * 0.5
		var on := 0.4 + 0.35 * sin(_t * 2.0)
		if open:
			on = clampf(1.0 - fposmod(fmod(_t * 6.0, 12.0) - float(k), 12.0) / 5.0, 0.15, 1.0)
		var lx := at.x + int(round(cos(th) * 29.0)) - 1
		var ly := cy + int(round(sin(th) * 29.0)) - 1
		box(c, lx - 1, ly - 1, 4, 4, faded(col, on * (0.18 + 0.12 * lit)))
		box(c, lx, ly, 2, 2, faded(col, on))
	wet(c, at.x - 26, 52, col, 0.10 + 0.08 * lit)
	# Chevrons along the wall, walking you to it.
	for k in 4:
		var step := fposmod(_t * 3.0 - float(k), 4.0)
		stamp(c, BAY_LEFT + 50 + k * 9, at.y - 30, [
			"##....",
			".##...",
			"..##..",
			"...##.",
			"..##..",
			".##...",
			"##....",
		], faded(ACCENT.darkened(0.1), (0.3 if step > 1.0 else 1.0) * (1.0 if open else 0.35)))
