class_name DragonTower
extends HandLaidRoom

## The dragon test's building: storeys laid by hand rather than generated, with
## a post for every guard and a door for the player.
##
## `LAYOUT` is one string per row of cells (`HandLaidRoom`): `#` is solid, `G`
## is a guard's post — the guard stands in that cell, on whatever is under it —
## `P` is the door the player comes in by, and anything else is open. The stairwells cut through
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

func layout() -> Array:
	return LAYOUT

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
	var door_cells := cells_marked("P")
	return stand_point(door_cells[0] if not door_cells.is_empty() else Vector2i(2, H - 3), Player.BODY.y * 0.5)
