extends Node2D
## The crouch: a state on the floor that lets the body down onto its feet.
##
## Down is held and the player crouches — stopped, lower, a smaller thing to
## hit, the feet where they were — and stands again when it is let go. It is a
## state like the others on the ground, so a jump or a dash goes out of it, a
## ledge drops out of it, and in the air there is no such thing. Whatever takes
## the hands off the body, or walks it, stands it up. Down is a key, or a stick
## pushed down past its threshold — three quarters of the way out — and
## sideways a gamepad's stick runs as it always did.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[CROUCH] PASS ", what)
	else:
		fails += 1
		push_error("CROUCH FAIL: " + what)

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func until(cond: Callable, limit: int = 240) -> bool:
	for i in limit:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())

func solid(centre: Vector2, size: Vector2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = centre
	b.add_child(cs)
	add_child(b)

## Lets the body come to a stop, standing, with every key up.
func settle(p: Player) -> void:
	for a in ["move_left", "move_right", "move_down", "jump", "dash"]:
		Input.action_release(a)
	await until(func() -> bool: return p.is_on_floor() and absf(p.velocity.x) < 1.0 and not p.crouched)
	await phys(2)

## The left stick, leant: a gamepad's, by the axes its move keys are bound to.
func lean(to: Vector2) -> void:
	for i in 2:
		var m := InputEventJoypadMotion.new()
		m.device = 0
		m.axis = JOY_AXIS_LEFT_X if i == 0 else JOY_AXIS_LEFT_Y
		m.axis_value = to.x if i == 0 else to.y
		Input.parse_input_event(m)

## Where the body's feet are: the bottom of its collider.
func feet(p: Player) -> float:
	return p.global_position.y + p.body_size.y * 0.5

func collider(p: Player) -> Vector2:
	for c in p.get_children():
		if c is CollisionShape2D:
			return ((c as CollisionShape2D).shape as RectangleShape2D).size
	return Vector2.ZERO

func _ready() -> void:
	solid(Vector2(600, 500), Vector2(4000, 200))
	await phys(2)
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = Vector2(300, 360)
	add_child(p)
	await settle(p)

	# --- down, and up again ----------------------------------------------------------
	check(p.state_name() == "Idle" and not p.crouched and p.body_size == Player.BODY
			and is_equal_approx(p.hurt_radius, Player.HURT_RADIUS),
		"standing, the body is its own size (%s, %s)" % [p.state_name(), str(p.body_size)])
	var floor_y := feet(p)
	var stood_at := p.global_position.y
	Input.action_press("move_down")
	await phys(4)
	check(p.state_name() == "Crouch" and p.crouched, "holding down crouches (%s)" % p.state_name())
	check(p.body_size == Player.CROUCH_BODY and collider(p) == Player.CROUCH_BODY,
		"the body is let down: %s, and its collider with it (%s)" % [str(p.body_size), str(collider(p))])
	check(is_equal_approx(p.hurt_radius, Player.CROUCH_HURT_RADIUS) and p.hurt_radius < Player.HURT_RADIUS,
		"a smaller thing to hit (%.0f, from %.0f)" % [p.hurt_radius, Player.HURT_RADIUS])
	check(absf(feet(p) - floor_y) < 0.6 and p.is_on_floor(),
		"onto its feet, which have not moved (%.1f off)" % (feet(p) - floor_y))
	var lower := p.global_position.y - stood_at
	check(absf(lower - (Player.BODY.y - Player.CROUCH_BODY.y) * 0.5) < 0.6,
		"so the middle of it — where a bolt finds it, and where its own weapon is — is lower (%.1fpx)" % lower)
	check(absf(p.standing_position().y - stood_at) < 0.6 and is_equal_approx(p.standing_position().x, p.global_position.x),
		"though where it would stand is where it stood, which is what a parked raid keeps (%.1f off)"
			% (p.standing_position().y - stood_at))
	await phys(30)
	check(p.state_name() == "Crouch" and absf(feet(p) - floor_y) < 0.6,
		"and it stays so for as long as down is held")
	Input.action_release("move_down")
	await phys(4)
	check(p.state_name() == "Idle" and not p.crouched and p.body_size == Player.BODY
			and collider(p) == Player.BODY and is_equal_approx(p.hurt_radius, Player.HURT_RADIUS),
		"let go, it stands: the body and the reach of a hit are what they were (%s)" % p.state_name())
	check(absf(feet(p) - floor_y) < 0.6 and absf(p.global_position.y - stood_at) < 0.6,
		"on the same feet, at the same height (%.1f off)" % (p.global_position.y - stood_at))

	# --- crouched, it does not walk --------------------------------------------------
	Input.action_press("move_down")
	await phys(4)
	var from := p.global_position.x
	p.face(1)
	Input.action_press("move_left")
	await phys(20)
	check(p.state_name() == "Crouch" and absf(p.global_position.x - from) < 1.0,
		"a direction held with it does not walk (moved %.1f)" % (p.global_position.x - from))
	check(p.facing == -1, "but turns the body to face that way")
	Input.action_release("move_left")
	await settle(p)

	# A run that crouches stops where a run that is let go of does.
	Input.action_press("move_right")
	await phys(20)
	check(p.state_name() == "Run" and p.velocity.x > 100.0, "(a run under way)")
	Input.action_press("move_down")
	await phys(2)
	check(p.state_name() == "Crouch", "down in the middle of a run crouches (%s)" % p.state_name())
	check(await until(func() -> bool: return absf(p.velocity.x) < 1.0, 60) and p.state_name() == "Crouch",
		"and brakes it to a stop")
	await settle(p)

	# --- out of it --------------------------------------------------------------------
	Input.action_press("move_down")
	await phys(4)
	Input.action_press("jump")
	await phys(3)
	Input.action_release("jump")
	check(not p.is_on_floor() and p.velocity.y < 0.0 and p.state_name() == "Rise",
		"a jump goes out of a crouch (%s)" % p.state_name())
	check(not p.crouched and p.body_size == Player.BODY, "standing: there is no crouch in the air")
	# Down is still held all the way up and down again.
	var aloft := 0
	var low_aloft := 0
	while not p.is_on_floor() and aloft < 300:
		await get_tree().physics_frame
		aloft += 1
		if p.crouched and not p.is_on_floor():
			low_aloft += 1
	check(low_aloft == 0, "held in the air it does nothing (%d frames low, of %d)" % [low_aloft, aloft])
	await phys(3)
	check(p.state_name() == "Crouch" and absf(feet(p) - floor_y) < 0.6,
		"and landing with it still held crouches on the spot (%s)" % p.state_name())
	p.stamina = Player.MAX_STAMINA
	Input.action_press("dash")
	await phys(2)
	Input.action_release("dash")
	await phys(1)
	check(p.state_name() == "Dash" and not p.crouched and p.body_size == Player.BODY,
		"a dash goes out of a crouch too, standing (%s)" % p.state_name())
	await settle(p)

	# --- what takes the hands off, or walks, stands it up -----------------------------
	Input.action_press("move_down")
	await phys(4)
	check(p.crouched, "(crouched)")
	p.talk_locked = true
	await phys(4)
	check(p.state_name() == "Idle" and not p.crouched,
		"held in a conversation, the body stands, whatever is still held (%s)" % p.state_name())
	p.talk_locked = false
	await phys(4)
	check(p.state_name() == "Crouch", "and let go of, the key still held crouches again")
	from = p.global_position.x
	var w := WalkTo.new(from + 90.0)
	p.input.add(w)
	await phys(6)
	check(not p.crouched and p.global_position.x > from + 2.0,
		"a walk walks it standing, down held or not (%s, %.0f)" % [p.state_name(), p.global_position.x - from])
	await until(func() -> bool: return w.done)
	await settle(p)

	# --- a stick ------------------------------------------------------------------------
	# Down is held once a gamepad's stick is past its threshold, three quarters
	# of the way out, and not before: a thumb running sideways wanders downward.
	# Sideways it runs past its own, much nearer the middle.
	lean(Vector2(0.0, 0.6))
	await phys(4)
	check(p.state_name() == "Idle" and not Input.is_action_pressed("move_down"),
		"a stick pushed down short of its threshold does nothing (%s)" % p.state_name())
	lean(Vector2(0.0, 0.85))
	await phys(4)
	check(p.state_name() == "Crouch", "past it, it crouches (%s)" % p.state_name())
	lean(Vector2(0.0, 0.6))
	await phys(4)
	check(p.state_name() == "Idle", "and eased back inside it, it stands (%s)" % p.state_name())
	from = p.global_position.x
	lean(Vector2(0.6, 0.0))
	await phys(12)
	check(p.state_name() == "Run" and p.global_position.x > from + 5.0,
		"a stick pushed sideways past its threshold runs (%s, %.0f)" % [p.state_name(), p.global_position.x - from])
	lean(Vector2(0.8, 0.4))
	await phys(6)
	check(p.state_name() == "Run", "and drifting down short of the crouch's, it is still a run (%s)" % p.state_name())
	lean(Vector2(-0.5, 0.85))
	await phys(8)
	check(p.state_name() == "Crouch" and p.facing == -1,
		"past both, down wins: a crouch, turned the way the stick leans (%s)" % p.state_name())
	lean(Vector2.ZERO)
	await settle(p)

	# --- the computer's hands -----------------------------------------------------------
	var bot := ComputerHands.new()
	p.input.add(bot)
	bot.crouch = true
	await phys(4)
	check(p.state_name() == "Crouch", "the computer's hands crouch it by saying so (%s)" % p.state_name())
	Input.action_press("move_down")
	bot.crouch = false
	await phys(4)
	check(p.state_name() == "Idle", "and the player's own down key is dropped with the rest of what they say")
	Input.action_release("move_down")
	p.input.remove(bot)
	await settle(p)

	# --- a ledge ------------------------------------------------------------------------
	# Shoved off an edge while crouched, the body falls standing.
	solid(Vector2(-3000, 300), Vector2(400, 40))
	var q := Player.new()
	q.collision_layer = 2
	q.collision_mask = 1
	q.position = Vector2(-2810, 200)
	add_child(q)
	await until(func() -> bool: return q.is_on_floor())
	Input.action_press("move_down")
	await phys(4)
	check(q.crouched, "(crouched by an edge)")
	q.knockback(Vector2.RIGHT, 400.0)
	check(await until(func() -> bool: return not q.is_on_floor(), 60), "a shove carries it off the edge")
	await phys(2)
	check(q.state_name() == "Fall" and not q.crouched and q.body_size == Player.BODY,
		"and it falls standing (%s)" % q.state_name())
	Input.action_release("move_down")

	print("[CROUCH] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
