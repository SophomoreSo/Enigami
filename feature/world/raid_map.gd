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
		dirs.shuffle()
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
		"name": "ENTRY GATE", "cond": "free", "time": 3.0,
		"x": 20, "y": Room.H - 4,
	}
	rooms[boss]["extraction"] = {
		"name": "ARBITER GATE", "cond": "boss", "time": 1.2,
		"x": 20, "y": Room.H - 4,
	}
	var mid: Array = keys.filter(func(c: Vector2i) -> bool:
		return c != entry and c != boss and not rooms[c].has("extraction"))
	if mid.size() > 0:
		var toll: Vector2i = mid[0]
		rooms[toll]["extraction"] = {
			"name": "TOLL GATE", "cond": "cost", "cost": 25, "time": 1.5,
			"x": 8, "y": Room.H - 4,
		}
	if mid.size() > 2:
		var quick: Vector2i = mid[mid.size() - 1]
		rooms[quick]["extraction"] = {
			"name": "CRACK IN THE WALL", "cond": "free", "time": 1.0,
			"x": 33, "y": 6,
		}
		rooms[quick]["danger"] = clampi(int(rooms[quick]["danger"]) + 2, 1, 5)

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
