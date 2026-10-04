class_name JeanGreyBase
extends HandLaidRoom

## The Jean Grey test's ground: three screens across, a yard, a ruin with two
## halls in it, and a diamond kept where only something that flies can reach
## it. The camera follows whoever the player is in.
##
## The player comes in by a pit in the yard's far corner, two cells deep, which
## none of the guards can see down into — the one place to wait unseen. A
## Crawler watches the yard from in front of the gate. Inside the gate a Gunman
## watches it along the floor, too far off to see the pit or the yard's far end
## and close enough to shoot anything that walks up to the gate. At the far end
## of the first hall there is a Crawler, and behind the wall there the vault
## hall: a Gunman and a Warden on the floor, a Drifter in the air, and a last
## Gunman under the ledge the diamond lies on — eight cells up, past any jump.
##
## Every guard stands on the floor but the one that flies. A guard sees from
## the middle of itself, so one stood up on a roof or a catwalk sees nothing on
## the floor near it past the edge it stands on — a Gunman up there would be
## a Gunman nobody had to get past.
##
## Gunmen in sight of where a throw has to be made, and ten seconds in
## each body: it is a long way in and a longer way out, the diamond passed from
## one guard to the next on the way back as the rock is on the way in, and a
## throw seen by a Gunman is a guard shot dead under the player's hands.
##
## `LAYOUT` (`HandLaidRoom`): `#` is solid, `P` is where the player starts, `,`
## is the rest of the pit — the start, where the diamond has to be brought —
## `D` is where the diamond lies, and a digit is a guard's post, which guard
## being `POSTS`'s to say. Anything else is open.

const LAYOUT := [
	"########################################################################################################################",
	"#......................................................................................................................#",
	"#......................................................................................................................#",
	"#......................................................................................................................#",
	"#......................................................................................................................#",
	"#.............................##########################################################################################",
	"#.............................#.................................#......................................................#",
	"#.............................#.................................#......................................................#",
	"#.............................#.................................#......................................................#",
	"#.............................#.................................#.............................................D........#",
	"#.............................#.................................#.....................................##################",
	"#.............................#.................................#......................................................#",
	"#.............................#.................................#......................................................#",
	"#.............................#.................................#......................................................#",
	"#.............................#.................................#......................................................#",
	"#.............................#.................................#..................................6...................#",
	"#......................................................................................................................#",
	"#............1......................2...............3...........................4.......5.................7............#",
	"#,,,,,##################################################################################################################",
	"#,P,,,##################################################################################################################",
	"########################################################################################################################",
	"########################################################################################################################",
]

## Who stands at each post, and which way they are looking when the test
## starts. They look over their shoulders now and then (`Enemy.GLANCE_MIN`),
## and that is what there is to wait for. One that flies holds its post in the
## air, in the middle of the cell, rather than standing on its floor.
const POSTS := {
	"1": {"kind": "CRAWLER", "facing": -1},
	"2": {"kind": "GUNMAN", "facing": -1},
	"3": {"kind": "CRAWLER", "facing": 1},
	"4": {"kind": "GUNMAN", "facing": 1},
	"5": {"kind": "WARDEN", "facing": -1},
	"6": {"kind": "DRIFTER", "facing": -1},
	"7": {"kind": "GUNMAN", "facing": -1},
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
	return stand_point(door_cells[0] if not door_cells.is_empty() else Vector2i(2, rows - 3), Player.BODY.y * 0.5)

## Where the diamond lies when nobody has taken it: on the floor of its cell.
func diamond_point() -> Vector2:
	var spots := cells_marked("D")
	return stand_point(spots[0] if not spots.is_empty() else Vector2i(cols - 4, 9), Diamond.RADIUS)

## Whether `at` is in the pit the player started in.
func in_start(at: Vector2) -> bool:
	var l := to_local(at)
	var mark := mark_at(int(floor(l.x / CELL)), int(floor(l.y / CELL)))
	return mark == "," or mark == "P"
