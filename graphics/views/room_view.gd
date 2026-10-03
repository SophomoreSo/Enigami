class_name RoomView
extends Node2D

## A room, drawn: the tile field, its door frames, whatever exit it
## holds, the cables hung from its rock and the foliage growing on its floors.
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

var room: Room
var _tiles: TileLayer
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

func _ready() -> void:
	room = get_parent() as Room
	z_index = 0
	_tiles = TileLayer.new()
	_tiles.view = self
	_tiles.z_index = -1
	add_child(_tiles)
	if room != null:
		room.built.connect(_on_built)
	# The rock past the room is only as wide as the screen shows, so a screen
	# that changes shape — a window dragged, a phone turned — has it drawn again.
	get_viewport().size_changed.connect(_tiles.queue_redraw)

func _on_built() -> void:
	_tiles.queue_redraw()
	_hang_lines()
	_grow_foliage()

## Scenery of somebody else's making, stood in the room: in front of the tiles
## and behind everything that hangs, grows or moves. The hideout dresses its
## room this way, in whichever of its looks is on (`HideoutScenery`); the room
## knows nothing of what it is given.
func dress(scenery: Node2D) -> void:
	scenery.z_index = -1
	add_child(scenery)
	move_child(scenery, _tiles.get_index() + 1)

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
	for y in range(0, Room.H - clear):
		for x in range(2, Room.W - 2):
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
	for y in range(1, Room.H):
		for x in range(1, Room.W - 1):
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
## the outside is, but for the gap a door cuts, which runs on through it.
func _rock(x: int, y: int) -> bool:
	if x >= 0 and y >= 0 and x < Room.W and y < Room.H:
		return room.is_solid(x, y)
	if y >= 0 and y < Room.H and Room.DOOR_ROWS.has(y):
		if (x < 0 and room.doors.has(Components.W)) or (x >= Room.W and room.doors.has(Components.E)):
			return false
	if x >= 0 and x < Room.W and Room.DOOR_COLS.has(x):
		if (y < 0 and room.doors.has(Components.N)) or (y >= Room.H and room.doors.has(Components.S)):
			return false
	return true

func _process(_delta: float) -> void:
	if room != null and not room.extraction.is_empty():
		queue_redraw()

func draw_static(c: CanvasItem) -> void:
	if room == null or not is_instance_valid(room):
		return
	var w := Room.W * Room.CELL
	var h := Room.H * Room.CELL
	c.draw_rect(Rect2(0, 0, w, h), Style.ROOM_BG)
	for x in range(0, Room.W + 1, 2):
		c.draw_line(Vector2(x * Room.CELL, 0), Vector2(x * Room.CELL, h), Style.ROOM_GRID, 2.0)
	for y in range(0, Room.H + 1, 2):
		c.draw_line(Vector2(0, y * Room.CELL), Vector2(w, y * Room.CELL), Style.ROOM_GRID, 2.0)

	var tint := Style.region_tint(int(room.data.get("region", 0)))
	for y in Room.H:
		for x in Room.W:
			if not room.is_solid(x, y):
				continue
			var r := Rect2(x * Room.CELL, y * Room.CELL, Room.CELL, Room.CELL)
			c.draw_rect(r, tint)
			if not room.is_solid(x, y - 1):
				c.draw_rect(Rect2(r.position, Vector2(Room.CELL, 4)), tint.lightened(0.35))
			c.draw_rect(r, Color(0, 0, 0, 0.22), false, 2.0)

	# The rock past the room, tiled the way the room's own is, and the tunnels
	# its doors open into.
	var out := reach(get_viewport())
	for y in range(-out.y, Room.H + out.y):
		for x in range(-out.x, Room.W + out.x):
			if x >= 0 and y >= 0 and x < Room.W and y < Room.H:
				continue
			var r := Rect2(x * Room.CELL, y * Room.CELL, Room.CELL, Room.CELL)
			if not _rock(x, y):
				c.draw_rect(r, Style.ROOM_BG)
				continue
			c.draw_rect(r, tint)
			if not _rock(x, y - 1):
				c.draw_rect(Rect2(r.position, Vector2(Room.CELL, 4)), tint.lightened(0.35))
			c.draw_rect(r, Color(0, 0, 0, 0.22), false, 2.0)

	for dir in room.doors:
		var dr := room.door_rect(int(dir))
		c.draw_rect(dr, Style.DOOR_FILL)
		c.draw_rect(dr, Style.DOOR_EDGE, false, 2.0)

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
