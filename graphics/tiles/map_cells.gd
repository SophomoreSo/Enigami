class_name MapCells
extends RefCounted

## A made map's cells, the way whatever draws it asks for them (`MapTiles`):
## its three layers (`MadeRoom`), read a cell at a time, the same whether they
## are a room standing in the world or a map on the creator's table.
##
## Past the map's edge the ground is solid — the map is shut in there — and
## nothing stands behind it or is put about it. What that ground looks like
## is the tileset's to say (`MapTiles.paint_beyond`).

var cols := 0
var rows := 0
var plan := PackedStringArray()
var back := PackedStringArray()
var dressing := PackedStringArray()
## Which tileset draws them, and which region's rock the plain rock is.
var tileset := ""
var region := 0

## A room's.
static func of_room(room: MadeRoom) -> MapCells:
	return of_rows(room.plan, room.back, room.dressing, room.tileset, room.region)

## A map's on the creator's table.
static func of_maker(maker: MapMaker) -> MapCells:
	return of_rows(maker.plan(), maker.back(), maker.dressing(), maker.tileset, maker.region)

static func of_rows(laid: PackedStringArray, behind: PackedStringArray, about: PackedStringArray,
		drawn_in: String = "", deep: int = 0) -> MapCells:
	var m := MapCells.new()
	m.plan = laid
	m.back = behind
	m.dressing = about
	m.rows = laid.size()
	for row in laid:
		m.cols = maxi(m.cols, row.length())
	m.tileset = drawn_in
	m.region = deep
	return m

func holds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < cols and y < rows

## The mark the plan has in cell (x, y): ground of some kind past its edge.
func ground(x: int, y: int) -> String:
	if not holds(x, y) or x >= plan[y].length():
		return MadeRoom.ROCK
	return plan[y][x]

## Whether cell (x, y) is ground: solid, whatever kind.
func solid(x: int, y: int) -> bool:
	return MadeRoom.is_ground(ground(x, y))

## What stands behind cell (x, y), and what is put about it: `.` for nothing.
func back_at(x: int, y: int) -> String:
	return _in(back, x, y)

func prop(x: int, y: int) -> String:
	return _in(dressing, x, y)

static func _in(layer: PackedStringArray, x: int, y: int) -> String:
	if y < 0 or y >= layer.size() or x < 0 or x >= layer[y].length():
		return MadeRoom.OPEN
	return layer[y][x]
