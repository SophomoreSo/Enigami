class_name Gate
extends Node2D

## A way up or down out of a raid's room: a gate standing on its floor, gone
## through by walking up to it and pressing interact. Rooms side by side are
## joined by the gaps in their walls, which are walked through; rooms one over
## the other are joined by a pair of these, one in each — the lower room's leads
## up and the upper room's leads down, and each puts the player down in front of
## the other. Nothing is jumped up into and nothing is fallen through.
##
## It is the same gesture as a `TreasureBox`, a `Station` in the hideout and an
## exit — stand at it, press the key. `graphics/views/gate_view.gd` draws it.

## Pressed while the player was at it. `dir` is the way it leads.
signal entered(dir: int)

## How far either side of its middle the player can stand and still be at it:
## the gate's own width, and a little.
const REACH := 40.0
## How far up from the floor it stands, in pixels: three cells, a doorway's
## height.
const TALL := 96.0

## The way it leads: `Components.N` up, `Components.S` down.
var dir: int = Components.N
var player: Player = null
## Whether the player is at it right now, recomputed every frame so the view can
## show the prompt without asking twice.
var near: bool = false
## The frame it was put down in. The player is stood in front of a gate on the
## way in, with the press that went through the other one still down: it is
## not this one's to answer.
var _born: int = -1

## `at` is the middle of the cell it stands in, half a cell above the floor —
## where a body that comes through it is put down (`Room.arrival_point`).
func setup(way: int, at: Vector2) -> void:
	dir = way
	position = at

func _ready() -> void:
	add_to_group("gates")
	_born = Engine.get_process_frames()

func _process(_delta: float) -> void:
	near = player != null and is_instance_valid(player) \
		and reach().has_point(player.global_position)
	if Engine.get_process_frames() == _born:
		return
	if offered() and Input.is_action_just_pressed("interact") \
			and not player.input_locked and not player.controls_locked():
		entered.emit(dir)

## Where the player has to be to be at it: in front of it, from its floor to
## its top.
func reach() -> Rect2:
	var floor_y := global_position.y + Room.CELL * 0.5
	return Rect2(global_position.x - REACH, floor_y - TALL, REACH * 2.0, TALL)

## Whether a press of interact would take the player through: at it, and with
## their hands in their own body rather than in a monster somewhere else.
func offered() -> bool:
	return near and player.vessel() == player
