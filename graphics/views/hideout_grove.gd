class_name HideoutGrove
extends HideoutScenery

## The hideout as what is left of a temple in a wood, with the roof long gone
## and the moon coming up through the trees. Three of its columns still stand,
## two of them with their lintel; past them it is forest, in the mist, with a
## fall of water in it somewhere. Lanterns hang from a rail lashed across the
## place and from the branches over it, the fireflies are out, and what the
## hideout needs has been set up among the roots: arms on a rack of forked
## poles, a tent with somebody small and capped behind its plank, and the gate
## as a ring of old stone under the biggest tree there is.
##
## One of the hideout's looks (`HideoutThemes`), on the ground they all stand
## on (`HideoutScenery`): everything is placed in pixels of the buffer the
## world is drawn into, drawn once or drawn again as it moves, and reads the
## room without changing it.

## --- where things are, in buffer pixels of the room -------------------------
## The rail lashed across the ruin, by its underside: what the stations' signs
## hang from.
const RAIL := 224
## How far the nearer trees may slide as the player walks the room, and the
## stretch of the wood that is drawn: in from the room's walls by that much,
## with a trunk at either end of the room to hide where it stops.
const SLIDE := 4
const VIEW_LEFT := LEFT + SLIDE
const VIEW_RIGHT := RIGHT - SLIDE
## Where the wood's floor is lost in the undergrowth.
const BRUSH := 262
## The columns still standing, by their middles, and how high each still
## stands: the first is broken off, the other two carry the lintel.
const COLUMNS := [[160, 92], [288, 66], [416, 66]]
## The moon, coming up behind the far trees.
const MOON_AT := Vector2i(236, 136)
const MOON := 34
## The cliff out in the wood, by its middle, and the water coming down it;
## and the line of its top, as how far each point is from that middle and how
## high it stands.
const CLIFF := 356
const CRAG := [[-30, 150], [-24, 126], [-17, 121], [-12, 104], [-2, 99], [8, 101], [13, 111],
	[19, 116], [24, 130], [31, 150]]
## The biggest tree, by the left edge of its trunk, and the standing stone
## beside it with the way through carved on it.
const TREE := 500
const STONE_LEFT := 444
## The trees of the middle depth: where each trunk is, how wide, and where its
## foot goes into the brush.
const TRUNKS := [[46, 9, 262], [98, 7, 258], [186, 11, 264], [268, 8, 256], [316, 6, 260],
	[388, 10, 262], [452, 8, 258]]
## The lanterns: where each hangs from and how far down, in order along the
## room. The first three hang from the rail, the rest from what is overhead.
const LANTERNS := [[60, RAIL, 5], [224, RAIL, 5], [440, RAIL, 5], [196, 34, 62], [352, 66, 16], [430, 30, 84]]
## The way through, on the standing stone: the rooms of it, on a grid.
const ROOMS := [
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(3, 1), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(3, 3), Vector2i(2, 3),
	Vector2i(5, 1), Vector2i(6, 1), Vector2i(1, 3), Vector2i(5, 3), Vector2i(2, 4), Vector2i(6, 0),
]

## --- its colours --------------------------------------------------------------
## The night, from overhead down to the glow the moon puts behind the trees.
const SKY := [
	Color(0.02, 0.045, 0.085),
	Color(0.025, 0.06, 0.105),
	Color(0.03, 0.078, 0.128),
	Color(0.04, 0.10, 0.152),
	Color(0.052, 0.124, 0.176),
	Color(0.068, 0.152, 0.20),
	Color(0.09, 0.184, 0.224),
	Color(0.118, 0.22, 0.248),
	Color(0.152, 0.262, 0.272),
	Color(0.19, 0.308, 0.296),
]
const MOON_FACE := Color(0.95, 0.96, 0.84)
const MOON_SHADE := Color(0.82, 0.86, 0.78)
const MOONLIGHT := Color(0.66, 0.92, 0.86)
const FAR := Color(0.105, 0.225, 0.25)
const MID := Color(0.05, 0.125, 0.14)
const DARK := Color(0.022, 0.058, 0.062)
const LEAF := Color(0.07, 0.19, 0.14)
const BARK := Color(0.075, 0.068, 0.06)
const STONE := Color(0.34, 0.38, 0.37)
const STONE_SHADE := Color(0.19, 0.225, 0.23)
const MOSS := Color(0.24, 0.44, 0.22)
const MOSS_LIT := Color(0.42, 0.66, 0.30)
const WOOD := Color(0.29, 0.195, 0.12)
const WOOD_LIT := Color(0.45, 0.32, 0.19)
const WOOD_DARK := Color(0.14, 0.095, 0.065)
const STEEL := Color(0.60, 0.67, 0.72)
const STEEL_LIT := Color(0.90, 0.97, 1.0)
const ROPE := Color(0.72, 0.64, 0.46)
const CANVAS := Color(0.80, 0.75, 0.60)
const CANVAS_STRIPE := Color(0.25, 0.44, 0.33)
const LAMP := Color(1.0, 0.76, 0.34)
const FLAME_OUT := Color(0.92, 0.32, 0.10)
const FLAME_MID := Color(1.0, 0.64, 0.18)
const FLAME_CORE := Color(1.0, 0.94, 0.60)
const FIREFLY := Color(0.82, 1.0, 0.45)
const SHROOM := Color(0.36, 0.96, 0.90)
const WATER := Color(0.62, 0.86, 0.90)
const SOIL := Color(0.10, 0.085, 0.07)
const CAP := Color(0.82, 0.24, 0.20)
const FACE := Color(0.92, 0.86, 0.72)
## The gate's light: when it would take you, and when it would not.
const OPEN := Color(0.45, 1.0, 0.76)
const SHUT := Color(1.0, 0.34, 0.28)

## Back to front. `_mist` is what moves out in the wood, and is not slid: what
## it draws on a depth it draws where that depth has got to.
var _sky: Layer
var _far: Layer
var _mist: Layer
var _mid: Layer
var _room: Layer
var _room_life: Layer
var _fittings: Layer
var _life: Layer

## The stars, `{x, y, a}`, and the ones that twinkle, `{x, y, every, from}`.
var _stars: Array = []
var _twinkles: Array = []
## The fireflies: `{x, y, a, b, c}`, where each hangs about and how it is out
## of step with the rest.
var _flies: Array = []
## The leaves coming down: `{x, y, speed, sway}`.
var _leaves: Array = []

func _build() -> void:
	plate = Color(0.085, 0.072, 0.05)
	ink = Color(0.56, 0.66, 0.42)
	ink_lit = Color(0.90, 1.0, 0.62)
	ink_shut = Color(0.96, 0.46, 0.36)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x620F
	for i in 60:
		_stars.append({"x": rng.randi_range(LEFT, RIGHT - 1), "y": rng.randi_range(TOP, 120),
			"a": rng.randf_range(0.25, 0.85)})
	for i in 8:
		_twinkles.append({"x": rng.randi_range(LEFT + 30, TREE - 10), "y": rng.randi_range(52, 112),
			"every": rng.randf_range(1.6, 4.2), "from": rng.randf_range(0.0, 4.0)})
	for i in 38:
		_flies.append({"x": rng.randi_range(LEFT + 30, RIGHT - 30), "y": rng.randi_range(120, 300),
			"a": rng.randf_range(0.0, TAU), "b": rng.randf_range(0.0, TAU), "c": rng.randf_range(0.0, TAU)})
	for i in 7:
		_leaves.append({"x": rng.randi_range(LEFT + 30, TREE - 10), "y": rng.randi_range(0, 280),
			"speed": rng.randf_range(7.0, 13.0), "sway": rng.randf_range(0.0, TAU)})
	_sky = still(_paint_sky)
	_far = still(_paint_far)
	_mist = moving(_paint_mist)
	_mid = still(_paint_mid)
	_room = still(_paint_room)
	_room_life = moving(_paint_room_life)
	_fittings = still(_paint_fittings)
	_life = moving(_paint_life)

