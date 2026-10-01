class_name Hands
extends InputMiddleware

## The player's own hands, at the head of their line: the keys, a gamepad, the
## console on the glass and the pointer, read through `Input` and `Pointer` the
## way the player always read them. It is the only thing on the line that knows
## a person is holding anything. Put something else at the head of a line and
## the same body walks for that instead.
##
## The console needs nothing here: a thumb on it presses the same actions a key
## does, and leans on the right stick to aim (`Touch`).

func process(s: InputState) -> InputState:
	s.move = Input.get_axis("move_left", "move_right")
	s.attack = Input.is_action_pressed("attack")
	s.cast = Input.is_action_pressed("cast_skill")
	# Edges, as the frame being asked in sees them: the physics frame's when the
	# body asks while it moves, the drawn frame's when it asks while it is drawn.
	s.jump_pressed = Input.is_action_just_pressed("jump")
	s.jump_released = Input.is_action_just_released("jump")
	s.dash_pressed = Input.is_action_just_pressed("dash")
	s.cast_released = Input.is_action_just_released("cast_skill")
	if body != null:
		_aim(s)
	return s

## The right stick while it is pushed past its dead zone, a gamepad's or the
## console's; the pointer the rest of the time.
func _aim(s: InputState) -> void:
	s.aiming = true
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > Player.STICK_DEAD:
		s.aim_by_stick = true
		s.aim = stick.normalized()
		s.aim_reach = Player.reach_of(stick.length())
		s.aim_point = body.global_position + s.aim * Player.STICK_AIM_REACH
		return
	s.aim_reach = 1.0
	# `Pointer` rather than the viewport: while the player has the controls the
	# game is doing the pointing, at whatever speed the setting asks for. It
	# answers the system's own pointer the rest of the time, and at 1.0 the two
	# are the same thing.
	var at := Pointer.world_point(body)
	var m := at - body.global_position
	s.aim = m.normalized() if m.length() > 4.0 else Vector2.ZERO
	s.aim_point = at
