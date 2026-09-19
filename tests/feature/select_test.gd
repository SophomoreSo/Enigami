extends Node
## Arming and casting are separate gestures: a number key only arms a slot, the
## attack button runs the weapon's own board, and the cast button runs whatever
## is armed and nothing else.

const GameScript := preload("res://app/game.gd")
var game: Node
var sb: Sandbox
var fired: Array = []
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SEL] PASS ", what)
	else:
		fails += 1
		push_error("SEL FAIL: " + what)

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

func hold_mouse(btn: int, n: int) -> void:
	var d := InputEventMouseButton.new()
	d.button_index = btn
	d.pressed = true
	Input.parse_input_event(d)
	await frames(n)
	var u := InputEventMouseButton.new()
	u.button_index = btn
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
	for i in p.runners.size():
		p.runners[i].fired.connect(func(_x: Payload) -> void: fired.append("slot %d" % (i + 1)))
	p.basic_runner.fired.connect(func(_x: Payload) -> void: fired.append("weapon"))
	check(p.selected_slot == 0, "slot 1 is armed to begin with")
	check(p.basic_runner != null, "the weapon brings its own attack, outside the loadout")

	for pair in [[2, KEY_2], [3, KEY_3], [1, KEY_1]]:
		fired = []
		await tap_key(int(pair[1]))
		check(p.selected_slot == int(pair[0]) - 1,
			"pressing %d arms slot %d" % [pair[0], pair[0]])
		check(fired.is_empty(), "and arming on its own fires nothing (%s)" % str(fired))

	fired = []
	await hold_mouse(MOUSE_BUTTON_LEFT, 20)
	check(fired.has("weapon"), "the attack button runs the weapon's own board (%s)" % str(fired))
	check(not fired.has("slot 1"), "and not the armed slot")

	# Only slots the weapon will carry — a refused one firing nothing is the
	# weapon rule, which weapon_fit_test covers.
	var cast_any := 0
	for i in p.runners.size():
		if not p.can_cast(i):
			continue
		await tap_key([KEY_1, KEY_2, KEY_3, KEY_4][i])
		fired = []
		await hold_mouse(MOUSE_BUTTON_RIGHT, 26)
		var want := "slot %d" % (i + 1)
		check(fired.has(want), "the cast button runs the armed slot (%s)" % str(fired))
		check(not fired.has("weapon"), "and not the weapon attack")
		var others := 0
		for f in fired:
			if f != want:
				others += 1
		check(others == 0, "and nothing else (%d strays)" % others)
		cast_any += 1
	check(cast_any > 0, "at least one slot was castable to test with")

	await tap_key(KEY_1)
	await tap_key(KEY_4)
	check(p.selected_slot == 0,
		"a number past the last slot is ignored, not clamped (armed %d of %d)"
			% [p.selected_slot + 1, p.runners.size()])

	print("[SEL] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
