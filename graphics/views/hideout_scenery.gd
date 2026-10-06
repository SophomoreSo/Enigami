class_name HideoutScenery
extends Node2D

## What the hideout's room is dressed in: one look of it, drawn in code a pixel
## of the picture at a time. There is no image behind any of it.
##
## This is the ground every look stands on, and no look itself. A look is a
## script of its own that extends this one — the city in the rain is
## `HideoutCity` — and says what its depths are and what is painted on each;
## which looks there are, and which one the room is wearing, is
## `HideoutThemes`. What is here is what they share: the room's own edges, in
## pixels of the buffer the world is drawn into (`PixelCamera`), where a room
## is 640 by 352, so nothing can land between two of them; where each
## station's fittings stand, and how lit they are for whoever is standing at
## one; the depths themselves, drawn once or drawn again as they move; what
## hangs in the room on a line and swings on it; and the handful of shapes
## everything is made of.
##
## It is scenery, and only that. It reads where the stations stand, whether the
## player is at one and whether the gate would open, and changes nothing; with
## it gone the hideout is the bare room it was. So it goes on moving while the
## game is stopped: it is weather, and a menu does not stop the rain.
##
## What a look paints glowing gives light as well (`shine`): a torch, a tube,
## a sign, each the light of its kind (`Shine`, a row of `lights`), put where
## it is painted and brightened and dimmed as the picture is (`_shine_now`).
## What is seen out past the room — the sky, the city, the wood — is lit as it
## is painted, and by nothing in the room: the room's own depth (`room`) says
## what of it is open.

const S := PixelCamera.SCALE

## --- the room, in buffer pixels ----------------------------------------------
## The room's own edges: the inside of its walls, its ceiling and its floor,
## and where the floor's own face ends and the rock under it goes on.
const LEFT := 16
const RIGHT := 624
const TOP := 16
const FLOOR := 320
const UNDER := 336
## How high the tallest thing against the wall may stand off the floor, which
## is what the stations' signs have to hang clear of.
const TALLEST := 68
## How many times a second what moves is drawn again. Not every frame: this
## is pixel art, moving a pixel at a time, and a screen drawing a hundred and
## twenty frames a second would have it all drawn four times for one picture.
const REDRAWS := 30.0
## What marks what is seen out past the room as out there (`room`).
const OUT_THERE := preload("res://graphics/assets/shaders/out_there.gdshader")

## A depth of the picture: drawn once, by whatever it was given, and again
## only when it is asked to be. It keeps count, so a test can see that what
## was meant to be drawn once was.
class Layer extends Node2D:
	var paint: Callable
	var painted := 0
	## Whether it is out past the room (`room`): every depth made before the
	## room is.
	var out_there := false

	func _draw() -> void:
		painted += 1
		if paint.is_valid():
			paint.call(self)

var world: HideoutWorld
## Which look this is, by its name among `HideoutThemes`'.
var look := ""
## The sign hung over each station (`HideoutWorldView`), in this look's own
## colours: the plate, and what is written on it — as it hangs, lit for
## somebody a press would count for, and shut.
var plate := Style.HIDEOUT_PLATE
var ink := Style.HIDEOUT_SIGN
var ink_lit := Style.HIDEOUT_SIGN_LIT
var ink_shut := Style.HIDEOUT_SIGN_SHUT
## The depths, back to front: the ones drawn once, and the ones that move and
## are drawn again REDRAWS times a second.
var _still: Array[Layer] = []
var _moving: Array[Layer] = []
## What hangs in the room and is drawn again as often as what moves is: see
## `hung`.
var _hung: Array[Layer] = []
## The cords hung in the room for a light to swing on, in the order they were
## hung: see `cord`.
var cords: Array[Rope] = []
var _t := 0.0
## How long until what moves is next drawn.
var _due := 0.0
## Where each station's fittings stand, in buffer pixels: under the station,
## on the floor. A station itself is the middle of the cell over it.
var _at: Dictionary = {}
## How lit each station's own fittings are, 0 to 1: up when the player is at
## one that would answer, and eased so it does not snap.
var _lit: Dictionary = {}

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	# Where the stations stand in the hideout as it is, for a scenery stood
	# somewhere with no stations to ask.
	for stand in [["weapons", 120], ["shop", 328], ["gate", 552]]:
		_at[stand[0]] = Vector2i(stand[1], FLOOR)
		_lit[stand[0]] = 0.0
	if world != null and is_instance_valid(world):
		for id in world.stations:
			var s: Station = world.stations[id]
			_at[id] = Vector2i(roundi(to_local(s.global_position).x / S), FLOOR)
			_lit[id] = 0.0
	_build()
	# Slid to where the player already stands, so a look put on in the middle
	# of the room does not open a pixel out and step into place.
	if _watched():
		_slide(_walked())

