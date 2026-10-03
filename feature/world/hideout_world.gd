class_name HideoutWorld
extends World

## Between raids, as a place rather than a screen. The player stands in a room
## and walks to what they want: the rack to pick the weapon they will carry, the
## counter to spend scrap, the gate to go. Each is a `Station` — walk up, press
## interact, and that station's panel opens over the room.
##
## The weapon's graph is not a station. TAB opens it from anywhere on the floor,
## the key that opens assembly in a raid, and the rack's BUILD opens it too. A
## workbench used to stand between the rack and the counter for it, which was a
## walk to reach what a key already reached.
##
## The panels are the ones the old screen was made of, built one at a time
## instead of three at once; `graphics/ui/hideout.gd` still owns what is in
## them. What changed is how they are reached.
##
## Nothing here draws. `graphics/views/hideout_world_view.gd` builds the camera,
## the signs over the stations and the panels they open.

signal deploy_requested(weapon: String)
signal title_requested()
## A station was used: "weapons" or "shop". The view opens the panel; the rules
## do not know there is one.
signal station_used(id: String)
## The weapon's graph was asked for — by the key that opens assembly in a raid,
## or off the rack's BUILD. The editor belongs to `app/game.gd`, so this only
## passes the ask on.
signal edit_requested()
## Something the room wants to say, for the HUD to toast. The raid says things
## the same way (`Raid.noticed`), and this is the same kind of thing: an answer
## to a press that would otherwise be silence.
signal noticed(text: String)
## The panel over the room opened or closed. The room keeps standing either way.
signal panel_changed(id: String)

## Where each station stands, in room cells. The floor is generated, so these
## are columns rather than exact spots: `_floor_at` drops each one onto whatever
## the generator put under it. Laid left to right in the order you would use
## them — pick a weapon, buy what its graph still needs, leave.
const STATION_CELLS := {
	"weapons": 7,
	"shop": 20,
	"gate": 34,
}

var room: Room
var player: Player
## id -> Station, in `STATION_CELLS` order.
var stations: Dictionary = {}
## Which panel is open over the room, or "" for none. While one is open the
## player is held still: they are reading, not walking.
var open_panel: String = ""
## `editing`, from `World`, is whether the workbench's editor is up over the
## room, opened on the assembly key or off the rack's BUILD. `app/game.gd` owns
## the editor and says so here, the way a raid and the sandbox are told theirs;
## the player is held under it just as under a panel. Opened by key from the
## floor it used to hold nobody, so the player walked the room behind it and
## the game kept the mouse for their aim.
## The weapon the kit is being built around. The rack writes it, the editor
## reads it, and the gate carries it.
var weapon_id: String = ""

func _ready() -> void:
	Arena.register(self)
	Cues.emit_cue(&"music_start")

	# One room, flat and empty: a hideout is somewhere to stand, and a generated
	# raid room's platforms would put the merchant on a ledge. `entry` is the
	# kind with no monsters and no loot in it, and `flat` is the room asking the
	# generator for a floor and four walls and nothing else.
	room = Room.new()
	add_child(room)
	room.build(Vector2i.ZERO, {
		"kind": "entry", "danger": 1, "region": 0, "variant": 3,
		"flat": true, "enemies": [], "loot": [],
	}, {}, 20260920)

	if weapon_id == "" or not GameState.owned_weapons.has(weapon_id):
		weapon_id = GameState.owned_weapons[0] if GameState.owned_weapons.size() > 0 else "SWORD"

	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	player.room = room
	refresh_kit()
	# Nothing here can hurt anybody, and a player who walked in wounded should
	# not be reading their health bar while they shop. The medbay is what heals
	# between raids; this is only the hideout refusing to be a fight.
	player.max_health = GameState.max_health()
	player.health = player.max_health
	player.global_position = room.cell_center(STATION_CELLS["weapons"] - 3,
		_floor_at(STATION_CELLS["weapons"] - 3))

	for id in STATION_CELLS:
		_build_station(String(id))
	_refresh_gate()
	GameState.kit_changed.connect(_refresh_gate)
	# The player standing in the room carries what the gate would carry, so a
	# graph built on the board has to reach them before the HUD can show it.
	GameState.kit_changed.connect(refresh_kit)
	GameState.stash_changed.connect(_refresh_gate)
	# The signs are words written once, unlike everything the view draws every
	# frame, so a language switched from the pause menu has to reach them.
	Loc.language_changed.connect(_relabel)

