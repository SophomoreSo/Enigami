class_name RoomView
extends Node2D

## A room, drawn: the tile field, its hazards and door frames, and whatever
## exit it holds.
##
## Tiles never change while a room is loaded, so they are drawn once onto their
## own layer the moment the room finishes building. Only the exit animates.
##
## The rock goes on past the room's edge, out to wherever the screen does. A
## room is 1280 across, and the screen is at least 1280x720 but takes the shape
## of the display: a phone longer than 16:9 shows more either side of the room,
## a squarer screen more above and below it. The camera stays on the room, so
## what those show is more of the rock the room was cut out of rather than the
## dark past the world, and a door's gap runs on through it as a tunnel, so a
## way out still reads as one.

var room: Room
var _tiles: TileLayer

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

	for cell in room.hazards:
		var base: Vector2 = Vector2(cell.x * Room.CELL, (cell.y + 1) * Room.CELL)
		for i in 4:
			var x0: float = base.x + float(i) * Room.CELL * 0.25
			c.draw_colored_polygon(PackedVector2Array([
				Vector2(x0, base.y),
				Vector2(x0 + Room.CELL * 0.125, base.y - 14.0),
				Vector2(x0 + Room.CELL * 0.25, base.y),
			]), Style.HAZARD)

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
