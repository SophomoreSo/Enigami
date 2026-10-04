class_name HideoutBrass
extends HideoutScenery

## The hideout as a terrace of a clock tower, high over a city of brass, on a
## bright day. Two arches open onto the sky — heaped cloud, an airship or two
## going over, the city's domes and spires down in the haze past the
## balustrade — and the rest is the tower's own: fluted columns, a ceiling in
## coffers, a pipe run across the place with the steam getting out of it, a
## window in coloured glass, and in the bay the great clock with its train of
## wheels turning and the board of lamps that shows where the gate goes. The
## arms hang in a rack beside a grindstone, the stall is kept by somebody
## wound up with a key, with a cat of the same make on the crate beside it,
## and the gate is a ring of brass with a crystal in it and a coil either
## side that throws sparks at it.
##
## One of the hideout's looks (`HideoutThemes`), on the ground they all stand
## on (`HideoutScenery`): everything is placed in pixels of the buffer the
## world is drawn into, drawn once or drawn again as it moves, and reads the
## room without changing it.

# A picture drawn in whole pixels halves and thirds whole numbers on purpose,
# all the way down.
@warning_ignore_start("integer_division")

## --- where things are, in buffer pixels of the room -------------------------
## The underside of the roof, the foot of the band of ornament under it, and
## where the arches spring from the columns' heads and how high they rise.
const ROOF := 40
const FRIEZE := 56
const SPRING := 102
const RISE := 44
## The pipe run across the place, by its underside: the stations' signs are
## hung straight off it, and what is written over one is clear of it. And the
## top of the balustrade along the terrace's far edge.
const PIPE := 229
const RAIL := 276
## The tower's own wall on the left, by where it ends, and where the gate's
## bay starts on the right. A column stands against each.
const TOWER := 46
const BAY_LEFT := 440
## The columns, by their middles, and the arches between them, by the edges
## of the columns each springs from.
const COLUMNS := [53, 229, 433]
const ARCHES := [[60, 222], [236, 426]]
## How far the nearer of the city may slide as the player walks the room, and
## the stretch of the outdoors that is drawn: wider than the arches by that
## much either end, behind the columns.
const SLIDE := 4
const VIEW_LEFT := 56
const VIEW_RIGHT := 430
## Where the city stands, in the haze.
const HORIZON := 300
## The clock in the bay, by its middle, and the train of wheels beside it:
## where each turns, how big it is, how many teeth it has, and which way and
## how fast it goes round — each the other way from the one that drives it.
const CLOCK := Vector2i(494, 108)
const WHEELS := [[548, 92, 17, 14, 0.5], [573, 105, 12, 10, -0.708], [592, 98, 9, 8, 0.944], [604, 107, 7, 6, -1.214]]
## The board of lamps under the clock, by its top-left, and the rooms on it,
## on a grid.
const BOARD := Vector2i(452, 150)
const ROOMS := [
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(3, 1), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(3, 3), Vector2i(2, 3),
	Vector2i(5, 1), Vector2i(6, 1), Vector2i(1, 3), Vector2i(5, 3), Vector2i(2, 4), Vector2i(6, 0),
]
## The lamps hung in the arches, by where each hangs and how far down, and the
## station each is over. Each hangs on a chain of its own (`_hang_lamps`).
const LAMPS := [[141, 60, 26, "weapons"], [331, 60, 26, "shop"]]
## The room a lamp takes up, from the pixel it hangs by: what has to go through
## it to set it swinging.
const LAMP_BODY := Rect2i(-4, 0, 9, 14)
## Where the steam gets out: the place, and how long between one breath of it
## and the next.
const LEAKS := [[396, PIPE - 6, 5.0], [468, PIPE + 12, 3.4], [112, PIPE - 6, 7.0]]

## --- its colours --------------------------------------------------------------
const BRASS := Color(0.85, 0.63, 0.30)
const BRASS_LIT := Color(0.99, 0.87, 0.54)
const BRASS_SHADE := Color(0.62, 0.41, 0.21)
const BRASS_DARK := Color(0.38, 0.23, 0.13)
const UMBER := Color(0.19, 0.11, 0.075)
const COPPER := Color(0.80, 0.44, 0.27)
const WOOD := Color(0.37, 0.22, 0.13)
const WOOD_LIT := Color(0.52, 0.33, 0.20)
const GLASS := Color(0.20, 0.40, 0.84)
const GLASS_LIT := Color(0.52, 0.80, 0.99)
const TEAL := Color(0.20, 0.70, 0.68)
const CREAM := Color(0.97, 0.93, 0.82)
const STEEL := Color(0.66, 0.70, 0.77)
const STEEL_LIT := Color(0.95, 0.98, 1.0)
const VIOLET := Color(0.74, 0.46, 1.0)
const CRYSTAL := Color(0.36, 0.62, 1.0)
const LAMP := Color(1.0, 0.88, 0.52)
## The day, from overhead down to the haze the city stands in.
const SKY := [
	Color(0.27, 0.53, 0.87),
	Color(0.32, 0.59, 0.90),
	Color(0.38, 0.65, 0.92),
	Color(0.45, 0.71, 0.94),
	Color(0.53, 0.77, 0.95),
	Color(0.62, 0.83, 0.96),
	Color(0.71, 0.88, 0.97),
	Color(0.80, 0.92, 0.97),
	Color(0.88, 0.94, 0.95),
	Color(0.94, 0.93, 0.89),
]
const CLOUD := Color(1.0, 1.0, 1.0)
const CLOUD_WARM := Color(0.99, 0.95, 0.86)
const CLOUD_SHADE := Color(0.94, 0.82, 0.72)
const CITY_FAR := Color(0.80, 0.80, 0.85)
const CITY_MID := Color(0.86, 0.78, 0.70)
const CITY_NEAR := Color(0.77, 0.63, 0.50)
const CITY_DARK := Color(0.57, 0.43, 0.36)
## The gate's light: when it would take you, and when it would not.
const OPEN := Color(0.30, 1.0, 0.62)
const SHUT := Color(1.0, 0.26, 0.22)

## Back to front. `_drift` is what moves out in the sky and over the city, and
## is not slid: what it draws on a depth it draws where that depth has got to.
var _sky: Layer
var _bank: Layer
var _far: Layer
var _near: Layer
var _drift: Layer
var _room: Layer
var _room_life: Layer
var _fittings: Layer
var _life: Layer

## The heaped cloud along the horizon, as the rounds it is made of:
## `{x, y, r}`. And the clouds going over, each `{y, speed, from, wide,
## rows}`: `y` is the foot of it, and a row is `[down, left, right]` from
## there.
var _heap: Array = []
var _clouds: Array = []
## The city, far and near: each building `{x, w, h, kind, salt}`.
var _far_city: Array = []
var _near_city: Array = []
## The chimneys of the nearer city that are smoking: `{x, y}`.
var _chimneys: Array = []

