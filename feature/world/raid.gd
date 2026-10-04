class_name Raid
extends World

## Runs one deployment: a connected map, one room loaded at a time, and the two
## ways a raid can end.
##
## Nothing here draws. `graphics/views/raid_view.gd` attaches itself to this
## node and builds the camera, the HUD and the assembly overlay from the state
## and signals below.

signal finished(result: String, payload: Dictionary)
## The assembly overlay opened or closed. The raid keeps running either way.
signal editing_changed(on: bool)
## The map opened or closed. The raid keeps running either way, as above.
signal reading_map_changed(on: bool)
## A new room is live and populated.
signal room_changed(room: Room)

var map: RaidMap
var room: Room = null
var player: Player
var reading_map: bool = false
var ended: bool = false
## What stands between the player and the exit they are standing in — a toll,
## a seal — or "" when nothing does, or they are not in one. An exit that will
## take them is the room's `extract_offered`, and the HUD writes the line for
## that one itself, since the line names the key that extracts.
var prompt: String = ""
## 0 → 1 while an extraction is being held.
var extract_ratio: float = 0.0
var _pending_dir: int = -1

func _ready() -> void:
	Arena.register(self)
	Cues.emit_cue(&"music_start")
	map = RaidMap.new()
	map.generate(GameState.raid_seed if GameState.raid_seed != 0 else randi())
	# A run put down with MAIN MENU: the map above is the same map, since it
	# grew from the same seed, and this writes back what the run had made of it.
	var parked: Dictionary = GameState.raid_progress if GameState.has_parked_raid() else {}
	if not parked.is_empty():
		map.restore(parked)
	# After the restore, so a run that is being walked back into finds the drop
	# in the room the map says it is in rather than in whatever the save last
	# wrote there. Collecting it clears it from both at once, so this can never
	# put a kit back that has already been picked up.
	_place_lost_kit()

	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	# The whole kit: every weapon carried and the raid's own copy of the graph
	# on each, with the one that was in hand in hand.
	var graphs: Array = []
	for w in GameState.raid_weapons:
		graphs.append(GameState.raid_graphs[w])
	player.setup_kit(GameState.raid_weapons, graphs, GameState.raid_hand)
	# A run put down with the rock lying in one of its rooms is walked back into
	# without it: it is still lying there.
	for w in _rocks_left_lying():
		player.let_go(w)
	# The profile is told which weapon is in hand as it changes: assembly opens
	# that one's graph, and a raid put down is picked back up holding it.
	player.weapon_switched.connect(func(_weapon: String) -> void: GameState.raid_hand = player.hand)
	player.died.connect(_on_player_died)
	add_child(player)

	if parked.is_empty():
		_enter_room(map.entry, -1)
		return
	# Back into the room it was left in, standing where it was left standing.
	# `_enter_room` puts the player on the room's own spawn point, which is the
	# right answer for walking in and the wrong one for never having left.
	_enter_room(_parked_coord(parked), -1)
	var at: Array = parked.get("pos", [])
	if at.size() == 2:
		player.global_position = Vector2(float(at[0]), float(at[1]))
		player.velocity = Vector2.ZERO
	player.health = clampf(float(parked.get("health", player.health)), 1.0, player.max_health)
	# The shuriken that were in hand: any stuck in the room it was put down in
	# were left behind with it, as walking out of a room leaves them.
	var stock: Dictionary = parked.get("stock", {})
	for w in stock:
		if player.stock.has(String(w)):
			player.stock[String(w)] = clampi(int(stock[w]), 0, Weapons.stack_of(String(w)))

## Puts a previous death's drop into the room it was left in. The map is that
## same map — the deployment reused the seed that built
## it — so the room is there, in the same place, with the same way in. What is
## written is the room's own record, which is what `Room.build` reads its
## contents out of.
##
## A drop from another map is left where it is rather than moved here: it
## belongs to a floor the player can still go back to, and dragging it onto
## this one would quietly turn a recovery run into a free delivery.
func _place_lost_kit() -> void:
	var kit: Dictionary = GameState.lost_kit
	if kit.is_empty() or int(kit.get("seed", 0)) != map.seed_base:
		return
	var c: Array = kit.get("room", [])
	if c.size() != 2:
		return
	var coord := Vector2i(int(c[0]), int(c[1]))
	if not map.has_room(coord):
		return
	(map.get_record(coord) as Dictionary)["lost_kit"] = kit.duplicate(true)

