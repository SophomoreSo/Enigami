extends Node2D
## Air movement: the ground jump, the wall kick, and the optional air jump that
## `Player.can_double_jump` gates. Synthetic presses are used the way a player
## produces them, so the buffer and coyote windows are exercised too.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[JUMP] PASS ", what)
	else:
		fails += 1
		push_error("JUMP FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

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

func spawn(at: Vector2) -> Player:
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = at
	add_child(p)
	return p

func land(p: Player) -> void:
	var guard := 0
	while not p.is_on_floor() and guard < 400:
		await get_tree().physics_frame
		guard += 1

## Presses jump and reports the upward speed that press bought. Holds until the
## arc peaks so the early-release cut does not eat the measurement.
func press(p: Player) -> float:
	var before := p.velocity.y
	Input.action_press("jump")
	# `is_action_just_pressed` only reads true on the physics frame after a
	# synthetic press, so give it two before measuring.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var gained := before - p.velocity.y
	var guard := 0
	while p.velocity.y < 0.0 and guard < 200:
		await get_tree().physics_frame
		guard += 1
	Input.action_release("jump")
	await get_tree().physics_frame
	return gained

func _ready() -> void:
	solid(Vector2(600, 500), Vector2(2000, 200))
	await frames(2)

	for allow in [true, false]:
		var p := spawn(Vector2(600, 320))
		p.can_double_jump = allow
		await land(p)
		var ground := await press(p)
		await frames(4)                      # falling by now
		var air := await press(p)
		print("[JUMP] can_double_jump=%-5s  ground +%.0f px/s | second press %+.0f px/s"
			% [str(allow), ground, air])
		check(ground > 500.0, "can_double_jump=%s: the ground jump still works" % allow)
		if allow:
			check(air > 400.0, "can_double_jump=true: a second press in the air lifts the player")
		else:
			check(air < 50.0, "can_double_jump=false: a second press in the air does nothing")
		p.queue_free()
		await frames(4)

	# One extra jump per airtime, and landing hands it back.
	var q := spawn(Vector2(600, 320))
	await land(q)
	await press(q)
	await frames(2)
	var air_one := await press(q)
	await frames(2)
	var air_two := await press(q)
	check(air_one > 400.0 and air_two < 50.0,
		"exactly one air jump per airtime (first %+.0f, second %+.0f)" % [air_one, air_two])
	await land(q)
	await frames(2)
	await press(q)
	await frames(2)
	var after_landing := await press(q)
	check(after_landing > 400.0, "landing gives the air jump back (%+.0f)" % after_landing)
	q.queue_free()
	await frames(4)

	# A wall kick is a fresh launch, so it hands the air jump back as well.
	solid(Vector2(980, 300), Vector2(80, 400))
	var w := spawn(Vector2(900, 320))
	await land(w)
	await press(w)                            # up alongside the wall
	Input.action_press("move_right")          # hug it, so a kick is available
	var guard := 0
	while w._wall_dir == 0 and guard < 200:
		await get_tree().physics_frame
		guard += 1
	var kicked := w._wall_dir != 0
	# Watched on every frame of the kick rather than where it ends: the kick used
	# to turn the player away from the wall for the one frame it fired on, and
	# the key still held turned them straight back.
	var turned := [0]
	var watch := func() -> void:
		if w.facing != 1:
			turned[0] += 1
	get_tree().physics_frame.connect(watch)
	var kick := await press(w)
	get_tree().physics_frame.disconnect(watch)
	Input.action_release("move_right")
	await frames(2)
	var after_kick := await press(w)
	check(kicked and kick > 400.0, "the wall kick fires (%+.0f)" % kick)
	check(turned[0] == 0,
		"and it leaves the player facing the way they hold, into the wall (%d frames turned away)"
			% turned[0])
	check(after_kick > 400.0, "and a wall kick refreshes the air jump (%+.0f)" % after_kick)

	print("[JUMP] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
