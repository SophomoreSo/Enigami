class_name GroveGroundView
extends Node2D

## The Jean Grey test's ground (`JeanGreyBase`) as the hideout's Moonlit Grove
## (`HideoutGrove`), in its colours: night over a wood, the moon low behind the
## trees, and the guarded building the ruin of a temple — old stone gone green
## along every top, its halls hung with lanterns, fireflies out over the yard.
##
## The ground is three screens across and the camera goes along it, so the
## far things go along slower than the ground: the moon hardly moves, the far
## wood a little more, the near trunks more again. Everything that stands still
## is drawn once, when the room is built; only the lanterns and the fireflies
## are drawn again every frame. The lanterns hang on cords, as the hideout's
## do (`Rope`), and swing when anything goes through one: a body, the player
## or a guard they are in, or an attack.
##
## Drawn in pixels of the buffer the world is drawn into (`HideoutScenery.S`
## world units each), with `HideoutScenery`'s brushes; a cell is `C` of them.

# A picture drawn in whole pixels halves whole numbers on purpose, all the way
# down.
@warning_ignore_start("integer_division")

const S := HideoutScenery.S
const C := Room.CELL / HideoutScenery.S

## How far along with the camera each depth goes: 1 would be pinned to the
## screen, 0 to the ground.
const MOON_DRIFT := 0.9
const FAR_DRIFT := 0.6
const MIST_DRIFT := 0.45
const MID_DRIFT := 0.25
## Where the moon stands on the screen, as a share of its width, and how high.
const MOON_ACROSS := 0.68
const MOON_HIGH := 46
const MOON_R := 15
## The interior of the ruin: its wall, the joints between its blocks, and the
## light of the lanterns on it.
const INSIDE := Color(0.06, 0.085, 0.09)
const INSIDE_JOINT := Color(0.09, 0.125, 0.13)
const EARTH := Color(0.085, 0.075, 0.065)
const EARTH_SPECK := Color(0.12, 0.105, 0.085)
## How far apart the lanterns hang under a roof, in cells, and how many
## fireflies are out.
const LANTERN_EVERY := 9
const FIREFLIES := 44
## The room a lantern takes up, from the pixel it hangs by: what has to go
## through it to swing it.
const LANTERN_BODY := Rect2i(-2, 0, 5, 7)

var room: JeanGreyBase
var _t: float = 0.0
var _sky: Depth
var _moon: Depth
var _far: Depth
var _mist: Depth
var _mid: Depth
var _ground: Depth
var _life: Depth
## The first column of the ruin: where its roof starts. Stone from there on is
## the temple's; short of it, the ground is the wood's earth.
var _front: int = 0
## Under-roof lanterns, as the cell they hang from; and the fireflies, each a
## place it wanders round and the beat it wanders at.
var _lanterns: Array[Vector2i] = []
var _flies: Array = []
## The cord each lantern hangs on, in the order of `_lanterns`, and the
## lantern riding the end of each.
var cords: Array[Rope] = []
var _hung: Array[Depth] = []

## One depth of the picture, painted by the view that owns it.
class Depth extends Node2D:
	var paint: Callable
	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)

func _ready() -> void:
	room = get_parent() as JeanGreyBase
	_sky = _depth(-12, _paint_sky)
	_moon = _depth(-11, _paint_moon)
	_far = _depth(-10, _paint_far)
	_mist = _depth(-9, _paint_mist)
	_mid = _depth(-8, _paint_mid)
	_ground = _depth(-5, _paint_ground)
	_life = _depth(-2, _paint_life, PixelCamera.WORLD_LAYER)
	if room != null:
		room.built.connect(_on_built)

## A depth of the picture at `z`. All but what is drawn again every frame are
## the back of the picture (`Lighting.BACKDROP_LAYER`): flat to any lamp, and
## not drawn a second time to say so.
func _depth(z: int, paint: Callable, layer: int = Lighting.BACKDROP_LAYER) -> Depth:
	var d := Depth.new()
	d.paint = paint
	d.z_index = z
	d.visibility_layer = layer
	add_child(d)
	return d

