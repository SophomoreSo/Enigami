class_name RoomView
extends Node2D

## A room, drawn: the tile field, its door frames, whatever exit it
## holds, the cables hung from its rock and the foliage growing on its floors.
## Its gates are drawn by their own views (`GateView`).
##
## And how it stands to the light (`Lighting`): which way its rock faces where
## it meets the open air, the shadow that rock throws, and the light its way
## out gives.
##
## Tiles never change while a room is loaded, so they are drawn once onto their
## own layer the moment the room finishes building. The exit animates, the
## cables sway, and the grass bends where somebody walks through it.
##
## The rock goes on past the room's edge, out to wherever the screen does. A
## room is 1280 across, and the screen is at least 1280x720 but takes the shape
## of the display: a phone longer than 16:9 shows more either side of the room,
## a squarer screen more above and below it. The camera stays on the room, so
## what those show is more of the rock the room was cut out of rather than the
## dark past the world, and a door's gap runs on through it as a tunnel, so a
## way out still reads as one.

## The lines hung from a room's rock — cables, and whatever else the content
## database's `hangings` say — are scenery: they hang from the ceiling and
## from under the ledges, and sway when somebody walks through them (`Rope`).
## Open cells a line needs under its end, to swing in without meeting a floor.
const SWING_ROOM := 2
## How far apart two lines hang, in cells, so they read as two.
const HANG_GAP := 3
## The corner of the room the readout stands over — the health bar and the
## slot cards, in the top left of the screen, which is the top left of the
## room on a screen the room's own shape. A line hung there is one nobody
## sees.
const READOUT_COLS := 10
const READOUT_ROWS := 8
## How much the way the rock faces counts, a pixel of the picture at a time in
## from where it meets the open air: its skin is lit only from its own side,
## and by three pixels in it takes any light alike.
const FACE := [1.0, 0.6, 0.3]
## The light a way out gives: how far it reaches in world units, how bright it
## is, and how much of it hangs in the air.
const EXIT_REACH := 170.0
const EXIT_LIGHT := 1.2
const EXIT_AIR := 0.06

var room: Room
var _tiles: TileLayer
## The tiles' twin, for the light: how the rock faces.
var _faces: Faces
## The rock's edges, for whatever lamp is near them to throw a shadow off.
var shadow: ShadowCaster
## The light of the way out, in a room that has one.
var exit_lamp: Lamp
## The lines hung in this room, in the order they were hung.
var ropes: Array = []
## The patches growing on this room's floors, in the order they were grown,
## which is the order they are drawn in (`Foliage`).
var plants: Array = []

## The static half. It sits behind everything and redraws only when asked.
class TileLayer extends Node2D:
	var view: RoomView

	func _draw() -> void:
		if view != null:
			view.draw_static(self)

## How the rock faces, for the light: the tiles' twin, drawn into the picture
## of the world's normals and nowhere else (`Lighting.NORMAL_LAYER`), and as
## often as the tiles are. The tiles themselves are the back of the picture
## (`Lighting.BACKDROP_LAYER`) and are not drawn there at all: they are flat,
## and they are most of what a frame costs to draw.
class Faces extends Node2D:
	var view: RoomView

	func _draw() -> void:
		if view != null:
			view.draw_faces(self)

func _ready() -> void:
	room = get_parent() as Room
	z_index = 0
	# What is drawn here itself is the way out, which is its own light.
	material = Lighting.glow()
	# Behind the tiles, so whatever stands in front of them — a look the room
	# is dressed in — is in front of this too.
	_faces = Faces.new()
	_faces.view = self
	_faces.z_index = -1
	_faces.visibility_layer = Lighting.NORMAL_LAYER
	add_child(_faces)
	_tiles = TileLayer.new()
	_tiles.view = self
	_tiles.z_index = -1
	_tiles.visibility_layer = Lighting.BACKDROP_LAYER
	add_child(_tiles)
	shadow = ShadowCaster.new()
	add_child(shadow)
	if room != null:
		room.built.connect(_on_built)
	# The rock past the room is only as wide as the screen shows, so a screen
	# that changes shape — a window dragged, a phone turned — has it drawn again.
	get_viewport().size_changed.connect(_on_reshaped)

