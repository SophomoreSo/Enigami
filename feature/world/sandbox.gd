class_name Sandbox
extends World

## A room where nothing is at stake. Parts are unlimited, each weapon's graph
## is a copy of the profile's, and the weapons can be swapped back to back so
## the differences between them are something you see rather than read.
##
## The bench's own buttons are `graphics/ui/sandbox_panel.gd`, in a drawer built
## by the view that attaches itself to this node, beside the raid's own HUD.

signal exit_requested()
signal editing_changed(on: bool)
## The dragon test was asked for: a building of guards to try a chain of lunges on.
signal dragon_test_requested()

const MONSTER_BUTTONS := ["CRAWLER", "SENTRY", "LOBBER", "HOPPER", "DRIFTER", "WARDEN", "ARBITER"]
## The column the apprentice stands in: by the left wall, which the wall kick
## they teach needs.
const APPRENTICE_CELL := 5

var room: Room
var player: Player
## Someone on the bench to talk to.
var npc: Npc
## The Tinker's apprentice, who talks free — in a bubble, while the player goes
## on trying things in front of them — and watches what they try.
var apprentice: Npc
## weapon id -> the graph tried here: a copy of the profile's, so nothing done
## on the bench reaches the hideout.
var graphs: Dictionary = {}
var weapon_index: int = 0
var inventory: Dictionary = {}
## Whether the drawer of bench tools is out. The player is held still while it
## is, the way they are while assembling: its buttons are pressed with the mouse
## they would otherwise be aiming with.
var tools_open: bool = false
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
	graphs.clear()
	for w in Weapons.ids():
		graphs[w] = GameState.weapon_board(String(w)).duplicate_board()

	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	player.room = room
	player.global_position = room.spawn_point()
	_apply_weapon()

	spawn_dummy()
	spawn_npc()
	spawn_apprentice()

func _apply_weapon() -> void:
	var ids := Weapons.ids()
	weapon_index = weapon_index % ids.size()
	player.setup(String(ids[weapon_index]), board())
	player.max_health = 9999.0
	player.health = 9999.0

## The graph on the weapon in hand: what the assembly board over the bench edits.
func board() -> SkillBoard:
	return graphs[current_weapon()]

func cycle_weapon() -> void:
	weapon_index += 1
	_apply_weapon()
	Cues.emit_cue(&"ui", {"kind": "weapon"})

func current_weapon() -> String:
	return String(Weapons.ids()[weapon_index % Weapons.ids().size()])

## Put down on the bench's own floor. It used to be dropped into a fixed cell
## partway up the room, and the generator is free to lay a platform through
## that cell — which left the dummy standing inside one, halfway up the screen
## with nothing under it that anybody could see.
func spawn_dummy() -> void:
	_spawn("DUMMY", 1, room.cell_center(28, _standing_row(28)))

## The lowest cell in column `x` with room above it for a body to stand in.
func _standing_row(x: int) -> int:
	for y in range(Room.H - 1, 0, -1):
		if not room.is_solid(x, y) and not room.is_solid(x, y - 1):
			return y
	return int(Room.H / 2)

## Dropped in above the floor and left to land, like everything else here. On no
## collision layer of its own, so nothing bumps into it.
func spawn_npc() -> void:
	npc = Npc.new()
	npc.setup("SAGE")
	npc.collision_layer = 0
	npc.collision_mask = 1
	npc.position = room.cell_center(20, 16)
	add_child(npc)

## Stood on the floor by the wall, the way the dummy is.
func spawn_apprentice() -> void:
	apprentice = Npc.new()
	apprentice.setup("APPRENTICE")
	apprentice.mode = Npc.Mode.FREE
	apprentice.collision_layer = 0
	apprentice.collision_mask = 1
	apprentice.position = room.cell_center(APPRENTICE_CELL, _standing_row(APPRENTICE_CELL))
	add_child(apprentice)

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

func open_dragon_test() -> void:
	dragon_test_requested.emit()

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
	player.input_locked = editing or tools_open
	editing_changed.emit(on)

func set_tools_open(on: bool) -> void:
	tools_open = on
	player.input_locked = editing or tools_open

func on_board_changed() -> void:
	player.rebuild_runner()

## Someone on the bench in talking range, with something to say.
func use_nearby() -> bool:
	for n in [npc, apprentice]:
		if n != null and is_instance_valid(n) and (n as Npc).answers_press():
			return true
	return false
