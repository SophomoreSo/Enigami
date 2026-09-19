extends Node
## Buttons layered over a running game must not hold the keyboard. A focused
## Button answers Godot's own `ui_accept` and `ui_focus_next`, which are the
## same SPACE and TAB the player jumps and opens assembly with — so clicking
## one used to cost them the next jump and the assembly screen.

const GameScript := preload("res://app/game.gd")

var game: Node
var sb: Sandbox
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[FOCUS] PASS ", what)
	else:
		fails += 1
		push_error("FOCUS FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func panel_buttons() -> Array:
	var out: Array = []
	var stack: Array = [Views.of(sb).panel]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out

func _ready() -> void:
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_sandbox()
	await frames(20)
	sb = game.current

	var btns := panel_buttons()
	print("[FOCUS] left panel has %d buttons" % btns.size())
	var focusable := 0
	for b in btns:
		if b.focus_mode != Control.FOCUS_NONE:
			focusable += 1
	check(focusable == 0, "no left-panel button can take the keyboard (%d of %d could)"
		% [focusable, btns.size()])

	# Click one the way a player does, then check the keys still reach the game.
	var spawn_btn: Button = null
	var spawn_label := Loc.t("hud.sandbox.spawn", [Monsters.name_for("CRAWLER")])
	for b in btns:
		if String(b.text) == spawn_label:
			spawn_btn = b
	check(spawn_btn != null, "found the '%s' button" % spawn_label)
	if spawn_btn == null:
		print("[FOCUS] ---- %d failures ----" % fails)
		get_tree().quit()
		return
	var before_enemies := 0
	for c in sb.get_children():
		if c is Enemy:
			before_enemies += 1
	spawn_btn.emit_signal("pressed")
	spawn_btn.grab_focus()      # the strongest form of what a click leaves behind
	await frames(3)
	var after_enemies := 0
	for c in sb.get_children():
		if c is Enemy:
			after_enemies += 1
	check(after_enemies > before_enemies, "the button still does its job when clicked")
	check(get_viewport().gui_get_focus_owner() == null,
		"and it holds no focus afterwards (owner=%s)" % str(get_viewport().gui_get_focus_owner()))

	# SPACE must jump, not re-press the button.
	sb.player.velocity = Vector2.ZERO
	var enemies_before_space := 0
	for c in sb.get_children():
		if c is Enemy:
			enemies_before_space += 1
	var guard := 0
	while not sb.player.is_on_floor() and guard < 400:
		await get_tree().physics_frame
		guard += 1
	# A raw SPACE, not the "jump" action: the real key drives both `jump` and
	# Godot's own `ui_accept`, and it is `ui_accept` that re-presses a focused
	# button. Pressing the action alone would never reproduce the bug.
	spawn_btn.grab_focus()
	await frames(2)
	var down := InputEventKey.new()
	down.keycode = KEY_SPACE
	down.physical_keycode = KEY_SPACE
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jumped := sb.player.velocity.y < -300.0
	var up := InputEventKey.new()
	up.keycode = KEY_SPACE
	up.physical_keycode = KEY_SPACE
	up.pressed = false
	Input.parse_input_event(up)
	await frames(3)
	var enemies_after_space := 0
	for c in sb.get_children():
		if c is Enemy:
			enemies_after_space += 1
	check(jumped, "SPACE jumps (vy=%.0f)" % sb.player.velocity.y)
	check(enemies_after_space == enemies_before_space,
		"and SPACE did not re-press the button (%d -> %d enemies)"
			% [enemies_before_space, enemies_after_space])

	# TAB must open assembly.
	spawn_btn.grab_focus()
	await frames(2)
	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.physical_keycode = KEY_TAB
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(4)
	check(sb.editing, "TAB opens assembly instead of moving button focus")

	# The pause menu is a menu: keyboard navigation there is wanted. What must
	# not happen is a button keeping the keyboard after the menu closes, which
	# would leave SPACE pressing an invisible RESUME instead of jumping.
	if sb.editing:
		sb.set_editing(false)
		await frames(4)
	game._pause()
	await frames(4)
	var pause_btn: Button = null
	var stack: Array = [game.pause_menu]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and pause_btn == null:
			pause_btn = n
		for c in n.get_children():
			stack.append(c)
	if pause_btn != null:
		pause_btn.grab_focus()
		await frames(2)
		check(get_viewport().gui_get_focus_owner() == pause_btn,
			"a pause-menu button can still be focused for keyboard navigation")
	game._unpause()
	await frames(4)
	check(get_viewport().gui_get_focus_owner() == null,
		"and closing the pause menu gives the keyboard back (owner=%s)"
			% str(get_viewport().gui_get_focus_owner()))

	print("[FOCUS] ---- %d failures ----" % fails)
	get_tree().quit()
