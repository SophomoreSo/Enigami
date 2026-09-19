class_name Room
extends Node2D

## One screen of the raid: a solid grid, doors on the sides that have
## neighbours, whatever monsters and loot the map says are still here, and
## sometimes an extraction point.

signal door_entered(dir: int)
signal enemy_killed(kind: String, pos: Vector2)
signal pickup_collected(pickup: Pickup)
signal extraction_progress(ratio: float, info: Dictionary)
signal extraction_done(info: Dictionary)
## Raised once the grid, the collision and the contents are all in place. A
## room is drawn once and then never again, so the view waits for this.
signal built()

const W := 40
const H := 22
const CELL := 32
const DOOR_ROWS := [15, 16, 17]
const DOOR_COLS := [18, 19, 20, 21]

var solid: PackedByteArray = PackedByteArray()
var doors: Dictionary = {}          ## dir -> true
var coord: Vector2i = Vector2i.ZERO
var data: Dictionary = {}           ## live room record owned by RaidMap
var rng := RandomNumberGenerator.new()
var body: StaticBody2D
var player: Player = null
var danger: int = 1

var extraction: Dictionary = {}     ## empty when this room has no exit
## How long the player has been holding the exit, in seconds.
var extract_hold: float = 0.0
var hazards: Array = []             ## cells carrying spikes
var _extract_active: bool = false

func build(room_coord: Vector2i, record: Dictionary, doorset: Dictionary, seed_base: int) -> void:
	coord = room_coord
	data = record
	doors = doorset
	danger = int(record.get("danger", 1))
	extraction = record.get("extraction", {})
	rng.seed = hash(Vector2i(seed_base, 0)) ^ hash(coord) ^ int(record.get("variant", 0))
	_generate()
	_build_collision()
	_spawn_contents()
	built.emit()

## --- grid -------------------------------------------------------------------
func _idx(x: int, y: int) -> int:
	return y * W + x

func _set_cell(x: int, y: int, v: int) -> void:
	if x < 0 or y < 0 or x >= W or y >= H:
		return
	solid[_idx(x, y)] = v

