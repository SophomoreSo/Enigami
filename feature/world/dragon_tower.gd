class_name DragonTower
extends Room

## The dragon test's building: storeys laid by hand rather than generated, with
## a post for every guard and a door for the player.
##
## `LAYOUT` is one string per row of cells: `#` is solid, `G` is a guard's post
## — the guard stands in that cell, on whatever is under it — `P` is the door
## the player comes in by, and anything else is open. The stairwells cut through
## the floors are where the lunges between storeys pass, so moving a post or
## closing a stairwell can break the chain; `tests/feature/dragon_test.tscn`
## says whether one cast still clears the floor. Nothing here draws: the
## building's picture is `graphics/views/tower_view.gd`.

const LAYOUT := [
	"########################################",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#.G....G...............................#",
	"########...#############################",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#...................G....G.............#",
	"##########################....##########",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#...............................G....G.#",
	"#############################...########",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#.P............G........G..............#",
	"########################################",
	"########################################",
]

## Who stands at the posts.
const GUARD := "GRUNT"

func _generate() -> void:
	solid.resize(W * H)
	solid.fill(0)
	hazards.clear()
	for y in H:
		for x in W:
			_set_cell(x, y, 1 if mark_at(x, y) == "#" else 0)

## The layout's character for cell (x, y). Anything off the drawn map is wall.
func mark_at(x: int, y: int) -> String:
	if y < 0 or y >= LAYOUT.size():
		return "#"
	var row := String(LAYOUT[y])
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

## One enemy record per post, in the shape `Room` spawns from. A guard holds its
## post rather than falling onto it, so it is placed standing already: half the
## collider an Enemy builds, which is its size × 1.9 tall.
func guard_records() -> Array:
	var half := float(Monsters.get_def(GUARD)["size"]) * 1.9 * 0.5
	var out: Array = []
	for c in cells_marked("G"):
		var p := stand_point(c, half)
		out.append({"kind": GUARD, "mod": "", "pos": [p.x, p.y]})
	return out

func spawn_point() -> Vector2:
	var doors := cells_marked("P")
	return stand_point(doors[0] if not doors.is_empty() else Vector2i(2, H - 3), Player.BODY.y * 0.5)
