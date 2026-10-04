class_name HandLaidRoom
extends Room

## A room laid by hand rather than generated: one string per row of cells,
## `#` solid and anything else open, top row first. It is as wide as its rows
## and as tall as there are of them (`cols`, `rows`), so one can be wider than
## the screen and the camera follow the player along it. What the other characters
## mean is the room's own business — a guard's post, the door the player comes
## in by, where something is kept — and it finds them with `cells_marked`. The
## dragon test's tower (`DragonTower`) and the Jean Grey test's base
## (`JeanGreyBase`) are two.

## The rows of cells, top to bottom, all the same length. Every room laid this
## way hands over its own.
func layout() -> Array:
	return []

## Its size is its rows' from the start, so whatever reads its marks before it
## is built — the posts a world spawns its guards from — reads all of them.
func _init() -> void:
	_measure()

func _measure() -> void:
	var laid := layout()
	rows = maxi(laid.size(), 1)
	cols = String(laid[0]).length() if not laid.is_empty() else W

func _generate() -> void:
	_measure()
	solid.resize(cols * rows)
	solid.fill(0)
	for y in rows:
		for x in cols:
			_set_cell(x, y, 1 if mark_at(x, y) == "#" else 0)

## The layout's character for cell (x, y). Anything off the drawn map is wall.
func mark_at(x: int, y: int) -> String:
	var laid := layout()
	if y < 0 or y >= laid.size():
		return "#"
	var row := String(laid[y])
	return row[x] if x >= 0 and x < row.length() else "#"

## Every cell carrying `mark`, row by row from the top.
func cells_marked(mark: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in rows:
		for x in cols:
			if mark_at(x, y) == mark:
				out.append(Vector2i(x, y))
	return out

## Where a body `half_height` tall stands in cell `c`: across the middle of the
## cell, feet on its floor.
func stand_point(c: Vector2i, half_height: float) -> Vector2:
	return Vector2((float(c.x) + 0.5) * CELL, float(c.y + 1) * CELL - half_height)