func _on_built() -> void:
	_on_reshaped()
	_hang_lines()
	_grow_foliage()
	_light_exit()

## The rock as far as the screen shows it: its picture, how it faces, and the
## edges it throws shadows off.
func _on_reshaped() -> void:
	_tiles.queue_redraw()
	_faces.queue_redraw()
	_cast()

## Scenery of somebody else's making, stood in the room: in front of the tiles
## and behind everything that hangs, grows or moves. The hideout dresses its
## room this way, in whichever of its looks is on (`HideoutScenery`); the room
## knows nothing of what it is given. A look is painted over the room's own
## rock, edge and all, so how that rock faces goes with it: a dressed room is
## as flat as the look painted on it.
func dress(scenery: Node2D) -> void:
	scenery.z_index = -1
	add_child(scenery)
	move_child(scenery, _tiles.get_index() + 1)
	_faces.visible = false

## What hangs from the room's rock is the `hangings` rows of the content
## database: of each kind of line, how many and how long. Where each hangs is
## decided here: from a solid cell with open air under it for its length and
## its swing — the ceiling, or the underside of a ledge — never at the edge
## of the room, never under the readout, and never two within HANG_GAP of
## each other. Which cells, how many and how long is rolled from the room's
## own seed, so a room looks the same every time it is walked into, and from
## a roll of its own rather than the room's, so the monsters and the loot
## fall as they always did. Each line is settled before it is seen, so a room
## never opens on lines dropping into place.
func _hang_lines() -> void:
	for r in ropes:
		if is_instance_valid(r):
			r.queue_free()
	ropes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = room.rng.seed ^ 0x5eedcab1e
	var hung: Array[Vector2i] = []
	for row in Rope.hangings():
		var kind := String(row["rope"])
		var longest := int(row["longest"])
		var spots := _spots(longest + SWING_ROOM)
		var want := rng.randi_range(int(row["fewest"]), int(row["most"]))
		var count := 0
		var tries := 0
		while count < want and not spots.is_empty() and tries < 40:
			tries += 1
			var spot: Vector2i = spots[rng.randi() % spots.size()]
			var crowded := false
			for h in hung:
				if absi(h.x - spot.x) < HANG_GAP:
					crowded = true
			if crowded:
				continue
			hung.append(spot)
			count += 1
			var rope := Rope.of(kind)
			rope.z_index = -1
			rope.visibility_layer = PixelCamera.WORLD_LAYER
			rope.hang(Vector2((spot.x + 0.5) * Room.CELL, (spot.y + 1) * Room.CELL),
				rng.randi_range(int(row["shortest"]), longest) * Room.CELL)
			rope.settle()
			add_child(rope)
			ropes.append(rope)