func _build_station(id: String) -> void:
	var x: int = int(STATION_CELLS[id])
	var s := Station.new()
	s.id = id
	s.player = player
	s.label = Loc.t("hideout.station.%s" % id)
	s.position = room.cell_center(x, _floor_at(x))
	s.used.connect(_on_station_used)
	add_child(s)
	stations[id] = s

## Every sign in the room, in the language now being played.
func _relabel(_lang: String) -> void:
	for id in stations:
		var s: Station = stations[id]
		s.label = Loc.t("hideout.station.%s" % id)
	_refresh_gate()

## The lowest cell in column `x` with a body's worth of room above it. The floor
## is generated, so nothing may assume where it is — a station standing inside a
## platform is exactly the bug the bench's own dummy used to have.
func _floor_at(x: int) -> int:
	for y in range(Room.H - 1, 0, -1):
		if not room.is_solid(x, y) and not room.is_solid(x, y - 1):
			return y
	return int(Room.H / 2)

## The gate is shut until there is a weapon to carry through it — one the
## vault still has. It says so rather than going quiet, since "nothing happens"
## is the one thing a door must never do. A weapon always has its graph, so
## there is nothing else to be short of.
func _refresh_gate() -> void:
	var gate: Station = stations.get("gate")
	if gate == null:
		return
	var owned: bool = GameState.owned_weapons.has(weapon_id)
	gate.open = owned
	gate.closed_reason = "" if owned else Loc.t("hideout.gate.no_weapon")

## The graph the gate would carry: the one on the weapon the rack was left on.
## The profile's own board, not a copy. A raid carries a copy because a raid
## writes on it; here it is only read — to be shown on the HUD and to be
## edited, which is editing the profile and is meant to be.
func armed_board() -> SkillBoard:
	return GameState.weapon_board(weapon_id)

## Puts the kit back on the player in the room: the weapon the rack was left on
## and the graph on it. Nothing in here fights, but the HUD over the room reads
## the player rather than the profile, so anything that changes the kit — the
## rack, a graph coming back from the editor — comes through here afterwards.
func refresh_kit() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.setup(weapon_id, armed_board())

func _on_station_used(s: Station) -> void:
	if open_panel != "":
		return
	if s.id == "gate":
		deploy_requested.emit(weapon_id)
		return
	open_station(s.id)

## Opens a station's panel, from a press or from a test. The player is held
## still while it is up: `Player.controls_locked` is what an NPC conversation
## uses to the same end, and reading a shop list is no different from listening.
func open_station(id: String) -> void:
	if not stations.has(id) or id == "gate":
		return
	open_panel = id
	_hold()
	station_used.emit(id)
	panel_changed.emit(id)

## Builds the open panel again, for when what is in it has changed underneath:
## a board came back from the editor with a different name, a purchase left the
## stash different. Nothing happens if no panel is open.
func refresh_panel() -> void:
	if open_panel != "":
		panel_changed.emit(open_panel)

func close_panel() -> void:
	if open_panel == "":
		return
	open_panel = ""
	_hold()
	_refresh_gate()
	panel_changed.emit("")

## The workbench's editor went up over the room, or came down again.
func set_editing(on: bool) -> void:
	editing = on
	_hold()

## Holds the player still while anything is up over the room — a panel, the
## editor — and lets them go once nothing is. They are stopped where they stand
## rather than left to slide, and still fall: held is not hung in the air.
func _hold() -> void:
	if player == null or not is_instance_valid(player):
		return
	var held := open_panel != "" or editing
	if held:
		player.velocity.x = 0.0
	player.input_locked = held

## The weapon the rack was last left on. Changing it re-reads the gate, since a
## weapon the vault no longer has is a raid nobody can be let into.
func set_weapon(id: String) -> void:
	weapon_id = id
	refresh_kit()
	_refresh_gate()

## Whether the player is being held still by something on screen. The view asks
## before it lets a key through, the same way the sandbox does while assembling.
func reading() -> bool:
	return open_panel != "" or editing

## A station's panel is up: the rack's, or the counter's. See `World.paneled`.
func paneled() -> bool:
	return open_panel != ""

func leave() -> void:
	title_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if reading():
		return
	# The key that opens assembly in a raid opens it here too, over the graph
	# the gate would carry. From the floor it is the way onto the board: there
	# is no workbench to walk to.
	if event.is_action_pressed("open_editor"):
		edit_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("interact"):
		return
	for id in stations:
		var s: Station = stations[id]
		if s.near and s.open:
			s.interact()
			get_viewport().set_input_as_handled()
			return

## A station open and within reach.
func use_nearby() -> bool:
	for s in stations.values():
		if (s as Station).near and (s as Station).open:
			return true
	return false