## A look's own: what it is made of, and its depths, back to front, each
## `still` or `moving`.
func _build() -> void:
	pass

## A look's own: its depths moved for where the player stands, -1 at the
## room's left wall and 1 at its right. `slid` is the step each takes.
func _slide(_across_the_room: float) -> void:
	pass

## A depth drawn once. Like one that moves, it is the back of the picture
## (`Lighting.BACKDROP_LAYER`): flat to any lamp, and thousands of boxes that
## are not drawn a second time to say so.
func still(paint: Callable) -> Layer:
	var l := Layer.new()
	l.paint = paint
	l.visibility_layer = Lighting.BACKDROP_LAYER
	add_child(l)
	_still.append(l)
	return l

## The room itself: a depth drawn once, as any `still` is, that is the room's
## walls and floor and what is built into them, and not what is seen out past
## them. Every depth before it is out there, and whatever it leaves open of
## them is marked so in the picture of the world's normals
## (`out_there.gdshader`): no lamp in the room lights the sky through its
## arches, and no darkness in the room dims it. Only what gives light out
## there with it does (`shine`).
func room(paint: Callable) -> Layer:
	for depth in _still + _moving:
		depth.out_there = true
	var l := still(paint)
	_mark_out_there(paint)
	return l

## The room's walls drawn once more, alone, into a picture of their own the
## size of the room, and that picture drawn over the room in the normals and
## nowhere else. It is the first of the look's drawn there, so whatever hangs
## in the room, and whoever stands in it, is drawn over the mark as it is over
## the walls, and is in the room.
func _mark_out_there(paint: Callable) -> void:
	var size := Vector2i(RIGHT - LEFT, FLOOR - TOP)
	var walls := SubViewport.new()
	walls.disable_3d = true
	walls.transparent_bg = true
	walls.size = size
	walls.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(walls)
	walls.canvas_transform = Transform2D(0.0, Vector2.ONE / S, 0.0, -Vector2(LEFT, TOP))
	var alone := Layer.new()
	alone.paint = paint
	walls.add_child(alone)
	var mark := Layer.new()
	mark.visibility_layer = Lighting.NORMAL_LAYER
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mark.material = ShaderMaterial.new()
	(mark.material as ShaderMaterial).shader = OUT_THERE
	var drawn := walls.get_texture()
	mark.paint = func(c: CanvasItem) -> void:
		c.draw_texture_rect(drawn, Rect2(Vector2(LEFT, TOP) * S, Vector2(size) * S), false)
	# Not before the walls have been drawn into their picture: an empty one
	# would mark the whole room out there.
	mark.visible = false
	RenderingServer.frame_post_draw.connect(mark.show, CONNECT_ONE_SHOT)
	add_child(mark)
	move_child(mark, 0)

## A depth that moves: drawn again REDRAWS times a second.
func moving(paint: Callable) -> Layer:
	var l := Layer.new()
	l.paint = paint
	l.visibility_layer = Lighting.BACKDROP_LAYER
	add_child(l)
	_moving.append(l)
	return l