func _on_built() -> void:
	_front = room.cols
	for y in range(1, room.rows - 5):
		for x in range(1, room.cols - 1):
			if room.is_solid(x, y) and room.is_solid(x + 1, y):
				_front = mini(_front, x)
	_lanterns.clear()
	for x in range(2, room.cols - 2):
		if x % LANTERN_EVERY != 4:
			continue
		var roof := _roof_over(x)
		if roof >= 0 and not room.is_solid(x, roof + 1) and not room.is_solid(x, roof + 2):
			_lanterns.append(Vector2i(x, roof))
	_hang_lanterns()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1984
	_flies.clear()
	for i in FIREFLIES:
		var at := Vector2(rng.randf_range(2.0, room.cols - 2.0) * C, rng.randf_range(4.0, room.rows - 4.5) * C)
		if room.is_solid(int(at.x / C), int(at.y / C)):
			continue
		_flies.append([at, rng.randf_range(0.0, TAU), rng.randf_range(0.6, 1.4)])
	for d in [_sky, _moon, _far, _mist, _mid, _ground]:
		d.queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_2d()
	var x := cam.global_position.x if cam != null else 0.0
	_moon.position.x = _snap(x * MOON_DRIFT)
	_far.position.x = _snap(x * FAR_DRIFT)
	_mist.position.x = _snap(x * MIST_DRIFT)
	_mid.position.x = _snap(x * MID_DRIFT)
	_life.queue_redraw()
	for lantern in _hung:
		lantern.queue_redraw()

## Every lantern on a cord of its own — the kind of line a light hangs on —
## from under its roof, with the lantern riding the end, hung in front of the
## ground and behind the fireflies, where it was painted when it hung still.
## Hung again from nothing whenever the ground is built.
func _hang_lanterns() -> void:
	for cord in cords:
		if is_instance_valid(cord):
			cord.queue_free()
	for lantern in _hung:
		if is_instance_valid(lantern):
			lantern.queue_free()
	cords.clear()
	_hung.clear()
	for cell in _lanterns:
		var at := Vector2(cell.x * C + C / 2, (cell.y + 1) * C)
		var drop := float((10 + (cell.x * 7) % 12) * S)
		var cord := Rope.of("cord")
		cord.color = HideoutGrove.ROPE.darkened(0.3)
		cord.z_index = _life.z_index
		cord.hang((at + Vector2(0.5, 0.5)) * S, drop, drop)
		add_child(cord)
		move_child(cord, _life.get_index())
		var lantern := Depth.new()
		lantern.paint = _paint_lantern.bind(cell.x)
		lantern.z_index = _life.z_index
		add_child(lantern)
		move_child(lantern, _life.get_index())
		cord.attach(lantern, cord.nodes.size() - 1, Vector2.ZERO,
			Rect2(Vector2(LANTERN_BODY.position) * S, Vector2(LANTERN_BODY.size) * S))
		cords.append(cord)
		_hung.append(lantern)

func _snap(v: float) -> float:
	return roundf(v / S) * S

## The stretch of a depth going along at `drift` that the screen can ever show,
## from where it starts to where it ends, in its own pixels: the camera stays
## inside the ground, so its middle runs from half a screen in at one end to
## half a screen in at the other, and the depth slides `drift` of that.
func _from(drift: float) -> int:
	return -int(_screen_w() * (drift * 0.5 + 0.1))

func _to(drift: float) -> int:
	var w := float(room.cols * C)
	return int((w - _screen_w() * 0.5) * (1.0 - drift) + _screen_w() * 0.6)

func _screen_w() -> float:
	return get_viewport().get_visible_rect().size.x / S

## The row of the nearest solid cell over open cell (x, row under it), or -1
## for one open to the sky: the top row of the ground is its edge, not a roof.
func _roof_over(x: int) -> int:
	for y in range(room.rows - 1, 0, -1):
		if room.is_solid(x, y) and y < room.rows - 4 and not room.is_solid(x, y + 1):
			var under := y + 1
			while under < room.rows and not room.is_solid(x, under):
				under += 1
			if under >= room.rows - 4:
				return y
	return -1

## Whether open cell (x, y) is under cover: somewhere above it in its column,
## short of the ground's top edge, there is stone.
func _covered(x: int, y: int) -> bool:
	for above in range(y - 1, 0, -1):
		if room.is_solid(x, above):
			return true
	return false

## Whether solid cell (x, y) is the ruin's masonry rather than the wood's
## earth: everything from the ruin's first column on, short of the canopy
## overhead.
func _masonry(x: int, y: int) -> bool:
	return y > 0 and x >= _front

## --- the night ----------------------------------------------------------------
func _paint_sky(c: CanvasItem) -> void:
	var w := (room.cols + 4) * C
	var band := (room.rows * C) / HideoutGrove.SKY.size()
	for i in HideoutGrove.SKY.size():
		HideoutScenery.box(c, -2 * C, -C + band * i, w, band + 1, HideoutGrove.SKY[i])
	HideoutScenery.box(c, -2 * C, -C + band * HideoutGrove.SKY.size(), w, room.rows * C, HideoutGrove.SKY[HideoutGrove.SKY.size() - 1])