## The wood slides a little as the player walks the room, the nearer trees
## further than the far ones and the sky not at all: whole pixels of the
## buffer, and never more than SLIDE of them.
func _slide(across: float) -> void:
	_far.position.x = slid(across, 2.0)
	_mid.position.x = slid(across, float(SLIDE))

## How far a depth has slid, in pixels of the buffer.
func _off(depth: Layer) -> int:
	return int(round(depth.position.x / S))

## Something that is the same at `x` every time and has no pattern to it.
static func _odd(x: int, salt: int = 0) -> int:
	return absi((x * 73856093) ^ ((x + salt) * 19349663) ^ (salt * 83492791)) % 1000

## A box of something out in the wood, cut off where the drawn stretch ends.
static func _out_there(c: CanvasItem, x: int, y: int, w: int, h: int, col: Color) -> void:
	var from := maxi(x, VIEW_LEFT)
	var top := maxi(y, TOP)
	box(c, from, top, mini(x + w, VIEW_RIGHT) - from, y + h - top, col)

## A round mass of leaves out there, cut off the same way.
static func _blob(c: CanvasItem, cx: int, cy: int, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		var half := int(floor(sqrt(float(r * r - dy * dy) + 0.5)))
		_out_there(c, cx - half, cy + dy, half * 2 + 1, 1, col)

## How high the cliff's top stands, `from` its middle.
static func _crag(from: int) -> int:
	for i in range(1, CRAG.size()):
		var a: Array = CRAG[i - 1]
		var b: Array = CRAG[i]
		if from <= int(b[0]):
			var along := float(from - int(a[0])) / float(maxi(int(b[0]) - int(a[0]), 1))
			return int(round(lerpf(float(a[1]), float(b[1]), clampf(along, 0.0, 1.0))))
	return int(CRAG[CRAG.size() - 1][1])

## Where the far trees' tops are at `x`: crown after crown.
static func _skyline(x: int) -> int:
	return 152 - int(16.0 * absf(sin(x * 0.060 + 0.4)) + 9.0 * absf(sin(x * 0.137 + 1.3))) - _odd(x, 3) % 2

## --- the wood -----------------------------------------------------------------

func _paint_sky(c: CanvasItem) -> void:
	bands(c, LEFT, TOP, RIGHT - LEFT, BRUSH - TOP, SKY)
	for s in _stars:
		box(c, int(s["x"]), int(s["y"]), 1, 1, Color(0.82, 0.95, 0.92, float(s["a"])))
	# The moon, low and very big, with its light in the air round it.
	glow(c, MOON_AT.x, MOON_AT.y, MOON + 22, faded(MOONLIGHT, 0.035))
	glow(c, MOON_AT.x, MOON_AT.y, MOON + 13, faded(MOONLIGHT, 0.05))
	glow(c, MOON_AT.x, MOON_AT.y, MOON + 6, faded(MOONLIGHT, 0.07))
	disc(c, MOON_AT.x, MOON_AT.y, MOON, MOON_FACE)
	disc(c, MOON_AT.x - 12, MOON_AT.y - 10, 7, MOON_SHADE)
	disc(c, MOON_AT.x + 10, MOON_AT.y - 16, 4, MOON_SHADE)
	disc(c, MOON_AT.x + 14, MOON_AT.y + 2, 6, MOON_SHADE)
	disc(c, MOON_AT.x - 4, MOON_AT.y + 8, 3, MOON_SHADE)
	box(c, MOON_AT.x - 22, MOON_AT.y + 2, 4, 3, MOON_SHADE)
	box(c, MOON_AT.x + 2, MOON_AT.y - 26, 5, 2, MOON_SHADE)

## The far trees, a crown after another all the way across, a cliff standing
## out of them with the water coming down it, and the mist they stand in.
func _paint_far(c: CanvasItem) -> void:
	for x in range(VIEW_LEFT, VIEW_RIGHT):
		var top := _skyline(x)
		box(c, x, top, 1, BRUSH - top, FAR)
		if _odd(x, 7) % 9 == 0:
			box(c, x, top + 9, 1, BRUSH - top - 9, FAR.darkened(0.14))
		if _odd(x, 5) % 4 == 0:
			box(c, x, top, 1, 2, FAR.lightened(0.07))
	# The cliff.
	var rock := FAR.darkened(0.18)
	for x in range(CLIFF - 30, CLIFF + 31):
		var top := _crag(x - CLIFF) + _odd(x, 11) % 2
		box(c, x, top, 1, maxi(_skyline(x) + 6 - top, 0), rock)
		# The moon on the faces of it that look her way.
		if x < CLIFF - 3:
			box(c, x, top, 1, 2 + _odd(x, 2) % 4, rock.lightened(0.12))
	for crack in [[CLIFF - 13, 112, 22], [CLIFF + 9, 110, 26], [CLIFF - 20, 126, 14], [CLIFF + 20, 124, 16]]:
		box(c, crack[0], crack[1], 1, crack[2], rock.darkened(0.25))
	for ledge in [[CLIFF - 22, 131, 7], [CLIFF + 12, 122, 8], [CLIFF - 10, 118, 5]]:
		box(c, ledge[0], ledge[1], ledge[2], 1, rock.lightened(0.10))
	# A tree or two that found a hold on top of it.
	for pine in [CLIFF - 9, CLIFF + 5]:
		stamp(c, pine, _crag(pine + 2 - CLIFF) - 7, ["..#..", ".###.", "..#..", ".###.", "#####", "..#..", "..#.."],
			FAR.darkened(0.3))
	# The water.
	box(c, CLIFF - 3, 101, 6, 115, faded(WATER, 0.62))
	box(c, CLIFF - 3, 101, 1, 115, faded(WATER, 0.30))
	box(c, CLIFF - 1, 101, 2, 115, faded(Color.WHITE, 0.28))
	# The mist.
	for k in 6:
		_out_there(c, VIEW_LEFT, 196 + k * 11, VIEW_RIGHT - VIEW_LEFT, 11, faded(MOONLIGHT, 0.035 + 0.022 * k))

## What moves out in the wood: stars, the water, the spray at the foot of it,
## and the mist going by.
func _paint_mist(c: CanvasItem) -> void:
	var far := _off(_far)
	for s in _twinkles:
		if fmod(_t + float(s["from"]), float(s["every"])) < float(s["every"]) * 0.5:
			box(c, int(s["x"]), int(s["y"]), 1, 1, Color(1.0, 1.0, 1.0, 0.9))
	for k in 9:
		var y := 100 + int(fmod(_t * 46.0 + k * 13.0, 112.0))
		box(c, CLIFF - 3 + (k * 3) % 6 + far, y, 1, 4, Color(1.0, 1.0, 1.0, 0.55))
	for k in 3:
		var puff := 0.5 + 0.5 * sin(_t * 1.7 + k * 2.1)
		_out_there(c, CLIFF - 10 + k * 5 + far, 208 - int(puff * 4.0), 9, 5, faded(WATER, 0.10 + 0.10 * puff))
	var span := VIEW_RIGHT - VIEW_LEFT
	for band in [[204, 2.6, 0.0, 130], [222, 1.7, 210.0, 170], [238, 3.4, 420.0, 110], [214, 2.1, 330.0, 90]]:
		var w: int = band[3]
		var x := VIEW_LEFT - w + int(fmod(_t * float(band[1]) + float(band[2]), float(span + w)))
		var y: int = band[0]
		_out_there(c, x, y, w, 3, faded(MOONLIGHT, 0.07))
		_out_there(c, x + 14, y - 2, w - 36, 2, faded(MOONLIGHT, 0.06))
		_out_there(c, x + 22, y + 3, w - 50, 2, faded(MOONLIGHT, 0.06))

## The nearer trees: trunks from the brush up out of sight, lit down the side
## the moon is on, with their leaves overhead and the bushes at their feet.
func _paint_mid(c: CanvasItem) -> void:
	for x in range(VIEW_LEFT, VIEW_RIGHT, 8):
		_blob(c, x + _odd(x, 1) % 5, 20 + _odd(x, 2) % 16, 8 + _odd(x, 3) % 6, MID)
	for x in range(VIEW_LEFT, VIEW_RIGHT, 13):
		_blob(c, x + _odd(x, 4) % 7, 256 + _odd(x, 5) % 7, 9 + _odd(x, 6) % 5, MID)
	_out_there(c, VIEW_LEFT, 258, VIEW_RIGHT - VIEW_LEFT, BRUSH - 258 + 8, MID)
	for t in TRUNKS:
		var x: int = t[0]
		var w: int = t[1]
		var foot: int = t[2]
		_out_there(c, x, TOP, w, foot - TOP, MID)
		_out_there(c, x - 1, foot - 9, w + 2, 9, MID)
		_out_there(c, x - 2, foot - 3, w + 4, 3, MID)
		# The side the moon is on.
		var rim := x + w - 1 if x < MOON_AT.x else x
		_out_there(c, rim, 44, 1, foot - 54, MID.lerp(MOONLIGHT, 0.20))
		for k in 11:
			_out_there(c, x + 2 + (k * 5) % maxi(w - 3, 1), 48 + k * 19, 1, 7, MID.darkened(0.3))
		# A limb, going up and out, with its leaves at the end of it.
		var reach := 1 if _odd(x, 9) % 2 == 0 else -1
		var from := x + w if reach > 0 else x - 1
		var limb := 84 + (x % 30)
		for k in 13:
			_out_there(c, from + reach * k, limb - k, 1, 3, MID)
		_blob(c, from + reach * 14, limb - 14, 5, MID)
		_blob(c, from + reach * 19, limb - 11, 4, MID)
		_blob(c, from + reach * 10, limb - 18, 4, MID)
		_blob(c, from + reach * 17, limb - 19, 3, MID)

## --- the ruin, and what grows over it ---------------------------------------

func _paint_room(c: CanvasItem) -> void:
	_paint_rays(c)
	_paint_brush(c)
	_paint_columns(c)
	_paint_trees(c)
	_paint_canopy(c)
	_paint_stone(c)
	_paint_rail(c)
	_paint_lamplight(c)
	_paint_ground(c)

## What stands among the roots.
func _paint_fittings(c: CanvasItem) -> void:
	_paint_log(c)
	_paint_arms(c, _at["weapons"])
	_paint_tent(c, _at["shop"])
	_paint_gate(c, _at["gate"])

## The moon, coming through the trees in shafts.
func _paint_rays(c: CanvasItem) -> void:
	for ray in [[-0.62, 0.030], [-0.22, 0.026], [0.30, 0.030], [0.74, 0.024]]:
		for k in 15:
			var y := MOON_AT.y + 26 + k * 10
			var cx := MOON_AT.x + int(tan(float(ray[0])) * float(y - MOON_AT.y))
			var w := 12 + k * 2
			var from := maxi(cx - w / 2, LEFT)
			box(c, from, y, mini(cx + w / 2, RIGHT) - from, 10, faded(MOONLIGHT, float(ray[1]) * (1.0 - k / 17.0)))

## The undergrowth along the back of the place: dark, to the height of a
## station's fittings, with a frond or a leaf of it catching the light.
func _paint_brush(c: CanvasItem) -> void:
	for x in range(LEFT, RIGHT, 9):
		glow(c, x + _odd(x, 21) % 6, 266 + _odd(x, 22) % 9, 11 + _odd(x, 23) % 6, DARK)
	box(c, LEFT, 270, RIGHT - LEFT, FLOOR - 270, DARK)
	for x in range(LEFT + 4, RIGHT - 4, 5):
		if _odd(x, 24) % 3 == 0:
			box(c, x, 252 + _odd(x, 25) % 20, 2, 1, LEAF)
	for fern in [52, 178, 244, 300, 388, 430, 492]:
		var base := 300 + _odd(fern, 26) % 8
		for tip in [[-9, -15], [-4, -19], [1, -20], [6, -17], [11, -12]]:
			line(c, fern, base, fern + int(tip[0]), base + int(tip[1]), LEAF.lightened(0.06))
		for tip in [[-9, -15], [6, -17]]:
			box(c, fern + int(tip[0]), base + int(tip[1]), 2, 1, MOSS)

## A column of the ruin: fluted, in drums, on its foot, with moss where the
## wet gets and ivy where it can climb.
func _column(c: CanvasItem, cx: int, top: int, whole: bool) -> void:
	box(c, cx - 7, top, 14, FLOOR - top, STONE_SHADE)
	box(c, cx - 7, top, 2, FLOOR - top, STONE)
	box(c, cx - 4, top, 2, FLOOR - top, STONE.darkened(0.14))
	box(c, cx, top, 2, FLOOR - top, STONE_SHADE.lightened(0.10))
	box(c, cx + 5, top, 2, FLOOR - top, STONE_SHADE.darkened(0.3))
	for y in range(top + 16, FLOOR - 10, 24):
		box(c, cx - 7, y, 14, 1, STONE_SHADE.darkened(0.4))
	if whole:
		box(c, cx - 10, top, 20, 4, STONE)
		box(c, cx - 10, top, 20, 1, STONE.lightened(0.12))
		box(c, cx - 9, top + 4, 18, 2, STONE_SHADE)
	else:
		# Broken off: what is left of the top drum.
		box(c, cx - 7, top - 5, 4, 5, STONE_SHADE)
		box(c, cx - 7, top - 5, 2, 5, STONE)
		box(c, cx - 1, top - 2, 3, 2, STONE_SHADE)
		box(c, cx + 4, top - 7, 3, 7, STONE_SHADE.darkened(0.2))
	box(c, cx - 8, FLOOR - 9, 16, 3, STONE_SHADE)
	box(c, cx - 9, FLOOR - 6, 18, 6, STONE.darkened(0.12))
	box(c, cx - 9, FLOOR - 6, 18, 1, STONE.lightened(0.05))
	# Moss.
	for k in 9:
		var my := top + 4 + _odd(cx + k, 31) % (FLOOR - top - 12)
		box(c, cx - 7 + _odd(cx + k, 32) % 10, my, 2 + _odd(cx + k, 33) % 3, 1 + _odd(k, 34) % 2, MOSS.darkened(0.2))
	box(c, cx - 9, FLOOR - 7, 7, 2, MOSS)
	box(c, cx + 3, FLOOR - 7, 5, 1, MOSS.darkened(0.2))
	# Ivy, up the dark side of it.
	for k in range(0, FLOOR - top - 30, 5):
		var iy := FLOOR - 10 - k
		box(c, cx + 5 + (k / 5) % 2, iy, 1, 5, LEAF)
		box(c, cx + 4 + (k / 5) % 3, iy + 1, 2, 2, MOSS if (k / 5) % 3 == 0 else LEAF.lightened(0.10))

func _paint_columns(c: CanvasItem) -> void:
	for i in COLUMNS.size():
		_column(c, int(COLUMNS[i][0]), int(COLUMNS[i][1]), i > 0)
	# The lintel the last two still carry, with what was carved along it.
	var from: int = int(COLUMNS[1][0]) - 12
	var to: int = int(COLUMNS[2][0]) + 12
	box(c, from, 52, to - from, 14, STONE_SHADE)
	box(c, from, 52, to - from, 2, STONE)
	box(c, from, 64, to - from, 2, STONE_SHADE.darkened(0.35))
	for x in range(from + 6, to - 6, 9):
		box(c, x, 57, 5, 1, STONE_SHADE.darkened(0.3))
		box(c, x + 2, 55, 1, 5, STONE_SHADE.darkened(0.3))
	for crack in [[from + 38, 52, 9], [to - 44, 56, 10]]:
		line(c, crack[0], crack[1], int(crack[0]) + 3, int(crack[1]) + int(crack[2]), STONE_SHADE.darkened(0.5))
	for x in range(from, to - 3, 4):
		if _odd(x, 35) % 3 != 0:
			box(c, x, 51 - _odd(x, 36) % 2, 3 + _odd(x, 37) % 3, 2, MOSS if _odd(x, 38) % 3 > 0 else MOSS_LIT.darkened(0.2))
	for vine in [[from + 20, 16], [from + 64, 26], [to - 30, 12], [to - 8, 22]]:
		for k in range(0, int(vine[1]), 3):
			box(c, int(vine[0]) + (k / 3) % 2, 66 + k, 1, 3, LEAF.lightened(0.04))
			if (k / 3) % 2 == 0:
				box(c, int(vine[0]) - 1, 67 + k, 2, 1, MOSS)

## The trunk at either end of the place: the one against the left wall, and
## the biggest tree there is, which the gate stands under — with its roots,
## the limb an owl has, and whoever has a light on inside it.
func _paint_trees(c: CanvasItem) -> void:
	box(c, LEFT, TOP, 20, FLOOR - TOP, BARK)
	for y in range(TOP + 8, FLOOR - 6, 19):
		glow(c, LEFT + 17 + _odd(y, 41) % 3, y, 5, BARK)
	box(c, TREE, TOP, RIGHT - TREE, FLOOR - TOP, BARK)
	for y in range(TOP + 4, FLOOR - 10, 17):
		glow(c, TREE + 2 - _odd(y, 42) % 3, y, 6, BARK)
	# Roots.
	for k in 22:
		box(c, TREE - 22 + k, FLOOR - k * 8 / 10, 30 - k, 1, BARK)
	for k in 12:
		box(c, LEFT + 18, FLOOR - 12 + k, 6 + k, 1, BARK)
	# Bark: the furrows down it, and the moon on the edge it can reach.
	for x in range(TREE + 6, RIGHT - 3, 7):
		var top := TOP + _odd(x, 43) % 40
		box(c, x + _odd(x, 44) % 3, top, 1, 70 + _odd(x, 45) % 150, BARK.darkened(0.4))
		box(c, x + 1 + _odd(x, 44) % 3, top + 4, 1, 60 + _odd(x, 45) % 140, BARK.lightened(0.07))
		box(c, x + 3 + _odd(x, 46) % 2, top + 150, 1, 40 + _odd(x, 47) % 90, BARK.darkened(0.4))
		box(c, x + 4 + _odd(x, 46) % 2, top + 154, 1, 30 + _odd(x, 47) % 80, BARK.lightened(0.07))
	for knot in [[TREE + 30, 96], [TREE + 84, 214], [TREE + 22, 232]]:
		disc(c, knot[0], knot[1], 4, BARK.darkened(0.45))
		disc(c, knot[0], knot[1], 4, BARK.lightened(0.09), 3)
	for x in [LEFT + 4, LEFT + 10, LEFT + 15]:
		box(c, x, TOP + _odd(x, 48) % 30, 1, 200 + _odd(x, 49) % 70, BARK.darkened(0.35))
	for y in range(60, 250, 9):
		box(c, TREE - 4 + _odd(y, 50) % 3, y, 1, 6, BARK.lerp(MOONLIGHT, 0.16))
		box(c, LEFT + 21 - _odd(y, 51) % 3, y, 1, 6, BARK.lerp(MOONLIGHT, 0.12))
	# The limb.
	box(c, TREE - 28, 126, 30, 4, BARK)
	box(c, TREE - 28, 126, 30, 1, BARK.lerp(MOONLIGHT, 0.14))
	glow(c, TREE - 31, 124, 7, DARK)
	glow(c, TREE - 37, 129, 5, DARK)
	box(c, TREE - 36, 121, 2, 1, LEAF)
	box(c, TREE - 30, 118, 2, 1, LEAF)
	# The owl, on it. Its eyes are `_paint_room_life`'s.
	stamp(c, TREE - 19, 114, [
		"##.....##",
		"#########",
		"#########",
		"#########",
		"#########",
		"#########",
		".#######.",
		".#######.",
		".#######.",
		"..#####..",
		"..#####..",
		"...###...",
	], Color(0.30, 0.25, 0.20))
	stamp(c, TREE - 18, 121, ["#.#.#.#", ".#.#.#.", "#.#.#.#", ".#.#.#."], Color(0.44, 0.38, 0.30))
	box(c, TREE - 16, 126, 2, 1, LAMP.darkened(0.2))
	box(c, TREE - 13, 126, 2, 1, LAMP.darkened(0.2))
	# The windows in the trunk, with somebody home.
	for win in [[606, 168, 4], [588, 132, 3]]:
		disc(c, win[0], win[1], int(win[2]) + 1, WOOD_DARK)
		disc(c, win[0], win[1], win[2], LAMP.darkened(0.15))
		box(c, win[0], int(win[1]) - int(win[2]), 1, int(win[2]) * 2 + 1, WOOD_DARK)
		box(c, int(win[0]) - int(win[2]), win[1], int(win[2]) * 2 + 1, 1, WOOD_DARK)
	# What grows on bark in the dark, and glows. How it comes and goes is
	# `_paint_room_life`'s.
	for shelf in [[TREE - 4, 204, 10], [TREE + 2, 252, 8], [TREE - 2, 176, 7], [LEFT + 16, 200, 9], [LEFT + 14, 236, 7]]:
		box(c, shelf[0], shelf[1], shelf[2], 2, SHROOM.darkened(0.25))
		box(c, int(shelf[0]) + 1, int(shelf[1]) + 2, int(shelf[2]) - 3, 1, SHROOM.darkened(0.5))
	# Ivy up the left one.
	for k in range(0, 150, 6):
		box(c, LEFT + 2 + _odd(k, 52) % 14, 90 + k, 2, 2, MOSS if k % 4 == 0 else LEAF.lightened(0.08))

## The leaves overhead, all along the top of the place, and what trails down
## out of them.
func _paint_canopy(c: CanvasItem) -> void:
	for x in range(LEFT, RIGHT, 7):
		glow(c, x + _odd(x, 61) % 5, TOP + 1 + _odd(x, 62) % 10, 7 + _odd(x, 63) % 5, DARK)
	for x in range(LEFT + 9, RIGHT, 23):
		glow(c, x + _odd(x, 64) % 9, 30 + _odd(x, 65) % 10, 6, DARK)
	for x in range(LEFT + 3, RIGHT - 3, 4):
		if _odd(x, 66) % 3 == 0:
			box(c, x, 22 + _odd(x, 67) % 18, 2, 1, LEAF)
	for vine in [[70, 58], [132, 84], [262, 48], [388, 40], [456, 64], [540, 46], [610, 70]]:
		var x: int = vine[0]
		for k in range(0, int(vine[1]), 3):
			var sway := (k / 6) % 2
			box(c, x + sway, 30 + k, 1, 3, LEAF.lightened(0.03))
			if (k / 3) % 3 == 0:
				box(c, x + sway - 1 + 2 * ((k / 9) % 2), 31 + k, 2, 1, MOSS.darkened(0.15))

## The standing stone, with the way through cut into it. What the cuts are lit
## in is `_paint_room_life`'s.
func _paint_stone(c: CanvasItem) -> void:
	var x := STONE_LEFT
	for k in 9:
		box(c, x + (8 - k), 148 + k, 40 - 2 * (8 - k), 1, STONE_SHADE)
	box(c, x, 157, 40, FLOOR - 157, STONE_SHADE)
	box(c, x, 160, 2, FLOOR - 160, STONE.darkened(0.1))
	box(c, x + 38, 160, 2, FLOOR - 160, STONE_SHADE.darkened(0.35))
	line(c, x + 28, 149, x + 22, 168, STONE_SHADE.darkened(0.45))
	line(c, x + 8, 232, x + 15, 262, STONE_SHADE.darkened(0.45))
	box(c, x + 4, 164, 32, 40, STONE_SHADE.darkened(0.3))
	box(c, x + 4, 164, 32, 1, STONE_SHADE.darkened(0.55))
	for row in [[212, 24], [217, 18], [246, 26], [251, 14]]:
		box(c, x + 7, row[0], row[1], 1, STONE_SHADE.darkened(0.35))
	for k in 12:
		box(c, x + _odd(k, 71) % 34, 150 + _odd(k, 72) % 16, 3 + _odd(k, 73) % 4, 2, MOSS.darkened(0.15))
	for k in 10:
		box(c, x + _odd(k, 74) % 36, 270 + _odd(k, 75) % 40, 2 + _odd(k, 76) % 4, 2, MOSS.darkened(0.25))
	box(c, x + 6, 147, 9, 2, MOSS_LIT.darkened(0.15))

## The rail: a long pole, lashed to the trees and the columns, with what has
## started to grow along it. The lanterns' cords hang from here and from
## overhead; the lanterns themselves are `_paint_room_life`'s.
func _paint_rail(c: CanvasItem) -> void:
	box(c, LEFT + 18, RAIL - 3, RIGHT - LEFT - 26, 3, WOOD)
	box(c, LEFT + 18, RAIL - 3, RIGHT - LEFT - 26, 1, WOOD_LIT)
	for x in range(LEFT + 40, RIGHT - 20, 47):
		box(c, x, RAIL - 2, 3, 1, WOOD_DARK)
	for col in COLUMNS:
		box(c, int(col[0]) - 2, RAIL - 5, 5, 7, ROPE)
		box(c, int(col[0]) - 2, RAIL - 3, 5, 1, ROPE.darkened(0.3))
	for tie in [LEFT + 18, RIGHT - 12]:
		box(c, tie, RAIL - 5, 4, 7, ROPE)
		box(c, tie, RAIL - 3, 4, 1, ROPE.darkened(0.3))
	for x in range(LEFT + 24, RIGHT - 14, 6):
		if _odd(x, 81) % 4 == 0:
			box(c, x, RAIL - 5, 3, 2, MOSS if _odd(x, 82) % 2 == 0 else LEAF.lightened(0.1))
	for lantern in LANTERNS:
		box(c, lantern[0], lantern[1], 1, lantern[2], ROPE.darkened(0.35))

## What the lanterns throw on whatever is behind them, as it lies when they
## hang still.
func _paint_lamplight(c: CanvasItem) -> void:
	for lantern in LANTERNS:
		var y: int = int(lantern[1]) + int(lantern[2]) + 5
		glow(c, lantern[0], y, 26, faded(LAMP, 0.04))
		glow(c, lantern[0], y, 17, faded(LAMP, 0.055))
		glow(c, lantern[0], y, 9, faded(LAMP, 0.07))

## The ground: earth, with moss along the top of it, stones in it, and the big
## tree's roots running through.
func _paint_ground(c: CanvasItem) -> void:
	box(c, LEFT, FLOOR, RIGHT - LEFT, UNDER - FLOOR, SOIL)
	box(c, LEFT, FLOOR, RIGHT - LEFT, 1, MOSS)
	box(c, LEFT, FLOOR + 1, RIGHT - LEFT, 1, MOSS.darkened(0.45))
	for x in range(LEFT + 6, RIGHT - 16, 31):
		var w := 7 + _odd(x, 91) % 9
		var sx := x + _odd(x, 92) % 12
		var sy := FLOOR + 4 + _odd(x, 93) % 6
		box(c, sx, sy, w, 4, STONE_SHADE.darkened(0.3))
		box(c, sx, sy, w, 1, STONE_SHADE)
	for x in range(LEFT + 3, RIGHT - 3, 7):
		box(c, x + _odd(x, 94) % 5, FLOOR + 3 + _odd(x, 95) % 12, 1, 1, SOIL.lightened(0.10))
	line(c, TREE - 20, FLOOR + 3, TREE - 70, FLOOR + 9, BARK.lightened(0.04))
	line(c, TREE + 10, FLOOR + 5, TREE + 90, FLOOR + 11, BARK.lightened(0.04))
	line(c, LEFT + 22, FLOOR + 4, LEFT + 64, FLOOR + 10, BARK.lightened(0.04))
	for lantern in LANTERNS:
		if int(lantern[1]) == RAIL:
			box(c, int(lantern[0]) - 16, FLOOR, 32, 1, MOSS.lerp(LAMP, 0.4))

## --- what stands among the roots ---------------------------------------------

## A length of tree that came down, somewhere to sit, with what has come up
## on it since. What that glows with is `_paint_room_life`'s.
func _paint_log(c: CanvasItem) -> void:
	var x := 190
	box(c, x, FLOOR - 15, 62, 15, WOOD_DARK)
	box(c, x, FLOOR - 15, 62, 2, WOOD)
	box(c, x + 3, FLOOR - 16, 54, 1, MOSS.darkened(0.1))
	for k in 8:
		box(c, x + 4 + k * 7, FLOOR - 12 + (k % 3) * 3, 5, 1, WOOD_DARK.darkened(0.35))
	oval(c, x + 62, FLOOR - 8, 4, 7, WOOD)
	oval(c, x + 62, FLOOR - 8, 2, 5, WOOD_LIT.darkened(0.15))
	box(c, x + 62, FLOOR - 9, 1, 3, WOOD_DARK)
	for shroom in [[x + 9, 6], [x + 15, 4], [x + 22, 7], [x + 44, 5], [x + 50, 8]]:
		var sx: int = shroom[0]
		var tall: int = shroom[1]
		box(c, sx + 2, FLOOR - 16 - tall, 1, tall, CANVAS.darkened(0.2))
		box(c, sx, FLOOR - 18 - tall, 5, 2, SHROOM.darkened(0.2))
		box(c, sx + 1, FLOOR - 19 - tall, 3, 1, SHROOM.darkened(0.1))

## The arms: a rack of forked poles with what there is to carry leant in it, a
## shield at its foot, and the stump the axe for the firewood lives in. What
## is lit on them is `_paint_life`'s.
func _paint_arms(c: CanvasItem, at: Vector2i) -> void:
	var x := at.x - 24
	var y := at.y
	# The stump.
	var sx := x - 24
	box(c, sx, y - 13, 18, 13, WOOD_DARK.lightened(0.05))
	box(c, sx - 2, y - 3, 22, 3, WOOD_DARK.lightened(0.05))
	box(c, sx, y - 15, 18, 3, WOOD_LIT.darkened(0.1))
	box(c, sx + 3, y - 14, 12, 1, WOOD_LIT.lightened(0.08))
	for k in [4, 9, 13]:
		box(c, sx + k, y - 11, 1, 9, WOOD_DARK.darkened(0.3))
	line(c, sx + 9, y - 16, sx + 16, y - 32, WOOD_LIT)
	stamp(c, sx + 5, y - 20, [".###..", "#####.", "######", ".####.", "..##.."], STEEL.darkened(0.15))
	box(c, sx + 5, y - 19, 1, 3, STEEL_LIT)
	# The rack: two forked poles and what is laid across them.
	for pole in [x, x + 46]:
		box(c, pole, y - 50, 2, 50, WOOD)
		box(c, pole, y - 50, 1, 50, WOOD_LIT)
		line(c, pole, y - 50, pole - 3, y - 56, WOOD)
		line(c, pole + 1, y - 50, pole + 4, y - 56, WOOD)
	box(c, x - 5, y - 52, 58, 2, WOOD_LIT.darkened(0.1))
	box(c, x - 5, y - 52, 58, 1, WOOD_LIT)
	box(c, x - 2, y - 22, 52, 2, WOOD)
	for tie in [x - 1, x + 45]:
		box(c, tie, y - 53, 4, 4, ROPE)
		box(c, tie, y - 23, 4, 4, ROPE)
	# A sword.
	box(c, x + 8, y - 46, 2, 30, STEEL)
	box(c, x + 8, y - 46, 1, 30, STEEL_LIT)
	box(c, x + 8, y - 48, 1, 2, STEEL_LIT)
	box(c, x + 5, y - 16, 8, 1, WOOD_LIT.lightened(0.2))
	box(c, x + 8, y - 15, 2, 7, WOOD_DARK)
	# An axe.
	box(c, x + 18, y - 48, 1, 42, WOOD_LIT)
	stamp(c, x + 15, y - 48, [".##.##.", "###.###", "###.###", "###.###", ".##.##."], STEEL)
	box(c, x + 15, y - 47, 1, 3, STEEL_LIT)
	# A spear, which stands taller than the rack.
	box(c, x + 27, y - 60, 1, 54, WOOD_LIT)
	stamp(c, x + 25, y - 66, ["..#..", ".###.", ".###.", ".###.", "..#..", "..#.."], STEEL)
	box(c, x + 27, y - 66, 1, 4, STEEL_LIT)
	box(c, x + 26, y - 59, 3, 2, MOSS_LIT)
	# A staff, grown rather than made, with whatever that is in the fork of it.
	box(c, x + 36, y - 44, 1, 38, WOOD_LIT.darkened(0.2))
	line(c, x + 36, y - 44, x + 33, y - 52, WOOD_LIT.darkened(0.2))
	line(c, x + 36, y - 44, x + 39, y - 51, WOOD_LIT.darkened(0.2))
	# The shield, at its foot.
	disc(c, x + 40, y - 12, 7, WOOD)
	disc(c, x + 40, y - 12, 7, STEEL.darkened(0.35), 6)
	box(c, x + 40, y - 18, 1, 13, WOOD_DARK)
	box(c, x + 36, y - 12, 9, 1, WOOD_DARK)
	disc(c, x + 40, y - 12, 2, STEEL)
	# The little lamp on the pole.
	box(c, x - 6, y - 44, 6, 1, WOOD_DARK)
	box(c, x - 6, y - 43, 1, 3, ROPE.darkened(0.35))

## The tent: striped canvas on a ridge pole, the plank across two barrels that
## does for a counter, what is for sale hung up and set out, a basket of apples,
## and the kettle on its fire. Whoever keeps it, and what burns, are
## `_paint_life`'s.
func _paint_tent(c: CanvasItem, at: Vector2i) -> void:
	var x := at.x - 32
	var y := at.y
	# Inside it, in the dark.
	box(c, x + 1, y - 46, 62, 26, Color(0.03, 0.045, 0.04))
	# The canvas, stripe by stripe, down from the ridge.
	for k in 22:
		var half := 4 + k * 16 / 10
		var row := y - 66 + k
		var from := at.x - half
		while from < at.x + half:
			var stripe := posmod(from - x, 16) / 8
			var to := mini(from + 8 - posmod(from - x, 8), at.x + half)
			box(c, from, row, to - from, 1, (CANVAS if stripe == 0 else CANVAS_STRIPE).darkened(0.04 * (k % 3)))
			from = to
	for k in 9:
		var sx := x - 6 + k * 8
		box(c, sx + 1, y - 44, 6, 1, CANVAS if k % 2 == 0 else CANVAS_STRIPE)
		box(c, sx + 2, y - 43, 4, 1, (CANVAS if k % 2 == 0 else CANVAS_STRIPE).darkened(0.15))
	box(c, at.x - 5, y - 67, 10, 1, WOOD_LIT)
	box(c, x - 1, y - 44, 2, 44, WOOD)
	box(c, x + 63, y - 44, 2, 44, WOOD)
	box(c, x - 1, y - 44, 1, 44, WOOD_LIT)
	# What hangs under it: herbs, and a string of something.
	for herb in [x + 6, x + 13, x + 49]:
		box(c, herb + 1, y - 43, 1, 3, ROPE.darkened(0.3))
		stamp(c, herb, y - 40, [".#.", "###", "###", ".#.", "###", ".#."], MOSS.darkened(0.05))
	for k in 5:
		box(c, x + 54 + (k % 2), y - 42 + k * 3, 2, 2, CANVAS.darkened(0.1))
	# The barrels, and the plank across them.
	for barrel in [x + 3, x + 47]:
		box(c, barrel, y - 18, 14, 18, WOOD)
		box(c, barrel, y - 18, 1, 18, WOOD_LIT.darkened(0.15))
		for stave in [barrel + 4, barrel + 8, barrel + 11]:
			box(c, stave, y - 17, 1, 17, WOOD_DARK)
		box(c, barrel, y - 14, 14, 1, STEEL.darkened(0.5))
		box(c, barrel, y - 5, 14, 1, STEEL.darkened(0.5))
	box(c, x + 17, y - 18, 30, 18, Color(0.03, 0.04, 0.035))
	box(c, x + 20, y - 12, 24, 12, WOOD_DARK)
	box(c, x + 20, y - 12, 24, 1, WOOD)
	for slat in [x + 26, x + 32, x + 38]:
		box(c, slat, y - 11, 1, 11, WOOD_DARK.darkened(0.35))
	box(c, x - 3, y - 21, 70, 3, WOOD_LIT)
	box(c, x - 3, y - 21, 70, 1, WOOD_LIT.lightened(0.14))
	box(c, x - 3, y - 18, 70, 1, WOOD_DARK)
	# What is set out on it.
	var jars := [Color(0.90, 0.36, 0.30), Color(0.36, 0.74, 0.92), Color(0.96, 0.78, 0.34), Color(0.62, 0.86, 0.42)]
	for k in 4:
		var jx := x + 2 + k * 5
		box(c, jx, y - 26, 3, 5, (jars[k] as Color).darkened(0.25))
		box(c, jx, y - 26, 1, 5, jars[k])
		box(c, jx + 1, y - 28, 1, 2, CANVAS.darkened(0.25))
	stamp(c, x + 48, y - 25, ["#.......#", "#########", ".#######.", "..#####.."], WOOD_DARK.lightened(0.1))
	for apple in [[x + 50, y - 27], [x + 53, y - 28], [x + 56, y - 27], [x + 52, y - 26]]:
		box(c, apple[0], apple[1], 2, 2, CAP)
	# A basket of the same, beside it.
	stamp(c, x - 22, y - 12, [
		"#............#",
		"##..........##",
		"##############",
		"##############",
		".############.",
		".############.",
		".############.",
		"..##########..",
		"..##########..",
		"..##########..",
		"...########...",
		"...########...",
	], WOOD_LIT.darkened(0.2))
	for k in 4:
		box(c, x - 20, y - 9 + k * 3, 10, 1, WOOD_DARK)
	for apple in [[x - 20, y - 14], [x - 17, y - 15], [x - 14, y - 14], [x - 12, y - 15], [x - 16, y - 13]]:
		box(c, apple[0], apple[1], 2, 2, CAP.darkened(0.08) if int(apple[0]) % 2 == 0 else CAP)
	# The kettle's sticks, the stones round the fire, and the kettle.
	var px := at.x + 56
	line(c, px - 10, y - 1, px, y - 28, WOOD)
	line(c, px + 10, y - 1, px, y - 28, WOOD)
	box(c, px, y - 26, 1, 8, ROPE.darkened(0.4))
	oval(c, px, y - 13, 5, 4, STEEL.darkened(0.62))
	box(c, px - 5, y - 17, 11, 1, STEEL.darkened(0.3))
	box(c, px - 3, y - 15, 1, 4, STEEL.darkened(0.4))
	box(c, px - 8, y - 15, 3, 1, STEEL.darkened(0.62))
	box(c, px - 8, y - 16, 1, 1, STEEL.darkened(0.62))
	for stone in [px - 9, px - 5, px + 3, px + 7]:
		box(c, stone, y - 3, 3, 3, STONE_SHADE)
		box(c, stone, y - 3, 3, 1, STONE.darkened(0.15))
	box(c, px - 4, y - 2, 9, 2, WOOD_DARK)

## The gate: a ring of old stone on its sill, half taken by the ivy, and a
## stone stood up either side of it. What is in it, and what the stones are
## lit in, are `_paint_life`'s.
func _paint_gate(c: CanvasItem, g: Vector2i) -> void:
	var cy := g.y - 36
	box(c, g.x - 32, g.y - 3, 64, 3, STONE_SHADE)
	box(c, g.x - 32, g.y - 3, 64, 1, STONE.darkened(0.1))
	box(c, g.x - 26, g.y - 7, 52, 4, STONE_SHADE)
	box(c, g.x - 26, g.y - 7, 52, 1, STONE.darkened(0.1))
	disc(c, g.x, cy, 30, STONE_SHADE.darkened(0.4))
	disc(c, g.x, cy, 29, STONE_SHADE.lightened(0.06))
	disc(c, g.x, cy, 29, STONE.darkened(0.08), 28)
	for k in 12:
		var a := TAU * k / 12.0 + 0.26
		line(c, g.x + int(round(cos(a) * 23.0)), cy + int(round(sin(a) * 23.0)),
			g.x + int(round(cos(a) * 29.0)), cy + int(round(sin(a) * 29.0)), STONE_SHADE.darkened(0.4))
	disc(c, g.x, cy, 22, Color(0.015, 0.035, 0.04))
	# Moss along the top of it, and the ivy down one side.
	for k in 14:
		var a := -PI * 0.5 + (k - 7) * 0.13
		box(c, g.x + int(round(cos(a) * 29.0)) - 1, cy + int(round(sin(a) * 29.0)) - 1, 3, 2,
			MOSS if k % 3 > 0 else MOSS_LIT.darkened(0.15))
	for k in 16:
		var a := -0.9 + k * 0.11
		var ix := g.x + int(round(cos(a) * 27.0))
		var iy := cy + int(round(sin(a) * 27.0))
		box(c, ix, iy, 2, 2, LEAF.lightened(0.08) if k % 2 == 0 else MOSS.darkened(0.1))
		if k % 4 == 1:
			box(c, ix + 1, iy + 2, 1, 4, LEAF.lightened(0.04))
	# The stones stood up beside it.
	for side: int in [-1, 1]:
		var sx := g.x + side * 44
		box(c, sx - 5, g.y - 30, 10, 30, STONE_SHADE)
		box(c, sx - 4, g.y - 33, 8, 3, STONE_SHADE)
		box(c, sx - 2, g.y - 35, 5, 2, STONE_SHADE)
		box(c, sx - 5, g.y - 30, 1, 30, STONE.darkened(0.1))
		box(c, sx + 4, g.y - 30, 1, 30, STONE_SHADE.darkened(0.4))
		box(c, sx - 5, g.y - 4, 6, 2, MOSS)
		box(c, sx - 1, g.y - 34, 4, 1, MOSS.darkened(0.2))

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

## A lantern, hung at (x, y) by its top: paper round a flame, swinging a
## little, and brighter by `more`.
func _lantern(c: CanvasItem, x: int, y: int, salt: int, more: float = 0.0) -> void:
	var f := flicker(_t, salt)
	var swing := int(round(sin(_t * 0.9 + float(salt) * 1.3) * 0.9))
	var lx := x - 3 + swing
	box(c, lx + 1, y, 5, 1, WOOD_DARK)
	box(c, lx, y + 1, 7, 8, LAMP.darkened(0.25 - 0.2 * f))
	box(c, lx + 1, y + 2, 5, 6, LAMP.lerp(Color.WHITE, 0.15 + 0.25 * f))
	box(c, lx + 3, y + 3, 1, 4, FLAME_CORE)
	box(c, lx + 1, y + 9, 5, 1, WOOD_DARK)
	box(c, lx + 3, y + 10, 1, 2, CAP)
	halo(c, lx, y + 1, 7, 8, LAMP, 5, (0.05 + 0.05 * more) * f)

## What the place does by itself: the lanterns, the fireflies, a leaf coming
## down, what glows on the bark and on the log, the owl, and the way through
## the stone.
func _paint_room_life(c: CanvasItem) -> void:
	for i in LANTERNS.size():
		var lantern: Array = LANTERNS[i]
		_lantern(c, lantern[0], int(lantern[1]) + int(lantern[2]), 3 + i * 7)
	for fly in _flies:
		var on := sin(_t * 1.3 + float(fly["c"]))
		if on <= 0.0:
			continue
		var x := int(fly["x"]) + int(round(sin(_t * 0.31 + float(fly["a"])) * 9.0))
		var y := int(fly["y"]) + int(round(sin(_t * 0.43 + float(fly["b"])) * 6.0))
		box(c, x, y, 1, 1, faded(FIREFLY, on))
		if on > 0.6:
			box(c, x - 1, y - 1, 3, 3, faded(FIREFLY, 0.16 * on))
	for leaf in _leaves:
		var fall := float(leaf["y"]) + float(leaf["speed"]) * _t
		var y := 36 + int(fall) % 280
		var x := int(leaf["x"]) + int(round(sin(fall * 0.09 + float(leaf["sway"])) * 7.0))
		box(c, x, y, 2 if int(fall * 0.4) % 2 == 0 else 1, 1, MOSS_LIT)
	# What glows: breathing, each a little out of step.
	var shelves := [[TREE - 4, 204, 10], [TREE + 2, 252, 8], [TREE - 2, 176, 7], [LEFT + 16, 200, 9], [LEFT + 14, 236, 7]]
	for i in shelves.size():
		var shelf: Array = shelves[i]
		var breath := 0.55 + 0.45 * sin(_t * 1.1 + i * 1.7)
		box(c, shelf[0], shelf[1], shelf[2], 1, faded(SHROOM.lightened(0.3), breath))
		halo(c, shelf[0], shelf[1], shelf[2], 2, SHROOM, 3, 0.05 * breath)
	var caps := [[199, 6], [205, 4], [212, 7], [234, 5], [240, 8]]
	for i in caps.size():
		var breath := 0.55 + 0.45 * sin(_t * 1.3 + i * 2.3)
		var sx: int = caps[i][0]
		var top: int = FLOOR - 19 - int(caps[i][1])
		box(c, sx + 1, top, 3, 1, faded(SHROOM.lightened(0.4), breath))
		halo(c, sx, top, 5, 3, SHROOM, 3, 0.06 * breath)
	# The owl: awake, and watching whoever is down there.
	var eyes := clampi(int((_player_x(float(TREE - 15)) - float(TREE - 15)) / 120.0), -1, 1)
	if fmod(_t + 0.9, 6.3) < 6.1:
		box(c, TREE - 17 + eyes, 117, 2, 2, LAMP)
		box(c, TREE - 13 + eyes, 117, 2, 2, LAMP)
		box(c, TREE - 16 + eyes + maxi(eyes, 0), 118, 1, 1, Color(0.04, 0.04, 0.04))
		box(c, TREE - 12 + eyes + maxi(eyes, 0), 118, 1, 1, Color(0.04, 0.04, 0.04))
	else:
		box(c, TREE - 17, 118, 2, 1, Color(0.18, 0.15, 0.12))
		box(c, TREE - 13, 118, 2, 1, Color(0.18, 0.15, 0.12))
	# Whoever is home in the trunk has a fire going.
	for win in [[606, 168, 4], [588, 132, 3]]:
		var f := flicker(_t, int(win[0]))
		halo(c, int(win[0]) - int(win[2]), int(win[1]) - int(win[2]), int(win[2]) * 2 + 1, int(win[2]) * 2 + 1,
			LAMP, 3, 0.05 * f)
	# The way through, in the stone: every room of it cut, and lit while there
	# is a way, with one of them brighter as the way is followed.
	var open := _gate_open()
	var cut := SHROOM if open else SHUT
	var mx := STONE_LEFT + 6
	var beat := 0.6 + 0.25 * sin(_t * 1.5)
	for r: Vector2i in ROOMS:
		box(c, mx + r.x * 4, 170 + r.y * 6, 3, 4, faded(cut, (0.55 if open else 0.3) * beat))
	if open:
		var here: Vector2i = ROOMS[int(_t * 1.6) % 14]
		box(c, mx + here.x * 4, 170 + here.y * 6, 3, 4, Color.WHITE)
		halo(c, mx + here.x * 4, 170 + here.y * 6, 3, 4, SHROOM, 2, 0.14)
	halo(c, STONE_LEFT + 4, 164, 32, 40, cut, 3, 0.02 * beat)

func _paint_life(c: CanvasItem) -> void:
	_life_arms(c, _at["weapons"], float(_lit["weapons"]))
	_life_tent(c, _at["shop"], float(_lit["shop"]))
	_life_gate(c, _at["gate"], float(_lit["gate"]))

## A glint on an edge: a cross of light, there and gone.
func _glint(c: CanvasItem, x: int, y: int, on: float) -> void:
	if on <= 0.0:
		return
	box(c, x, y - 1, 1, 3, faded(STEEL_LIT, on))
	box(c, x - 1, y, 3, 1, faded(STEEL_LIT, on))

func _life_arms(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var x := at.x - 24
	var y := at.y
	# The lamp on the pole, up for somebody standing here.
	_lantern(c, x - 6, y - 40, 51, lit)
	# What is in the fork of the staff.
	var pulse := 0.6 + 0.4 * sin(_t * 2.3)
	halo(c, x + 35, y - 51, 3, 3, SHROOM, 3, 0.10 * pulse * (0.6 + 0.4 * lit))
	box(c, x + 35, y - 51, 3, 3, SHROOM.lerp(Color.WHITE, 0.5 * pulse))
	var turn := fmod(_t, 4.0)
	_glint(c, x + 8, y - 43, clampf(1.0 - absf(turn - 0.5) * 4.0, 0.0, 1.0) * (0.5 + 0.5 * lit))
	_glint(c, x + 15, y - 46, clampf(1.0 - absf(turn - 1.7) * 4.0, 0.0, 1.0) * (0.5 + 0.5 * lit))
	_glint(c, x + 27, y - 64, clampf(1.0 - absf(turn - 2.9) * 4.0, 0.0, 1.0) * (0.5 + 0.5 * lit))
	if lit > 0.0:
		box(c, x - 5, y - 53, 58, 1, faded(ink_lit, lit))

func _life_tent(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var x := at.x - 32
	var y := at.y
	var eyes := clampi(int((_player_x(float(at.x)) - float(at.x)) / 60.0), -2, 2)
	# Whoever keeps the tent: a cap, mostly, and a face under it.
	var hx := at.x - 8
	var hy := y - 42
	var bob := int(round(sin(_t * 1.6) * 0.6))
	stamp(c, hx, hy + bob, [
		"....########....",
		"..############..",
		".##############.",
		"################",
		"################",
		"################",
		".##############.",
	], CAP)
	for spot in [[3, 2, 3, 2], [9, 1, 3, 2], [12, 4, 2, 2], [6, 4, 2, 1]]:
		box(c, hx + int(spot[0]), hy + bob + int(spot[1]), spot[2], spot[3], FACE)
	box(c, hx + 1, hy + bob + 5, 14, 1, CAP.darkened(0.3))
	box(c, hx + 3, hy + bob + 7, 10, 9, FACE)
	box(c, hx + 3, hy + bob + 7, 10, 1, FACE.darkened(0.2))
	box(c, hx + 12, hy + bob + 8, 1, 8, FACE.darkened(0.15))
	if fmod(_t, 3.9) > 3.75:
		box(c, hx + 5 + eyes, hy + bob + 11, 2, 1, Color(0.10, 0.08, 0.08))
		box(c, hx + 9 + eyes, hy + bob + 11, 2, 1, Color(0.10, 0.08, 0.08))
	else:
		box(c, hx + 5 + eyes, hy + bob + 10, 2, 2, Color(0.10, 0.08, 0.08))
		box(c, hx + 9 + eyes, hy + bob + 10, 2, 2, Color(0.10, 0.08, 0.08))
	box(c, hx + 4, hy + bob + 13, 1, 1, CAP.lightened(0.25))
	box(c, hx + 11, hy + bob + 13, 1, 1, CAP.lightened(0.25))
	# The lantern under the ridge, up for somebody at the plank.
	_lantern(c, x + 40, y - 43, 67, lit)
	if lit > 0.0:
		box(c, x - 3, y - 22, 70, 1, faded(ink_lit, lit))
	# The fire, and the kettle coming to the boil over it.
	var px := at.x + 56
	var burn := flicker(_t, 77)
	_flame(c, px - 2, y - 2, 7, burn, 5)
	_flame(c, px + 2, y - 2, 6, flicker(_t, 78), 6)
	halo(c, px - 4, y - 8, 9, 7, LAMP, 5, 0.05 * burn)
	for k in 2:
		var up := fmod(_t * 0.9 + k * 0.5, 1.0)
		box(c, px + int(round(sin(up * 9.0 + k * 3.0) * 3.0)), y - 8 - int(up * 14.0), 1, 1, faded(FLAME_MID, 1.0 - up))
	for k in 3:
		var up := fmod(_t * 0.3 + k * 0.33, 1.0)
		box(c, px - 7 - int(up * 3.0) + int(round(sin(up * 6.0 + k) * 1.5)), y - 16 - int(up * 14.0), 2, 1,
			Color(0.85, 0.92, 0.92, 0.28 * (1.0 - up)))

func _life_gate(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var cy := at.y - 36
	var open := _gate_open()
	var col := OPEN if open else SHUT
	if open:
		# What is in the ring, when it will take you: lights, going round.
		disc(c, at.x, cy, 20, faded(col, 0.035 + 0.03 * lit))
		disc(c, at.x, cy, 13, faded(col, 0.04 + 0.03 * lit))
		for k in 3:
			var r := 6 + k * 6
			var a := _t * (1.2 - 0.3 * k) + k * 2.1
			for seg in 5:
				var th := a + seg * 0.24
				var dot := faded(col, (0.3 + 0.5 * lit) * (1.0 - seg / 5.0))
				box(c, at.x + int(round(cos(th) * r)), cy + int(round(sin(th) * r)), 2, 2, dot)
				box(c, at.x - int(round(cos(th) * r)), cy - int(round(sin(th) * r)), 2, 2, dot)
		disc(c, at.x, cy, 3, faded(col, 0.4 + 0.4 * lit))
	else:
		# And when it will not: grown shut.
		var briar := Color(0.10, 0.075, 0.05)
		for vine in [[-21, -6, 20, 9], [-19, 10, 21, -11], [-12, -18, 9, 20], [-20, 2, 20, -1]]:
			line(c, at.x + int(vine[0]), cy + int(vine[1]), at.x + int(vine[2]), cy + int(vine[3]), briar)
			line(c, at.x + int(vine[0]), cy + int(vine[1]) + 1, at.x + int(vine[2]), cy + int(vine[3]) + 1, briar)
		for thorn in [[-12, -3], [-3, 2], [7, 4], [12, -5], [-8, 8], [2, -9], [9, 13], [-14, 4]]:
			box(c, at.x + int(thorn[0]), cy + int(thorn[1]), 1, 2, briar.lightened(0.12))
		for bud in [[-6, -1], [10, 1], [1, 9]]:
			box(c, at.x + int(bud[0]), cy + int(bud[1]), 2, 2, faded(col, 0.55 + 0.25 * sin(_t * 2.0)))
	# The lights set round the ring: chasing while it is open, all together
	# and slow while it is not.
	for k in 12:
		var th := TAU * k / 12.0 - PI * 0.5
		var on := 0.45 + 0.35 * sin(_t * 2.0)
		if open:
			on = clampf(1.0 - fposmod(fmod(_t * 6.0, 12.0) - float(k), 12.0) / 5.0, 0.15, 1.0)
		var lx := at.x + int(round(cos(th) * 26.0)) - 1
		var ly := cy + int(round(sin(th) * 26.0)) - 1
		box(c, lx - 1, ly - 1, 4, 4, faded(col, on * (0.16 + 0.12 * lit)))
		box(c, lx, ly, 2, 2, faded(col, on))
	# The sign cut in each standing stone.
	for side: int in [-1, 1]:
		var sx := at.x + side * 44
		var on := (0.5 + 0.3 * sin(_t * 1.6 + side)) * (0.7 + 0.3 * lit)
		stamp(c, sx - 2, at.y - 26, RUNES[0 if side < 0 else 1], faded(col, on))
		halo(c, sx - 2, at.y - 26, 4, 7, col, 2, 0.05 * on)

## The signs cut in the stones either side of the gate.
const RUNES := [
	["#..#", "#.#.", "##..", "#.#.", "#..#", "....", ".##."],
	[".##.", "#..#", ".##.", "..#.", ".#..", "....", "#..#"],
]
