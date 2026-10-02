extends Node
## Which pointer each screen gets.
##
## The crosshair is for aiming, so it is on the screens the player aims on —
## the battleground and the hideout floor — and on nothing else. Every window
## over them is buttons: the workbench, the settings, the weapon rack, the map,
## the pause menu. Those get the system's own arrow.
##
## The crosshair used to be handed to the window as its arrow at boot, so every
## menu in the game pointed with it. And the workbench opened by key from the
## hideout floor left the player holding the controls under it, so the game
## kept the mouse there: the crosshair went on wandering over the board.
##
## Checked with the console off, where the game hides the system pointer on
## those two screens and draws the crosshair itself, and with it on, where the
## game never hides it and the window's own pointer wears the crosshair instead.
##
## And a third case: the computer with the controls — somebody talking holds the
## player — where the crosshair stays, the computer's, and the system's arrow is
## shown beside it. The pause menu over that is a window like any other, and
## back out of it both are on the screen again.

const GameScript := preload("res://app/game.gd")

var fails := 0
var game: Node

func check(ok: bool, what: String) -> void:
	if ok:
		print("[CURSOR] PASS ", what)
	else:
		fails += 1
		push_error("CURSOR FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await frames(2)
	await frames(2)

func wearing_crosshair() -> bool:
	return Pointer._worn != null and Pointer._worn == Pointer._tex

## A screen the player aims on. With the console off the game hides the system
## pointer and draws the crosshair itself; with it on, the window's pointer is
## the crosshair.
func aiming(where: String) -> void:
	if Touch.wanted():
		check(Pointer.game_is_pointing() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
				and wearing_crosshair() and not Pointer._crosshair.visible,
			"%s: the window's own pointer is the crosshair" % where)
	else:
		check(Pointer.game_is_pointing() and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN
				and Pointer._crosshair.visible,
			"%s: the game hides the system pointer and draws the crosshair (mode %d)"
				% [where, Input.mouse_mode])

## A window: buttons, and the system's arrow to press them with.
func arrow(where: String) -> void:
	check(not Pointer.game_is_pointing() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"%s: the mouse is the system's (mode %d)" % [where, Input.mouse_mode])
	check(not wearing_crosshair() and not Pointer._crosshair.visible,
		"%s: and it is the system's own arrow, with no crosshair anywhere" % where)

## The computer has the controls: the crosshair is its, and the system's arrow is
## in sight beside it.
func both(where: String) -> void:
	check(Pointer.computer_is_pointing() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"%s: the computer has the pointing, and the system pointer is in sight (mode %d)"
			% [where, Input.mouse_mode])
	check(not wearing_crosshair() and Pointer._crosshair.visible,
		"%s: as the system's own arrow, beside the game's crosshair" % where)

func _ready() -> void:
	var was_mode := Touch.mode
	Touch.set_mode(Touch.OFF)
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	await _the_title()
	await _the_hideout()
	await _the_battleground()
	await _with_the_console()
	await _a_conversation()
	Touch.set_mode(was_mode)
	await frames(2)
	print("[CURSOR] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _the_title() -> void:
	arrow("the title")
	var title := game.current as TitleScreen
	title._toggle_settings()
	await frames(3)
	arrow("the title's settings")
	title._toggle_settings()
	await frames(2)

func _the_hideout() -> void:
	game.goto_hideout()
	await frames(10)
	var hideout := game.current as HideoutWorld
	aiming("the hideout floor")

	hideout.open_station("weapons")
	await frames(3)
	arrow("the weapon rack")
	hideout.close_panel()
	await frames(3)
	aiming("the floor, with the rack put away")

	hideout.open_station("bench")
	await frames(3)
	check(game.editor != null, "the bench opens the workbench itself")
	arrow("the workbench, opened at the bench")
	await key(KEY_ESCAPE)
	check(game.editor == null, "ESC puts the workbench away")
	aiming("the floor, with the workbench put away")

	# The key that opens assembly in a raid opens it here too, over the weapon's
	# graph. Nothing held the player still under it, so the game went on taking
	# the mouse for them.
	await key(KEY_TAB)
	check(game.editor != null, "TAB on the floor opens the workbench")
	arrow("the workbench, opened by key from the floor")
	check(hideout.player.controls_locked(), "and the player is held still under it")
	await key(KEY_TAB)
	check(game.editor == null, "TAB puts it away")
	aiming("the floor, with the workbench put away")
	check(not hideout.player.controls_locked(), "and the player is let go again")

	await key(KEY_ESCAPE)
	check(get_tree().paused, "ESC on the floor pauses")
	arrow("the pause menu")
	game._pause_general(true)
	await frames(3)
	arrow("the pause menu's settings")
	game._pause_general(false)
	await frames(2)
	await key(KEY_ESCAPE)
	check(not get_tree().paused, "ESC puts the pause menu away")
	aiming("the floor, unpaused")

func _the_battleground() -> void:
	game._deploy("SWORD")
	await frames(12)
	var raid := game.current as Raid
	aiming("the raid")
	await key(KEY_TAB)
	check(raid.editing, "TAB opens the raid's assembly board")
	arrow("the raid's assembly board")
	await key(KEY_TAB)
	aiming("the raid, with the board put away")
	await key(KEY_M)
	check(raid.reading_map, "M opens the map")
	arrow("the raid's map")
	await key(KEY_M)
	aiming("the raid, with the map put away")
	await key(KEY_ESCAPE)
	arrow("the raid, paused")
	await key(KEY_ESCAPE)
	aiming("the raid, unpaused")

## The console on the glass never hides the system pointer — a phone aims with
## its sticks — so it is the window's own pointer that has to change.
func _with_the_console() -> void:
	var raid := game.current as Raid
	Touch.set_mode(Touch.ON)
	await frames(3)
	aiming("the raid, with the console up")
	raid.set_editing(true)
	await frames(3)
	arrow("the raid's board, with the console up")
	raid.set_editing(false)
	await frames(3)
	aiming("the raid again, with the console up")
	# Held by the game on the console: the system pointer was never hidden, and
	# a phone has no crosshair to leave standing — it aims with its sticks.
	raid.player.talk_locked = true
	await frames(3)
	check(Pointer.computer_is_pointing() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
			and not wearing_crosshair() and not Pointer._crosshair.visible,
		"the player held, with the console up: the system's arrow, and no crosshair drawn")
	raid.player.talk_locked = false
	await frames(3)
	aiming("the raid once more, with the console up")

## Talking to the SAGE at the bench, with the console off: the game holds the
## player, so the computer has the pointing.
func _a_conversation() -> void:
	Touch.set_mode(Touch.OFF)
	game.goto_sandbox()
	await frames(12)
	var bench := game.current as Sandbox
	var guard := 0
	while not (bench.npc.is_on_floor() and bench.player.is_on_floor()) and guard < 600:
		await get_tree().physics_frame
		guard += 1
	aiming("the bench")
	bench.player.global_position = bench.npc.global_position + Vector2(-Npc.TALK_SPOT, 0.0)
	bench.player.velocity = Vector2.ZERO
	guard = 0
	while not bench.npc.in_range and guard < 120:
		await get_tree().physics_frame
		guard += 1
	Input.action_press("interact")
	guard = 0
	while not bench.npc.is_talking() and guard < 240:
		await get_tree().physics_frame
		guard += 1
	Input.action_release("interact")
	await frames(3)
	check(bench.npc.is_talking() and bench.player.talk_locked, "the SAGE is talking, and holds the player")
	both("a conversation")
	await key(KEY_ESCAPE)
	check(get_tree().paused, "ESC in a conversation pauses")
	arrow("the pause menu, over a conversation")
	await key(KEY_ESCAPE)
	check(not get_tree().paused and bench.npc.is_talking(), "ESC puts it away, with the conversation still going")
	both("the conversation again, unpaused")
	bench.npc.end_conversation()
	await frames(3)
	aiming("the bench, the conversation over")
