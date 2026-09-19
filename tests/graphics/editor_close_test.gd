extends Node
## The editor has to close and STAY closed. It previously reopened in the same
## frame, because the screen that owns it polled the same keypress.

const GameScript := preload("res://app/game.gd")
var game: Node
var fails := 0

func say(s: String) -> void:
	print("[CLOSE] ", s)

func check(ok: bool, what: String) -> void:
	if ok:
		say("PASS " + what)
	else:
		fails += 1
		push_error("CLOSE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	get_viewport().push_input(e)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	get_viewport().push_input(up)
	await frames(3)

func click(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	get_viewport().push_input(m)
	await get_tree().process_frame
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		get_viewport().push_input(e)
		await get_tree().process_frame
	await frames(3)

func _ready() -> void:
	GameState.reset_profile()
	seed(7)
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)

	# --- raid ---------------------------------------------------------------
	var slots: Array = [0, 1, 2]
	game._deploy("SWORD", slots)
	await frames(10)
	var raid: Raid = game.current
	await key(KEY_TAB)
	check(raid.editing, "TAB opens the editor in a raid")
	await key(KEY_TAB)
	check(not raid.editing, "TAB closes it")
	await frames(10)
	check(not raid.editing and not Views.of(raid).editor.visible, "it stays closed after 10 frames")
	check(not raid.player.input_locked, "the player can move again")

	await key(KEY_TAB)
	check(raid.editing, "reopens on the next TAB")
	await key(KEY_ESCAPE)
	check(not raid.editing, "ESC closes it too")
	await frames(6)
	check(not raid.editing, "ESC-close is not undone")
	check(not game.get_tree().paused, "ESC that closed the editor did not also pause")

	await key(KEY_TAB)
	check(raid.editing, "open again for the close button")
	await click(Views.of(raid).editor._close_rect().get_center())
	check(not raid.editing, "the CLOSE button closes it")
	await frames(6)
	check(not raid.editing, "button-close is not undone")

	# ESC with no editor open should still reach the pause menu.
	await key(KEY_ESCAPE)
	check(game.get_tree().paused, "ESC still pauses when no editor is open")
	game._unpause()
	await frames(4)

	# --- sandbox ------------------------------------------------------------
	game.goto_sandbox()
	await frames(12)
	var sb: Sandbox = game.current
	await key(KEY_TAB)
	check(sb.editing, "TAB opens the editor in the sandbox")
	await key(KEY_TAB)
	check(not sb.editing, "TAB closes it")
	await frames(8)
	check(not sb.editing, "it stays closed")
	check(Views.of(sb).panel.visible, "the bench panel comes back")
	await key(KEY_TAB)
	await key(KEY_ESCAPE)
	check(not sb.editing, "ESC closes the sandbox editor")
	check(game.state == 3, "that ESC did not also leave the sandbox")

	# --- hideout workbench --------------------------------------------------
	game.goto_hideout()
	await frames(10)
	game._edit_library_skill(0)
	await frames(6)
	check(game.editor != null and is_instance_valid(game.editor), "workbench editor opened")
	await key(KEY_TAB)
	check(game.editor == null, "TAB closes the workbench editor")
	game._edit_library_skill(0)
	await frames(6)
	await key(KEY_ESCAPE)
	check(game.editor == null, "ESC closes the workbench editor")
	game._edit_library_skill(0)
	await frames(6)
	var ed: SkillEditor = game.editor
	await click(ed._close_rect().get_center())
	check(game.editor == null, "the CLOSE button closes the workbench editor")

	say("---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