## The cells a line needing `clear` open cells under it may hang from: solid,
## with that much air below, in from the room's edge and out from under the
## readout.
func _spots(clear: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(0, room.rows - clear):
		for x in range(2, room.cols - 2):
			if x < READOUT_COLS and y < READOUT_ROWS:
				continue
			if room.is_solid(x, y) and _clear_under(x, y, clear):
				out.append(Vector2i(x, y))
	return out

## Whether the `n` cells under (x, y) are open.
func _clear_under(x: int, y: int, n: int) -> bool:
	for k in range(1, n + 1):
		if room.is_solid(x, y + k):
			return false
	return true

## What grows on the room's floors is the `growths` rows of the content
## database: of each kind of foliage, how many patches and how long. Where each
## grows is decided here: along the top of solid cells with open air over
## them — the floor and the tops of the ledges — never at the room's edge, and
## never over a patch of its own kind. Which cells, how
## many and how long is rolled from the room's own seed, so a room looks the
## same every time it is walked into, and from a roll of its own rather than
## the room's, so the monsters and the loot fall as they always did.
func _grow_foliage() -> void:
	for p in plants:
		if is_instance_valid(p):
			p.queue_free()
	plants.clear()
	var ground := _ground()
	if ground.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = room.rng.seed ^ 0xf011a6e
	for row in Foliage.growths():
		var kind := String(row["foliage"])
		var want := rng.randi_range(int(row["fewest"]), int(row["most"]))
		var taken := {}
		var count := 0
		var tries := 0
		while count < want and tries < 40:
			tries += 1
			var long := rng.randi_range(int(row["shortest"]), int(row["longest"]))
			var start: Vector2i = ground.keys()[rng.randi() % ground.size()]
			var fits := true
			for k in long:
				var cell := start + Vector2i(k, 0)
				if not ground.has(cell) or taken.has(cell):
					fits = false
					break
			if not fits:
				continue
			for k in long:
				taken[start + Vector2i(k, 0)] = true
			count += 1
			var patch := Foliage.of(kind)
			@warning_ignore("integer_division")
			patch.grow(long * Room.CELL / Foliage.S, rng.randi())
			patch.position = Vector2(start.x * Room.CELL, start.y * Room.CELL)
			patch.z_index = -1
			patch.visibility_layer = PixelCamera.WORLD_LAYER
			add_child(patch)
			plants.append(patch)

## The cells foliage may grow on top of, as a set: solid, with open air over
## them inside the room and in from its edge.
func _ground() -> Dictionary:
	var out := {}
	for y in range(1, room.rows):
		for x in range(1, room.cols - 1):
			if room.is_solid(x, y) and not room.is_solid(x, y - 1):
				out[Vector2i(x, y)] = true
	return out

## How many cells past the room the screen shows on each side, across and down,
## with two more for a shake to swing into — for whatever draws a room's
## surroundings, the tower's too. Every screen frames a room at its own size and
## only ever closes in on it (`Fx.direct`), so the viewport is the most of the
## world there is to cover.
static func reach(vp: Viewport) -> Vector2i:
	var shown := vp.get_visible_rect().size
	var spare := (shown - Vector2(Room.W, Room.H) * Room.CELL).max(Vector2.ZERO) * 0.5
	return Vector2i((spare / Room.CELL).ceil()) + Vector2i(2, 2)

## Whether a cell is rock, out past the room's own edge as well as in it. All of
## the outside is, but for the gap a doorway cuts, which runs on through it.
func _rock(x: int, y: int) -> bool:
	if x >= 0 and y >= 0 and x < room.cols and y < room.rows:
		return room.is_solid(x, y)
	if y >= 0 and y < room.rows and Room.DOOR_ROWS.has(y):
		if (x < 0 and room.doors.has(Components.W)) or (x >= room.cols and room.doors.has(Components.E)):
			return false
	return true

func _process(_delta: float) -> void:
	if room != null and not room.extraction.is_empty():
		queue_redraw()
		if exit_lamp != null:
			exit_lamp.color = Style.EXIT_OPEN if room.extraction_blocked_reason() == "" else Style.EXIT_SEALED

## A way out lights the room round it, in its own colour: open or sealed.
func _light_exit() -> void:
	if exit_lamp != null:
		exit_lamp.queue_free()
		exit_lamp = null
	if room.extraction.is_empty():
		return
	exit_lamp = Lamp.of(Style.EXIT_OPEN, EXIT_REACH, EXIT_LIGHT)
	exit_lamp.volume = EXIT_AIR
	exit_lamp.position = room.extraction_rect().get_center()
	add_child(exit_lamp)

## Every line where the room's rock meets open air, out as far as the screen
## shows: [from, to, the way the rock faces there], each as long a run as it
## goes on for. Rock beside rock is no line. Both things the light wants of
## the rock are read off these: where it faces (`draw_faces`), and what it
## throws shadows off (`_cast`).
func air_lines() -> Array:
	var lines: Array = []
	if room == null or not is_instance_valid(room) or room.solid.is_empty():
		return lines
	var cell := float(Room.CELL)
	var out := reach(get_viewport())
	# Floors and the undersides of things: along every line between two rows.
	for y in range(-out.y + 1, room.rows + out.y):
		var from := 0
		var way := 0
		for x in range(-out.x, room.cols + out.x + 1):
			var now := 0
			if x < room.cols + out.x:
				var below := _rock(x, y)
				var above := _rock(x, y - 1)
				if below and not above:
					now = -1
				elif above and not below:
					now = 1
			if now != way:
				if way != 0:
					lines.append([Vector2(from, y) * cell, Vector2(x, y) * cell, Vector2(0, way)])
				from = x
				way = now
	# Walls: along every line between two columns.
	for x in range(-out.x + 1, room.cols + out.x):
		var from := 0
		var way := 0
		for y in range(-out.y, room.rows + out.y + 1):
			var now := 0
			if y < room.rows + out.y:
				var after := _rock(x, y)
				var before := _rock(x - 1, y)
				if after and not before:
					now = -1
				elif before and not after:
					now = 1
			if now != way:
				if way != 0:
					lines.append([Vector2(x, from) * cell, Vector2(x, y) * cell, Vector2(way, 0)])
				from = y
				way = now
	return lines

## Which way the rock faces, wherever it meets the open air: its skin, FACE
## pixels deep, painted in the colour of the way out of it (`Lighting.faces`)
## — up along a floor, down under a ledge, sideways on a wall, a strip the
## length of each run — and both ways at once round a corner that stands out
## into the air. The rest of the rock is left alone and is flat.
func draw_faces(c: CanvasItem) -> void:
	if room == null or not is_instance_valid(room):
		return
	var px := float(PixelCamera.SCALE)
	var deep := FACE.size()
	for line: Array in air_lines():
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		var way: Vector2 = line[2]
		for k in deep:
			# In from the line, the other way from the one the rock faces: a row
			# of the picture, or a column, for each step.
			var into := -way * float(k) * px
			var strip := Rect2(from + into, (to - from) - way * px).abs()
			c.draw_rect(strip, Lighting.faces(way, FACE[k]))
	var cell := float(Room.CELL)
	var out := reach(get_viewport())
	for y in range(-out.y, room.rows + out.y):
		for x in range(-out.x, room.cols + out.x):
			if not _rock(x, y):
				continue
			var left := not _rock(x - 1, y)
			var right := not _rock(x + 1, y)
			var up := not _rock(x, y - 1)
			var down := not _rock(x, y + 1)
			if not ((left or right) and (up or down)):
				continue
			var at := Vector2(x, y) * cell
			# A corner out in the open air faces both ways out of it: each of its
			# pixels by how near either side it is.
			for corner in [[left, up, -1, -1], [right, up, 1, -1], [left, down, -1, 1], [right, down, 1, 1]]:
				if not (corner[0] and corner[1]):
					continue
				for i in deep:
					for j in deep:
						var both := Vector2(float(corner[2]) * float(FACE[i]), float(corner[3]) * float(FACE[j]))
						var spot := Vector2(
							i * px if corner[2] < 0 else cell - (i + 1) * px,
							j * px if corner[3] < 0 else cell - (j + 1) * px)
						c.draw_rect(Rect2(at + spot, Vector2(px, px)), Lighting.faces(both, maxf(FACE[i], FACE[j])))

## The rock's edges, for a lamp to throw shadows off: every line where it
## meets open air, each run of it one edge that faces the air. Rock beside
## rock is no edge, so the rock is lit as far into itself as a lamp reaches,
## and dark only behind another piece of it.
func _cast() -> void:
	var ends := PackedVector2Array()
	var facings := PackedVector2Array()
	for line: Array in air_lines():
		ends.append(line[0])
		ends.append(line[1])
		facings.append(line[2])
	shadow.edges(ends, facings)

func draw_static(c: CanvasItem) -> void:
	if room == null or not is_instance_valid(room):
		return
	var w := room.cols * Room.CELL
	var h := room.rows * Room.CELL
	c.draw_rect(Rect2(0, 0, w, h), Style.ROOM_BG)
	for x in range(0, room.cols + 1, 2):
		c.draw_line(Vector2(x * Room.CELL, 0), Vector2(x * Room.CELL, h), Style.ROOM_GRID, 2.0)
	for y in range(0, room.rows + 1, 2):
		c.draw_line(Vector2(0, y * Room.CELL), Vector2(w, y * Room.CELL), Style.ROOM_GRID, 2.0)

	var tint := Style.region_tint(int(room.data.get("region", 0)))
	for y in room.rows:
		for x in room.cols:
			if not room.is_solid(x, y):
				continue
			var r := Rect2(x * Room.CELL, y * Room.CELL, Room.CELL, Room.CELL)
			c.draw_rect(r, tint)
			if not room.is_solid(x, y - 1):
				c.draw_rect(Rect2(r.position, Vector2(Room.CELL, 4)), tint.lightened(0.35))
			_outline(c, r, Color(0, 0, 0, 0.22))

	# The rock past the room, tiled the way the room's own is, and the tunnels
	# its doors open into.
	var out := reach(get_viewport())
	for y in range(-out.y, room.rows + out.y):
		for x in range(-out.x, room.cols + out.x):
			if x >= 0 and y >= 0 and x < room.cols and y < room.rows:
				continue
			var r := Rect2(x * Room.CELL, y * Room.CELL, Room.CELL, Room.CELL)
			if not _rock(x, y):
				c.draw_rect(r, Style.ROOM_BG)
				continue
			c.draw_rect(r, tint)
			if not _rock(x, y - 1):
				c.draw_rect(Rect2(r.position, Vector2(Room.CELL, 4)), tint.lightened(0.35))
			_outline(c, r, Color(0, 0, 0, 0.22))

	for dir in room.doors:
		var dr := room.door_rect(int(dir))
		c.draw_rect(dr, Style.DOOR_FILL)
		_outline(c, dr, Style.DOOR_EDGE)

## A rect's edge, as an unfilled `draw_rect` two units wide draws it, out of
## four filled rects. An unfilled rect is a polygon of its own, which the
## renderer draws on its own and which cuts the run of rects either side of it
## in two: round every cell of rock in the field, that was two draws a cell —
## a thousand a frame for the bench, and most of what its frame cost. Filled,
## every rect in the field is drawn together, to the same pixels.
static func _outline(c: CanvasItem, r: Rect2, col: Color) -> void:
	c.draw_rect(Rect2(r.position.x - 1.0, r.position.y - 1.0, r.size.x + 2.0, 2.0), col)
	c.draw_rect(Rect2(r.position.x - 1.0, r.end.y - 1.0, r.size.x + 2.0, 2.0), col)
	c.draw_rect(Rect2(r.position.x - 1.0, r.position.y + 1.0, 2.0, r.size.y - 2.0), col)
	c.draw_rect(Rect2(r.end.x - 1.0, r.position.y + 1.0, 2.0, r.size.y - 2.0), col)

func _draw() -> void:
	if room == null or not is_instance_valid(room) or room.extraction.is_empty():
		return
	var r := room.extraction_rect()
	var reason := room.extraction_blocked_reason()
	var col := Style.EXIT_OPEN if reason == "" else Style.EXIT_SEALED
	draw_rect(r, Color(col.r, col.g, col.b, 0.12))
	draw_rect(r, col, false, 2.0)
	var c := r.get_center()
	var t := float(Time.get_ticks_msec()) / 700.0
	for i in 3:
		var rad: float = 20.0 + float(i) * 12.0 + sin(t + float(i)) * 3.0
		draw_arc(c, rad, 0, TAU, 28, Color(col.r, col.g, col.b, 0.45 - 0.1 * float(i)), 2.0)
	var title := RaidMap.exit_name(room.extraction)
	PixelCamera.draw_text(self, c + Vector2(0, -60), title, col)
	if room.extract_hold > 0.0:
		var need := float(room.extraction.get("time", 2.5))
		draw_arc(c, 52.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(room.extract_hold / need, 0.0, 1.0),
			32, Color(0.6, 1.0, 0.8), 4.0)
