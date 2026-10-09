extends Node
## The editor has to close and STAY closed. It previously reopened in the same
## frame, because the screen that owns it polled the same keypress.
##
## And it and the map are one screen, a tab each along its top: the keys and
## the tabs put either page up in the other's place, and the map's back arrow
## puts the screen away like the board's. In a raid the map's page is the floor
## plan; on the bench and in the hideout it is there all the same, saying there
## is no map, and the map's key brings the screen up on it.

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

## The middle of `id`'s tab along the top of a screen with `pages` on it.
func tab_of(pages: Array, id: String) -> Vector2:
	return (ScreenTabs.tab_rects(pages, UiKit.mobile())[pages.find(id)] as Rect2).get_center()

func _ready() -> void:
	GameState.reset_profile()
	seed(7)
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)

	# --- raid ---------------------------------------------------------------
	game._deploy("SWORD")
	await frames(10)
	var raid: Raid = game.current
	await key(KEY_TAB)
	check(raid.editing, "TAB opens the editor in a raid")
	check(not Views.of(raid).hud.visible, "and the HUD is put away under it")
	await key(KEY_TAB)
	check(not raid.editing, "TAB closes it")
	check(Views.of(raid).hud.visible, "and the HUD comes back")
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
	check(not raid.editing, "the back arrow closes it")
	await frames(6)
	check(not raid.editing, "button-close is not undone")

	# --- the map window, which has the same hazard ---------------------------
	await key(KEY_M)
	check(raid.reading_map, "M opens the map in a raid")
	check(Views.of(raid).map_panel.visible, "and the window is on screen")
	check(not Views.of(raid).hud.visible, "the HUD is put away under it too")
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

	# The other way: M over the workbench puts the map up in its place. Then
	# the tabs along the top, and the map's own back arrow.
	await key(KEY_TAB)
	await key(KEY_M)
	check(raid.reading_map and not raid.editing, "M over the workbench swaps it for the map")
	check(raid.player.input_locked and not Views.of(raid).hud.visible,
		"the player still stands still, and the HUD stays away")
	var pages: Array = Views.of(raid).map_panel.pages
	await click(tab_of(pages, ScreenTabs.GRAPH))
	check(raid.editing and not raid.reading_map and Views.of(raid).editor.visible
			and not Views.of(raid).map_panel.visible,
		"a click on the GRAPH tab puts the board up in the map's place")
	await click(tab_of(pages, ScreenTabs.GRAPH))
	check(raid.editing and not raid.reading_map, "and another on it, the page that is up, does nothing")
	await click(tab_of(pages, ScreenTabs.MAP))
	check(raid.reading_map and not raid.editing and Views.of(raid).map_panel.visible
			and not Views.of(raid).editor.visible,
		"a click on the MAP tab puts the map up in the board's")
	await click(ScreenTabs.back_rect(UiKit.mobile()).get_center())
	check(not raid.reading_map and not raid.editing and not raid.player.input_locked,
		"the map's back arrow puts the screen away")
	check(Views.of(raid).hud.visible, "and the HUD comes back")
	await frames(6)
	check(not raid.reading_map and not raid.editing, "and it stays away")

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
	check(not Views.of(sb).hud.visible, "and the HUD is put away under it")
	await key(KEY_TAB)
	check(not sb.editing, "TAB closes it")
	await frames(8)
	check(not sb.editing, "it stays closed")
	check(Views.of(sb).panel.visible, "the bench panel comes back")
	check(Views.of(sb).hud.visible, "and the HUD with it")
	await key(KEY_TAB)
	await key(KEY_ESCAPE)
	check(not sb.editing, "ESC closes the sandbox editor")
	check(game.state == GameScript.State.SANDBOX, "that ESC did not also leave the sandbox")
	check(not game.get_tree().paused, "nor did it pause behind the editor")

	# The bench has no map, and the MAP tab is there all the same: its page
	# says so. The keys and the tabs go between the two as in a raid, the screen
	# staying up, and the map's key brings it up on its own page.
	var bench_pages: ScreenPages = Views.of(sb).pages
	await key(KEY_TAB)
	check(Views.of(sb).editor.pages.has(ScreenTabs.MAP), "the bench's board has the MAP tab on its top")
	await click(tab_of(Views.of(sb).editor.pages, ScreenTabs.MAP))
	check(sb.editing and bench_pages.map.visible and not Views.of(sb).editor.visible
			and bench_pages.map.map == null,
		"a click on it puts the map's page up, with no map on it, the screen still up")
	check(sb.player.input_locked and not Views.of(sb).hud.visible, "the player still held, the HUD still away")
	await key(KEY_TAB)
	check(sb.editing and Views.of(sb).editor.visible and not bench_pages.map.visible,
		"TAB on the map's page puts the board back")
	await key(KEY_M)
	check(sb.editing and bench_pages.map.visible, "M on the board puts the map's page up")
	await key(KEY_M)
	check(not sb.editing and not bench_pages.map.visible and not Views.of(sb).editor.visible,
		"M on the map's page puts the screen away")
	await key(KEY_M)
	check(sb.editing and bench_pages.map.visible and not Views.of(sb).editor.visible,
		"M on the bench puts the screen up on the map's page")
	await click(ScreenTabs.back_rect(UiKit.mobile()).get_center())
	check(not sb.editing and not bench_pages.map.visible and Views.of(sb).hud.visible,
		"its back arrow puts the screen away")
	await key(KEY_TAB)
	check(sb.editing and Views.of(sb).editor.visible, "and TAB brings it back on the board's page")
	await key(KEY_TAB)
	check(not sb.editing, "TAB on the board puts it away again")

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
	game._edit_weapon_graph()
	await frames(6)
	check(game.editor != null and is_instance_valid(game.editor), "workbench editor opened")
	check(not Views.of(game.hideout_ref).hud.visible, "and the HUD over the room is put away under it")
	await key(KEY_TAB)
	check(game.editor == null, "TAB closes the workbench editor")
	check(Views.of(game.hideout_ref).hud.visible, "and the HUD comes back")
	game._edit_weapon_graph()
	await frames(6)
	await key(KEY_ESCAPE)
	check(game.editor == null, "ESC closes the workbench editor")
	check(not game.get_tree().paused, "and does not pause the hideout behind it")
	game._edit_weapon_graph()
	await frames(6)
	var ed: SkillEditor = game.editor
	await click(ed._close_rect().get_center())
	check(game.editor == null, "the back arrow closes the workbench editor")

	# The hideout has no map either: M on its floor puts the workbench's screen
	# up on the map's page, which says so, and the GRAPH tab puts the board up.
	await frames(4)
	await key(KEY_M)
	check(game.editor != null and game.editor_pages != null and game.editor_pages.map.visible
			and not game.editor.visible and game.editor_pages.map.map == null,
		"M in the hideout puts the workbench's screen up on the map's page")
	await click(tab_of(game.editor.pages, ScreenTabs.GRAPH))
	check(game.editor != null and game.editor.visible and not game.editor_pages.map.visible,
		"the GRAPH tab puts the board up in its place")
	await key(KEY_M)
	await key(KEY_M)
	check(game.editor == null and game.editor_pages == null, "M twice: the map's page, then away")
	check(not game.get_tree().paused, "with nothing paused on the way")

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
