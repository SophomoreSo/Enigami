class_name RaidMap
extends RefCounted

## The raid is one connected map of screen-sized rooms rather than a queue of
## fights. Room records live here, so a cleared room stays cleared and loot left
## on the floor is still there when you come back.

const MW := 7
const MH := 5

var rooms: Dictionary = {}          ## Vector2i -> record
var entry: Vector2i = Vector2i.ZERO
var seed_base: int = 0
var rng := RandomNumberGenerator.new()
var elapsed: float = 0.0            ## raid clock; pressure rises with it

func generate(s: int) -> void:
	seed_base = s
	rng.seed = s
	rooms.clear()
	entry = Vector2i(0, MH - 1)
	var frontier: Array[Vector2i] = [entry]
	rooms[entry] = _record(entry, "entry", 0)

	# Grow a connected blob outward from the entry.
	var target := rng.randi_range(13, 17)
	while rooms.size() < target and not frontier.is_empty():
		var from: Vector2i = frontier[rng.randi() % frontier.size()]
		var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		_shuffle(dirs)
		var placed := false
		for d in dirs:
			var c: Vector2i = from + d
			if c.x < 0 or c.y < 0 or c.x >= MW or c.y >= MH or rooms.has(c):
				continue
			rooms[c] = _record(c, "normal", _distance(c))
			frontier.append(c)
			placed = true
			break
		if not placed:
			frontier.erase(from)

	# A few extra links so the map has loops to double back through.
	var keys := rooms.keys()
	for i in int(keys.size() * 0.35):
		var a: Vector2i = keys[rng.randi() % keys.size()]
		var d: Vector2i = [Vector2i(1, 0), Vector2i(0, 1)][rng.randi() % 2]
		if rooms.has(a + d):
			rooms[a]["extra_links"] = rooms[a].get("extra_links", [])
			rooms[a]["extra_links"].append(a + d)

	_assign_roles()

## Shuffled with this map's own generator rather than with `Array.shuffle`,
## which draws on the global one. The seed is a promise — a raid put down and
## picked back up is the same floor, and so is the one a death left a kit lying
## on — and a promise that only holds until the next `randomize()` is no promise
## at all. It is the one draw in here that was not already `rng`'s.
func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _record(c: Vector2i, kind: String, dist: int) -> Dictionary:
	return {
		"kind": kind,
		"danger": clampi(1 + int(dist / 2), 1, 5),
		"region": clampi(int(dist / 3), 0, 3),
		"variant": rng.randi(),
		"visited": false,
		"coord": c,
	}

func _distance(c: Vector2i) -> int:
	return absi(c.x - entry.x) + absi(c.y - entry.y)

func _assign_roles() -> void:
	var keys: Array = rooms.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _distance(a) > _distance(b))

	# Boss sits at the far end of the map.
	var boss: Vector2i = keys[0]
	rooms[boss]["kind"] = "boss"
	rooms[boss]["danger"] = 5

	# Treasure rooms are deep but not at the boss.
	var treasures := 0
	for c in keys:
		if treasures >= 3:
			break
		if c == boss or c == entry:
			continue
		if _distance(c) >= 3 and rng.randf() < 0.55:
			rooms[c]["kind"] = "treasure"
			treasures += 1

	# Extractions. The way in is always a way out; the rest trade cost,
	# condition and distance against each other.
	rooms[entry]["extraction"] = {
		"id": "entry", "name": EXIT_NAMES["entry"], "cond": "free", "time": 3.0,
		"x": 20, "y": Room.H - 4,
	}
	rooms[boss]["extraction"] = {
		"id": "arbiter", "name": EXIT_NAMES["arbiter"], "cond": "boss", "time": 1.2,
		"x": 20, "y": Room.H - 4,
	}
	var mid: Array = keys.filter(func(c: Vector2i) -> bool:
		return c != entry and c != boss and not rooms[c].has("extraction"))
	if mid.size() > 0:
		var toll: Vector2i = mid[0]
		rooms[toll]["extraction"] = {
			"id": "toll", "name": EXIT_NAMES["toll"], "cond": "cost", "cost": 25, "time": 1.5,
			"x": 8, "y": Room.H - 4,
		}
	if mid.size() > 2:
		var quick: Vector2i = mid[mid.size() - 1]
		rooms[quick]["extraction"] = {
			"id": "crack", "name": EXIT_NAMES["crack"], "cond": "free", "time": 1.0,
			"x": 33, "y": 6,
		}
		rooms[quick]["danger"] = clampi(int(rooms[quick]["danger"]) + 2, 1, 5)

## What each kind of exit is called, in English. This is the fallback under
## `hud.exit.<id>` in `localization/`, gathered here rather than spelled out in
## `generate` so `tests/shared/loc_test` can hold the two together.
const EXIT_NAMES := {
	"entry": "ENTRY GATE",
	"arbiter": "ARBITER GATE",
	"toll": "TOLL GATE",
	"crack": "CRACK IN THE WALL",
}

## What an exit is called on the door and on the results sheet. The `name` in
## the record above is the English fallback under it, like every other name the
## rules invent; `id` is what the translation is keyed by.
static func exit_name(info: Dictionary) -> String:
	return Loc.opt("hud.exit.%s" % String(info.get("id", "")),
		String(info.get("name", "EXIT")))

func has_room(c: Vector2i) -> bool:
	return rooms.has(c)

func get_record(c: Vector2i) -> Dictionary:
	return rooms.get(c, {})

## Which sides of this room have a neighbour to walk into.
func doors_for(c: Vector2i) -> Dictionary:
	var d: Dictionary = {}
	if rooms.has(c + Vector2i(1, 0)):
		d[Components.E] = true
	if rooms.has(c + Vector2i(-1, 0)):
		d[Components.W] = true
	if rooms.has(c + Vector2i(0, 1)):
		d[Components.S] = true
	if rooms.has(c + Vector2i(0, -1)):
		d[Components.N] = true
	return d

static func dir_delta(dir: int) -> Vector2i:
	return Components.dir_to_vec(dir)

static func opposite(dir: int) -> int:
	return Components.opposite(dir)

## Raid pressure: the longer you stay, the more the place notices.
func pressure() -> int:
	return clampi(int(elapsed / 75.0), 0, 4)

func advance(delta: float) -> void:
	elapsed += delta

## --- putting the map down ---------------------------------------------------
## Only what the run has changed. The layout is `generate(seed_base)` all over
## again, so what is written down is the records it filled in: which rooms have
## been opened, what is still standing in them and what is still on their floor.
##
## A record's `coord` is left out and put back from its key — a `Vector2i` does
## not survive JSON, and the key already says which room it is.
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for c: Vector2i in rooms:
		var rec: Dictionary = (rooms[c] as Dictionary).duplicate(true)
		rec.erase("coord")
		out["%d,%d" % [c.x, c.y]] = rec
	return {"rooms": out, "elapsed": elapsed}

## The other half: the map is generated first, then this writes the run back
## over it. A room the save does not mention keeps the one `generate` made,
## so a save from an older map is missing rooms rather than broken by them.
func restore(saved: Dictionary) -> void:
	elapsed = float(saved.get("elapsed", 0.0))
	var saved_rooms: Dictionary = saved.get("rooms", {})
	for key in saved_rooms:
		var parts := String(key).split(",")
		if parts.size() != 2:
			continue
		var c := Vector2i(int(parts[0]), int(parts[1]))
		if not rooms.has(c):
			continue
		var rec: Dictionary = (saved_rooms[key] as Dictionary).duplicate(true)
		rec["coord"] = c
		rooms[c] = rec
