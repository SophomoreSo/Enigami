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
var rng := RandomNumberGenerator.new()
var editing: bool = false
var ended: bool = false
## What the player could do where they are standing, or "" for nothing.
var prompt: String = ""
## 0 → 1 while an extraction is being held.
var extract_ratio: float = 0.0
var _pending_dir: int = -1

## First-raid onboarding. Each step clears itself once the player has actually
## done the thing, so the game teaches by watching rather than by gating.
const TUTORIAL_STEPS := [
	"Move with A and D. SPACE jumps — press it again against a wall to kick off.",
	"Hold the LEFT MOUSE BUTTON to run skill slot 1. Your board's length sets its rhythm.",
	"Press TAB to open assembly. The raid does not pause while you build.",
	"The glowing frames in the walls are doors. The map is yours to pick through.",
	"Loot is only yours once you leave. Stand in an exit and hold F.",
]
var tutorial_step: int = 0
var _tutorial_on: bool = false
var _moved: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	Arena.register(self)
	Cues.emit_cue(&"music_start")
	map = RaidMap.new()
	map.generate(GameState.raid_seed if GameState.raid_seed != 0 else randi())
	rng.seed = map.seed_base

	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.setup(GameState.raid_weapon, GameState.raid_boards)
	player.died.connect(_on_player_died)
	add_child(player)

	_tutorial_on = not bool(GameState.records.get("tutorial_done", false))
	_enter_room(map.entry, -1)
	_last_pos = player.global_position
	noticed.emit(Loc.t("hud.toast.deployed"))
	if _tutorial_on:
		for r in player.runners:
			r.fired.connect(_on_tutorial_fire)

func _process(delta: float) -> void:
	if ended:
		return
	map.advance(delta)
	if room != null:
		var dir := room.check_doors(player)
		if dir >= 0 and _pending_dir < 0:
			_travel(dir)
	_update_prompt()
	_update_tutorial(delta)

## The onboarding line to show right now, or "" once it is done with.
## The step's line, in the language being played. The English above is the
## fallback under it, the way every other lookup falls back.
func tutorial_text() -> String:
	if not _tutorial_on:
		return ""
	return Loc.opt("hud.tutorial.%d" % tutorial_step, String(TUTORIAL_STEPS[tutorial_step]))

func _on_tutorial_fire(_p: Payload) -> void:
	if tutorial_step == 1:
		_advance_tutorial()

func _advance_tutorial() -> void:
	tutorial_step += 1
	Cues.emit_cue(&"ui", {"kind": "tutorial"})
	if tutorial_step >= TUTORIAL_STEPS.size():
		_tutorial_on = false
		GameState.records["tutorial_done"] = true
		GameState.save_game()

func _update_tutorial(delta: float) -> void:
	if not _tutorial_on:
		return
	match tutorial_step:
		0:
			_moved += player.global_position.distance_to(_last_pos)
			_last_pos = player.global_position
			if _moved > 260.0:
				_advance_tutorial()
		2:
			if editing:
				_advance_tutorial()
		4:
			if extract_ratio > 0.05:
				_advance_tutorial()
	_last_pos = player.global_position

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
	if room != null:
		room.queue_free()
		room = null
	var rec: Dictionary = map.get_record(coord)
	var first_visit := not bool(rec.get("visited", false))
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

	# Staying too long draws attention: revisited rooms can pick up a stray.
	var press := map.pressure()
	if not first_visit and press >= 2 and rng.randf() < 0.2 * float(press):
		var kind := Monsters.pick(rng, int(rec["danger"]) + press)
		var extra := {"kind": kind, "mod": "", "pos": [Room.W * Room.CELL * 0.5, 120.0]}
		rec["enemies"].append(extra)
		room._spawn_enemy(extra)
		noticed.emit(Loc.t("hud.toast.followed"))

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
	if _tutorial_on and tutorial_step == 3:
		_advance_tutorial()
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
