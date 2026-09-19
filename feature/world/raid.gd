class_name Raid
extends Node2D

## Runs one deployment: a connected map, one room loaded at a time, and the two
## ways a raid can end.
##
## Nothing here draws. `graphics/views/raid_view.gd` attaches itself to this
## node and builds the camera, the HUD and the assembly overlay from the state
## and signals below.

signal finished(result: String, payload: Dictionary)
## Something worth saying once, in passing: loot picked up, a boss down.
signal noticed(text: String)
## The assembly overlay opened or closed. The raid keeps running either way.
signal editing_changed(on: bool)
## A new room is live and populated.
signal room_changed(room: Room)

var map: RaidMap
var room: Room = null
var player: Player
var editing: bool = false
var ended: bool = false
## What the player could do where they are standing, or "" for nothing.
var prompt: String = ""
## 0 → 1 while an extraction is being held.
var extract_ratio: float = 0.0
var _pending_dir: int = -1

func _ready() -> void:
	Arena.register(self)
	Cues.emit_cue(&"music_start")
	map = RaidMap.new()
	map.generate(GameState.raid_seed if GameState.raid_seed != 0 else randi())

	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.setup(GameState.raid_weapon, GameState.raid_boards)
	player.died.connect(_on_player_died)
	add_child(player)

	_enter_room(map.entry, -1)
	noticed.emit(Loc.t("hud.toast.deployed"))

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
## through a door comes through after them. Returns how many did.
func _carry_followers(target: Vector2i, dir: int) -> int:
	var door: Vector2 = room.door_rect(dir).get_center()
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
	# on the very frame it arrived.
	var at := Room.arrival_point(RaidMap.opposite(dir))
	var into := Vector2(RaidMap.dir_delta(dir)) * ARRIVAL_SPACING
	for i in chasing.size():
		_relocate(chasing[i], target, at + into * float(i + 1))
	return chasing.size()

## Whether a monster is one that could walk into another room at all. A boss
## holds its arena: its gate stays sealed until it falls, and one that wandered
## off could open that gate from anywhere on the map. Something that does not
## walk does not wander either.
func _can_wander(e: Enemy) -> bool:
	return not bool(e.def.get("boss", false)) and e.ai() != "turret"

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
	if not room.extraction.is_empty():
		var reason := room.extraction_blocked_reason()
		if room.extraction_rect().has_point(player.global_position):
			txt = Loc.t("hud.extract.hold") if reason == "" else reason
	prompt = txt

## --- rooms ------------------------------------------------------------------
func _enter_room(coord: Vector2i, from_dir: int) -> void:
	var followed := 0
	if room != null:
		# What the room has become is written back before it is torn down, so
		# walking back in finds the room that was left rather than a fresh one.
		room.save_state()
		if from_dir >= 0:
			followed = _carry_followers(coord, from_dir)
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
	room.enemy_killed.connect(_on_enemy_killed)
	room.extraction_progress.connect(_on_extract_progress)
	room.extraction_done.connect(_on_extract_done)
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
	if followed > 0:
		noticed.emit(Loc.t("hud.toast.followed"))

func _travel(dir: int) -> void:
	var target: Vector2i = room.coord + RaidMap.dir_delta(dir)
	if not map.has_room(target):
		return
	_pending_dir = dir
	Cues.at(&"travel", player.global_position)
	_enter_room(target, dir)

## --- events -----------------------------------------------------------------
func _on_pickup(p: Pickup) -> void:
	if p.scrap_amount > 0:
		GameState.raid_scrap += p.scrap_amount
		noticed.emit(Loc.t("hud.toast.scrap", [p.scrap_amount]))
	else:
		GameState.add_component(p.component_id, 1, GameState.raid_bag)
		noticed.emit(Loc.t("hud.pickup", [Components.name_for(p.component_id)]))

func _on_enemy_killed(kind: String, _pos: Vector2) -> void:
	if Monsters.get_def(kind).get("boss", false):
		noticed.emit(Loc.t("hud.toast.boss_down"))

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

func _on_player_died(_a: Actor) -> void:
	if ended:
		return
	ended = true
	TimeCtl.clear()
	Cues.emit_cue(&"raid_lost")
	var lost := GameState.die()
	finished.emit("died", lost)

## --- assembly ---------------------------------------------------------------
## Opening the workbench does not pause the raid; it only takes the controls
## away from the player, which is the whole risk of editing in the field.
func set_editing(on: bool) -> void:
	if editing == on:
		return
	editing = on
	player.input_locked = on
	Cues.emit_cue(&"ui", {"kind": "editor"})
	editing_changed.emit(on)

func on_board_changed(slot: int) -> void:
	player.rebuild_runner(slot)
