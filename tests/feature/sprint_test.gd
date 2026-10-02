extends Node2D
## The sprint: the same run, half as fast again, for as long as it is asked for.
##
## Held with a direction the body goes that way faster, and let go it is a run
## again. It is a pace and nothing else — no state of its own, no cost — so it
## turns, jumps and stops as a run does, carries into the air while it is held,
## and does nothing by itself. A crouch still stops it, a hold still holds it,
## a walk the game is walking is still a walk, and a chill slows it as it slows
## a run. The key says it; on the console it is the stick dragged far out of
## its ring, which is touch_pad_test's.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SPRINT] PASS ", what)
	else:
		fails += 1
		push_error("SPRINT FAIL: " + what)

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

func settle(p: Player) -> void:
	for a in ["move_left", "move_right", "move_down", "jump", "dash", "sprint"]:
		Input.action_release(a)
	await until(func() -> bool: return p.is_on_floor() and absf(p.velocity.x) < 1.0 and not p.crouched)
	await phys(2)

## The speed the body settles at, held as it is for a while.
func top_speed(p: Player) -> float:
	await phys(40)
	return absf(p.velocity.x)

func _ready() -> void:
	solid(Vector2(0, 500), Vector2(40000, 200))
	await phys(2)
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = Vector2(0, 360)
	add_child(p)
	await settle(p)

	check(Player.SPRINT_SPEED > Player.RUN_SPEED * 1.2,
		"a sprint is a good deal faster than a run (%.0f against %.0f)" % [Player.SPRINT_SPEED, Player.RUN_SPEED])

	# --- held with a direction --------------------------------------------------------
	Input.action_press("move_right")
	var run := await top_speed(p)
	check(is_equal_approx(run, Player.RUN_SPEED), "holding right alone is a run (%.0f)" % run)
	Input.action_press("sprint")
	var sprint := await top_speed(p)
	check(is_equal_approx(sprint, Player.SPRINT_SPEED) and p.velocity.x > 0.0,
		"with sprint held it is a sprint, the same way (%.0f)" % sprint)
	check(p.state_name() == "Run", "which is a pace, not a state of its own (%s)" % p.state_name())
	Input.action_release("sprint")
	var again := await top_speed(p)
	check(is_equal_approx(again, Player.RUN_SPEED), "let go of, it is a run again (%.0f)" % again)
	Input.action_press("sprint")
	await phys(30)
	Input.action_release("move_right")
	Input.action_press("move_left")
	var back := await top_speed(p)
	check(is_equal_approx(back, Player.SPRINT_SPEED) and p.velocity.x < 0.0 and p.facing == -1,
		"it turns as a run does, and sprints the other way (%.0f)" % p.velocity.x)
	await settle(p)

	# --- by itself, and under a crouch ------------------------------------------------
	var from := p.global_position.x
	Input.action_press("sprint")
	await phys(20)
	check(p.state_name() == "Idle" and absf(p.global_position.x - from) < 1.0,
		"sprint held with no direction goes nowhere (%s)" % p.state_name())
	Input.action_press("move_right")
	Input.action_press("move_down")
	await phys(30)
	check(p.state_name() == "Crouch" and absf(p.velocity.x) < 1.0,
		"and with down held as well it is a crouch: a crouch stops a sprint as it stops a run (%s)" % p.state_name())
	Input.action_release("move_down")
	sprint = await top_speed(p)
	check(is_equal_approx(sprint, Player.SPRINT_SPEED), "up again, the sprint goes on (%.0f)" % sprint)

	# --- into the air -------------------------------------------------------------------
	Input.action_press("jump")
	await phys(3)
	Input.action_release("jump")
	var slowest := INF
	var aloft := 0
	while not p.is_on_floor() and aloft < 300:
		await get_tree().physics_frame
		aloft += 1
		slowest = minf(slowest, absf(p.velocity.x))
	check(aloft > 10 and slowest > Player.RUN_SPEED * 1.2,
		"a jump out of a sprint keeps its speed while sprint is held (never under %.0f in %d frames)" % [slowest, aloft])
	await settle(p)

	# --- what holds or walks the body ------------------------------------------------------
	Input.action_press("move_right")
	Input.action_press("sprint")
	await phys(30)
	p.talk_locked = true
	check(await until(func() -> bool: return absf(p.velocity.x) < 1.0, 60), "a hold stops a sprint dead, like anything else the hands were doing")
	p.talk_locked = false
	await settle(p)
	Input.action_press("sprint")
	from = p.global_position.x
	var w := WalkTo.new(from + 400.0)
	p.input.add(w)
	var fastest := 0.0
	for i in 40:
		await get_tree().physics_frame
		fastest = maxf(fastest, absf(p.velocity.x))
	check(fastest > 100.0 and fastest <= Player.RUN_SPEED + 1.0,
		"a walk the game is walking is a walk, sprint held or not (%.0f at most)" % fastest)
	w.cancel()
	await settle(p)

	# --- a chill ----------------------------------------------------------------------------
	p.chill_time = 10.0
	Input.action_press("move_right")
	Input.action_press("sprint")
	var chilled := await top_speed(p)
	check(is_equal_approx(chilled, Player.SPRINT_SPEED * p.speed_scale()) and chilled < Player.RUN_SPEED,
		"a chill slows a sprint by as much as it slows a run (%.0f)" % chilled)
	p.chill_time = 0.0
	await settle(p)

	# --- the other hands -----------------------------------------------------------------------
	var bot := ComputerHands.new()
	p.input.add(bot)
	bot.move = 1.0
	bot.sprint = true
	sprint = await top_speed(p)
	check(is_equal_approx(sprint, Player.SPRINT_SPEED), "the computer's hands sprint it by saying so (%.0f)" % sprint)
	bot.sprint = false
	run = await top_speed(p)
	check(is_equal_approx(run, Player.RUN_SPEED), "and run it by not (%.0f)" % run)
	p.input.remove(bot)
	await settle(p)

	# A gamepad: the left stick clicked in, held, with the stick over.
	var click := InputEventJoypadButton.new()
	click.device = 0
	click.button_index = JOY_BUTTON_LEFT_STICK
	click.pressed = true
	Input.parse_input_event(click)
	var lean := InputEventJoypadMotion.new()
	lean.device = 0
	lean.axis = JOY_AXIS_LEFT_X
	lean.axis_value = 1.0
	Input.parse_input_event(lean)
	sprint = await top_speed(p)
	check(is_equal_approx(sprint, Player.SPRINT_SPEED), "a gamepad sprints with its left stick clicked in (%.0f)" % sprint)
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	lean = lean.duplicate()
	lean.axis_value = 0.0
	Input.parse_input_event(lean)
	await settle(p)

	print("[SPRINT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
