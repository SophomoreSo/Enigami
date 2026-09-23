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
## Checked with the console off, where the game takes the mouse on those two
## screens and draws the crosshair itself, and with it on, where the game never
## takes the mouse and the window's own pointer wears the crosshair instead.

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

## A screen the player aims on. With the console off the game has the mouse and
## draws the crosshair itself; with it on, the window's pointer is the crosshair.
func aiming(where: String) -> void:
	if Touch.wanted():
		check(Pointer.game_is_pointing() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
				and wearing_crosshair() and not Pointer._crosshair.visible,
			"%s: the window's own pointer is the crosshair" % where)
	else:
		check(Pointer.game_is_pointing() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
				and Pointer._crosshair.visible,
			"%s: the game has the mouse and draws the crosshair (mode %d)"
				% [where, Input.mouse_mode])

## A window: buttons, and the system's arrow to press them with.
func arrow(where: String) -> void:
	check(not Pointer.game_is_pointing() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"%s: the mouse is the system's (mode %d)" % [where, Input.mouse_mode])
	check(not wearing_crosshair() and not Pointer._crosshair.visible,
		"%s: and it is the system's own arrow, with no crosshair anywhere" % where)

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
	arrow("the bench")
	game._edit_library_skill(0)
	await frames(3)
	arrow("the workbench, opened at the bench")
	await key(KEY_ESCAPE)
	check(game.editor == null, "ESC puts the workbench away")
	arrow("the bench, with the workbench put away")
	hideout.close_panel()
	await frames(3)

	# The key that opens assembly in a raid opens it here too, over whatever is
	# armed. Nothing held the player still under it, so the game went on taking
	# the mouse for them.
	var slots := GameState.get_loadout(hideout.weapon_id)
	slots[0] = 0
	GameState.set_loadout(hideout.weapon_id, slots)
	hideout.set_weapon(hideout.weapon_id)
	await frames(3)
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
	game._deploy("SWORD", [0, 1, 2])
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

## The console on the glass never takes the mouse — a phone aims with its
## sticks — so it is the window's own pointer that has to change.
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
