class_name Raid
extends Node2D

## Runs one deployment: a connected map, one room loaded at a time, the live
## skill editor, and the two ways a raid can end.

signal finished(result: String, payload: Dictionary)

var map: RaidMap
var room: Room = null
var player: Player
var camera: Camera2D
var hud: Hud
var editor: SkillEditor
var rng := RandomNumberGenerator.new()
var editing: bool = false
var ended: bool = false
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
	Fx.register_world(self)
	Audio.play_music()
	map = RaidMap.new()
	map.generate(GameState.raid_seed if GameState.raid_seed != 0 else randi())
	rng.seed = map.seed_base

	camera = Camera2D.new()
	camera.position = Vector2(Room.W * Room.CELL, Room.H * Room.CELL) * 0.5
	camera.zoom = Vector2.ONE
	add_child(camera)
	camera.make_current()
	Fx.register_camera(camera)

	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.setup(GameState.raid_weapon, GameState.raid_boards)
	player.died.connect(_on_player_died)
	add_child(player)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Hud.new()
	hud.player = player
	hud.map = map
	layer.add_child(hud)

	editor = SkillEditor.new()
	editor.visible = false
	editor.title_text = "ASSEMBLY · raid running"
	editor.closed.connect(_close_editor)
	editor.board_changed.connect(_on_board_changed)
	layer.add_child(editor)

	_tutorial_on = not bool(GameState.records.get("tutorial_done", false))
	_enter_room(map.entry, -1)
	_last_pos = player.global_position
	hud.show_toast("Deployed. Hold F at an exit to leave with what you carry.")
	if _tutorial_on:
		for r in player.runners:
			r.fired.connect(_on_tutorial_fire)

func _process(delta: float) -> void:
	if ended:
		return
	map.advance(delta)
	if room != null:
		hud.room = room
		var dir := room.check_doors(player)
		if dir >= 0 and _pending_dir < 0:
			_travel(dir)
	_update_prompt()
	_update_tutorial(delta)

func _on_tutorial_fire(_p: Payload) -> void:
	if tutorial_step == 1:
		_advance_tutorial()

func _advance_tutorial() -> void:
	tutorial_step += 1
	Audio.play("ui")
	if tutorial_step >= TUTORIAL_STEPS.size():
		_tutorial_on = false
		hud.tutorial = ""
		GameState.records["tutorial_done"] = true
		GameState.save_game()

func _update_tutorial(delta: float) -> void:
	if not _tutorial_on:
		hud.tutorial = ""
		return
	hud.tutorial = TUTORIAL_STEPS[tutorial_step]
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
			if hud.extract_ratio > 0.05:
				_advance_tutorial()
	_last_pos = player.global_position

## Event-driven rather than polled: when the editor consumes TAB to close
## itself, this must not see the same press and open it straight back up.
func _unhandled_input(event: InputEvent) -> void:
	if ended:
		return
	if event.is_action_pressed("open_editor"):
		_toggle_editor()
		get_viewport().set_input_as_handled()

func _update_prompt() -> void:
	if room == null:
		return
	var txt := ""
	if not room.extraction.is_empty():
		var reason := room.extraction_blocked_reason()
		if room.extraction_rect().has_point(player.global_position):
			txt = "hold F to extract" if reason == "" else reason
	hud.prompt = txt

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
		hud.show_toast("Something followed you in here.")

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

func _travel(dir: int) -> void:
	var target: Vector2i = room.coord + RaidMap.dir_delta(dir)
	if not map.has_room(target):
		return
	if _tutorial_on and tutorial_step == 3:
		_advance_tutorial()
	_pending_dir = dir
	Fx.burst(player.global_position, Color(0.5, 0.8, 1.0), 8, 120.0)
	_enter_room(target, dir)

## --- events -----------------------------------------------------------------
func _on_pickup(p: Pickup) -> void:
	if p.scrap_amount > 0:
		GameState.raid_scrap += p.scrap_amount
		hud.show_toast("+%d scrap" % p.scrap_amount)
	else:
		GameState.add_component(p.component_id, 1, GameState.raid_bag)
		hud.show_toast("Recovered %s — assemble it with TAB" % Components.get_def(p.component_id).get("name", p.component_id))

func _on_enemy_killed(kind: String, _pos: Vector2) -> void:
	if Monsters.get_def(kind).get("boss", false):
		hud.show_toast("The Arbiter is down. Its gate is open.")

func _on_extract_progress(ratio: float, _info: Dictionary) -> void:
	hud.extract_ratio = ratio

func _on_extract_done(info: Dictionary) -> void:
	if ended:
		return
	if String(info.get("cond", "free")) == "cost":
		GameState.raid_scrap -= int(info.get("cost", 0))
	ended = true
	Audio.play("extract")
	Fx.clear_time_effects()
	var result := GameState.extract()
	result["exit"] = info.get("name", "EXIT")
	finished.emit("extracted", result)

func _on_player_died(_a: Actor) -> void:
	if ended:
		return
	ended = true
	Fx.clear_time_effects()
	Fx.shake(16.0)
	var lost := GameState.die()
	finished.emit("died", lost)

## --- editor -----------------------------------------------------------------
func _toggle_editor() -> void:
	if editing:
		_close_editor()
	else:
		_open_editor()

func _open_editor() -> void:
	editing = true
	editor.weapon_id = player.weapon_id
	editor.configure(GameState.raid_boards, GameState.raid_bag, false, player.runners)
	editor.visible = true
	editor.grab_focus()
	player.input_locked = true
	Audio.play("ui")

func _close_editor() -> void:
	editing = false
	editor.visible = false
	player.input_locked = false

func _on_board_changed(slot: int) -> void:
	player.rebuild_runner(slot)
