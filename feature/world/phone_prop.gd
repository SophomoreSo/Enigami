class_name PhoneProp
extends Node2D

## The phone, put down on a room's floor (`Phone.put_down_at`) and walked away
## from. It lies where it was dropped, coming down to the floor first if it was
## dropped over a gap; rings there when its alarm runs out, which calls the
## monsters in earshot to it (`Phone.tick`); and is picked up again by standing
## over it and pressing interact, the gesture a gate and a treasure box
## answer. `graphics/views/phone_prop_view.gd` draws it.

## Picked up.
signal taken()

## How far from it the player can stand and still be over it.
const REACH := 28.0

var player: Player = null
var room = null
## Whether the player is over it right now, for the view's prompt.
var near: bool = false
var velocity := Vector2.ZERO
## The frame it was put down in: the press that put it down is not this one's
## to answer.
var _born := -1

## The phone put down at `pos` in `room`, for `player` to pick up.
static func lay(in_room, who: Player, pos: Vector2) -> PhoneProp:
	var p := PhoneProp.new()
	p.room = in_room
	p.player = who
	p.position = pos
	in_room.add_child(p)
	return p

func _ready() -> void:
	add_to_group("phone_prop")
	_born = Engine.get_process_frames()

func _process(delta: float) -> void:
	# It comes down onto the floor the way a pickup does.
	if room != null and is_instance_valid(room) and room.has_method("is_solid_at") \
			and not room.is_solid_at(global_position + Vector2(0.0, 6.0)):
		velocity.y += 1100.0 * delta
		var next := global_position + velocity * delta
		if room.is_solid_at(next + Vector2(0.0, 6.0)):
			velocity = Vector2.ZERO
		else:
			global_position = next
	else:
		velocity = Vector2.ZERO
	near = player != null and is_instance_valid(player) \
		and player.global_position.distance_to(global_position) <= REACH + Player.BODY.y * 0.5
	if Engine.get_process_frames() == _born:
		return
	if offered() and Input.is_action_just_pressed("interact") \
			and not player.input_locked and not player.controls_locked():
		Phone.pick_up()
		taken.emit()
		queue_free()

## Whether a press of interact would pick it up: the player over it, with their
## hands in their own body.
func offered() -> bool:
	return near and player.vessel() == player

## Whether it is ringing where it lies.
func ringing() -> bool:
	return Phone.ringing > 0.0