## The moon, where it stands on the screen when the camera is at the start of
## the ground; it hardly moves from there.
func _paint_moon(c: CanvasItem) -> void:
	var vp := get_viewport().get_visible_rect().size / S
	var cx := int(vp.x * MOON_ACROSS) - int(vp.x * 0.5 * MOON_DRIFT)
	for k in range(4, 0, -1):
		HideoutScenery.disc(c, cx, MOON_HIGH, MOON_R + k * 5, HideoutScenery.faded(HideoutGrove.MOONLIGHT, 0.035))
	HideoutScenery.disc(c, cx, MOON_HIGH, MOON_R, HideoutGrove.MOON_SHADE)
	HideoutScenery.disc(c, cx - 2, MOON_HIGH - 2, MOON_R - 2, HideoutGrove.MOON_FACE)
	HideoutScenery.disc(c, cx + 5, MOON_HIGH + 4, 3, HideoutGrove.MOON_SHADE)
	HideoutScenery.disc(c, cx - 6, MOON_HIGH + 6, 2, HideoutGrove.MOON_SHADE)

## The far wood: crowns against the moonlit haze, on a span wide enough for
## wherever the camera takes it.
func _paint_far(c: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var from := _from(FAR_DRIFT)
	var to := _to(FAR_DRIFT)
	var base := int(room.rows * C * 0.62)
	HideoutScenery.box(c, from, base, to - from, room.rows * C - base, HideoutGrove.FAR)
	var x := from
	while x < to:
		var r := rng.randi_range(10, 22)
		HideoutScenery.oval(c, x, base - rng.randi_range(4, 16), r, r + rng.randi_range(4, 12), HideoutGrove.FAR)
		x += rng.randi_range(14, 26)

func _paint_mist(c: CanvasItem) -> void:
	var from := _from(MIST_DRIFT)
	var to := _to(MIST_DRIFT)
	var y := int(room.rows * C * 0.66)
	for k in 6:
		HideoutScenery.box(c, from, y + k * 4, to - from, 4, HideoutScenery.faded(HideoutGrove.MOONLIGHT, 0.05 - 0.007 * k))

## The near trunks, with their crowns over them, darker than anything further.
func _paint_mid(c: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var to := _to(MID_DRIFT)
	var foot := (room.rows - 3) * C
	var x := _from(MID_DRIFT)
	while x < to:
		var w := rng.randi_range(5, 10)
		var top := rng.randi_range(20, 60)
		HideoutScenery.box(c, x, top, w, foot - top, HideoutGrove.MID)
		HideoutScenery.box(c, x + w - 2, top, 2, foot - top, HideoutGrove.DARK)
		HideoutScenery.oval(c, x + w / 2, top, rng.randi_range(18, 30), rng.randi_range(12, 18), HideoutGrove.LEAF.darkened(0.25))
		x += rng.randi_range(70, 120)

## --- the ruin -----------------------------------------------------------------
func _paint_ground(c: CanvasItem) -> void:
	for y in room.rows:
		for x in room.cols:
			if room.is_solid(x, y):
				_paint_solid(c, x, y)
			elif _covered(x, y):
				_paint_inside(c, x, y)
	# The wood goes on past the ground's ends, and the earth under it.
	HideoutScenery.box(c, -2 * C, room.rows * C, (room.cols + 4) * C, 2 * C, EARTH)

## A stretch of the ruin's back wall: dark blocks, coursed, a little lighter
## at their joints.
func _paint_inside(c: CanvasItem, x: int, y: int) -> void:
	var px := x * C
	var py := y * C
	HideoutScenery.box(c, px, py, C, C, INSIDE)
	HideoutScenery.box(c, px, py + C / 2, C, 1, INSIDE_JOINT)
	HideoutScenery.box(c, px + (8 if y % 2 == 0 else 0), py, 1, C / 2, INSIDE_JOINT)
	HideoutScenery.box(c, px + (0 if y % 2 == 0 else 8), py + C / 2, 1, C / 2, INSIDE_JOINT)

func _paint_solid(c: CanvasItem, x: int, y: int) -> void:
	var px := x * C
	var py := y * C
	var top := y > 0 and not room.is_solid(x, y - 1)
	if y == 0:
		# The canopy over everything.
		HideoutScenery.box(c, px, py - C, C, C * 2, HideoutGrove.DARK)
		HideoutScenery.oval(c, px + 8, py + C - 2, 10, 5, HideoutGrove.LEAF.darkened(0.3))
		return
	if not _masonry(x, y):
		if x == 0 and y < room.rows - 4:
			# The wood's edge: one great trunk.
			HideoutScenery.box(c, px, py, C, C, HideoutScenery.faded(HideoutGrove.BARK, 1.0))
			HideoutScenery.box(c, px + C - 3, py, 2, C, HideoutGrove.WOOD_DARK)
			HideoutScenery.box(c, px + 4, py + (y * 5) % 12, 1, 3, HideoutGrove.WOOD)
			return
		HideoutScenery.box(c, px, py, C, C, EARTH)
		HideoutScenery.box(c, px + (x * 7 + y * 3) % 12, py + (x * 5 + y * 11) % 12 + 2, 2, 1, EARTH_SPECK)
		if top:
			HideoutScenery.box(c, px, py, C, 3, HideoutGrove.MOSS.darkened(0.25))
			HideoutScenery.box(c, px + (x * 5) % 11, py - 2, 1, 2, HideoutGrove.MOSS)
			HideoutScenery.box(c, px + (x * 3 + 6) % 13, py - 3, 1, 3, HideoutGrove.MOSS_LIT.darkened(0.2))
		return
	# A block of the temple's stone, lit along its top and left.
	HideoutScenery.box(c, px, py, C, C, HideoutGrove.STONE_SHADE)
	HideoutScenery.box(c, px, py, C, 1, HideoutGrove.STONE.darkened(0.15))
	HideoutScenery.box(c, px, py, 1, C, HideoutGrove.STONE.darkened(0.3))
	HideoutScenery.box(c, px, py + C - 1, C, 1, HideoutGrove.STONE_SHADE.darkened(0.35))
	HideoutScenery.box(c, px + C - 1, py, 1, C, HideoutGrove.STONE_SHADE.darkened(0.35))
	if (x * 13 + y * 7) % 5 == 0:
		HideoutScenery.box(c, px + 3, py + 9, 5, 1, HideoutGrove.STONE_SHADE.darkened(0.25))
	if top:
		# Moss along every top, hanging over the edge here and there.
		HideoutScenery.box(c, px, py, C, 2, HideoutGrove.MOSS)
		HideoutScenery.box(c, px + (x * 7) % 12, py, 3, 1, HideoutGrove.MOSS_LIT)
		if (x + y) % 3 == 0:
			HideoutScenery.box(c, px + (x * 5) % 13, py + 2, 1, 3 + x % 3, HideoutGrove.MOSS.darkened(0.2))
	elif not room.is_solid(x, y + 1) and y + 1 < room.rows and (x * 11 + y) % 4 == 0:
		# Roots and vines hanging from under the stone.
		HideoutScenery.box(c, px + (x * 3) % 13, py + C, 1, 4 + (x % 5) * 2, HideoutGrove.LEAF.lightened(0.05))

## --- what moves -----------------------------------------------------------------
func _paint_life(c: CanvasItem) -> void:
	for f in _flies:
		var home: Vector2 = f[0]
		var beat: float = f[2]
		var a: float = float(f[1]) + _t * beat
		var p := home + Vector2(cos(a) * 14.0, sin(a * 1.7) * 6.0)
		var on := 0.5 + 0.5 * sin(_t * 2.3 * beat + float(f[1]) * 3.0)
		if on < 0.25:
			continue
		HideoutScenery.box(c, int(p.x), int(p.y), 1, 1, HideoutScenery.faded(HideoutGrove.FIREFLY, on))
		HideoutScenery.box(c, int(p.x) - 1, int(p.y), 3, 1, HideoutScenery.faded(HideoutGrove.FIREFLY, on * 0.25))

## A lantern, about the pixel it hangs by on the end of its cord, and its
## light on whatever is behind it. `salt` puts its flame out of step with the
## others'.
func _paint_lantern(c: CanvasItem, salt: int) -> void:
	var k := HideoutScenery.flicker(_t, salt)
	HideoutScenery.halo(c, -2, 0, 5, 6, HideoutGrove.LAMP, 9, 0.07 * k)
	HideoutScenery.box(c, -2, 0, 5, 1, HideoutGrove.WOOD_DARK)
	HideoutScenery.box(c, -2, 1, 5, 5, HideoutScenery.faded(HideoutGrove.LAMP, 0.55 + 0.4 * k))
	HideoutScenery.box(c, -1, 2, 3, 3, HideoutScenery.faded(HideoutGrove.FLAME_CORE, 0.6 + 0.4 * k))
	HideoutScenery.box(c, -2, 6, 5, 1, HideoutGrove.WOOD_DARK)