## Something that hangs in the room and swings — a lantern on the end of its
## cord — and is neither kind of depth: it is carried by what it hangs on
## (`Rope.attach`), so it is drawn about its own origin, which is the pixel it
## hangs by, and is never slid. Drawn once, since being carried draws nothing
## again; or with `again`, as often as what moves is — a flame flickers
## wherever it has swung to.
func hung(paint: Callable, again: bool = false) -> Layer:
	var l := Layer.new()
	l.paint = paint
	add_child(l)
	if again:
		_hung.append(l)
	return l

## A cord hung in the room from the pixel `at`, `drop` pixels long, for a
## light to swing on: a `Rope` of the kind `cord`, which is one length, taut
## under what rides it (`ride`). In `colour`, a look's own for what its lights
## hang on — a chain's iron, a strap's leather — or the kind's with none
## given. It hangs from the middle of that pixel: in that column, and not on
## the line between two.
func cord(at: Vector2i, drop: int, colour: Color = Color(0, 0, 0, 0)) -> Rope:
	var rope := Rope.of("cord")
	if colour.a > 0.0:
		rope.color = colour
	var length := float(drop * S)
	rope.hang((Vector2(at) + Vector2(0.5, 0.5)) * S, length,
		length / float(maxi(1, roundi(length / rope.segment))))
	add_child(rope)
	cords.append(rope)
	return rope

## `what` — something `hung` — put on the end of the cord `on`, to swing with
## it. With a `body`, the room it takes up from the pixel it hangs by, it is
## something to walk into: a body going through it sets it swinging, and so
## does an attack.
func ride(on: Rope, what: Layer, body: Rect2i = Rect2i()) -> void:
	on.attach(what, on.nodes.size() - 1, Vector2.ZERO,
		Rect2(Vector2(body.position) * S, Vector2(body.size) * S))

func _process(delta: float) -> void:
	_t += delta
	if world != null and is_instance_valid(world):
		for id in world.stations:
			var s: Station = world.stations[id]
			var want := 1.0 if s.near and s.open else 0.0
			_lit[id] = move_toward(float(_lit.get(id, 0.0)), want, delta * 5.0)
	if _watched():
		_slide(_walked())
	_shine_now()
	_due -= delta
	if _due <= 0.0:
		_due = maxf(_due + 1.0 / REDRAWS, 0.0)
		for l in _moving:
			l.queue_redraw()
		for l in _hung:
			l.queue_redraw()

## --- what gives light ------------------------------------------------------

## `layer` — a depth, or something hung — gives the light of the kind `kind`
## (`Shine`, a row of `lights`) at the pixel (x, y) of the buffer: of the room,
## or, on something hung, about the pixel it hangs by. The light is where the
## layer is, and slides or swings with it; on a depth out past the room
## (`room`) it is out there too, and lights what is. In `colour`, for one a
## look tints its own way; and `wide` by `tall` pixels, for an area a look
## sizes its own way. Answers it, for the look to brighten and dim
## (`_shine_now`).
func shine(layer: Node2D, kind: String, x: float, y: float, colour: Color = Color(0, 0, 0, 0),
		wide: int = 0, tall: int = 0) -> Shine:
	var s := Shine.give(layer, kind, Vector2(x, y) * S)
	s.out_there = layer is Layer and (layer as Layer).out_there
	if colour.a > 0.0:
		s.color = Color(colour.r, colour.g, colour.b)
	if wide > 0:
		s.size = Vector2(wide, maxi(tall, 1)) * S
	return s

## A look's own: how lit each of its lights is this moment, as its picture
## is. Every frame.
func _shine_now() -> void:
	pass

## Whether there is a player in the room to move the depths for.
func _watched() -> bool:
	return world != null and is_instance_valid(world) \
		and world.player != null and is_instance_valid(world.player)

## How far across the room the player stands: -1 at its left wall, 1 at its
## right.
func _walked() -> float:
	var middle := (LEFT + RIGHT) * 0.5
	return clampf((to_local(world.player.global_position).x / S - middle) / (RIGHT - middle - 4.0), -1.0, 1.0)