## The thrown weapons lying in this map's rooms, by the records the rooms keep:
## the rock, if a run put down left it on a floor somewhere.
func _rocks_left_lying() -> Array:
	var out: Array = []
	for c in map.rooms:
		for r in (map.rooms[c] as Dictionary).get("rocks", []):
			out.append(String((r as Dictionary).get("weapon", "")))
	return out

func _parked_coord(parked: Dictionary) -> Vector2i:
	var c: Array = parked.get("room", [])
	if c.size() != 2:
		return map.entry
	var coord := Vector2i(int(c[0]), int(c[1]))
	return coord if map.has_room(coord) else map.entry

## The run, written down where it stands, for `GameState.park_raid`. The room on
## screen is the one room whose record is out of date — what is still standing
## in it and where it has got to is in the room, not in the map — so it is
## written back first, exactly as walking through a door writes it back.
func park() -> Dictionary:
	if room != null:
		room.save_state()
	var saved := map.to_save()
	saved["room"] = [room.coord.x, room.coord.y] if room != null else [map.entry.x, map.entry.y]
	# Where they stand, not where a crouch has let them down to: they come back
	# standing.
	var at := player.standing_position()
	saved["pos"] = [at.x, at.y]
	saved["health"] = player.health
	saved["stock"] = player.stock.duplicate()
	return saved

func _process(delta: float) -> void:
	if ended:
		return
	map.advance(delta)
	if room != null:
		var dir := room.check_doors(player)
		if dir >= 0 and _pending_dir < 0:
			_travel(dir)
	_update_prompt()
	_update_wandering()

## --- monsters that change rooms ---------------------------------------------
## Only the room the player is standing in is ever live, so a monster that
## leaves one is not simulated on its way anywhere: its record is handed to the
## room it walked into, and it is standing there when that room is next opened.
## That record is the monster — kind, modifier and wounds — so what arrives is
## the one that left and not another roll of the same kind.

## How close to the door a monster has to be, when the player goes through it,
## to come through after them. A room's width is 1280, so this is near enough
## that only something already on the player's heels follows.
const FOLLOW_RANGE := 260.0

## How far apart arrivals are spaced, in from the door they came through, so a
## pair that follows the player does not land in one place.
const ARRIVAL_SPACING := 30.0

## A monster standing in a doorway walks through it.
func _update_wandering() -> void:
	if room == null or ended:
		return
	for c in room.get_children():
		if not (c is Enemy) or (c as Enemy).dead:
			continue
		var e := c as Enemy
		if not _can_wander(e):
			continue
		var dir := room.door_at(e.global_position)
		if dir < 0:
			continue
		var target: Vector2i = room.coord + RaidMap.dir_delta(dir)
		if not map.has_room(target):
			continue
		Cues.at(&"travel", e.global_position)
		_relocate(e, target, Room.arrival_point(RaidMap.opposite(dir)))

## Whatever was chasing the player and is still at their heels when they go
## through a doorway or a gate comes through after them.
func _carry_followers(target: Vector2i, dir: int) -> void:
	var door: Vector2 = room.way_point(dir)
	var chasing: Array = []
	for c in room.get_children():
		if not (c is Enemy) or (c as Enemy).dead:
			continue
		var e := c as Enemy
		if e.aggro and _can_wander(e) \
				and room.to_local(e.global_position).distance_to(door) <= FOLLOW_RANGE:
			chasing.append(e)
	# In from the door rather than in the mouth of it: a monster left standing
	# in the doorway would be walked straight back out again by the sweep above
	# on the very frame it arrived. Through a gate, along the floor beside the
	# one they come out of, not into the rock over it or under it.
	var at := Room.arrival_point(RaidMap.opposite(dir))
	var into := Vector2(RaidMap.dir_delta(dir)) * ARRIVAL_SPACING
	if dir == Components.N or dir == Components.S:
		into = Vector2(ARRIVAL_SPACING, 0.0)
	for i in chasing.size():
		_relocate(chasing[i], target, at + into * float(i + 1))

