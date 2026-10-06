class_name RockTiles
extends MapTiles

## The plain rock a raid's rooms are cut from (`RoomView`), as a tileset: every
## kind of ground drawn as that rock, in its region's tint, lit along its tops;
## a darker stretch of it behind, for a wall; and past the map's edge, the
## same rock. Out beyond it there is nothing but the room's own dark, with the
## grid on it every room has.

# Pixel art halves whole numbers on purpose.
@warning_ignore_start("integer_division")

func id() -> String:
	return "rock"

func title() -> String:
	return Loc.t("hud.maker.tiles.rock.title")

func ground_marks() -> PackedStringArray:
	return PackedStringArray([MadeRoom.ROCK])

func back_marks() -> PackedStringArray:
	return PackedStringArray(["#"])

func ground_name(_mark: String) -> String:
	return Loc.t("hud.maker.tiles.rock.rock")

func back_name(_mark: String) -> String:
	return Loc.t("hud.maker.tiles.rock.wall")

func paint_ground(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	var tint := Style.region_tint(cells.region)
	var r := Rect2(x * Room.CELL, y * Room.CELL, Room.CELL, Room.CELL)
	c.draw_rect(r, tint)
	if not cells.solid(x, y - 1):
		c.draw_rect(Rect2(r.position, Vector2(Room.CELL, 4)), tint.lightened(0.35))
	c.draw_rect(r, Color(0, 0, 0, 0.22), false, 2.0)

## The same rock, set back in the dark: coursed, and darker.
func paint_back(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	if cells.back_at(x, y) != "#":
		return
	var wall := Style.region_tint(cells.region).darkened(0.5)
	var px := x * C
	var py := y * C
	box(c, px, py, C, C, wall)
	box(c, px, py + C / 2, C, 1, wall.darkened(0.3))
	box(c, px + (C / 2 if y % 2 == 0 else 0), py, 1, C / 2, wall.darkened(0.3))
	box(c, px + (0 if y % 2 == 0 else C / 2), py + C / 2, 1, C / 2, wall.darkened(0.3))

func outside_colour() -> Color:
	return Style.region_tint(0).darkened(0.4)

## The room's own dark under everything, with its grid on it.
func depths() -> Array[Depth]:
	var dark := Depth.new()
	dark.paint = _dark
	dark.drift = 0.0
	dark.z_index = -12
	dark.visibility_layer = Lighting.BACKDROP_LAYER
	var out: Array[Depth] = [dark]
	return out

func _dark(c: CanvasItem, area: Rect2, _rest: Rect2, _t: float) -> void:
	c.draw_rect(area, Style.ROOM_BG)
	var from := Vector2i((area.position / (Room.CELL * 2)).floor())
	var to := Vector2i((area.end / (Room.CELL * 2)).ceil())
	for x in range(from.x, to.x + 1):
		c.draw_line(Vector2(x * Room.CELL * 2, area.position.y), Vector2(x * Room.CELL * 2, area.end.y), Style.ROOM_GRID, 2.0)
	for y in range(from.y, to.y + 1):
		c.draw_line(Vector2(area.position.x, y * Room.CELL * 2), Vector2(area.end.x, y * Room.CELL * 2), Style.ROOM_GRID, 2.0)
