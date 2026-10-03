class_name HandLaidRoom
extends Room

## A room laid by hand rather than generated: one string per row of cells,
## `#` solid and anything else open, top row first. What the other characters
## mean is the room's own business — a guard's post, the door the player comes
## in by, where something is kept — and it finds them with `cells_marked`. The
## dragon test's tower (`DragonTower`) and the Jean Grey test's base
## (`JeanGreyBase`) are two.

## The rows of cells, top to bottom, `W` characters each. Every room laid this
## way hands over its own.
func layout() -> Array:
	return []

func _generate() -> void:
	solid.resize(W * H)
	solid.fill(0)
	for y in H:
		for x in W:
			_set_cell(x, y, 1 if mark_at(x, y) == "#" else 0)

## The layout's character for cell (x, y). Anything off the drawn map is wall.
func mark_at(x: int, y: int) -> String:
	var rows := layout()
	if y < 0 or y >= rows.size():
		return "#"
	var row := String(rows[y])
	return row[x] if x >= 0 and x < row.length() else "#"

## Every cell carrying `mark`, row by row from the top.
func cells_marked(mark: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in H:
		for x in W:
			if mark_at(x, y) == mark:
				out.append(Vector2i(x, y))
	return out

## Where a body `half_height` tall stands in cell `c`: across the middle of the
## cell, feet on its floor.
func stand_point(c: Vector2i, half_height: float) -> Vector2:
	return Vector2((float(c.x) + 0.5) * CELL, float(c.y + 1) * CELL - half_height)
