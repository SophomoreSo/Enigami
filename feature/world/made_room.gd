class_name MadeRoom
extends HandLaidRoom

## A room made in the map creator (`MapMaker`) and kept as a scene under
## `data/maps/` (`Maps`). The scene is this node and nothing else, and its
## layers — rows of cells, written the way every hand-laid room is — are
## properties the file carries, so the file is the room. Anywhere a room is
## wanted, one is picked up and stood:
##
##     var room := Maps.load_room("keep")      # or load(path).instantiate()
##     add_child(room)
##     room.stand()
##
## Three layers, each one string a row and a character a cell, `.` for none:
##
##   plan      the ground, and what stands on it: the one layer the rules
##             read. A cell of it is open, or ground (`GROUND`), which is solid
##             whatever kind it is; or what is put in it — `P` where the player
##             starts, `T` the room's treasure box, `x` ground worth digging,
##             and a letter of `MONSTERS` a monster's post. A monster stands in
##             its cell, on whatever is under it, and one that flies holds the
##             middle of it; the box and the ground to dig are put down on the
##             first floor under their cells, so neither is ever left hanging.
##   back      what stands behind all of it: a wall, a column, a tree.
##   dressing  what is put about it: a lantern, a patch of grass, a vine.
##
## The last two are the picture's, and nothing here reads them. Which marks
## they hold, and what each looks like, is the tileset's — `tileset`, by id —
## which draws the ground as well: every kind of ground is as solid as the
## next, and what kind it is says only how it looks.
##
## The rock goes on past the plan's edge, as it is drawn to (`RoomView`): the
## room is shut in on every side whatever its outermost cells hold, so a gap in
## a wall is an alcove and never a way to fall out of the world.
##
## Nothing here draws.

## The ground every hand-laid room is cut from: stone.
const ROCK := "#"
const OPEN := "."
const START := "P"
const BOX := "T"
const DIG := "x"
## The kinds of ground, by the mark that lays each. All of them are solid,
## glass as much as stone: clear glass and a mirror are ground a body stands on
## and cannot go through, and what either shows is the picture's.
const GROUND := {"#": "stone", "%": "earth", "|": "bark", "=": "wood", "*": "leaves",
	"o": "glass", "@": "mirror"}
## A monster's post, by the letter that marks it.
const MONSTERS := {
	"c": "CRAWLER", "s": "SENTRY", "l": "LOBBER", "h": "HOPPER", "d": "DRIFTER",
	"w": "WARDEN", "g": "GUNMAN", "u": "GRUNT", "y": "DUMMY", "a": "ARBITER",
}
## The marks a room holds one of at most: a player starts in one place, and a
## room keeps its loot in one box (`Room.box`).
const ONE_OF := [START, BOX]
## How far past the plan's edge the rock nothing leaves through goes, in cells.
const BEYOND := 4

## The ground, and what stands on it: the rows of cells, top to bottom, all
## the same length.
@export var plan: PackedStringArray = PackedStringArray():
	set(value):
		plan = value
		_measure()
## What stands behind it, a row to each of the plan's. A row it does not have
## is nothing.
@export var back: PackedStringArray = PackedStringArray()
## What is put about it, the same way.
@export var dressing: PackedStringArray = PackedStringArray()
## Which tileset draws it, by id: "" for the plain rock a raid's rooms are cut
## from. Which there are is the picture's (`graphics/tiles/`).
@export var tileset: String = ""
## Which region's rock the plain rock is: the tint a raid's rooms take from
## how deep they lie.
@export_range(0, 3) var region: int = 0

func layout() -> Array:
	return Array(plan)

## Straight off the plan: `layout` copies it, and this is asked once a cell.
func mark_at(x: int, y: int) -> String:
	if y < 0 or y >= plan.size():
		return ROCK
	var row := plan[y]
	return row[x] if x >= 0 and x < row.length() else ROCK

## What stands behind cell (x, y), and what is put about it: `.` for nothing,
## and off the map.
func back_at(x: int, y: int) -> String:
	return _in(back, x, y)

func dressing_at(x: int, y: int) -> String:
	return _in(dressing, x, y)

static func _in(layer: PackedStringArray, x: int, y: int) -> String:
	if y < 0 or y >= layer.size() or x < 0 or x >= layer[y].length():
		return OPEN
	return layer[y][x]

## Whether `mark` is ground: solid, whatever kind it is.
static func is_ground(mark: String) -> bool:
	return GROUND.has(mark)

## Everything that can be put in a cell of the plan that is not ground, in the
## order the map creator offers it: the player's start, each monster, the box
## and the ground to dig.
static func things() -> PackedStringArray:
	var out := PackedStringArray([START])
	for mark in MONSTERS:
		out.append(String(mark))
	out.append(BOX)
	out.append(DIG)
	return out