## Whether a monster is one that could walk into another room at all. A boss
## holds its arena: its gate stays sealed until it falls, and one that wandered
## off could open that gate from anywhere on the map. Something that does not
## walk does not wander either.
func _can_wander(e: Enemy) -> bool:
	return not bool(e.def.get("boss", false)) and e.ai() != "turret" and not e.piloted()

## Hands one monster over to the room at `target`, standing at `at`. Its record
## goes with it, so it is the same monster when that room is next opened, and
## the body here goes away — the room it has walked into is not loaded, and
## nothing outside the live room is.
func _relocate(e: Enemy, target: Vector2i, at: Vector2) -> void:
	var into: Dictionary = map.get_record(target)
	if into.is_empty() or not e.has_meta("record"):
		return
	var rec: Dictionary = e.get_meta("record")
	rec["pos"] = [at.x, at.y]
	rec["hp"] = e.health
	(room.data["enemies"] as Array).erase(rec)
	var arrivals: Array = into.get("arrivals", [])
	arrivals.append(rec)
	into["arrivals"] = arrivals
	# Out of the target list now rather than at the end of the frame, so nothing
	# still swinging this frame can find a monster that has left the room — and
	# silenced, so it cannot get a last attack away into a room it is no longer
	# standing in.
	e.remove_from_group("actors")
	e.process_mode = Node.PROCESS_MODE_DISABLED
	e.queue_free()

func _update_prompt() -> void:
	if room == null:
		return
	var txt := ""
	if not room.extraction.is_empty() and room.extraction_rect().has_point(player.global_position) \
			and player.vessel() == player:
		# Only what is in the way. The line for an exit that is open used to be
		# written here too, and it names the key that extracts — which changed
		# its words with the console, a thing no rule should know. The HUD
		# writes that one now, off `room.extract_offered`.
		txt = room.extraction_blocked_reason()
	prompt = txt

## --- rooms ------------------------------------------------------------------
func _enter_room(coord: Vector2i, from_dir: int) -> void:
	if room != null:
		# What the room has become is written back before it is torn down, so
		# walking back in finds the room that was left rather than a fresh one.
		room.save_state()
		if from_dir >= 0:
			_carry_followers(coord, from_dir)
		# Nothing in the room being left gets another turn. A monster's board is
		# mid-cycle when the door is crossed, and a node that has been freed
		# still runs out the frame it was freed in — and the raid processes
		# before its own children do, so the last thing the old room did was
		# fire into the new one, after the sweep below had already been round.
		room.process_mode = Node.PROCESS_MODE_DISABLED
		room.queue_free()
		room = null
	# The room goes, and so does everything that was still flying around in it.
	# Attacks hang off the raid rather than off the room, so without this a
	# volley loosed on the way through a door arrived in the next room with the
	# player and kept going across it. After the room is silenced, so that
	# anything it managed to loose on its way out is swept up with the rest.
	Attacks.clear_in_flight(self)
	var rec: Dictionary = map.get_record(coord)
	rec["visited"] = true

	room = Room.new()
	room.player = player
	add_child(room)
	room.build(coord, rec, map.doors_for(coord), map.seed_base)
	room.pickup_collected.connect(_on_pickup)
	room.lost_kit_collected.connect(_on_lost_kit)
	room.box_opened.connect(_on_box_opened)
	room.spot_dug.connect(_on_spot_dug)
	room.extraction_progress.connect(_on_extract_progress)
	room.extraction_done.connect(_on_extract_done)
	room.gate_entered.connect(_take_gate)
	room.player = player

	player.room = room
	if from_dir < 0:
		player.global_position = room.spawn_point()
	else:
		player.global_position = room.entry_point(RaidMap.opposite(from_dir))
	player.velocity = Vector2.ZERO
	for c in room.get_children():
		if c is Enemy:
			c.room = room
	_pending_dir = -1
	room_changed.emit(room)

func _travel(dir: int) -> void:
	var target: Vector2i = room.coord + RaidMap.dir_delta(dir)
	if not map.has_room(target):
		return
	_pending_dir = dir
	Cues.at(&"travel", player.global_position)
	_enter_room(target, dir)

