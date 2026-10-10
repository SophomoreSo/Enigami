class_name LightingTest
extends World

## A proving ground for the light (`Lighting`): a stretch of the Moonlit Grove
## at night with a light of each kind hung in it and a dummy beside each, to
## walk through and see what a body does in each. Left to right: a lantern
## hung behind whoever walks into it, one hung in front, a fire and a
## fireplace, and a spotlight, which lights bodies as it always did.
##
## The ground is a made map (`MadeRoom`) laid out here, the way the map
## creator would lay it, so its lanterns hang on cords and swing when they are
## walked through, its grass leans and its fires burn as any made map's do.
## Nothing is at stake: the bench's kit is in hand, copies of the profile's
## graphs, and the body cannot fall. R sets the ground again and ESC goes back
## to the bench.
##
## What is lit, and how — which lanterns hang in front, how dark the night is,
## the light on the crosshair — is the picture's:
## `graphics/views/lighting_test_view.gd`. Nothing here knows a light is lit.

signal exit_requested()
## The ground was set again: a fresh room, and the body back at the start.
signal floor_reset()

const TILESET := "grove"
## The ground: leaves overhead, earth underfoot, a trunk at either end, the
## start (`P`) at the left and a dummy (`y`) beside each light.
const PLAN := [
	"********************************************************",
	"|......................................................|",
	"|......................................................|",
	"|......................................................|",
	"|......................................................|",
	"|......................................................|",
	"|......................................................|",
	"|......................................................|",
	"|......................................................|",
	"|......................................................|",
	"|..P......y............y.........y...............y.....|",
	"%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%",
	"%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%",
	"%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%",
]
## What stands behind: a column between each stretch and the next, and a rail
## over each hung light for it to hang from.
const BACK := [
	"........................................................",
	"..............|............|............|...............",
	"..............|............|............|...............",
	"..............|............|............|...............",
	"..............|............|............|...............",
	"..............|............|............|...............",
	"..............|............|............|..=========....",
	"....=========.|..=========.|............|...............",
	"..............|............|............|...............",
	"..............|............|............|...............",
	"..............|............|............|...............",
	"........................................................",
	"........................................................",
	"........................................................",
]
## What is put about it: a lantern (`L`) at a body's height under each of the
## first two rails, a fire (`F`) and a fireplace (`H`), a lightbulb (`B`) under
## the last rail, and grass (`g`) here and there.
const DRESSING := [
	"........................................................",
	"........................................................",
	"........................................................",
	"........................................................",
	"........................................................",
	"........................................................",
	"........................................................",
	"........................................................",
	"...............................................B........",
	"........................................................",
	".....g..L...g.....g..L...g...F.g...g.H......g.......g...",
	"........................................................",
	"........................................................",
	"........................................................",
]
## The stretches of the ground, a light each, left to right: the columns each
## takes up, and what is in it.
const ZONES := [
	{"what": "behind", "from": 1, "to": 13},
	{"what": "front", "from": 15, "to": 26},
	{"what": "fire", "from": 28, "to": 39},
	{"what": "spot", "from": 41, "to": 54},
]

var room: MadeRoom
var player: Player
## weapon id -> the graph tried here: a copy of the profile's, as on the bench.
var graphs: Dictionary = {}

func _ready() -> void:
	Arena.register(self)
	Cues.emit_cue(&"music_start")
	# Copies only: nothing tried here reaches the hideout.
	for w in Weapons.ids():
		graphs[w] = GameState.weapon_board(String(w)).duplicate_board()
	_stand()

## The stretch `x` world units along the ground is in, or {} between two.
static func zone_at(x: float) -> Dictionary:
	var column := int(floorf(x / Room.CELL))
	for z: Dictionary in ZONES:
		if column >= int(z["from"]) and column <= int(z["to"]):
			return z
	return {}

## The ground stood up as it was laid, with a body at its start and the
## bench's kit in hand.
func _stand() -> void:
	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	var ids := Weapons.ids()
	var kit: Array = []
	var boards: Array = []
	for k in mini(Player.MAX_WEAPONS, ids.size()):
		kit.append(ids[k])
		boards.append(graphs[String(ids[k])])
	player.setup_kit(kit, boards, 0)
	player.max_health = 9999.0
	player.health = 9999.0

	room = MadeRoom.new()
	room.plan = PackedStringArray(PLAN)
	room.back = PackedStringArray(BACK)
	room.dressing = PackedStringArray(DRESSING)
	room.tileset = TILESET
	# Before it is stood: what the room puts down is told who to answer to.
	room.player = player
	add_child(room)
	room.stand()
	player.room = room
	player.global_position = room.spawn_point()
	player.velocity = Vector2.ZERO

## Everything back as it was laid: a fresh room — its lanterns hanging still —
## and the body at the start, with nothing left in flight.
func reset_floor() -> void:
	Attacks.clear_in_flight(self)
	if player != null and is_instance_valid(player):
		# Out of the hunt now rather than at the end of the frame.
		player.remove_from_group("player")
		player.queue_free()
	if room != null and is_instance_valid(room):
		# Nothing in the room being struck gets another turn (`Raid._enter_room`).
		room.process_mode = Node.PROCESS_MODE_DISABLED
		room.queue_free()
	_stand()
	floor_reset.emit()

func leave() -> void:
	exit_requested.emit()