## Where a depth that slides `most` pixels either way sits for `across`: whole
## pixels of the buffer, and the other way from the player, as a thing further
## off than the glass does.
static func slid(across: float, most: float) -> float:
	return -roundf(across * most) * S

## Whether the gate would let anybody through.
func _gate_open() -> bool:
	if world != null and is_instance_valid(world) and world.stations.has("gate"):
		return (world.stations["gate"] as Station).open
	return true

## Where the player stands, in buffer pixels across the room, or `otherwise`
## with nobody in it: for whatever in a look watches them go by.
func _player_x(otherwise: float) -> float:
	if not _watched():
		return otherwise
	return to_local(world.player.global_position).x / S

## --- drawing, a pixel of the buffer at a time -------------------------------

## Every box ever drawn, counted: what a frame costs is how far this moved
## while it was drawn, which `tests/graphics/hideout_scenery_test` holds to a
## budget — what stands still is drawn once, and only what moves again.
static var boxes := 0

static func box(c: CanvasItem, x: int, y: int, w: int, h: int, col: Color) -> void:
	if w > 0 and h > 0:
		boxes += 1
		c.draw_rect(Rect2(x * S, y * S, w * S, h * S), col)

## Every other pair of pixels along a row, for where one colour gives way to
## the next: two rows of it, out of step, are a blend a pixel face can make.
static func checker(c: CanvasItem, x: int, y: int, w: int, col: Color, step: int) -> void:
	var at := x + (2 if step % 2 == 1 else 0)
	while at < x + w:
		box(c, at, y, mini(2, x + w - at), 1, col)
		at += 4

## One colour giving way to the next down a box: `tones` from its top to its
## foot, each a band of it, with the seams between them checkered.
static func bands(c: CanvasItem, x: int, y: int, w: int, h: int, tones: Array) -> void:
	var band := float(h) / float(tones.size())
	for i in tones.size():
		var from := y + int(round(band * i))
		box(c, x, from, w, y + int(round(band * (i + 1))) - from, tones[i])
		if i > 0:
			checker(c, x, from - 2, w, tones[i], 0)
			checker(c, x, from - 1, w, tones[i], 1)
			checker(c, x, from, w, tones[i - 1], 0)

## A bitmap — one string a row, `#` for a pixel — with its top-left at (x, y).
static func stamp(c: CanvasItem, x: int, y: int, rows: Array, col: Color) -> void:
	for j in rows.size():
		var row := String(rows[j])
		var i := row.find("#")
		while i >= 0:
			var end := i
			while end < row.length() and row[end] == "#":
				end += 1
			box(c, x + i, y + j, end - i, 1, col)
			i = row.find("#", end)

## A bitmap in more colours than one: every letter of `rows` that `inks` has a
## colour for is a pixel of it, and anything else is nothing.
static func picture(c: CanvasItem, x: int, y: int, rows: Array, inks: Dictionary) -> void:
	for j in rows.size():
		var row := String(rows[j])
		var i := 0
		while i < row.length():
			var ch := row[i]
			var end := i + 1
			while end < row.length() and row[end] == ch:
				end += 1
			if inks.has(ch):
				box(c, x + i, y + j, end - i, 1, inks[ch])
			i = end

## A filled circle, a row at a time, and the same with a hole in it.
static func disc(c: CanvasItem, cx: int, cy: int, r: int, col: Color, hole: int = 0) -> void:
	for dy in range(-r, r + 1):
		var half := int(floor(sqrt(float(r * r - dy * dy) + 0.5)))
		var gap := -1
		if hole > 0 and absi(dy) <= hole:
			gap = int(floor(sqrt(float(hole * hole - dy * dy) + 0.5)))
		if gap >= 0:
			box(c, cx - half, cy + dy, half - gap, 1, col)
			box(c, cx + gap + 1, cy + dy, half - gap, 1, col)
		else:
			box(c, cx - half, cy + dy, half * 2 + 1, 1, col)

