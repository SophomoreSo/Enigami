class_name HandsOff
extends InputMiddleware

## Takes the hands off the body: nothing the player presses walks, turns,
## jumps, dashes, swings, charges or casts, and the weapon stays where it was
## last pointed. A screen over the game puts one on the player's line, and so
## does a conversation in the box (`Player.input_locked`, `Player.talk_locked`).
##
## It stands after the hands and before anything that steers, so the game can
## still walk a body its player may not move. The acts it stops, it stops by
## shutting their gates, so one raised further down the line — a jump something
## presses for the body — is stopped as well.

func _init() -> void:
	rank = HOLD

func process(s: InputState) -> InputState:
	s.move = 0.0
	s.turn = 0
	s.attack = false
	s.cast = false
	s.aiming = false
	s.can_jump = false
	s.can_dash = false
	s.can_cast = false
	return s
