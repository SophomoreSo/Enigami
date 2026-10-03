class_name JeanGreyBase
extends HandLaidRoom

## The Jean Grey test's ground: a yard, a guarded building, and a diamond kept
## where only something that flies can reach it.
##
## The player comes in by a pit in the yard's far corner, two cells deep, which
## none of the guards can see down into — the one place to wait unseen. The
## building's gate is watched from outside by one guard, and nothing inside
## sees out past it: the gate is two cells high, and the guard watching the
## hall does it from a catwalk, over the gate's lintel. The hall has guards on
## the floor and one in the air; the diamond lies on a ledge high in its far
## end, out of any jump. So the way in is the way the test is
## named for: into the gate guard from behind, through the gate as one of them,
## into the one that flies, up to the ledge — and the diamond carried back out
## to the pit, the last stretch in the player's own hands.
##
## `LAYOUT` (`HandLaidRoom`): `#` is solid, `P` is where the player starts, `,`
## is the rest of the pit — the start, where the diamond has to be brought —
## `D` is where the diamond lies, and a digit is a guard's post, which guard
## being `POSTS`'s to say. Anything else is open.

const LAYOUT := [
	"########################################",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#.............##########################",
	"#.............#........................#",
	"#.............#........................#",
	"#.............#........................#",
	"#.............#.....................D..#",
	"#.............#..................#######",
	"#.............#........................#",
	"#.............#......2.................#",
	"#.............#....#####...............#",
	"#.............#........................#",
	"#.............#................5.......#",
	"#......................................#",
	"#...........1.............3.........4..#",
	"#,,,,,##################################",
	"#,P,,,##################################",
	"########################################",
	"########################################",
]

## Who stands at each post, and which way they are looking when the test
## starts. They look over their shoulders now and then (`Enemy.GLANCE_MIN`),
## and that is what there is to wait for. One that flies holds its post in the
## air, in the middle of the cell, rather than standing on its floor.
const POSTS := {
	"1": {"kind": "CRAWLER", "facing": -1},
	"2": {"kind": "SENTRY", "facing": 1},
	"3": {"kind": "CRAWLER", "facing": -1},
	"4": {"kind": "WARDEN", "facing": -1},
	"5": {"kind": "DRIFTER", "facing": -1},
}

func layout() -> Array:
	return LAYOUT

## One enemy record per post, in the shape `Room` spawns from, with the way the
## guard faces beside it. One on the ground is placed standing already: half
## the collider an Enemy builds, which is its size × 1.9 tall.
func guard_records() -> Array:
	var out: Array = []
	for mark in POSTS:
		var post: Dictionary = POSTS[mark]
		var kind := String(post["kind"])
		for c in cells_marked(String(mark)):
			var p := cell_center(c.x, c.y)
			if Monsters.get_def(kind)["ai"] != "flyer":
				p = stand_point(c, float(Monsters.get_def(kind)["size"]) * 1.9 * 0.5)
			out.append({"kind": kind, "mod": "", "pos": [p.x, p.y], "facing": int(post["facing"])})
	return out

## A guard put down looks the way its post says, rather than whichever way it
## happened to turn when it was made.
func _spawn_enemy(e: Dictionary) -> void:
	super._spawn_enemy(e)
	for c in get_children():
		if c is Enemy and c.get_meta("record", null) == e:
			(c as Enemy).face(int(e.get("facing", 1)))

func spawn_point() -> Vector2:
	var door_cells := cells_marked("P")
	return stand_point(door_cells[0] if not door_cells.is_empty() else Vector2i(2, H - 3), Player.BODY.y * 0.5)

## Where the diamond lies when nobody has taken it: on the floor of its cell.
func diamond_point() -> Vector2:
	var spots := cells_marked("D")
	return stand_point(spots[0] if not spots.is_empty() else Vector2i(W - 4, 9), Diamond.RADIUS)

## Whether `at` is in the pit the player started in.
func in_start(at: Vector2) -> bool:
	var l := to_local(at)
	var mark := mark_at(int(floor(l.x / CELL)), int(floor(l.y / CELL)))
	return mark == "," or mark == "P"