## The monster `mark` posts, or "" for a mark that is not a monster's.
static func monster_of(mark: String) -> String:
	return String(MONSTERS.get(mark, ""))

## Solid wherever the plan has ground of any kind, and off the end of a row.
func _generate() -> void:
	_measure()
	solid.resize(cols * rows)
	solid.fill(0)
	for y in rows:
		var row := plan[y] if y < plan.size() else ""
		for x in cols:
			if x >= row.length() or GROUND.has(row[x]):
				solid[_idx(x, y)] = 1

## Stands the room up out of its own plan: the grid, the rock, and whatever
## the marks say is in it.
func stand(seed_base: int = 0) -> void:
	build(Vector2i.ZERO, record(), {}, seed_base)

## The record `Room.build` fills the room from: the monsters at their posts,
## the box and the ground to dig where they were laid, and nothing rolled — a
## made room holds what was put in it. What the box and the ground hold is
## rolled from the plan itself — on dice of its own, not the room's — so the
## same map always hides the same things.
func record() -> Dictionary:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(plan)
	var rec := {"kind": "entry", "danger": 1, "region": region, "variant": hash(plan) % 65536,
		"enemies": monster_records(), "loot": [], "digs": []}
	var boxes := cells_marked(BOX)
	if not boxes.is_empty():
		var at := _put_down(boxes[0])
		rec["loot"] = _haul(dice, dice.randi_range(2, 4))
		rec["box"] = {"pos": [at.x, at.y], "opened": false}
	for c in cells_marked(DIG):
		var at := _put_down(c)
		var buried: Array = [{"scrap": dice.randi_range(5, 18)}]
		buried.append_array(_parts(dice, 2 if dice.randf() < 0.3 else 1))
		(rec["digs"] as Array).append({"pos": [at.x, at.y], "loot": buried, "dug": false})
	return rec

## One enemy record per post, in the shape `Room` spawns from. A monster on the
## ground is placed standing already: half the collider an Enemy builds, which
## is its size × 1.9 tall.
func monster_records() -> Array:
	var out: Array = []
	for mark in MONSTERS:
		var kind := String(MONSTERS[mark])
		var def := Monsters.get_def(kind)
		for c in cells_marked(String(mark)):
			var p := cell_center(c.x, c.y)
			if String(def["ai"]) != "flyer":
				p = stand_point(c, float(def["size"]) * 1.9 * 0.5)
			out.append({"kind": kind, "mod": "", "pos": [p.x, p.y]})
	return out

## Where the player starts: standing in the cell marked for it, or with no such
## cell, on the floor nearest the middle of the room.
func spawn_point() -> Vector2:
	var starts := cells_marked(START)
	if not starts.is_empty():
		return stand_point(starts[0], Player.BODY.y * 0.5)
	var middle := Vector2(cols, rows) * 0.5
	var best := Vector2i(-1, -1)
	for y in rows:
		for x in cols:
			if is_solid(x, y) or not is_solid(x, y + 1):
				continue
			if best.x < 0 or Vector2(x, y).distance_squared_to(middle) < Vector2(best).distance_squared_to(middle):
				best = Vector2i(x, y)
	if best.x < 0:
		return middle * CELL
	return stand_point(best, Player.BODY.y * 0.5)

## The middle of the cell a thing laid in `c` comes to rest in: `c` itself, or
## the first one under it with ground beneath.
func _put_down(c: Vector2i) -> Vector2:
	while not GROUND.has(mark_at(c.x, c.y + 1)):
		c.y += 1
	return cell_center(c.x, c.y)

## What a box holds, a piece at a time: gold, or a part off the loot table.
func _haul(dice: RandomNumberGenerator, pieces: int) -> Array:
	var out: Array = []
	for i in pieces:
		if dice.randf() < 0.3:
			out.append({"scrap": dice.randi_range(5, 18)})
		else:
			out.append_array(_parts(dice, 1))
	return out

func _parts(dice: RandomNumberGenerator, count: int) -> Array:
	var out: Array = []
	var pool := Components.loot_pool()
	for i in count:
		if not pool.is_empty():
			out.append({"id": pool[dice.randi() % pool.size()]})
	return out

## The room's own rock, and the rock past its edge on every side.
func _build_collision() -> void:
	super._build_collision()
	var wide := float(cols * CELL)
	var high := float(rows * CELL)
	var thick := float(BEYOND * CELL)
	for side: Rect2 in [
			Rect2(-thick, -thick, wide + thick * 2.0, thick),
			Rect2(-thick, high, wide + thick * 2.0, thick),
			Rect2(-thick, 0.0, thick, high),
			Rect2(wide, 0.0, thick, high)]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = side.size
		shape.shape = rect
		shape.position = side.get_center()
		body.add_child(shape)
