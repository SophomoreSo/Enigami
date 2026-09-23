extends Node
## The bench's screen: the raid's own HUD, and the drawer the bench's tools
## slide out of.
##
## The tools used to be a column of buttons down the left of the screen that
## nothing could press. The game has the mouse while the player aims, and a
## captured mouse clicks where the pointer was parked rather than where the
## crosshair is; and the console on the glass takes a press anywhere on the left
## of the screen for its movement stick. So what is checked here is that every
## way of pressing gets there: the crosshair, a free mouse, the console played
## with a mouse on a desk, and a thumb.

const GameScript := preload("res://app/game.gd")

var fails := 0
var game: Node
var bench: Sandbox
var panel: SandboxPanel

func check(ok: bool, what: String) -> void:
	if ok:
		print("[DRAWER] PASS ", what)
	else:
		fails += 1
		push_error("DRAWER FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func on_glass(at: Vector2) -> Vector2:
	return get_window().get_final_transform() * at

func press(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = on_glass(at)
	e.global_position = e.position
	Input.parse_input_event(e)

func click(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = on_glass(at)
	m.global_position = m.position
	Input.parse_input_event(m)
	await frames(2)
	press(at, true)
	await frames(2)
	press(at, false)
	await frames(3)

func tap(at: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = on_glass(at)
		e.pressed = down
		Input.parse_input_event(e)
		await frames(2)
	await frames(3)

func key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await frames(2)
	await frames(2)

## Long enough for the slide to finish, by the clock: a test window runs at
## whatever rate it likes, so a count of frames is no measure of it.
func settle() -> void:
	await get_tree().create_timer(SandboxPanel.SLIDE + 0.15).timeout
	await frames(2)

func enemies() -> int:
	return bench.get_children().filter(func(c: Node) -> bool: return c is Enemy).size()

func spawn_button() -> Button:
	for b in panel._grid.get_children():
		if (b as Button).text == Loc.t("hud.sandbox.spawn", [Monsters.name_for("CRAWLER")]):
			return b
	return null

func tab() -> Vector2:
	return panel.tab_rect().get_center()

func aiming() -> bool:
	return Pointer.game_is_pointing() and not bench.player.input_locked

func _ready() -> void:
	var was_mode := Touch.mode
	var was_size := DisplayServer.window_get_size()
	# Not 1:1, where a design position and a window position are the same
	# number and a press sent to the wrong one lands anyway.
	DisplayServer.window_set_size(Vector2i(1440, 810))
	Touch.set_mode(Touch.OFF)
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_sandbox()
	await frames(20)
	bench = game.current as Sandbox
	panel = Views.of(bench).panel
	await _the_screen()
	await _with_the_crosshair()
	await _with_a_free_mouse()
	await _over_the_workbench()
	await _with_the_console()
	await _with_a_thumb()
	Touch.set_mode(was_mode)
	DisplayServer.window_set_size(was_size)
	print("[DRAWER] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _the_screen() -> void:
	var hud: Hud = Views.of(bench).hud
	check(hud != null and hud.visible and hud.player == bench.player,
		"the bench wears the raid's own HUD, over its player")
	check(not panel.is_out() and panel.drawer_rect().end.x <= 0.0,
		"the drawer starts in, all of it off the left edge (%s)" % str(panel.drawer_rect()))
	var t := panel.tab_rect()
	check(t.position.x <= 0.0 and t.end.x >= SandboxPanel.TAB.x - PixelDraw.PX,
		"with its tab left on the screen at the edge (%s)" % str(t))
	check(aiming() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"and the player aiming, with the game holding the mouse")

## The game has the mouse while the player aims, so the press is wherever the
## crosshair is — not wherever the parked pointer is, which is where the click
## itself says it happened.
func _with_the_crosshair() -> void:
	Pointer.point = tab()
	var parked := Vector2(900, 400)
	press(parked, true)
	await frames(2)
	check(panel.is_out(), "a click with the crosshair on the tab pulls the drawer out")
	check(bench.player.input_locked, "the player is held still while it is out")
	check(bench.player.basic_runner == null or not bench.player.basic_runner.active,
		"so the click that pulled it does not swing the weapon")
	press(parked, false)
	await settle()
	check(panel.drawer_rect().position.x == 0.0, "it slides all the way out (%s)" % str(panel.drawer_rect()))
	check(not Pointer.game_is_pointing() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
			and Pointer._worn == null,
		"and the mouse is handed back as the system's own arrow, to press its buttons with")

func _with_a_free_mouse() -> void:
	var spawn := spawn_button()
	check(spawn != null and spawn.is_visible_in_tree(), "the drawer carries a button per monster")
	if spawn == null:
		return
	var before := enemies()
	await click(spawn.get_global_rect().get_center())
	check(enemies() == before + 1, "SPAWN CRAWLER spawns one (%d -> %d)" % [before, enemies()])
	await click(tab())
	check(not panel.is_out(), "a click on the tab pushes the drawer back in")
	await settle()
	check(panel.drawer_rect().end.x <= 0.0 and spawn.get_global_rect().end.x <= 0.0,
		"all the way off the edge, buttons and all")
	check(aiming(), "and the player has the controls again")

	# ESC closes it the way it closes every other window, before it would pause.
	panel.set_out(true)
	await settle()
	await key(KEY_ESCAPE)
	check(not panel.is_out() and not get_tree().paused, "ESC puts the drawer away rather than pausing")
	await key(KEY_ESCAPE)
	check(get_tree().paused, "and ESC with it away pauses the bench")
	game._unpause()
	await frames(3)

## The workbench takes the screen from the drawer and hands it back as it was.
func _over_the_workbench() -> void:
	panel.set_out(true)
	await settle()
	await key(KEY_TAB)
	check(bench.editing and not panel.is_visible_in_tree(), "TAB raises the workbench, and the drawer goes")
	await key(KEY_TAB)
	check(not bench.editing and panel.is_visible_in_tree() and panel.is_out(),
		"closing it brings the drawer back out")
	check(bench.player.input_locked, "with the player still held for it")
	panel.set_out(false)
	await settle()
	check(aiming(), "until it goes in")

## The console reads a press on the left of the screen as its movement stick,
## ahead of every Control. Played with a mouse, on a desk.
func _with_the_console() -> void:
	Touch.set_mode(Touch.ON)
	await frames(4)
	var pad: TouchPad = game.touch_pad
	check(pad.visible and pad.face == TouchPad.Face.PLAY, "with the console up and the player playing")
	# Pressed and dragged, the way a thumb meaning the stick would be: the stick
	# only comes out for a thumb that moves.
	var at := tab()
	press(at, true)
	await frames(2)
	var m := InputEventMouseMotion.new()
	m.position = on_glass(at + Vector2(30, 0))
	m.global_position = m.position
	Input.parse_input_event(m)
	await frames(2)
	check(panel.is_out(), "a press on the tab pulls the drawer out")
	check(not pad.stick_showing(), "rather than growing the movement stick under it")
	press(at + Vector2(30, 0), false)
	await frames(3)
	await settle()
	check(pad.face == TouchPad.Face.SCREEN, "and the console steps back to its screen keys")
	var before := enemies()
	await click(spawn_button().get_global_rect().get_center())
	check(enemies() == before + 1, "so its buttons press (%d -> %d)" % [before, enemies()])
	await click(tab())
	check(not panel.is_out(), "and its tab puts it away again")
	await settle()

## A thumb: the system hands it over as a click first and as itself after, and
## the drawer answers once, not twice.
func _with_a_thumb() -> void:
	await tap(tab())
	check(panel.is_out(), "a thumb on the tab pulls the drawer out, once")
	await settle()
	var before := enemies()
	await tap(spawn_button().get_global_rect().get_center())
	check(enemies() == before + 1, "a thumb on SPAWN CRAWLER spawns one (%d -> %d)" % [before, enemies()])
	await tap(tab())
	check(not panel.is_out(), "and a thumb on the tab puts it away")
	await settle()
	check(aiming(), "handing the player back the controls")