func is_solid(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= W or y >= H:
		return true
	return solid[_idx(x, y)] == 1

func is_solid_at(gp: Vector2) -> bool:
	var l := to_local(gp)
	return is_solid(int(floor(l.x / CELL)), int(floor(l.y / CELL)))

func out_of_bounds(gp: Vector2) -> bool:
	var l := to_local(gp)
	return l.x < -64 or l.y < -64 or l.x > W * CELL + 64 or l.y > H * CELL + 64

func cell_center(x: int, y: int) -> Vector2:
	return Vector2(float(x) + 0.5, float(y) + 0.5) * CELL

## Grid-marched sight line, used by monsters before they commit to a target.
func has_line_of_sight(a: Vector2, b: Vector2) -> bool:
	var la := to_local(a)
	var lb := to_local(b)
	var steps := int(la.distance_to(lb) / (CELL * 0.5)) + 1
	for i in range(1, steps):
		var p: Vector2 = la.lerp(lb, float(i) / float(steps))
		if is_solid(int(floor(p.x / CELL)), int(floor(p.y / CELL))):
			return false
	return true

## Stops a lunge at the first wall on the way.
func clamp_dash(from: Vector2, to: Vector2) -> Vector2:
	var steps := int(from.distance_to(to) / 8.0) + 1
	var last := from
	for i in range(1, steps + 1):
		var p: Vector2 = from.lerp(to, float(i) / float(steps))
		if is_solid_at(p):
			return last
		last = p
	return to

## --- generation -------------------------------------------------------------
func _generate() -> void:
	solid.resize(W * H)
	solid.fill(0)
	for x in W:
		for y in H:
			var border := x == 0 or y == 0 or x == W - 1 or y >= H - 2
			_set_cell(x, y, 1 if border else 0)

	# Door gaps are carved after the shell so they always connect.
	if doors.has(Components.W):
		for r in DOOR_ROWS:
			_set_cell(0, r, 0)
			_set_cell(1, r, 0)
	if doors.has(Components.E):
		for r in DOOR_ROWS:
			_set_cell(W - 1, r, 0)
			_set_cell(W - 2, r, 0)
	if doors.has(Components.N):
		for c in DOOR_COLS:
			_set_cell(c, 0, 0)
			_set_cell(c, 1, 0)
	if doors.has(Components.S):
		for c in DOOR_COLS:
			_set_cell(c, H - 1, 0)
			_set_cell(c, H - 2, 0)

	# The floor by each side door is levelled so an entering player always lands.
	var floor_row: int = DOOR_ROWS[DOOR_ROWS.size() - 1] + 1
	if doors.has(Components.W):
		for x in range(1, 4):
			_set_cell(x, floor_row, 1)
	if doors.has(Components.E):
		for x in range(W - 4, W - 1):
			_set_cell(x, floor_row, 1)

	var platform_count := rng.randi_range(3, 6)
	for i in platform_count:
		var len_p := rng.randi_range(4, 10)
		var px := rng.randi_range(3, W - 4 - len_p)
		var py := rng.randi_range(5, H - 5)
		for x in range(px, px + len_p):
			_set_cell(x, py, 1)

	# A climbable stack under a top door, so a north exit is always reachable.
	if doors.has(Components.N):
		var cx: int = DOOR_COLS[0]
		var y := H - 5
		var side := 1
		while y > 2:
			for x in range(cx - 2, cx + 3):
				_set_cell(x + side * 3, y, 1)
			side *= -1
			y -= 3

	# Falling into a bottom door should not be blocked by a platform.
	if doors.has(Components.S):
		for c in DOOR_COLS:
			for y in range(H - 7, H):
				_set_cell(c, y, 0)
		for c in DOOR_COLS:
			_set_cell(c, H - 1, 0)

	# An exit must always be reachable: clear a pocket around it and floor it.
	if not extraction.is_empty():
		var ex: int = int(extraction.get("x", int(W / 2)))
		var ey: int = int(extraction.get("y", H - 4))
		for x in range(ex - 3, ex + 4):
			for y in range(ey - 3, ey + 2):
				if x > 0 and x < W - 1 and y > 0 and y < H - 2:
					_set_cell(x, y, 0)
		for x in range(ex - 3, ex + 4):
			if x > 0 and x < W - 1:
				_set_cell(x, ey + 2, 1)

	# Hazards give a reason to respect the layout.
	hazards.clear()
	if rng.randf() < 0.45:
		var hx := rng.randi_range(4, W - 8)
		var hlen := rng.randi_range(2, 5)
		for x in range(hx, hx + hlen):
			if not is_solid(x, H - 3) and is_solid(x, H - 2):
				hazards.append(Vector2i(x, H - 3))

func _build_collision() -> void:
	body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	# Merge each row's solid cells into runs, so a room is a handful of shapes.
	for y in H:
		var x := 0
		while x < W:
			if not is_solid(x, y):
				x += 1
				continue
			var start := x
			while x < W and is_solid(x, y):
				x += 1
			var run := x - start
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(run * CELL, CELL)
			shape.shape = rect
			shape.position = Vector2(start * CELL + run * CELL * 0.5, y * CELL + CELL * 0.5)
			body.add_child(shape)

## --- contents ---------------------------------------------------------------
func _spawn_contents() -> void:
	if not data.has("enemies"):
		data["enemies"] = _roll_enemies()
	if not data.has("loot"):
		data["loot"] = _roll_loot()
	for e in data["enemies"]:
		_spawn_enemy(e)
	for l in data["loot"]:
		_spawn_pickup(l)

func _roll_enemies() -> Array:
	var out: Array = []
	var kind := String(data.get("kind", "normal"))
	if kind == "entry":
		return out
	if kind == "boss":
		out.append({"kind": "ARBITER", "mod": "", "pos": [W * CELL * 0.7, 200.0]})
		return out
	var n := rng.randi_range(1, 2 + danger)
	if kind == "treasure":
		n += 1
	for i in n:
		var mk := Monsters.pick(rng, danger)
		var mod_id := ""
		if rng.randf() < 0.12 + 0.05 * float(danger):
			mod_id = String(Enemy.MODIFIERS[rng.randi() % Enemy.MODIFIERS.size()])
		var p := _random_open_point()
		out.append({"kind": mk, "mod": mod_id, "pos": [p.x, p.y]})
	return out

func _roll_loot() -> Array:
	var out: Array = []
	var kind := String(data.get("kind", "normal"))
	var n := 0
	if kind == "treasure":
		n = rng.randi_range(2, 4)
	elif kind == "normal" and rng.randf() < 0.5:
		n = 1
	for i in n:
		var p := _random_open_point()
		if rng.randf() < 0.3:
			out.append({"scrap": rng.randi_range(5, 18), "pos": [p.x, p.y]})
		else:
			var cid: String = Components.LOOT_POOL[rng.randi() % Components.LOOT_POOL.size()]
			out.append({"id": cid, "pos": [p.x, p.y]})
	return out

func _random_open_point() -> Vector2:
	for attempt in 60:
		var x := rng.randi_range(3, W - 4)
		var y := rng.randi_range(3, H - 4)
		if not is_solid(x, y) and not is_solid(x, y - 1) and is_solid(x, y + 1):
			return cell_center(x, y)
	return cell_center(int(W / 2), 5)

func _spawn_enemy(e: Dictionary) -> void:
	var n := Enemy.new()
	n.setup(String(e["kind"]), danger, String(e.get("mod", "")))
	n.position = Vector2(float(e["pos"][0]), float(e["pos"][1]))
	n.room = self
	n.collision_layer = 4
	n.collision_mask = 1
	n.set_meta("record", e)
	add_child(n)

func _spawn_pickup(l: Dictionary) -> void:
	var p := Pickup.new()
	if l.has("scrap"):
		p.setup_scrap(int(l["scrap"]), Vector2(float(l["pos"][0]), float(l["pos"][1])))
	else:
		p.setup_component(String(l["id"]), Vector2(float(l["pos"][0]), float(l["pos"][1])))
	p.room = self
	p.velocity = Vector2.ZERO
	p.set_meta("record", l)
	p.collected.connect(_on_pickup_collected)
	add_child(p)

func _on_pickup_collected(p: Pickup) -> void:
	# Drops created by a kill carry no record; only pre-placed loot does.
	if p.has_meta("record"):
		data["loot"].erase(p.get_meta("record"))
	pickup_collected.emit(p)

func on_enemy_died(e: Enemy) -> void:
	if e.has_meta("record"):
		data["enemies"].erase(e.get_meta("record"))
	# Monsters give back the parts their own attack was made of.
	var pool := Monsters.drop_pool(e.kind)
	var chance := 0.45
	if e.def.get("elite", false):
		chance = 0.9
	if e.def.get("boss", false):
		chance = 1.0
	if not pool.is_empty() and rng.randf() < chance:
		var drops := 1
		if e.def.get("boss", false):
			drops = 3
		for i in drops:
			var cid: String = pool[rng.randi() % pool.size()]
			var p := Pickup.new()
			p.setup_component(cid, e.global_position)
			p.room = self
			p.collected.connect(_on_pickup_collected)
			add_child(p)
	var scrap_amount := int(e.def.get("scrap", 2))
	if scrap_amount > 0:
		var sp := Pickup.new()
		sp.setup_scrap(scrap_amount, e.global_position)
		sp.room = self
		sp.collected.connect(_on_pickup_collected)
		add_child(sp)
	if e.def.get("boss", false):
		data["boss_dead"] = true
	enemy_killed.emit(e.kind, e.global_position)

func enemies_left() -> int:
	var n := 0
	for c in get_children():
		if c is Enemy and not c.dead:
			n += 1
	return n

## --- doors & extraction -----------------------------------------------------
func door_rect(dir: int) -> Rect2:
	match dir:
		Components.W: return Rect2(0, DOOR_ROWS[0] * CELL, CELL * 1.2, DOOR_ROWS.size() * CELL)
		Components.E: return Rect2((W - 1.2) * CELL, DOOR_ROWS[0] * CELL, CELL * 1.2, DOOR_ROWS.size() * CELL)
		Components.N: return Rect2(DOOR_COLS[0] * CELL, 0, DOOR_COLS.size() * CELL, CELL * 1.2)
		Components.S: return Rect2(DOOR_COLS[0] * CELL, (H - 1.2) * CELL, DOOR_COLS.size() * CELL, CELL * 1.2)
	return Rect2()

## Where a player arriving through `from_dir` should be put down.
func entry_point(from_dir: int) -> Vector2:
	match from_dir:
		Components.W: return cell_center(2, DOOR_ROWS[1])
		Components.E: return cell_center(W - 3, DOOR_ROWS[1])
		Components.N: return cell_center(DOOR_COLS[1], 2)
		Components.S: return cell_center(DOOR_COLS[1], H - 4)
	return cell_center(int(W / 2), int(H / 2))

func spawn_point() -> Vector2:
	return cell_center(int(W / 2), DOOR_ROWS[1])

func extraction_rect() -> Rect2:
	if extraction.is_empty():
		return Rect2()
	var c: Vector2 = cell_center(int(extraction.get("x", W / 2)), int(extraction.get("y", H - 4)))
	return Rect2(c - Vector2(48, 56), Vector2(96, 96))

func extraction_blocked_reason() -> String:
	if extraction.is_empty():
		return Loc.t("hud.extract.no_exit")
	match String(extraction.get("cond", "free")):
		"cost":
			if GameState.raid_scrap < int(extraction.get("cost", 20)):
				return Loc.t("hud.extract.needs_scrap",
					[int(extraction.get("cost", 20)), GameState.raid_scrap])
		"boss":
			if not bool(data.get("boss_dead", false)):
				return Loc.t("hud.extract.sealed")
	return ""

func _process(delta: float) -> void:
	_update_extraction(delta)

func _update_extraction(delta: float) -> void:
	if extraction.is_empty() or player == null or not is_instance_valid(player):
		return
	var inside := extraction_rect().has_point(player.global_position)
	var reason := extraction_blocked_reason()
	if inside and reason == "" and Input.is_action_pressed("interact") and not player.controls_locked():
		extract_hold += delta
		_extract_active = true
		if int(extract_hold * 8.0) != int((extract_hold - delta) * 8.0):
			Cues.at(&"extract_tick", player.global_position)
		var need := float(extraction.get("time", 2.5))
		extraction_progress.emit(clampf(extract_hold / need, 0.0, 1.0), extraction)
		if extract_hold >= need:
			extraction_done.emit(extraction)
			extract_hold = 0.0
	else:
		if _extract_active:
			extraction_progress.emit(0.0, extraction)
		_extract_active = false
		extract_hold = maxf(0.0, extract_hold - delta * 2.0)

func check_doors(p: Player) -> int:
	for dir in doors:
		if door_rect(dir).has_point(to_local(p.global_position)):
			return int(dir)
	return -1
