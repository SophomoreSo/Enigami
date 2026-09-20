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

	# --- the map window, which has the same hazard ---------------------------
	await key(KEY_M)
	check(raid.reading_map, "M opens the map in a raid")
	check(Views.of(raid).map_panel.visible, "and the window is on screen")
	check(raid.player.input_locked, "the player stands still while reading it")
	await key(KEY_M)
	check(not raid.reading_map, "M closes it")
	await frames(10)
	check(not raid.reading_map and not Views.of(raid).map_panel.visible,
		"it stays closed after 10 frames")
	check(not raid.player.input_locked, "and the player can move again")

	await key(KEY_M)
	check(raid.reading_map, "reopens on the next M")
	await key(KEY_ESCAPE)
	check(not raid.reading_map, "ESC closes it too")
	check(not game.get_tree().paused, "ESC that closed the map did not also pause")

	# One pair of hands: the workbench takes the map's place rather than opening
	# behind it, and closing the workbench leaves nothing holding the controls.
	await key(KEY_M)
	await key(KEY_TAB)
	check(raid.editing and not raid.reading_map, "TAB over the map swaps it for the workbench")
	await key(KEY_TAB)
	check(not raid.editing and not raid.player.input_locked,
		"and closing the workbench hands the controls back")

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
	check(game.state == GameScript.State.SANDBOX, "that ESC did not also leave the sandbox")
	check(not game.get_tree().paused, "nor did it pause behind the editor")

	# ESC with nothing open pauses the bench. It used to walk out of it, which
	# put the player in the hideout for pressing a key that should have stopped
	# the game for a moment.
	await key(KEY_ESCAPE)
	check(game.get_tree().paused, "ESC on the bench pauses it")
	check(game.state == GameScript.State.SANDBOX, "and leaves the bench standing")
	check(game.pause_title.visible and not game.pause_abandon.visible,
		"the way out on offer is the one that costs nothing")
	await key(KEY_ESCAPE)
	check(not game.get_tree().paused, "and ESC again puts it away")

	# The way out that the pause menu does offer.
	await key(KEY_ESCAPE)
	game.pause_title.emit_signal("pressed")
	await frames(10)
	check(not game.get_tree().paused, "leaving the bench unpauses")
	check(game.state == GameScript.State.TITLE,
		"and hands back to the title it was opened from (state=%d)" % game.state)

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
	check(not game.get_tree().paused, "and does not pause the hideout behind it")
	game._edit_library_skill(0)
	await frames(6)
	var ed: SkillEditor = game.editor
	await click(ed._close_rect().get_center())
	check(game.editor == null, "the CLOSE button closes the workbench editor")

	# --- the hideout pauses too ----------------------------------------------
	# It is a menu, but it is the one the player stands in between raids, and
	# the volume and the rebinding list are behind this key everywhere else.
	await frames(6)
	await key(KEY_ESCAPE)
	check(game.get_tree().paused, "ESC in the hideout pauses it")
	check(game.state == GameScript.State.HIDEOUT, "and leaves the hideout standing")
	check(game.pause_title.visible, "the way out on offer is the one to the title")
	check(not game.pause_abandon.visible, "and it is the only one on offer")
	await key(KEY_ESCAPE)
	check(not game.get_tree().paused, "ESC again puts it away")
	check(game.state == GameScript.State.HIDEOUT, "with the hideout still there")

	# The way out that menu does offer, which costs nothing: the vault keeps
	# everything the hideout holds.
	await key(KEY_ESCAPE)
	game.pause_title.emit_signal("pressed")
	await frames(10)
	check(not game.get_tree().paused, "leaving the hideout unpauses")
	check(game.state == GameScript.State.TITLE,
		"and hands back to the title (state=%d)" % game.state)

	say("---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
