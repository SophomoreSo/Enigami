extends Node
## Holding the cast button charges; letting go is what casts, with whatever the
## hold paid for. A tap is a charge of nothing, so a quick press still casts.

const GameScript := preload("res://scripts/core/game.gd")

var game: Node
var sb: Sandbox
var shots: int = 0
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[CHG] PASS ", what)
	else:
		fails += 1
		push_error("CHG FAIL: " + what)

## Shots one cast would produce at a given charge, off the preview.
func shots_at(r: SkillRunner, bonus: int) -> int:
	var saved := r.ttl_bonus
	r.ttl_bonus = bonus
	var n: int = (r.simulate()["outputs"] as Array).size()
	r.ttl_bonus = saved
	return n

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

## Waits for the armed slot to come free, so one cast cannot bleed into the next.
func settle(p: Player) -> void:
	var guard := 0
	while not p.runners[p.selected_slot].is_ready() and guard < 900:
		await get_tree().process_frame
		guard += 1
	await frames(4)

## Holds for `secs`, releases, and reports what that one cast fired.
func hold_and_count(p: Player, secs: float) -> int:
	await settle(p)
	p.mana = Player.MAX_MANA
	p.charge = 0.0
	await frames(4)
	shots = 0
	await hold(secs)
	await settle(p)
	return shots

func hold(secs: float) -> void:
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_RIGHT
	d.pressed = true
	Input.parse_input_event(d)
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_RIGHT
	u.pressed = false
	Input.parse_input_event(u)
	await frames(3)

func _ready() -> void:
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_sandbox()
	await frames(20)
	sb = game.current
	var p := sb.player
	p.runners[0].fired.connect(func(_x: Payload) -> void: shots += 1)
	p.select_slot(0)
	await frames(4)

	check(is_equal_approx(p.mana, Player.MAX_MANA), "mana starts full")
	check(is_equal_approx(p.charge, 0.0), "and nothing is charged")
	var base := p.runners[0].cycle_ttl()
	check(base == p.runners[0].pass_cost,
		"an uncharged cast is worth exactly one pass of the board (%d)" % base)

	# Holding fires nothing; the release is what casts.
	shots = 0
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_RIGHT
	d.pressed = true
	Input.parse_input_event(d)
	await wait(0.8)
	check(shots == 0, "holding the button casts nothing while it is down (%d)" % shots)
	check(p.charge > 0.0, "it charges instead (%.0f)" % p.charge)
	var paid := p.charge
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_RIGHT
	u.pressed = false
	Input.parse_input_event(u)
	await frames(3)
	check(shots > 0, "and letting go casts it (%d shot(s))" % shots)
	check(absf(p.cast_charge - paid) < 1.5,
		"with everything the hold paid for, not a bled-down remnant (%.1f of %.1f)"
			% [p.cast_charge, paid])
	await settle(p)

	# On a board with no cycle the charge has nowhere to go, and must not turn
	# one cast into several.
	check(await hold_and_count(p, 0.15) == 1, "a tap on a cycle-free board casts once")
	check(await hold_and_count(p, 1.5) == 1, "and so does a full charge on it")

	# Charging engages on every skill, cycle in the graph or not — the mana goes
	# either way. What the life is worth is then up to what the player built.
	p.mana = Player.MAX_MANA
	p.charge = 0.0
	await frames(6)
	await hold(1.2)
	check(p.mana < Player.MAX_MANA - 5.0,
		"holding a board with no cycle spends mana (%.0f left)" % p.mana)
	check(p.charge_cap() > 0.0,
		"every board has room for some charge (%.0f)" % p.charge_cap())
	# Read from what the release banked: `charge` is emptied into it on the way.
	check(p.cast_charge > 0.0, "and the release banks real charge (%.0f)" % p.cast_charge)
	check(shots_at(p.runners[0], int(p.cast_charge)) == shots_at(p.runners[0], 0),
		"but on this board it buys no extra casts (%d)" % shots_at(p.runners[0], 0))
	await frames(2)

	# A looping board is what has somewhere to spend it.
	var loop := SkillBoard.new(7, 5, "Winding Blade")
	loop.place("INPUT", Vector2i(0, 1), 0)
	loop.place("WIRE", Vector2i(1, 1), 3)
	loop.place("DAMAGE", Vector2i(1, 0), 0)
	loop.place("DAMAGE", Vector2i(2, 0), 0)
	loop.place("WIRE", Vector2i(3, 0), 1)
	loop.place("WIRE", Vector2i(3, 1), 2)
	loop.place("TEE", Vector2i(2, 1), 1)
	loop.place("SLASH", Vector2i(2, 2), 0)
	loop.place("OUTPUT", Vector2i(3, 2), 0)
	sb.boards[0] = loop
	p.setup("SWORD", sb.boards)
	p.select_slot(0)
	await frames(6)
	check(shots_at(p.runners[0], SkillRunner.MAX_TTL_BONUS) > shots_at(p.runners[0], 0),
		"charging a loop does buy more (%d -> %d)"
			% [shots_at(p.runners[0], 0), shots_at(p.runners[0], SkillRunner.MAX_TTL_BONUS)])
	p.mana = Player.MAX_MANA
	p.charge = 0.0
	await frames(6)
	await hold(1.2)
	check(p.mana < Player.MAX_MANA - 5.0, "holding it spends mana (%.0f left)" % p.mana)
	await frames(2)

	# With mana gone there is nothing left to buy life with.
	p.mana = 0.0
	p.charge = 0.0
	await frames(4)
	var before_ttl := p.runners[0].cycle_ttl()
	await hold(1.0)
	check(p.runners[0].cycle_ttl() <= before_ttl + 1,
		"with no mana, holding buys no life (%d)" % p.runners[0].cycle_ttl())

	# It comes back on its own.
	var t := 0.0
	while p.mana < Player.MAX_MANA and t < 12.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	check(p.mana >= Player.MAX_MANA - 0.01, "mana refills on its own (%.2fs)" % t)

	# Charge never outlives the hold that bought it.
	p.charge = Player.MAX_CHARGE_TTL
	# Waited on the clock, not on a frame count: this runs uncapped.
	var decay := 0.0
	while p.charge > 0.01 and decay < 3.0:
		await get_tree().process_frame
		decay += get_process_delta_time()
	check(p.charge <= 0.01, "charge bleeds off once released (%.2fs)" % decay)
	await frames(2)
	check(p.runners[0].ttl_bonus == 0, "and the board drops back to base life")

	print("[CHG] ---- %d failures ----" % fails)
	get_tree().quit()
