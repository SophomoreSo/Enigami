extends Node
## A weapon only carries skills it accepts, and the rule holds at the moment of
## firing — not just when the loadout was built. A board can turn incompatible
## after it is equipped: edited mid-raid, or carried onto another weapon in the
## sandbox, which is what this drives.

const GameScript := preload("res://app/game.gd")

var game: Node
var sb: Sandbox
var fired: Array = []
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[FIT] PASS ", what)
	else:
		fails += 1
		push_error("FIT FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func tap_key(code: int) -> void:
	var d := InputEventKey.new()
	d.physical_keycode = code
	d.keycode = code
	d.pressed = true
	Input.parse_input_event(d)
	await frames(4)
	var u := InputEventKey.new()
	u.physical_keycode = code
	u.keycode = code
	u.pressed = false
	Input.parse_input_event(u)
	await frames(2)

func cast_for(n: int) -> void:
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_RIGHT
	d.pressed = true
	Input.parse_input_event(d)
	await frames(n)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_RIGHT
	u.pressed = false
	Input.parse_input_event(u)
	await frames(3)

func hold_weapon(w: String) -> void:
	var guard := 0
	while sb.current_weapon() != w and guard < 8:
		sb.cycle_weapon()
		guard += 1
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
	# Slot 1 is melee (Sword Basic), slot 2 ranged (Gun Basic), slot 3 utility.
	check(p.runners.size() >= 3, "the sandbox starts with the three sample skills")

	await hold_weapon("SWORD")
	check(p.can_cast(0), "a sword carries a melee skill")
	check(not p.can_cast(1), "a sword refuses a ranged skill")
	check(p.can_cast(2), "and still carries a pure-utility one")

	await hold_weapon("GUN")
	check(not p.can_cast(0), "a gun refuses a melee skill")
	check(p.can_cast(1), "a gun carries a ranged one")

	await hold_weapon("ROCK")
	check(p.can_cast(0) and p.can_cast(1), "a rock takes either")

	# The refusal has to hold when the button is actually pressed, not only in
	# the readout the HUD colours.
	await hold_weapon("SWORD")
	for i in p.runners.size():
		p.runners[i].fired.connect(func(_x: Payload) -> void: fired.append(i + 1))

	await tap_key(KEY_2)
	fired = []
	await cast_for(30)
	check(fired.is_empty(), "casting the refused slot fires nothing at all (%s)" % str(fired))
	check(Weapons.rejection_note("SWORD", p.runners[1].board) != "",
		"and there is a note to show for it: '%s'"
			% Weapons.rejection_note("SWORD", p.runners[1].board))

	await tap_key(KEY_1)
	fired = []
	await cast_for(30)
	check(fired.has(1), "the accepted slot still casts normally (%s)" % str(fired))

	# The weapon's own attack is never refused: it is the weapon's own board.
	fired = []
	# An array, because a lambda captures a local int by value.
	var basic := [0]
	p.basic_runner.fired.connect(func(_x: Payload) -> void: basic[0] += 1)
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	Input.parse_input_event(d)
	await frames(24)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	Input.parse_input_event(u)
	await frames(3)
	check(int(basic[0]) > 0,
		"the weapon's own attack is never refused (%d shots)" % basic[0])

	print("[FIT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