## A filled oval, `rx` across by `ry` down from its middle, a row at a time.
static func oval(c: CanvasItem, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	for dy in range(-ry, ry + 1):
		var half := int(floor(float(rx) * sqrt(maxf(1.0 - float(dy * dy) / float(ry * ry), 0.0)) + 0.5))
		box(c, cx - half, cy + dy, half * 2 + 1, 1, col)

## A line from one pixel to another, a pixel wide: a run of them a row, or a
## column, whichever way it leans.
static func line(c: CanvasItem, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	if dx >= dy:
		if x1 < x0:
			line(c, x1, y1, x0, y0, col)
			return
		var from := x0
		var row := y0
		for x in range(x0, x1 + 1):
			var y := y0 + int(round(float(y1 - y0) * float(x - x0) / float(maxi(dx, 1))))
			if y != row:
				box(c, from, row, x - from, 1, col)
				from = x
				row = y
		box(c, from, row, x1 + 1 - from, 1, col)
	else:
		if y1 < y0:
			line(c, x1, y1, x0, y0, col)
			return
		var from := y0
		var column := x0
		for y in range(y0, y1 + 1):
			var x := x0 + int(round(float(x1 - x0) * float(y - y0) / float(dy)))
			if x != column:
				box(c, column, from, 1, y - from, col)
				from = y
				column = x
		box(c, column, from, 1, y1 + 1 - from, col)

## A disc of light on whatever is behind it, kept inside the room: none of a
## look may show past the room's own walls.
static func glow(c: CanvasItem, cx: int, cy: int, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		var y := cy + dy
		if y < TOP or y >= UNDER:
			continue
		var half := int(floor(sqrt(float(r * r - dy * dy) + 0.5)))
		var from := maxi(cx - half, LEFT)
		box(c, from, y, mini(cx + half + 1, RIGHT) - from, 1, col)

## Light spilling out of a box of it: the same colour laid round it in steps,
## thinner the further out.
static func halo(c: CanvasItem, x: int, y: int, w: int, h: int, col: Color, reach: int, strength: float = 0.16) -> void:
	for k in range(reach, 0, -1):
		var spill := Color(col.r, col.g, col.b, strength * (1.0 - float(k - 1) / float(reach)))
		box(c, x - k, y - k + 1, w + 2 * k, h + 2 * k - 2, spill)
		box(c, x - k + 1, y - k, w + 2 * k - 2, h + 2 * k, spill)

## Light lying on the floor under whatever threw it, where a floor is wet or
## polished enough to hold it: every other row of it, fainter the further down.
static func wet(c: CanvasItem, x: int, w: int, col: Color, strength: float) -> void:
	for k in 6:
		box(c, x + k, FLOOR + 2 + k * 2, w - k * 2, 1, Color(col.r, col.g, col.b, strength * (1.0 - k / 6.0)))

## Words in light, in the buffer's own pixels: `x` is their middle and `y`
## their top. `size` is the face's own or a multiple of it.
static func words(c: CanvasItem, x: int, y: int, text: String, col: Color, size: int = 8) -> void:
	var tall := Loc.text_size(text, size)
	@warning_ignore("integer_division")
	var line_at := y + tall * 7 / 8
	PixelCamera.draw_text(c, Vector2(x * S, line_at * S), text, col, Color(0, 0, 0, 0), size)

## A light that stutters: on, but for a burst of flicker every so often,
## out of step with the others by its `salt`.
static func stutter(t: float, every: float, salt: int) -> float:
	var into := fmod(t + float(salt) * 1.7, every)
	if into > 0.45:
		return 1.0
	return 0.25 if (int(t * 24.0) * 7 + salt) % 5 < 2 else 1.0

## A flame's light: never still, never out — two slow swells and a quick one,
## each of a look's fires out of step with the rest by its `salt`.
static func flicker(t: float, salt: int) -> float:
	var s := float(salt) * 2.3
	return 0.78 + 0.12 * sin(t * 7.1 + s) + 0.07 * sin(t * 12.7 + s * 1.7) + 0.03 * sin(t * 23.0 + s * 0.6)

static func faded(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, col.a * a)