func _build() -> void:
	plate = Color(0.17, 0.10, 0.07)
	ink = Color(0.82, 0.61, 0.30)
	ink_lit = Color(1.0, 0.91, 0.58)
	# Dark, since it is written over the sky and over brass in the sun.
	ink_shut = Color(0.74, 0.10, 0.10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xB4A5
	var x := VIEW_LEFT - 8
	while x < VIEW_RIGHT + 8:
		var r := rng.randi_range(13, 25)
		_heap.append({"x": x, "y": 214 - rng.randi_range(0, 16), "r": r})
		if rng.randf() < 0.6:
			_heap.append({"x": x + rng.randi_range(-6, 8), "y": 196 - rng.randi_range(0, 18), "r": rng.randi_range(9, 16)})
		x += rng.randi_range(15, 27)
	for cloud in [[98, 2.2, 0.0, 2, 13], [140, 1.3, 190.0, 3, 15], [80, 3.0, 330.0, 1, 9], [166, 0.9, 80.0, 2, 10]]:
		var made := _cloud(rng, cloud[3], cloud[4])
		_clouds.append({"y": cloud[0], "speed": cloud[1], "from": cloud[2], "wide": made["wide"], "rows": made["rows"]})
	_far_city = _raise(rng, 9, 22, 28, 62)
	_near_city = _raise(rng, 12, 30, 18, 46)
	for b in _near_city:
		if int(b["kind"]) == 0 and rng.randf() < 0.5:
			_chimneys.append({"x": int(b["x"]) + int(b["w"]) - 3, "y": HORIZON - int(b["h"]) - 4})
	_sky = still(_paint_sky)
	_bank = still(_paint_bank)
	_far = still(_paint_far)
	_near = still(_paint_near)
	_drift = moving(_paint_drift)
	_room = still(_paint_room)
	_hang_lamps()
	_room_life = moving(_paint_room_life)
	_fittings = still(_paint_fittings)
	_life = moving(_paint_life)

## What is out past the arches slides a little as the player walks the room,
## the nearer of the city furthest and the sky not at all: whole pixels of
## the buffer, and never more than SLIDE of them.
func _slide(across: float) -> void:
	_bank.position.x = slid(across, 1.0)
	_far.position.x = slid(across, 2.0)
	_near.position.x = slid(across, float(SLIDE))

## How far a depth has slid, in pixels of the buffer.
func _off(depth: Layer) -> int:
	return int(round(depth.position.x / S))

## Something that is the same for `k` every time and has no pattern to it.
static func _odd(k: int, salt: int = 0) -> int:
	return absi((k * 73856093) ^ ((k + salt) * 19349663) ^ (salt * 83492791)) % 1000

## A box of something out there, cut off where the drawn stretch of it ends
## and under the band the arches hang from.
static func _out_there(c: CanvasItem, x: int, y: int, w: int, h: int, col: Color) -> void:
	var from := maxi(x, VIEW_LEFT)
	var top := maxi(y, FRIEZE)
	box(c, from, top, mini(x + w, VIEW_RIGHT) - from, mini(y + h, FLOOR) - top, col)

## A round of the same, a row at a time.
static func _round(c: CanvasItem, cx: int, cy: int, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		var half := int(floor(sqrt(float(r * r - dy * dy) + 0.5)))
		_out_there(c, cx - half, cy + dy, half * 2 + 1, 1, col)

## How high the arch between the columns at `from` and `to` stands over the
## column `x`: half an oval, from one column's head to the next.
static func _arch(from: int, to: int, x: int) -> int:
	var half := float(to - from) * 0.5
	var out := (float(x) + 0.5 - (float(from) + half)) / half
	return SPRING - int(round(float(RISE) * sqrt(maxf(1.0 - out * out, 0.0))))

## A cloud to go over: a round in the middle of it, lower ones shouldered up
## either side, all on a flat foot — kept as the row of pixels each line of it
## covers.
func _cloud(rng: RandomNumberGenerator, shoulders: int, big: int) -> Dictionary:
	var middle := big + shoulders * big * 8 / 10
	var rounds: Array = [[middle + rng.randi_range(-3, 3), big]]
	for side: int in [-1, 1]:
		for k in range(1, shoulders + 1):
			var r := maxi(big * (10 - k * 3) / 10 + rng.randi_range(-1, 2), 4)
			rounds.append([middle + side * (k * big * 8 / 10 + rng.randi_range(-2, 2)), r])
	var left := {}
	var right := {}
	for puff in rounds:
		var cx: int = puff[0]
		var r: int = puff[1]
		# Each stands on the foot: a third of it is under, and is not there.
		var cy := -r * 2 / 3
		for dy in range(-r, r * 2 / 3 + 1):
			var half := int(floor(sqrt(float(r * r - dy * dy) + 0.5)))
			var row := cy + dy
			left[row] = mini(int(left.get(row, 9999)), cx - half)
			right[row] = maxi(int(right.get(row, -9999)), cx + half)
	var rows: Array = []
	var downs := left.keys()
	downs.sort()
	for i in downs.size():
		var row: int = downs[i]
		# The foot of it is flat, and rounds under at either end.
		var under := maxi(3 - (downs.size() - 1 - i), 0) * 2
		rows.append([row, int(left[row]) + under, int(right[row]) - under])
	return {"wide": middle * 2, "rows": rows}

## A depth of the city across the view: buildings side by side, most of them
## plain, some domed, some with a spire or a pointed roof.
func _raise(rng: RandomNumberGenerator, narrow: int, wide: int, low: int, high: int) -> Array:
	var out: Array = []
	var x := VIEW_LEFT
	while x < VIEW_RIGHT:
		var w := rng.randi_range(narrow, wide)
		var roll := rng.randf()
		out.append({"x": x, "w": w, "h": rng.randi_range(low, high), "salt": rng.randi() % 1000,
			"kind": 1 if roll < 0.16 else (2 if roll < 0.30 else (3 if roll < 0.44 else 0))})
		x += w + (rng.randi_range(0, 2) if rng.randf() < 0.4 else 0)
	return out

## --- out past the arches -----------------------------------------------------

func _paint_sky(c: CanvasItem) -> void:
	bands(c, TOWER, FRIEZE, BAY_LEFT - TOWER, FLOOR - FRIEZE, SKY)
	# A few high wisps, which do not go anywhere.
	for wisp in [[84, 70, 40], [176, 84, 26], [262, 66, 48], [352, 78, 34], [300, 96, 22], [118, 100, 30]]:
		_out_there(c, wisp[0], wisp[1], wisp[2], 1, faded(CLOUD, 0.55))
		_out_there(c, int(wisp[0]) + 5, int(wisp[1]) + 1, int(wisp[2]) - 12, 1, faded(CLOUD, 0.4))

## The cloud heaped along the horizon: white where the sun is on it, and warm
## underneath.
func _paint_bank(c: CanvasItem) -> void:
	for p in _heap:
		_round(c, int(p["x"]), int(p["y"]) + 5, int(p["r"]), CLOUD_SHADE)
	_out_there(c, VIEW_LEFT, 222, VIEW_RIGHT - VIEW_LEFT, FLOOR - 222, CLOUD_SHADE)
	for p in _heap:
		_round(c, int(p["x"]), int(p["y"]), int(p["r"]), CLOUD_WARM)
	for p in _heap:
		_round(c, int(p["x"]) - 2, int(p["y"]) - 3, int(p["r"]) - 4, CLOUD)
	# The haze it goes down into.
	for k in 6:
		_out_there(c, VIEW_LEFT, 230 + k * 12, VIEW_RIGHT - VIEW_LEFT, 12, faded(SKY[9], 0.16 + 0.10 * k))

func _paint_far(c: CanvasItem) -> void:
	_city(c, _far_city, CITY_FAR, CITY_FAR.lightened(0.10), CITY_FAR.darkened(0.08), false)
	for k in 4:
		_out_there(c, VIEW_LEFT, 270 + k * 8, VIEW_RIGHT - VIEW_LEFT, 8, faded(SKY[9], 0.14 + 0.10 * k))

func _paint_near(c: CanvasItem) -> void:
	_city(c, _near_city, CITY_NEAR, CITY_MID, CITY_DARK, true)
	# The great dome, and the tower with the clock on it: every city has one
	# of each.
	var dome := 194
	_out_there(c, dome - 22, HORIZON - 30, 44, 30, CITY_NEAR)
	_out_there(c, dome - 22, HORIZON - 30, 2, 30, CITY_MID)
	for col in range(dome - 18, dome + 18, 6):
		_out_there(c, col, HORIZON - 26, 2, 22, CITY_DARK)
	_out_there(c, dome - 24, HORIZON - 32, 48, 2, CITY_MID)
	for up in range(0, 21):
		var half := int(floor(sqrt(float(400 - up * up) + 0.5)))
		_out_there(c, dome - half, HORIZON - 32 - up, half * 2 + 1, 1, CITY_NEAR.lerp(COPPER, 0.25))
		_out_there(c, dome - half, HORIZON - 32 - up, maxi(half / 3, 1), 1, CITY_MID)
	for rib in [-12, -6, 0, 6, 12]:
		_out_there(c, dome + rib, HORIZON - 50 + absi(rib) / 2, 1, 18 - absi(rib) / 2, CITY_DARK)
	_out_there(c, dome - 3, HORIZON - 58, 7, 6, CITY_NEAR)
	_out_there(c, dome - 4, HORIZON - 59, 9, 1, CITY_MID)
	_out_there(c, dome, HORIZON - 70, 1, 11, CITY_DARK)
	var tower := 372
	_out_there(c, tower - 6, HORIZON - 74, 12, 74, CITY_NEAR)
	_out_there(c, tower - 6, HORIZON - 74, 2, 74, CITY_MID)
	_out_there(c, tower + 4, HORIZON - 74, 2, 74, CITY_DARK)
	_out_there(c, tower - 8, HORIZON - 76, 16, 2, CITY_MID)
	for up in 14:
		_out_there(c, tower - 7 + up / 2, HORIZON - 77 - up, 14 - up, 1, CITY_DARK)
	_out_there(c, tower, HORIZON - 98, 1, 8, CITY_DARK)
	_round(c, tower, HORIZON - 62, 4, CREAM)
	_out_there(c, tower, HORIZON - 65, 1, 4, CITY_DARK)
	_out_there(c, tower, HORIZON - 62, 3, 1, CITY_DARK)
	for win in [HORIZON - 48, HORIZON - 36, HORIZON - 24]:
		_out_there(c, tower - 2, win, 2, 4, CITY_DARK)
		_out_there(c, tower + 1, win, 2, 4, CITY_DARK)
	# What the haze leaves of its streets.
	_out_there(c, VIEW_LEFT, HORIZON, VIEW_RIGHT - VIEW_LEFT, FLOOR - HORIZON, CITY_NEAR.lerp(SKY[9], 0.25))

## A depth of the city: each building's body, the side the sun is on, its
## roof, and — on the nearer of them — its windows.
func _city(c: CanvasItem, buildings: Array, body: Color, lit: Color, dark: Color, windows: bool) -> void:
	for b in buildings:
		var x: int = b["x"]
		var w: int = b["w"]
		var top: int = HORIZON - int(b["h"])
		var salt: int = b["salt"]
		_out_there(c, x, top, w, HORIZON - top, body)
		_out_there(c, x, top, maxi(w / 6, 1), HORIZON - top, lit)
		_out_there(c, x + w - maxi(w / 7, 1), top, maxi(w / 7, 1), HORIZON - top, dark)
		_out_there(c, x - 1, top, w + 2, 1, lit)
		match int(b["kind"]):
			1:
				# A dome, on its drum, with a point on top.
				var r := maxi(w / 2 - 1, 3)
				for up in range(0, r + 1):
					var half := int(floor(sqrt(float(r * r - up * up) + 0.5)))
					_out_there(c, x + w / 2 - half, top - up, half * 2 + 1, 1, body)
					_out_there(c, x + w / 2 - half, top - up, maxi(half / 3, 1), 1, lit)
				_out_there(c, x + w / 2, top - r - 5, 1, 5, dark)
			2:
				# A spire.
				for up in 16:
					_out_there(c, x + w / 2 - (15 - up) / 5, top - up - 1, 1 + (15 - up) * 2 / 5, 1, body)
				_out_there(c, x + w / 2, top - 21, 1, 5, dark)
			3:
				# A pointed roof.
				for up in range(0, w / 2 + 1):
					_out_there(c, x + up, top - up - 1, w - up * 2, 1, dark)
			_:
				if w > 14 and salt % 3 == 0:
					_out_there(c, x + 3, top - 4, 3, 4, body)
					_out_there(c, x + w - 6, top - 6, 2, 6, body)
		if not windows:
			continue
		for wy in range(top + 4, HORIZON - 4, 6):
			for wx in range(x + 3, x + w - 3, 4):
				if _odd(wx * 7 + wy, salt) % 4 != 0:
					_out_there(c, wx, wy, 2, 3, dark)

## What moves out there: the clouds going over, an airship or two, the birds,
## and the smoke off the city's chimneys.
func _paint_drift(c: CanvasItem) -> void:
	var span := VIEW_RIGHT - VIEW_LEFT
	for cloud in _clouds:
		var wide: int = cloud["wide"]
		var x := VIEW_LEFT - wide + int(fmod(float(cloud["from"]) + _t * float(cloud["speed"]), float(span + wide)))
		var y: int = cloud["y"]
		var rows: Array = cloud["rows"]
		for i in rows.size():
			var row: Array = rows[i]
			var tone := CLOUD
			if i >= rows.size() - 3:
				tone = CLOUD_SHADE
			elif i >= rows.size() * 6 / 10:
				tone = CLOUD_WARM
			_out_there(c, x + int(row[1]), y + int(row[0]), int(row[2]) - int(row[1]) + 1, 1, tone)
	# The big airship, going one way, and a small one a long way off, going
	# the other.
	var along := fmod(_t * 4.0 + 120.0, float(span + 90))
	_airship(c, VIEW_RIGHT + 30 - int(along), 124 + int(round(sin(_t * 0.4) * 2.0)), 1.0, -1)
	along = fmod(_t * 1.6 + 40.0, float(span + 50))
	_airship(c, VIEW_LEFT - 24 + int(along), 168, 0.45, 1)
	# Birds.
	var flock := fmod(_t * 7.0, float(span + 80))
	for k in 5:
		var bx := VIEW_LEFT - 30 + int(flock) + k * 7 - absi(k - 2) * 2
		var by := 86 + absi(k - 2) * 4 + int(round(sin(_t * 0.7 + k) * 2.0))
		var up := int(_t * 4.0 + k) % 2 == 0
		_out_there(c, bx, by, 1, 1, UMBER)
		_out_there(c, bx - 1, by - (1 if up else 0), 1, 1, UMBER)
		_out_there(c, bx + 1, by - (1 if up else 0), 1, 1, UMBER)
	# Smoke.
	var near := _off(_near)
	for chimney in _chimneys:
		for k in 4:
			var rise := fmod(_t * 0.22 + k * 0.25 + float(int(chimney["x"]) % 7) * 0.1, 1.0)
			_out_there(c, int(chimney["x"]) + near + int(rise * 9.0), int(chimney["y"]) - int(rise * 22.0),
				2 + int(rise * 3.0), 2, faded(CLOUD, 0.5 * (1.0 - rise)))

## An airship, by the middle of its bag: `big` of full size, and going
## `heading` across.
func _airship(c: CanvasItem, x: int, y: int, big: float, heading: int) -> void:
	var rx := int(26.0 * big)
	var ry := maxi(int(9.0 * big), 2)
	var bag := BRASS.lerp(SKY[8], 1.0 - big * 0.8)
	var rib := BRASS_SHADE.lerp(SKY[8], 1.0 - big * 0.8)
	for dy in range(-ry, ry + 1):
		var half := int(floor(float(rx) * sqrt(maxf(1.0 - float(dy * dy) / float(ry * ry), 0.0)) + 0.5))
		_out_there(c, x - half, y + dy, half * 2 + 1, 1, bag if dy < ry / 3 else rib)
	if big < 0.7:
		_out_there(c, x - 2, y + ry + 1, 5, 1, rib)
		return
	for band in [-14, -5, 5, 14]:
		_out_there(c, x + band, y - ry + 2 + absi(band) / 6, 1, ry * 2 - 3 - absi(band) / 3, rib)
	_out_there(c, x - rx + 4, y - ry + 2, rx + 4, 1, BRASS_LIT.lerp(SKY[8], 0.2))
	# Its fins, at the end it is not going towards.
	var tail := x - heading * (rx - 1)
	for k in 6:
		_out_there(c, tail - heading * k if heading < 0 else tail - k, y - 7 + k, k + 2, 1, COPPER)
		_out_there(c, tail - heading * k if heading < 0 else tail - k, y + 7 - k, k + 2, 1, COPPER.darkened(0.2))
	# The car slung under it, and the screw behind that.
	_out_there(c, x - 8, y + ry + 2, 16, 4, BRASS_DARK)
	_out_there(c, x - 8, y + ry + 2, 16, 1, BRASS_SHADE)
	for port in [-5, -1, 3]:
		_out_there(c, x + port, y + ry + 3, 2, 2, GLASS_LIT)
	_out_there(c, x - 5, y + ry, 1, 2, UMBER)
	_out_there(c, x + 5, y + ry, 1, 2, UMBER)
	var screw := x - heading * 10
	if int(_t * 14.0) % 2 == 0:
		_out_there(c, screw, y + ry + 1, 1, 6, UMBER)
	else:
		_out_there(c, screw, y + ry + 3, 1, 2, UMBER)

## --- the terrace ----------------------------------------------------------------

func _paint_room(c: CanvasItem) -> void:
	_paint_roof(c)
	_paint_arches(c)
	_paint_tower(c)
	_paint_bay(c)
	_paint_balustrade(c)
	_paint_columns(c)
	_paint_pipe(c)
	_paint_floor(c)

## What stands on the terrace.
func _paint_fittings(c: CanvasItem) -> void:
	_paint_trunks(c)
	_paint_rack(c, _at["weapons"])
	_paint_stall(c, _at["shop"])
	_paint_gate(c, _at["gate"])

## Overhead: the roof in coffers, and under it the band of ornament the
## arches hang from.
func _paint_roof(c: CanvasItem) -> void:
	box(c, LEFT, TOP, RIGHT - LEFT, ROOF - TOP, BRASS_DARK)
	for x in range(LEFT + 6, RIGHT - 30, 38):
		box(c, x, TOP + 3, 32, 17, UMBER.lightened(0.04))
		box(c, x, TOP + 3, 32, 1, UMBER)
		box(c, x, TOP + 19, 32, 1, BRASS_SHADE)
		box(c, x + 31, TOP + 3, 1, 17, BRASS_SHADE.darkened(0.2))
		box(c, x + 14, TOP + 9, 4, 4, BRASS_SHADE)
		box(c, x + 15, TOP + 10, 2, 2, BRASS_LIT)
	box(c, LEFT, ROOF - 3, RIGHT - LEFT, 3, BRASS_SHADE)
	box(c, LEFT, ROOF, RIGHT - LEFT, FRIEZE - ROOF, BRASS)
	box(c, LEFT, ROOF, RIGHT - LEFT, 2, BRASS_LIT)
	box(c, LEFT, ROOF + 2, RIGHT - LEFT, 1, BRASS_SHADE)
	box(c, LEFT, FRIEZE - 4, RIGHT - LEFT, 1, BRASS_SHADE)
	box(c, LEFT, FRIEZE - 1, RIGHT - LEFT, 1, BRASS_DARK)
	for x in range(LEFT + 5, RIGHT - 6, 12):
		disc(c, x + 3, ROOF + 7, 2, BRASS_SHADE)
		box(c, x + 3, ROOF + 6, 1, 1, BRASS_LIT)
		box(c, x + 8, ROOF + 6, 2, 3, BRASS_SHADE)
	for x in range(LEFT + 2, RIGHT - 3, 6):
		box(c, x, FRIEZE - 3, 3, 2, BRASS_SHADE)

## The arches: what is solid of each, between the curve of it and the band
## over it, with the moulding round the curve and a wheel let into the
## corners for show.
func _paint_arches(c: CanvasItem) -> void:
	for span in ARCHES:
		var from: int = span[0]
		var to: int = span[1]
		var x := from
		while x < to:
			var top := _arch(from, to, x)
			var run := 1
			while x + run < to and _arch(from, to, x + run) == top:
				run += 1
			box(c, x, FRIEZE, run, top - FRIEZE, BRASS_SHADE)
			x += run
		for col in range(from, to):
			var top := _arch(from, to, col)
			var meets := maxi(_arch(from, to, maxi(col - 1, from)), _arch(from, to, mini(col + 1, to - 1)))
			box(c, col, top - 3, 1, 2, BRASS)
			box(c, col, top - 1, 1, 1 + maxi(meets - top, 0), BRASS_LIT)
			box(c, col, top - 4, 1, 1, BRASS_DARK)
			# A bead hung from it, every so often along the flat of it.
			if (col - from) % 9 == 4 and meets - top < 2:
				box(c, col, top, 1, 2, BRASS_SHADE)
				box(c, col, top + 2, 1, 1, BRASS_LIT)
		for corner in [from + 13, to - 14]:
			_wheel(c, corner, FRIEZE + 15, 9, BRASS, BRASS_DARK)
			_teeth(c, corner, FRIEZE + 15, 9, 8, 0.3, BRASS)
		# The boss at the top of it, which a lamp hangs from.
		var mid := (from + to) / 2
		box(c, mid - 4, FRIEZE, 8, 5, BRASS_LIT)
		box(c, mid - 3, FRIEZE + 5, 6, 2, BRASS)
		box(c, mid - 4, FRIEZE, 8, 1, CREAM)

## The lamps in the arches, each hung from its arch's boss on a chain of its
## own (`cord`) with the lamp riding the end, so it swings when something goes
## through it — a bolt, a blade: they hang over anybody's head.
func _hang_lamps() -> void:
	for lamp: Array in LAMPS:
		ride(cord(Vector2i(lamp[0], lamp[1]), lamp[2], UMBER),
			hung(_paint_lamp.bind(String(lamp[3])), true), LAMP_BODY)

## A lamp on the end of its chain, about the pixel it hangs by: lit when the
## `station` under it would answer.
func _paint_lamp(c: CanvasItem, station: String) -> void:
	var on := float(_lit.get(station, 0.0))
	box(c, -3, 0, 7, 2, BRASS_DARK)
	box(c, -4, 2, 9, 9, UMBER)
	box(c, -3, 3, 7, 7, CREAM.darkened(0.25).lerp(LAMP, on))
	box(c, -3, 3, 2, 7, CREAM.darkened(0.1).lerp(Color.WHITE, on))
	box(c, 0, 3, 1, 7, UMBER)
	box(c, -2, 11, 5, 1, BRASS_DARK)
	box(c, 0, 12, 1, 2, BRASS_DARK)
	if on > 0.0:
		halo(c, -3, 3, 7, 7, LAMP, 4, 0.10 * on)

## A wheel's body: a round of metal with a darker ring let into it.
func _wheel(c: CanvasItem, cx: int, cy: int, r: int, metal: Color, dark: Color) -> void:
	disc(c, cx, cy, r - 1, metal)
	disc(c, cx, cy, r - 3, dark, maxi(r - 5, 1))
	disc(c, cx, cy, 2, dark)

## A wheel's teeth, and the holes through it, at the turn it has come to.
func _teeth(c: CanvasItem, cx: int, cy: int, r: int, count: int, turn: float, metal: Color) -> void:
	for k in count:
		var a := turn + TAU * k / float(count)
		box(c, cx + int(round(cos(a) * float(r))) - 1, cy + int(round(sin(a) * float(r))) - 1, 3, 3, metal)
	if r < 9:
		return
	for k in 4:
		var a := turn + TAU * k / 4.0
		box(c, cx + int(round(cos(a) * float(r) * 0.5)) - 1, cy + int(round(sin(a) * float(r) * 0.5)) - 1, 2, 2, UMBER)

## The tower's own wall, at the left: plate, riveted, with a window in
## coloured glass and a wheel to shut the steam off.
func _paint_tower(c: CanvasItem) -> void:
	box(c, LEFT, FRIEZE, TOWER - LEFT, FLOOR - FRIEZE, BRASS_SHADE)
	box(c, LEFT, FRIEZE, 1, FLOOR - FRIEZE, BRASS)
	for y in [100, 212, 262]:
		box(c, LEFT, y, TOWER - LEFT, 1, BRASS_DARK)
		box(c, LEFT, y + 1, TOWER - LEFT, 1, BRASS)
	for y in range(FRIEZE + 6, FLOOR - 4, 9):
		box(c, LEFT + 2, y, 1, 1, BRASS_LIT)
		box(c, TOWER - 3, y, 1, 1, BRASS_LIT)
	# The window: a lancet, leaded, in the colours glass comes in.
	var wx := LEFT + 7
	var panes := [GLASS, GLASS.lightened(0.18), TEAL, GLASS.darkened(0.15), VIOLET.darkened(0.25), GLASS_LIT.darkened(0.2)]
	for row in range(0, 86):
		var y := 118 + row
		var inset := maxi(8 - row, 0) * 7 / 8
		box(c, wx + inset, y, 16 - inset * 2, 1, UMBER)
		if inset < 7:
			box(c, wx + inset + 1, y, 14 - inset * 2, 1, panes[(row / 7 + (row / 3) % 2) % panes.size()])
	box(c, wx + 7, 120, 2, 84, UMBER)
	for y in range(132, 204, 14):
		box(c, wx + 1, y, 14, 1, UMBER)
	for k in 10:
		box(c, wx + 3 + (k % 3) * 4, 128 + k * 7, 2, 2, GLASS_LIT)
	box(c, wx - 1, 204, 18, 3, BRASS)
	box(c, wx - 1, 204, 18, 1, BRASS_LIT)
	# The wheel.
	disc(c, LEFT + 15, 244, 6, SHUT.darkened(0.3), 4)
	box(c, LEFT + 15, 239, 1, 11, SHUT.darkened(0.3))
	box(c, LEFT + 10, 244, 11, 1, SHUT.darkened(0.3))
	box(c, LEFT + 14, 243, 3, 3, BRASS_LIT)

## The gate's bay: the tower's front. The great clock and the wheels beside
## it, the board of lamps under that, a weight swinging in its case, and the
## boiler that drives the lot. What turns, swings and is lit is
## `_paint_room_life`'s.
func _paint_bay(c: CanvasItem) -> void:
	var wall := BRASS_SHADE.lerp(BRASS, 0.4)
	box(c, BAY_LEFT, FRIEZE, RIGHT - BAY_LEFT, FLOOR - FRIEZE, wall)
	box(c, BAY_LEFT, PIPE + 2, RIGHT - BAY_LEFT, FLOOR - PIPE - 2, wall.darkened(0.14))
	for x in [486, 532, 578]:
		box(c, x, FRIEZE, 1, FLOOR - FRIEZE, BRASS_DARK)
		box(c, x + 1, FRIEZE, 1, FLOOR - FRIEZE, BRASS_LIT.darkened(0.15))
	for y in [146, 210]:
		box(c, BAY_LEFT, y, RIGHT - BAY_LEFT, 1, BRASS_DARK)
		box(c, BAY_LEFT, y + 1, RIGHT - BAY_LEFT, 1, BRASS_LIT.darkened(0.15))
	for y in range(FRIEZE + 5, FLOOR - 6, 10):
		for x in [BAY_LEFT + 3, 483, 529, 575, RIGHT - 4]:
			box(c, x, y, 1, 1, BRASS_LIT)
	# The clock: its case, its face, and the hours round it.
	disc(c, CLOCK.x, CLOCK.y, 31, BRASS_DARK)
	disc(c, CLOCK.x, CLOCK.y, 30, BRASS_LIT)
	disc(c, CLOCK.x, CLOCK.y, 28, BRASS)
	disc(c, CLOCK.x, CLOCK.y, 26, BRASS_SHADE)
	disc(c, CLOCK.x, CLOCK.y, 24, CREAM)
	disc(c, CLOCK.x, CLOCK.y, 24, CREAM.darkened(0.10), 22)
	for hour in 12:
		var a := TAU * hour / 12.0
		var long := 3 if hour % 3 == 0 else 2
		box(c, CLOCK.x + int(round(sin(a) * 19.0)) - 1, CLOCK.y - int(round(cos(a) * 19.0)) - 1, long, long, UMBER)
	disc(c, CLOCK.x, CLOCK.y, 9, CREAM.darkened(0.06), 8)
	for k in 8:
		var a := TAU * k / 8.0 + 0.39
		box(c, CLOCK.x + int(round(cos(a) * 29.0)), CLOCK.y + int(round(sin(a) * 29.0)), 1, 1, BRASS_DARK)
	# The wheels' bodies, on the plate they are pinned to.
	box(c, 530, 72, 86, 46, wall.darkened(0.22))
	box(c, 530, 72, 86, 1, BRASS_DARK)
	box(c, 530, 117, 86, 1, BRASS_LIT.darkened(0.2))
	for i in WHEELS.size():
		var w: Array = WHEELS[i]
		_wheel(c, w[0], w[1], w[2], COPPER if i % 2 == 1 else BRASS, BRASS_DARK)
	# The board of lamps: a plate, with a socket for every room.
	box(c, BOARD.x - 1, BOARD.y - 1, 68, 58, BRASS_DARK)
	box(c, BOARD.x, BOARD.y, 66, 56, BRASS_LIT)
	box(c, BOARD.x + 2, BOARD.y + 2, 62, 52, UMBER.lightened(0.03))
	for r: Vector2i in ROOMS:
		for step in [Vector2i(1, 0), Vector2i(0, 1)]:
			if ROOMS.has(r + step):
				if step.x == 1:
					box(c, BOARD.x + 5 + r.x * 8 + 5, BOARD.y + 9 + r.y * 7 + 2, 3, 1, BRASS_DARK)
				else:
					box(c, BOARD.x + 5 + r.x * 8 + 2, BOARD.y + 9 + r.y * 7 + 5, 1, 2, BRASS_DARK)
	for corner in [Vector2i(3, 3), Vector2i(62, 3), Vector2i(3, 52), Vector2i(62, 52)]:
		box(c, BOARD.x + corner.x, BOARD.y + corner.y, 1, 1, BRASS_LIT)
	# The weight, in its case of glass.
	box(c, 561, 138, 38, 68, BRASS_DARK)
	box(c, 562, 139, 36, 66, BRASS)
	box(c, 564, 141, 32, 62, Color(0.10, 0.17, 0.20))
	box(c, 564, 141, 32, 1, UMBER)
	for k in 9:
		box(c, 566 + k, 144 + k * 5, 4, 5, Color(0.80, 0.92, 1.0, 0.05))
	# The boiler: a drum of copper, strapped, with its glass and its fire
	# door, and the pipe up from it.
	var bx := 450
	box(c, bx + 13, PIPE, 3, 26, BRASS_SHADE)
	box(c, bx + 13, PIPE, 1, 26, BRASS_LIT)
	for up in range(0, 15):
		var half := int(floor(sqrt(float(196 - up * up) + 0.5)))
		box(c, bx + 14 - half, 264 - up, half * 2 + 1, 1, COPPER.darkened(0.12))
		box(c, bx + 14 - half, 264 - up, maxi(half / 3, 1), 1, COPPER.lightened(0.2))
	box(c, bx, 264, 29, FLOOR - 264, COPPER.darkened(0.12))
	box(c, bx, 264, 5, FLOOR - 264, COPPER.lightened(0.2))
	box(c, bx + 5, 264, 4, FLOOR - 264, COPPER)
	box(c, bx + 23, 264, 6, FLOOR - 264, COPPER.darkened(0.4))
	for strap in [266, 288, 312]:
		box(c, bx - 1, strap, 31, 3, BRASS)
		box(c, bx - 1, strap, 31, 1, BRASS_LIT)
		for rivet in [bx + 3, bx + 12, bx + 21]:
			box(c, rivet, strap + 1, 1, 1, BRASS_DARK)
	disc(c, bx + 14, 278, 5, BRASS_DARK)
	disc(c, bx + 14, 278, 4, CREAM)
	box(c, bx + 7, 296, 15, 12, UMBER)
	box(c, bx + 7, 296, 15, 1, BRASS_DARK)
	box(c, bx + 21, 300, 2, 4, BRASS_LIT)
	# And pipes up the far corner.
	for px in [606, 613]:
		box(c, px, PIPE + 2, 4, FLOOR - PIPE - 2, BRASS_SHADE)
		box(c, px, PIPE + 2, 1, FLOOR - PIPE - 2, BRASS_LIT)
		for y in range(PIPE + 16, FLOOR - 6, 30):
			box(c, px - 1, y, 6, 3, BRASS)

## The balustrade along the terrace's far edge: a rail, a foot, a post every
## so often with a ball on it, and the turned balusters between.
func _paint_balustrade(c: CanvasItem) -> void:
	var from := TOWER + 14
	var to := BAY_LEFT - 14
	box(c, from, FLOOR - 6, to - from, 6, BRASS_SHADE)
	box(c, from, FLOOR - 6, to - from, 1, BRASS_LIT)
	for x in range(from + 4, to - 5, 8):
		picture(c, x, RAIL + 5, [
			".LBD.",
			"LBBBD",
			".LBD.",
			"..B..",
			"..B..",
			".LBD.",
			".LBD.",
			"LBBBD",
			"LBBBD",
			"LBBBD",
			"LBBBD",
			"LBBBD",
			".LBD.",
			".LBD.",
			"..B..",
			"..B..",
			"..B..",
			"..B..",
			".LBD.",
			"LBBBD",
			".LBD.",
			"..B..",
			"..B..",
			".LBD.",
			"LBBBD",
			"LBBBD",
			"LBBBD",
			".LBD.",
			"..B..",
			".LBD.",
			"LBBBD",
			"LBBBD",
			"LBBBD",
		], {"L": BRASS_LIT, "B": BRASS, "D": BRASS_SHADE})
	box(c, from, RAIL, to - from, 5, BRASS)
	box(c, from, RAIL, to - from, 2, BRASS_LIT)
	box(c, from, RAIL + 4, to - from, 1, BRASS_SHADE)
	for x in range(from + 61, to - 30, 61):
		box(c, x - 3, RAIL - 4, 7, FLOOR - RAIL + 4, BRASS)
		box(c, x - 3, RAIL - 4, 2, FLOOR - RAIL + 4, BRASS_LIT)
		box(c, x + 2, RAIL - 4, 2, FLOOR - RAIL + 4, BRASS_SHADE)
		box(c, x - 4, RAIL - 5, 9, 2, BRASS_LIT)
		disc(c, x, RAIL - 8, 3, BRASS)
		box(c, x - 1, RAIL - 10, 2, 2, BRASS_LIT)
		box(c, x - 4, FLOOR - 6, 9, 6, BRASS)
		box(c, x - 4, FLOOR - 6, 9, 1, BRASS_LIT)

## The columns: fluted, banded, with a head the arches spring from and a foot
## on the floor.
func _paint_columns(c: CanvasItem) -> void:
	for cx: int in COLUMNS:
		box(c, cx - 7, FRIEZE, 14, SPRING - FRIEZE, BRASS_SHADE)
		box(c, cx - 7, SPRING, 14, FLOOR - SPRING, BRASS)
		box(c, cx - 7, SPRING, 2, FLOOR - SPRING, BRASS_LIT)
		box(c, cx - 3, SPRING, 1, FLOOR - SPRING, BRASS_SHADE)
		box(c, cx + 1, SPRING, 2, FLOOR - SPRING, BRASS_SHADE)
		box(c, cx + 4, SPRING, 3, FLOOR - SPRING, BRASS_DARK)
		for y in range(SPRING + 40, FLOOR - 20, 44):
			box(c, cx - 8, y, 16, 4, BRASS)
			box(c, cx - 8, y, 16, 1, BRASS_LIT)
			box(c, cx - 8, y + 3, 16, 1, BRASS_DARK)
		# The head.
		box(c, cx - 8, SPRING + 6, 16, 3, BRASS_SHADE)
		box(c, cx - 10, SPRING + 2, 20, 4, BRASS)
		box(c, cx - 10, SPRING + 2, 3, 4, BRASS_LIT)
		box(c, cx - 12, SPRING - 2, 24, 4, BRASS)
		box(c, cx - 12, SPRING - 2, 24, 1, BRASS_LIT)
		box(c, cx + 8, SPRING - 1, 4, 3, BRASS_SHADE)
		disc(c, cx - 10, SPRING + 3, 2, BRASS_DARK)
		disc(c, cx + 9, SPRING + 3, 2, BRASS_DARK)
		box(c, cx - 10, SPRING + 3, 1, 1, BRASS_LIT)
		box(c, cx + 9, SPRING + 3, 1, 1, BRASS_LIT)
		# The foot.
		box(c, cx - 9, FLOOR - 10, 18, 4, BRASS)
		box(c, cx - 9, FLOOR - 10, 18, 1, BRASS_LIT)
		box(c, cx - 11, FLOOR - 6, 22, 6, BRASS)
		box(c, cx - 11, FLOOR - 6, 22, 1, BRASS_LIT)
		box(c, cx + 7, FLOOR - 5, 4, 5, BRASS_SHADE)

## The pipe run across the place, on its brackets, with its joints, a glass
## to read it by and a wheel to shut it. The stations' signs hang from it.
func _paint_pipe(c: CanvasItem) -> void:
	box(c, TOWER, PIPE - 5, RIGHT - TOWER, 5, COPPER)
	box(c, TOWER, PIPE - 5, RIGHT - TOWER, 1, COPPER.lightened(0.3))
	box(c, TOWER, PIPE - 1, RIGHT - TOWER, 1, COPPER.darkened(0.4))
	for x in range(TOWER + 26, RIGHT - 8, 44):
		box(c, x, PIPE - 6, 4, 7, BRASS)
		box(c, x, PIPE - 6, 1, 7, BRASS_LIT)
		box(c, x + 3, PIPE - 6, 1, 7, BRASS_SHADE)
	for cx: int in COLUMNS:
		box(c, cx - 9, PIPE - 7, 18, 9, BRASS_SHADE)
		box(c, cx - 9, PIPE - 7, 18, 1, BRASS_LIT)
		box(c, cx - 6, PIPE - 4, 2, 2, BRASS_LIT)
		box(c, cx + 4, PIPE - 4, 2, 2, BRASS_LIT)
	# The glass. Its needle is `_paint_room_life`'s.
	box(c, 181, PIPE - 14, 2, 9, BRASS_SHADE)
	disc(c, 182, PIPE - 19, 7, BRASS_DARK)
	disc(c, 182, PIPE - 19, 6, BRASS_LIT)
	disc(c, 182, PIPE - 19, 5, CREAM)
	for mark in 5:
		var a := -2.4 + mark * 0.6
		box(c, 182 + int(round(sin(a) * 4.0)), PIPE - 19 - int(round(cos(a) * 4.0)), 1, 1, UMBER)
	# The wheel.
	box(c, 271, PIPE - 11, 2, 6, BRASS_SHADE)
	disc(c, 272, PIPE - 14, 5, SHUT.darkened(0.2), 3)
	box(c, 272, PIPE - 18, 1, 9, SHUT.darkened(0.2))
	box(c, 268, PIPE - 14, 9, 1, SHUT.darkened(0.2))

## The floor: the terrace's own edge, worked along its face, with a strip of
## copper let in before the gate.
func _paint_floor(c: CanvasItem) -> void:
	box(c, LEFT, FLOOR, RIGHT - LEFT, UNDER - FLOOR, BRASS_SHADE)
	box(c, LEFT, FLOOR, RIGHT - LEFT, 2, BRASS_LIT)
	box(c, LEFT, FLOOR + 2, RIGHT - LEFT, 1, BRASS)
	box(c, LEFT, FLOOR + 3, RIGHT - LEFT, 1, BRASS_DARK)
	box(c, LEFT, FLOOR + 13, RIGHT - LEFT, 1, BRASS_LIT.darkened(0.15))
	box(c, LEFT, FLOOR + 14, RIGHT - LEFT, 2, BRASS_DARK)
	for x in range(LEFT + 4, RIGHT - 12, 16):
		oval(c, x + 8, FLOOR + 8, 5, 3, BRASS_DARK)
		oval(c, x + 8, FLOOR + 8, 3, 1, BRASS)
		box(c, x + 7, FLOOR + 7, 2, 1, BRASS_LIT)
		box(c, x, FLOOR + 8, 2, 2, BRASS_LIT)
	var g: Vector2i = _at["gate"]
	box(c, g.x - 40, FLOOR, 80, 2, COPPER)
	box(c, g.x - 40, FLOOR, 80, 1, COPPER.lightened(0.3))
	for rivet in range(g.x - 37, g.x + 38, 7):
		box(c, rivet, FLOOR + 1, 1, 1, BRASS_DARK)

## --- what stands on the terrace -------------------------------------------------

## Trunks, strapped, and a glass on three legs for looking at what goes over.
func _paint_trunks(c: CanvasItem) -> void:
	for trunk in [[176, 22, 18], [200, 16, 12], [180, 14, 10]]:
		var x: int = trunk[0]
		var w: int = trunk[1]
		var h: int = trunk[2]
		var y: int = FLOOR - h - (18 if h == 10 else 0)
		box(c, x - 1, y - 1, w + 2, h + 1, UMBER)
		box(c, x, y, w, h, WOOD)
		box(c, x, y, w, 2, WOOD_LIT)
		for strap in [x + 3, x + w - 5]:
			box(c, strap, y, 2, h, BRASS_SHADE)
			box(c, strap, y, 2, 1, BRASS_LIT)
		box(c, x + w / 2 - 1, y + 3, 3, 3, BRASS_LIT)
	var tx := 252
	line(c, tx, FLOOR - 28, tx - 9, FLOOR - 1, UMBER)
	line(c, tx, FLOOR - 28, tx + 9, FLOOR - 1, UMBER)
	box(c, tx, FLOOR - 28, 1, 28, UMBER)
	for k in 18:
		box(c, tx - 9 + k, FLOOR - 26 - k * 8 / 10, 3 if k < 12 else 4, 3 if k < 12 else 4, BRASS if k % 6 < 5 else BRASS_DARK)
	box(c, tx - 9, FLOOR - 25, 1, 2, BRASS_LIT)
	box(c, tx + 9, FLOOR - 42, 4, 1, BRASS_LIT)
	box(c, tx - 11, FLOOR - 26, 2, 3, UMBER)

## The rack: posts with a ball on each, a board between them with what there
## is to carry hung on it, a wheel over it for show, and the grindstone
## beside it. What is lit on it, and the stone going round, are
## `_paint_life`'s.
func _paint_rack(c: CanvasItem, at: Vector2i) -> void:
	var x := at.x - 27
	var y := at.y - 58
	box(c, x - 3, at.y - 6, 60, 6, UMBER)
	box(c, x - 2, at.y - 6, 58, 5, BRASS_SHADE)
	box(c, x - 2, at.y - 6, 58, 1, BRASS_LIT)
	box(c, x + 2, y + 5, 50, 48, UMBER)
	box(c, x + 3, y + 6, 48, 46, WOOD)
	for plank in [x + 15, x + 27, x + 39]:
		box(c, plank, y + 6, 1, 46, UMBER.lightened(0.05))
	for post in [x, x + 51]:
		box(c, post - 1, y + 2, 5, 51, UMBER)
		box(c, post, y + 2, 3, 50, BRASS)
		box(c, post, y + 2, 1, 50, BRASS_LIT)
		box(c, post + 2, y + 2, 1, 50, BRASS_SHADE)
		disc(c, post + 1, y, 2, BRASS)
		box(c, post, y - 1, 1, 1, BRASS_LIT)
	_wheel(c, x + 27, y + 4, 7, BRASS, BRASS_DARK)
	_teeth(c, x + 27, y + 4, 7, 8, 0.2, BRASS)
	box(c, x - 1, y + 4, 56, 4, UMBER)
	box(c, x - 1, y + 3, 56, 4, BRASS)
	box(c, x - 1, y + 3, 56, 1, BRASS_LIT)
	box(c, x - 1, y + 6, 56, 1, BRASS_SHADE)
	# A sword.
	box(c, x + 10, y + 11, 2, 24, STEEL)
	box(c, x + 10, y + 11, 1, 24, STEEL_LIT)
	box(c, x + 7, y + 35, 8, 1, BRASS_LIT)
	box(c, x + 10, y + 36, 2, 7, UMBER)
	box(c, x + 10, y + 43, 2, 2, BRASS_LIT)
	# An axe.
	box(c, x + 21, y + 11, 1, 34, WOOD_LIT)
	stamp(c, x + 18, y + 12, [".###.", "#####", "#####", "##.##", "#...#"], STEEL)
	box(c, x + 18, y + 13, 1, 2, STEEL_LIT)
	# A staff, with whatever that is in the claw at the end of it.
	box(c, x + 32, y + 16, 1, 29, BRASS_SHADE)
	stamp(c, x + 30, y + 10, ["#...#", "#...#", "#...#", ".#.#.", "..#.."], BRASS_LIT)
	# And a spanner, since something here always wants tightening.
	stamp(c, x + 40, y + 12, [
		"#...#",
		"#...#",
		"#####",
		".###.",
		"..#..",
		"..#..",
		"..#..",
		"..#..",
		"..#..",
		"..#..",
		"..#..",
		"..#..",
		"..#..",
		".###.",
		"#####",
		"#.#.#",
		"#...#",
	], STEEL.darkened(0.12))
	box(c, x + 40, y + 12, 1, 3, STEEL_LIT)
	for peg in [[x + 8, y + 22], [x + 19, y + 24], [x + 30, y + 26], [x + 40, y + 21]]:
		box(c, peg[0], peg[1], 6 if int(peg[0]) != x + 30 else 5, 1, BRASS_SHADE)
	# The grindstone, on its trestle.
	var gx := at.x + 44
	line(c, gx - 7, at.y - 1, gx - 2, at.y - 14, UMBER)
	line(c, gx + 7, at.y - 1, gx + 2, at.y - 14, UMBER)
	box(c, gx - 8, at.y - 2, 17, 2, WOOD)
	disc(c, gx, at.y - 15, 8, UMBER)
	disc(c, gx, at.y - 15, 7, Color(0.68, 0.66, 0.62))
	disc(c, gx, at.y - 15, 7, Color(0.80, 0.78, 0.74), 6)
	disc(c, gx, at.y - 15, 2, BRASS)

## The stall: an awning in stripes on its poles, shelves of what there is to
## buy, the counter with its till, a crate beside it, and a horn that plays.
## Whoever keeps it, the cat, and what the horn is playing are `_paint_life`'s.
func _paint_stall(c: CanvasItem, at: Vector2i) -> void:
	var x := at.x - 32
	var y := at.y
	# The shelves behind.
	box(c, x + 3, y - 59, 58, 41, UMBER)
	box(c, x + 4, y - 58, 56, 40, WOOD)
	box(c, x + 6, y - 56, 52, 36, UMBER.lightened(0.02))
	var goods := [TEAL, VIOLET, LAMP, COPPER, GLASS_LIT]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5407
	for shelf in 3:
		var sy := y - 46 + shelf * 12
		box(c, x + 6, sy, 52, 1, BRASS)
		var gx := x + 8
		while gx < x + 54:
			var gw := rng.randi_range(3, 4)
			var gh := rng.randi_range(3, 6)
			var tone: Color = goods[rng.randi() % goods.size()]
			# Not where the keeper stands.
			if not (shelf > 0 and gx > x + 19 and gx < x + 43):
				box(c, gx, sy - gh, gw, gh, tone.darkened(0.22))
				box(c, gx, sy - gh, 1, gh, tone.lightened(0.15))
				box(c, gx + gw / 2, sy - gh - 2, 1, 2, BRASS_LIT)
			gx += gw + rng.randi_range(1, 3)
	# The awning, on its poles.
	for pole in [x - 3, x + 65]:
		box(c, pole - 1, y - 64, 4, 64, UMBER)
		box(c, pole, y - 64, 2, 64, BRASS)
		box(c, pole, y - 64, 1, 64, BRASS_LIT)
	for k in 12:
		var stripe := TEAL if k % 2 == 0 else CREAM
		box(c, x - 4 + k * 6, y - 66, 6, 6, stripe)
		box(c, x - 3 + k * 6, y - 60, 4, 1, stripe)
		box(c, x - 2 + k * 6, y - 59, 2, 1, stripe.darkened(0.18))
	box(c, x - 5, y - 67, 74, 1, BRASS_LIT)
	box(c, x - 4, y - 61, 72, 1, Color(0, 0, 0, 0.10))
	# The counter itself, with brass at its corners and the stall's mark.
	box(c, x - 3, y - 22, 70, 22, UMBER)
	box(c, x - 2, y - 21, 68, 3, WOOD_LIT)
	box(c, x - 2, y - 21, 68, 1, WOOD_LIT.lightened(0.18))
	box(c, x, y - 18, 64, 18, WOOD)
	for gx in [x + 20, x + 43]:
		box(c, gx, y - 17, 1, 17, UMBER.lightened(0.04))
	for corner in [x, x + 59]:
		box(c, corner, y - 18, 5, 5, BRASS)
		box(c, corner, y - 18, 5, 1, BRASS_LIT)
		box(c, corner + 2, y - 16, 1, 1, BRASS_DARK)
	box(c, at.x - 9, y - 14, 18, 9, BRASS)
	box(c, at.x - 9, y - 14, 18, 1, BRASS_LIT)
	box(c, at.x - 9, y - 6, 18, 1, BRASS_SHADE)
	disc(c, at.x, y - 10, 3, BRASS_DARK, 1)
	for tooth in [[0, -4], [0, 4], [-4, 0], [4, 0]]:
		box(c, at.x + int(tooth[0]), y - 10 + int(tooth[1]), 1, 1, BRASS_DARK)
	# The till.
	box(c, x + 47, y - 32, 14, 11, UMBER)
	box(c, x + 48, y - 31, 12, 10, BRASS)
	box(c, x + 48, y - 31, 12, 1, BRASS_LIT)
	box(c, x + 50, y - 36, 7, 5, UMBER)
	box(c, x + 51, y - 35, 5, 4, CREAM)
	box(c, x + 53, y - 34, 1, 2, UMBER)
	for k in 6:
		box(c, x + 50 + (k % 3) * 3, y - 28 + (k / 3) * 3, 2, 2, CREAM)
	box(c, x + 60, y - 28, 3, 1, BRASS_SHADE)
	box(c, x + 62, y - 30, 1, 3, BRASS_LIT)
	# A crate, for the cat.
	box(c, x - 24, y - 17, 18, 17, UMBER)
	box(c, x - 23, y - 16, 16, 16, WOOD)
	box(c, x - 23, y - 16, 16, 2, WOOD_LIT)
	box(c, x - 16, y - 14, 2, 14, UMBER.lightened(0.05))
	for corner in [x - 23, x - 10]:
		box(c, corner, y - 16, 3, 3, BRASS)
		box(c, corner, y - 3, 3, 3, BRASS_SHADE)
	# The cat: of the same make as the keeper. Its eyes and its tail are
	# `_paint_life`'s.
	picture(c, x - 21, y - 27, [
		"D.....D...",
		"BD...BD...",
		"LBBBBBD...",
		"LBBBBBD...",
		"LBBBBBD...",
		".LBBBD....",
		".LBBBBD...",
		"LBBBBBBD..",
		"LBBBBBBD..",
		"LBBBBBBD..",
		".LBBBBD...",
	], {"L": BRASS_LIT, "B": BRASS, "D": BRASS_DARK})
	box(c, x - 19, y - 20, 4, 1, BRASS_DARK)
	# The horn, on its table.
	var mx := x + 74
	box(c, mx - 1, y - 19, 22, 3, UMBER)
	box(c, mx, y - 18, 20, 2, WOOD_LIT)
	box(c, mx + 2, y - 16, 2, 16, WOOD)
	box(c, mx + 16, y - 16, 2, 16, WOOD)
	box(c, mx + 3, y - 26, 13, 8, UMBER)
	box(c, mx + 4, y - 25, 11, 7, WOOD)
	box(c, mx + 4, y - 25, 11, 1, WOOD_LIT)
	box(c, mx + 6, y - 27, 7, 2, UMBER)
	for k in 13:
		var wide := 2 + k * 9 / 12
		box(c, mx + 8 + k - wide / 4, y - 30 - k - wide / 2, wide, wide, BRASS if k < 10 else BRASS_LIT)
	oval(c, mx + 24, y - 46, 4, 5, BRASS_DARK)
	oval(c, mx + 25, y - 46, 2, 3, UMBER)
	box(c, mx + 8, y - 30, 2, 3, BRASS_SHADE)
	box(c, mx + 15, y - 22, 3, 1, BRASS_SHADE)
	box(c, mx + 17, y - 23, 1, 3, BRASS_LIT)

## The gate: a ring of brass on its step with a coil stood either side of it.
## What turns round it, what is in it, its lamps and the sparks are
## `_paint_life`'s.
func _paint_gate(c: CanvasItem, g: Vector2i) -> void:
	var cy := g.y - 36
	for side: int in [-1, 1]:
		var px := g.x + side * 44
		box(c, px - 4, g.y - 5, 9, 5, BRASS_SHADE)
		box(c, px - 4, g.y - 5, 9, 1, BRASS_LIT)
		box(c, px - 3, g.y - 38, 6, 33, UMBER)
		box(c, px - 2, g.y - 38, 4, 33, BRASS)
		box(c, px - 2, g.y - 38, 1, 33, BRASS_LIT)
		box(c, px + 1, g.y - 38, 1, 33, BRASS_SHADE)
		for ring in range(g.y - 34, g.y - 8, 6):
			box(c, px - 4, ring, 8, 2, COPPER)
			box(c, px - 4, ring, 8, 1, COPPER.lightened(0.3))
		disc(c, px, g.y - 43, 5, UMBER)
		disc(c, px, g.y - 43, 4, COPPER)
		box(c, px - 2, g.y - 46, 2, 2, COPPER.lightened(0.4))
	box(c, g.x - 30, g.y - 4, 60, 4, BRASS)
	box(c, g.x - 30, g.y - 4, 60, 1, BRASS_LIT)
	box(c, g.x - 30, g.y - 1, 60, 1, BRASS_SHADE)
	disc(c, g.x, cy, 29, UMBER)
	disc(c, g.x, cy, 28, BRASS)
	disc(c, g.x, cy, 28, BRASS_LIT, 26)
	disc(c, g.x, cy, 22, BRASS_SHADE)
	disc(c, g.x, cy, 21, BRASS_DARK)
	disc(c, g.x, cy, 20, Color(0.03, 0.04, 0.10))

## --- what moves, and what is lit --------------------------------------------

## A breath of steam, out of (x, y) and up: `into` it, from nothing to gone.
func _steam(c: CanvasItem, x: int, y: int, into: float) -> void:
	if into < 0.0 or into > 1.0:
		return
	for k in 4:
		var up := clampf(into * 1.3 - k * 0.1, 0.0, 1.0)
		if up <= 0.0:
			continue
		var size := 2 + int(up * 5.0)
		box(c, x + int(round(sin(up * 5.0 + k) * 3.0)) - size / 2 + int(up * 4.0), y - int(up * 26.0) - size / 2,
			size, size, faded(CLOUD, 0.55 * (1.0 - up)))

## A hand of a clock, from its middle: `long`, at the turn `a` from straight
## up.
func _hand(c: CanvasItem, cx: int, cy: int, a: float, long: float, col: Color) -> void:
	line(c, cx, cy, cx + int(round(sin(a) * long)), cy - int(round(cos(a) * long)), col)

## What the terrace does by itself: the clock and its wheels, the weight
## swinging, the lamps on the board, the steam, the glass on the pipe, and the
## sun on the window. The lamps hung in the arches are on their chains.
func _paint_room_life(c: CanvasItem) -> void:
	# The clock keeps a quicker time than most: its long hand goes round in a
	# minute.
	_hand(c, CLOCK.x, CLOCK.y, _t * TAU / 720.0, 11.0, UMBER)
	_hand(c, CLOCK.x + 1, CLOCK.y, _t * TAU / 720.0, 11.0, UMBER)
	_hand(c, CLOCK.x, CLOCK.y, _t * TAU / 60.0, 18.0, UMBER)
	_hand(c, CLOCK.x, CLOCK.y, floor(_t) * TAU / 60.0 * 6.0, 20.0, SHUT.darkened(0.15))
	disc(c, CLOCK.x, CLOCK.y, 2, BRASS_DARK)
	box(c, CLOCK.x, CLOCK.y, 1, 1, BRASS_LIT)
	for i in WHEELS.size():
		var w: Array = WHEELS[i]
		_teeth(c, w[0], w[1], w[2], w[3], _t * float(w[4]), COPPER if i % 2 == 1 else BRASS)
	# The weight.
	var swing := sin(_t * 2.6) * 0.30
	var bob := Vector2i(580 + int(round(sin(swing) * 50.0)), 144 + int(round(cos(swing) * 50.0)))
	line(c, 580, 144, bob.x, bob.y, BRASS_LIT)
	disc(c, bob.x, bob.y, 4, BRASS)
	box(c, bob.x - 2, bob.y - 2, 2, 2, BRASS_LIT)
	box(c, 578, 142, 5, 3, BRASS_DARK)
	_life_board(c)
	# Steam, where the joints let it go.
	for i in LEAKS.size():
		var leak: Array = LEAKS[i]
		_steam(c, leak[0], leak[1], fmod(_t + i * 1.3, float(leak[2])) / 1.6)
	# The glass on the pipe: never quite steady.
	var needle := -0.9 + sin(_t * 1.3) * 0.5 + sin(_t * 7.0) * 0.08
	_hand(c, 182, PIPE - 19, needle, 4.0, SHUT.darkened(0.1))
	var boiler := 0.6 + sin(_t * 0.8) * 0.4 + sin(_t * 9.0) * 0.06
	_hand(c, 464, 278, boiler, 3.0, SHUT.darkened(0.1))
	# The fire in the boiler, through the gap in its door.
	var fire := flicker(_t, 4)
	box(c, 459, 300, 9, 2, Color(1.0, 0.55, 0.15).lerp(LAMP, fire))
	box(c, 461, 303, 5, 1, faded(Color(1.0, 0.55, 0.15), fire))
	# The sun, moving on the coloured glass.
	var glint := fmod(_t * 0.25, 1.0)
	if glint < 0.5:
		var gy := 124 + int(glint * 2.0 * 76.0)
		box(c, LEFT + 9, gy, 12, 1, faded(Color.WHITE, 0.55))
		box(c, LEFT + 11, gy + 2, 8, 1, faded(Color.WHITE, 0.3))

## The board of lamps: every room of the way through lit, and one of them
## brighter as the way is followed — or all of them red, when there is no way.
func _life_board(c: CanvasItem) -> void:
	var open := _gate_open()
	var x := BOARD.x + 5
	var y := BOARD.y + 9
	for r: Vector2i in ROOMS:
		box(c, x + r.x * 8, y + r.y * 7, 5, 5, BRASS_DARK)
		box(c, x + r.x * 8 + 1, y + r.y * 7 + 1, 3, 3,
			LAMP.darkened(0.25) if open else SHUT.darkened(0.25 + 0.15 * sin(_t * 2.0)))
	box(c, x + 1, y + 15, 3, 3, OPEN.darkened(0.15))
	box(c, x + 49, y + 1, 3, 3, SHUT)
	box(c, x + 17, y + 29, 3, 3, GLASS_LIT)
	if open:
		var here: Vector2i = ROOMS[int(_t * 1.6) % 14]
		box(c, x + here.x * 8 + 1, y + here.y * 7 + 1, 3, 3, Color.WHITE)
		halo(c, x + here.x * 8 + 1, y + here.y * 7 + 1, 3, 3, LAMP, 2, 0.20)
	# The tape coming out of the foot of it, with whatever it says.
	var tick := int(_t * 10.0)
	for k in 9:
		var tx := (k * 7 + 58 - tick % 7) % 58
		box(c, BOARD.x + 4 + tx, BOARD.y + 48, 3, 2, CREAM if (k + tick / 7) % 3 != 0 else CREAM.darkened(0.35))

func _paint_life(c: CanvasItem) -> void:
	_life_rack(c, _at["weapons"], float(_lit["weapons"]))
	_life_stall(c, _at["shop"], float(_lit["shop"]))
	_life_gate(c, _at["gate"], float(_lit["gate"]))

## A glint on an edge: a cross of light, there and gone.
func _glint(c: CanvasItem, x: int, y: int, on: float) -> void:
	if on <= 0.0:
		return
	box(c, x, y - 1, 1, 3, faded(Color.WHITE, on))
	box(c, x - 1, y, 3, 1, faded(Color.WHITE, on))

func _life_rack(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var x := at.x - 27
	var y := at.y - 58
	# What is in the claw of the staff.
	var pulse := 0.6 + 0.4 * sin(_t * 2.3)
	halo(c, x + 31, y + 10, 3, 3, CRYSTAL, 3, 0.12 * pulse * (0.6 + 0.4 * lit))
	box(c, x + 31, y + 10, 3, 3, CRYSTAL.lerp(Color.WHITE, 0.5 * pulse))
	# The sun on an edge, one after another, and more for somebody standing
	# here.
	var turn := fmod(_t, 4.0)
	_glint(c, x + 10, y + 14, clampf(1.0 - absf(turn - 0.5) * 4.0, 0.0, 1.0) * (0.5 + 0.5 * lit))
	_glint(c, x + 18, y + 14, clampf(1.0 - absf(turn - 1.7) * 4.0, 0.0, 1.0) * (0.5 + 0.5 * lit))
	_glint(c, x + 42, y + 13, clampf(1.0 - absf(turn - 2.9) * 4.0, 0.0, 1.0) * (0.5 + 0.5 * lit))
	# The stone, going round — and throwing sparks, with somebody at the rack.
	var gx := at.x + 44
	for k in 3:
		var a := _t * (2.0 + 5.0 * lit) + TAU * k / 3.0
		box(c, gx + int(round(cos(a) * 5.0)), at.y - 15 + int(round(sin(a) * 5.0)), 1, 1, Color(0.46, 0.44, 0.42))
	if lit > 0.3:
		for k in 5:
			var out := fmod(_t * 3.0 + k * 0.2, 1.0)
			box(c, gx - 7 - int(out * 9.0), at.y - 19 + int(out * out * 12.0) - k % 2, 1, 1,
				faded(LAMP.lerp(Color.WHITE, 0.4), lit * (1.0 - out)))
	# The rack's rail, bright when it would answer.
	if lit > 0.0:
		box(c, x - 1, y + 3, 56, 1, faded(Color.WHITE, lit))
		box(c, x, y + 8, 1, 44, faded(BRASS_LIT, lit))
		box(c, x + 53, y + 8, 1, 44, faded(BRASS_LIT, lit))

func _life_stall(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var x := at.x - 32
	var y := at.y
	var eyes := clampi(int((_player_x(float(at.x)) - float(at.x)) / 60.0), -2, 2)
	# Whoever keeps the stall: a head of brass under a tall hat, two lenses,
	# and the key in its shoulder going round.
	var hx := at.x - 7
	var hy := y - 39
	box(c, hx + 1, hy - 8, 12, 8, UMBER)
	box(c, hx + 2, hy - 7, 2, 6, UMBER.lightened(0.10))
	box(c, hx + 1, hy - 3, 12, 2, COPPER)
	box(c, hx - 1, hy, 16, 1, UMBER)
	box(c, hx, hy + 1, 14, 11, UMBER)
	box(c, hx + 1, hy + 1, 12, 10, BRASS)
	box(c, hx + 1, hy + 1, 2, 10, BRASS_LIT)
	box(c, hx + 11, hy + 1, 2, 10, BRASS_SHADE)
	for rivet in [hx + 2, hx + 11]:
		box(c, rivet, hy + 2, 1, 1, BRASS_DARK)
	var glow_eye := VIOLET.lerp(Color.WHITE, 0.15 + 0.25 * lit)
	for eye in [hx + 3, hx + 8]:
		box(c, eye + eyes / 2, hy + 4, 4, 4, UMBER)
		if fmod(_t, 4.3) > 4.15:
			box(c, eye + eyes / 2 + 1, hy + 6, 2, 1, glow_eye.darkened(0.3))
		else:
			box(c, eye + eyes / 2 + 1, hy + 5, 2, 2, glow_eye)
			box(c, eye + eyes / 2 + 1 + maxi(mini(eyes, 1), 0), hy + 5, 1, 1, Color.WHITE)
	box(c, hx + 4, hy + 9, 6, 1, BRASS_DARK)
	box(c, hx + 5, hy + 9, 1, 1, CREAM)
	box(c, hx + 7, hy + 9, 1, 1, CREAM)
	box(c, hx + 5, hy + 12, 4, 2, BRASS_DARK)
	box(c, hx - 2, hy + 14, 18, 5, UMBER)
	box(c, hx - 1, hy + 14, 16, 5, BRASS_SHADE)
	box(c, hx - 1, hy + 14, 16, 1, BRASS)
	box(c, hx + 5, hy + 14, 4, 2, COPPER)
	var wind := int(_t * 3.0) % 4
	box(c, hx + 15, hy + 15, 3, 1, UMBER)
	if wind % 2 == 0:
		box(c, hx + 18, hy + 13, 1, 5, BRASS_LIT)
		box(c, hx + 17, hy + 13 if wind == 0 else hy + 17, 3, 1, BRASS_LIT)
	else:
		box(c, hx + 17, hy + 15, 4, 1, BRASS_LIT)
		box(c, hx + 20 if wind == 1 else hx + 17, hy + 14, 1, 3, BRASS_LIT)
	# The counter's edge, bright when it would answer, and the till's flag up.
	if lit > 0.0:
		box(c, x - 2, y - 22, 68, 1, faded(Color.WHITE, lit))
		box(c, x + 52, y - 34, 3, 2, faded(SHUT, lit))
	# The cat: watching, and thinking about it.
	var cat := x - 21
	if fmod(_t + 1.7, 5.1) < 4.9:
		box(c, cat + 1 + maxi(eyes, 0) / 2, y - 24, 2, 1, VIOLET.lightened(0.2))
		box(c, cat + 4 + maxi(eyes, 0) / 2, y - 24, 2, 1, VIOLET.lightened(0.2))
	var swish := int(round(sin(_t * 1.7) * 1.4))
	box(c, cat + 8, y - 19, 1, 2, BRASS)
	box(c, cat + 8 + swish, y - 22, 1, 3, BRASS)
	box(c, cat + 8 + swish * 2, y - 24, 1, 2, BRASS_LIT)
	# The horn: its plate going round, and what it is playing.
	var mx := x + 74
	box(c, mx + 6 + int(_t * 5.0) % 6, y - 26, 2, 1, BRASS_LIT)
	for k in 3:
		var up := fmod(_t * 0.35 + k * 0.33, 1.0)
		var nx := mx + 20 + int(up * 12.0) + int(round(sin(up * 7.0 + k * 2.0) * 2.0))
		var ny := y - 44 - int(up * 14.0)
		var note := faded(UMBER, 1.0 - up)
		box(c, nx, ny, 1, 5, note)
		box(c, nx - 2, ny + 4, 3, 2, note)
		if k % 2 == 0:
			box(c, nx + 1, ny, 2, 1, note)

func _life_gate(c: CanvasItem, at: Vector2i, lit: float) -> void:
	var cy := at.y - 36
	var open := _gate_open()
	var col := OPEN if open else SHUT
	# The ring is a wheel, and turns while there is a way through.
	_teeth(c, at.x, cy, 29, 16, _t * 0.5 if open else 0.2, BRASS)
	if open:
		# What is in it: the crystal, and its light going round it.
		disc(c, at.x, cy, 18, faded(CRYSTAL, 0.05 + 0.04 * lit))
		disc(c, at.x, cy, 11, faded(CRYSTAL, 0.07 + 0.05 * lit))
		for k in 2:
			var r := 10 + k * 6
			var a := _t * (1.3 - 0.5 * k) + k * 2.1
			for seg in 5:
				var th := a + seg * 0.24
				var dot := faded(CRYSTAL.lightened(0.2), (0.3 + 0.5 * lit) * (1.0 - seg / 5.0))
				box(c, at.x + int(round(cos(th) * r)), cy + int(round(sin(th) * r)), 2, 2, dot)
				box(c, at.x - int(round(cos(th) * r)), cy - int(round(sin(th) * r)), 2, 2, dot)
		var beat := 0.75 + 0.25 * sin(_t * 2.2)
		picture(c, at.x - 10, cy - 9, [
			".......L.............",
			"......LLB.......L....",
			".....LLBBB.....LB....",
			"....LLLBBBB...LBBD...",
			"...LLLBBBBBB.LBBBD...",
			"..LLLBBBBBBBBBBBBDD..",
			".LLLBBBBBBBBBBBBBBDD.",
			"LLLBBBBBBBBBBBBBBBDDD",
			".LLBBBBBBBBBBBBBBDDD.",
			"..LBBBBBBBBBBBBBDDD..",
			"...BBBBBBBBBBBBDDD...",
			"....BBBBB.BBBBDDD....",
			".....BBB...BBDDD.....",
			"......B.....DDD......",
			".............D.......",
		], {"L": CRYSTAL.lerp(Color.WHITE, 0.6 * beat), "B": CRYSTAL, "D": CRYSTAL.darkened(0.38)})
		box(c, at.x - 3, cy - 3, 5, 1, CRYSTAL.lerp(Color.WHITE, 0.8 * beat))
		box(c, at.x - 2, cy - 2, 2, 1, Color.WHITE)
		# A spark of its own, off the point of it.
		var crack := int(_t * 7.0)
		if _odd(crack, 9) % 5 == 0:
			var tip := Vector2i(at.x + 7, cy - 8)
			var end := Vector2i(at.x + 12 + _odd(crack, 2) % 5, cy - 13 - _odd(crack, 4) % 4)
			line(c, tip.x, tip.y, (tip.x + end.x) / 2 + 1, (tip.y + end.y) / 2 + 2, VIOLET.lightened(0.3))
			line(c, (tip.x + end.x) / 2 + 1, (tip.y + end.y) / 2 + 2, end.x, end.y, VIOLET.lightened(0.3))
	else:
		# And when there is not: the leaves of it are shut.
		disc(c, at.x, cy, 20, BRASS_SHADE)
		for k in 8:
			var a := TAU * k / 8.0
			line(c, at.x + int(round(cos(a) * 20.0)), cy + int(round(sin(a) * 20.0)),
				at.x + int(round(cos(a + 1.9) * 4.0)), cy + int(round(sin(a + 1.9) * 4.0)), BRASS_DARK)
		disc(c, at.x, cy, 3, BRASS_DARK)
		box(c, at.x - 1, cy - 1, 2, 2, faded(col, 0.6 + 0.4 * sin(_t * 2.0)))
	# The lamps round it: chasing while it is open, all slow red while it is
	# not.
	for k in 12:
		var th := TAU * k / 12.0 - PI * 0.5
		var on := 0.45 + 0.35 * sin(_t * 2.0)
		if open:
			on = clampf(1.0 - fposmod(fmod(_t * 6.0, 12.0) - float(k), 12.0) / 5.0, 0.15, 1.0)
		var lx := at.x + int(round(cos(th) * 24.0)) - 1
		var ly := cy + int(round(sin(th) * 24.0)) - 1
		box(c, lx - 1, ly - 1, 4, 4, UMBER)
		box(c, lx - 1, ly - 1, 4, 4, faded(col, on * (0.30 + 0.20 * lit)))
		box(c, lx, ly, 2, 2, col.darkened(0.55).lerp(col, on))
	# The coils: a spark thrown across to the ring, now and then, while there
	# is a way through, and a red lamp on each while there is not.
	for side: int in [-1, 1]:
		var px := at.x + side * 44
		if not open:
			box(c, px - 1, at.y - 44, 2, 2, faded(SHUT, 0.5 + 0.4 * sin(_t * 2.0)))
			continue
		var strike := int(_t * 9.0) + (side + 1) * 3
		if _odd(strike, 5) % 10 >= 4 + int(3.0 * (1.0 - lit)):
			continue
		var from := Vector2i(px - side * 4, at.y - 44)
		var to := Vector2i(at.x + side * 27, cy - 9)
		var last := from
		for k in range(1, 5):
			var next := Vector2i(int(lerpf(float(from.x), float(to.x), k / 4.0)),
				int(lerpf(float(from.y), float(to.y), k / 4.0)) + (_odd(strike * 7 + k, 3) % 7 - 3 if k < 4 else 0))
			line(c, last.x, last.y, next.x, next.y, VIOLET.lightened(0.25))
			last = next
		box(c, from.x - 1, from.y - 1, 3, 3, faded(VIOLET.lightened(0.5), 0.8))
