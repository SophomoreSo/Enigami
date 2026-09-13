class_name Sandbox
extends Node2D

## A room where nothing is at stake. Parts are unlimited, boards are copies of
## the library, and the same skill can be tried on each weapon back to back so
## the differences between weapons are something you see rather than read.
##
## The bench's own readouts and buttons are `graphics/ui/sandbox_panel.gd`,
## built by the view that attaches itself to this node.

signal exit_requested()
signal editing_changed(on: bool)
## The loadout changed under the bench, so anything cached about it is stale.
signal loadout_changed()

const MONSTER_BUTTONS := ["CRAWLER", "SENTRY", "LOBBER", "HOPPER", "DRIFTER", "WARDEN", "ARBITER"]

var room: Room
var player: Player
var boards: Array = []
var weapon_index: int = 0
var inventory: Dictionary = {}
var editing: bool = false
var _dps_window: Array = []   ## [time, damage] pairs over the last few seconds
var _dps: float = 0.0

func _ready() -> void:
	Arena.register(self)
	Cues.emit_cue(&"music_start")

	room = Room.new()
	add_child(room)
	var record := {"kind": "entry", "danger": 1, "region": 0, "variant": 7, "enemies": [], "loot": []}
	room.build(Vector2i.ZERO, record, {}, 12345)

	# Copies only: nothing here touches the hideout.
	boards.clear()
	for b in GameState.skill_library:
		boards.append(b.duplicate_board())
	if boards.is_empty():
		boards.append(Weapons.make_innate_board("SWORD"))
	boards = boards.slice(0, 4)

	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	player.room = room
	player.global_position = room.spawn_point()
	_apply_weapon()

	spawn_dummy()

func _apply_weapon() -> void:
	var ids := Weapons.ids()
	weapon_index = weapon_index % ids.size()
	player.setup(String(ids[weapon_index]), boards)
	player.max_health = 9999.0
	player.health = 9999.0
	loadout_changed.emit()

func cycle_weapon() -> void:
	weapon_index += 1
	_apply_weapon()
	Cues.emit_cue(&"ui", {"kind": "weapon"})

func current_weapon() -> String:
	return player.weapon_id

func spawn_dummy() -> void:
	_spawn("DUMMY", 1, room.cell_center(28, 16))

func spawn_monster(kind: String) -> void:
	_spawn(kind, 2, room.cell_center(24 + randi() % 8, 10))

func _spawn(kind: String, danger: int, at: Vector2) -> void:
	var e := Enemy.new()
	e.setup(kind, danger, "")
	e.position = at
	e.room = room
	e.collision_layer = 4
	e.collision_mask = 1
	e.damaged.connect(_on_damage)
	add_child(e)

func clear_monsters() -> void:
	for c in get_children():
		if c is Enemy:
			c.queue_free()

func leave() -> void:
	exit_requested.emit()

func _on_damage(_a: Actor, amount: float) -> void:
	_dps_window.append([float(Time.get_ticks_msec()) / 1000.0, amount])

func _process(_delta: float) -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	_dps_window = _dps_window.filter(func(e: Array) -> bool: return now - float(e[0]) <= 3.0)
	var total := 0.0
	for e in _dps_window:
		total += float(e[1])
	_dps = total / 3.0

func dps() -> float:
	return _dps

func set_editing(on: bool) -> void:
	if editing == on:
		return
	editing = on
	player.input_locked = on
	editing_changed.emit(on)

func on_board_changed(slot: int) -> void:
	player.rebuild_runner(slot)
	loadout_changed.emit()