## Through one of the room's gates, up or down: into the room on the other side
## of it, standing in front of the gate that leads back.
func _take_gate(dir: int) -> void:
	if ended or _pending_dir >= 0:
		return
	_travel(dir)

## --- events -----------------------------------------------------------------
func _on_pickup(p: Pickup) -> void:
	if p.scrap_amount > 0:
		GameState.raid_scrap += p.scrap_amount
	else:
		GameState.add_component(p.component_id, 1, GameState.raid_bag)

## A treasure box, opened. Everything in it goes into the run at once, like a
## pickup but all together.
func _on_box_opened(_box: TreasureBox, items: Array) -> void:
	_take_haul(items)

## Ground dug up with the shovel: what was buried goes into the run the way a
## box's does.
func _on_spot_dug(_spot: DigSpot, items: Array) -> void:
	_take_haul(items)

## Loot records, `{"id": ...}` or `{"scrap": ...}`, into the run's bag and
## purse.
func _take_haul(items: Array) -> void:
	for l in items:
		if l.has("scrap"):
			GameState.raid_scrap += int(l["scrap"])
		else:
			# The record can be out of a raid parked before one of its parts was renamed.
			GameState.add_component(Components.current_id(String(l["id"])), 1, GameState.raid_bag)

## The drop, picked back up. What was in it goes into the run rather than
## straight home — a recovered kit is being carried, and it still has to be
## walked out — and the rest is left to the exit.
func _on_lost_kit(_k: LostKit) -> void:
	GameState.recover_lost_kit()

func _on_extract_progress(ratio: float, _info: Dictionary) -> void:
	extract_ratio = ratio

func _on_extract_done(info: Dictionary) -> void:
	if ended:
		return
	if String(info.get("cond", "free")) == "cost":
		GameState.raid_scrap -= int(info.get("cost", 0))
	ended = true
	Cues.emit_cue(&"extract_done")
	TimeCtl.clear()
	var result := GameState.extract()
	result["exit"] = RaidMap.exit_name(info)
	finished.emit("extracted", result)

## Where the player fell is where the kit stays. The room and the spot in it go
## with the death, because they are what the next deployment needs to put it
## back on the floor — see `GameState.die`.
func _on_player_died(a: Actor) -> void:
	if ended:
		return
	ended = true
	TimeCtl.clear()
	Cues.emit_cue(&"raid_lost")
	var where: Dictionary = {}
	if room != null:
		where = {"room": [room.coord.x, room.coord.y],
			"pos": [a.global_position.x, a.global_position.y]}
	var lost := GameState.die(where)
	finished.emit("died", lost)

## --- assembly ---------------------------------------------------------------
## Opening the workbench does not pause the raid; it only takes the controls
## away from the player, which is the whole risk of editing in the field.
func set_editing(on: bool) -> void:
	if editing == on:
		return
	# One pair of hands: the workbench takes over from the map rather than
	# standing on top of it, so closing either one gives the controls back.
	if on:
		set_reading_map(false)
	editing = on
	player.input_locked = editing or reading_map
	Cues.emit_cue(&"ui", {"kind": "editor"})
	editing_changed.emit(on)

## --- the map ----------------------------------------------------------------
## Reading the map costs exactly what the workbench costs: the raid runs on, the
## clock keeps climbing and the player stands still while they look.
func set_reading_map(on: bool) -> void:
	if reading_map == on or (on and editing):
		return
	reading_map = on
	player.input_locked = editing or reading_map
	Cues.emit_cue(&"ui", {"kind": "map"})
	reading_map_changed.emit(on)

func on_board_changed() -> void:
	player.rebuild_runner()

## An exit the player is standing in, with nothing sealing it, a gate they are
## at, a shut treasure box within reach, ground to dig with the shovel in hand,
## or — from inside a monster — the body, with the weapon in its hands to take.
func use_nearby() -> bool:
	if player != null and player.can_take_weapon():
		return true
	return room != null and is_instance_valid(room) \
		and (room.extract_offered or room.gate_offered() or room.box_offered() or room.dig_offered())
