class_name DragonTest
extends Node2D

## A proving ground for a chain of lunges, after the room in Katana ZERO where
## the Dragon tries out his dash: a building of storeys with guards posted apart
## on every floor, each one dropped by a single cut, and all of them within one
## charged cast of the board this screen hands the player.
##
## Nothing is at stake. Parts are free, health does not run out, and a cleared
## floor is set again a moment later. The building is `DragonTower`; what the
## screen looks like is `graphics/views/dragon_test_view.gd`.

signal exit_requested()
signal editing_changed(on: bool)
## The loadout changed under the screen, so anything cached about it is stale.
signal loadout_changed()
## The last guard fell. `one_cast` says whether a single cast took all of them.
signal cleared(one_cast: bool)
## Every guard is back at their post and the player is back at the door.
signal floor_reset()

const WEAPON := "SWORD"
## Seconds between the last guard falling and the floor being set again.
const RESET_DELAY := 2.4

var room: DragonTower
var player: Player
var boards: Array = []
## The editor's pool: unused, because parts are unlimited here as on the bench.
var inventory: Dictionary = {}
var editing: bool = false
var total_guards: int = 0
var guards_left: int = 0
## Guards cut down since the last skill went out, and the most any one cast has
## taken since the screen opened.
var cast_kills: int = 0
var best_cast: int = 0
## Attacks in the cast now running — what the charge that paid for it bought.
var cast_chain: int = 0
## Counts down while a cleared floor waits to be set again.
var reset_in: float = 0.0
## Seconds since the screen opened.
var elapsed: float = 0.0

## Whether kills are being counted for a cast: set when a skill's cycle starts,
## and cleared by the weapon's own swing, which is not what the count is about.
var _counting: bool = false
var _chain_cache: Dictionary = {}

## The board this room is built around: a DASHSLASH+ whose ON HIT walks three
## OVERCLOCKs back round into it. Every lap the cast has life for is one more
## lunge at the nearest guard still standing.
static func dragon_board() -> SkillBoard:
	var b := SkillBoard.new(7, 5, Loc.t("hud.dragon.board"))
	b.place("INPUT", Vector2i(0, 2), 0)
	b.place("DASHSLASH_AUTO", Vector2i(1, 2), 0)
	b.place("ON_HIT", Vector2i(3, 2), 0)
	b.place("OUTPUT", Vector2i(4, 2), 0)
	b.place("OVERCLOCK", Vector2i(3, 3), 2)
	b.place("OVERCLOCK", Vector2i(2, 3), 2)
	b.place("OVERCLOCK", Vector2i(1, 3), 3)
	return b

func _ready() -> void:
	Arena.register(self)
	Cues.emit_cue(&"music_start")

	room = DragonTower.new()
	add_child(room)
	var guards := room.guard_records()
	total_guards = guards.size()
	guards_left = total_guards
	room.build(Vector2i.ZERO, {"kind": "entry", "danger": 1, "region": 0, "variant": 0,
		"enemies": guards, "loot": []}, {}, 0)
	room.enemy_killed.connect(_on_guard_down)

	boards = [dragon_board()]
	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	player.room = room
	player.global_position = room.spawn_point()
	player.setup(WEAPON, boards)
	player.max_health = 9999.0
	player.health = 9999.0
	# The cycle starting is the hook, not the attack going out: a lunge resolves
	# its first kill inside the call that fires it, so a count opened on the
	# attack would already be a kill behind by the time it was zeroed.
	for r in player.runners:
		r.cycle_started.connect(_begin_cast.bind(r))
	player.basic_runner.cycle_started.connect(_end_cast)

func _process(delta: float) -> void:
	elapsed += delta
	if reset_in > 0.0:
		reset_in -= delta
		if reset_in <= 0.0:
			reset_floor()

func _begin_cast(r: SkillRunner) -> void:
	_counting = true
	cast_kills = 0
	# The charge is spent by now and back at zero, so what this cast is worth is
	# read off the life it actually started with.
	cast_chain = chain_length(r.ttl_bonus)

func _end_cast() -> void:
	_counting = false

func _on_guard_down(_kind: String, _pos: Vector2) -> void:
	guards_left = maxi(guards_left - 1, 0)
	if _counting:
		cast_kills += 1
		best_cast = maxi(best_cast, cast_kills)
	if guards_left == 0:
		reset_in = RESET_DELAY
		cleared.emit(cast_kills >= total_guards)

## Stands every guard back at their post and the player back at the door with
## full meters, and calls off anything still in flight, so every attempt starts
## the way the first one did.
func reset_floor() -> void:
	reset_in = 0.0
	for c in get_children():
		if c is Attacks.Deferred or c is DashSlash or c is MeleeArc or c is Projectile or c is AreaBurst:
			c.queue_free()
	for c in room.get_children():
		if c is Enemy:
			# Out of the target list now rather than at the end of the frame, so
			# nothing still swinging this frame can find a guard on its way out.
			c.remove_from_group("actors")
			c.queue_free()
	var guards := room.guard_records()
	room.data["enemies"] = guards
	for e in guards:
		room._spawn_enemy(e)
	total_guards = guards.size()
	guards_left = total_guards
	cast_kills = 0
	_counting = false
	player.global_position = room.spawn_point()
	player.velocity = Vector2.ZERO
	player.mana = Player.MAX_MANA
	player.stamina = Player.MAX_STAMINA
	player.charge = 0.0
	floor_reset.emit()

## Attacks one cast of the armed skill would land at `bonus` charge if every one
## connects: the cast itself and each ON HIT follow-up hung off it.
func chain_length(bonus: int) -> int:
	var slot := player.selected_slot
	var key := Vector2i(slot, bonus)
	if not _chain_cache.has(key):
		var sim := SkillRunner.new(player.runners[slot].board)
		sim.base_payload_provider = func() -> Payload: return Weapons.base_payload(WEAPON)
		sim.ttl_bonus = bonus
		var walk := sim.simulate()
		var follow := 0
		var link = (walk["triggers"] as Dictionary).get("ON_HIT", null)
		while link != null:
			follow += 1
			link = link.on_hit
		_chain_cache[key] = 0 if (walk["outputs"] as Array).is_empty() else 1 + follow
	return int(_chain_cache[key])

## The least charge whose chain reaches every guard on the floor, or -1 when no
## charge the player can hold does.
func charge_to_clear() -> int:
	for bonus in SkillRunner.MAX_TTL_BONUS + 1:
		if chain_length(bonus) >= total_guards:
			return bonus
	return -1

func set_editing(on: bool) -> void:
	if editing == on:
		return
	editing = on
	player.input_locked = on
	editing_changed.emit(on)

func on_board_changed(slot: int) -> void:
	player.rebuild_runner(slot)
	_chain_cache.clear()
	loadout_changed.emit()

func leave() -> void:
	exit_requested.emit()
