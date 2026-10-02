extends Node
## A conversation on the glass, read and answered with thumbs alone.
##
## While somebody talks the screen is two halves, and neither is drawn. The
## right reads: a tap brings the line coming in out whole and does nothing
## else, and a thumb held there goes on — once a landing, however long it stays.
## The left picks: a tap on its top half moves the answer up, on its bottom half
## down, and a thumb keeps the half it landed on.
##
## Played with the sandbox's SAGE, through the console's own `_input`, from the
## USE that opens the conversation to the hold that ends it — and with a thumb
## still down at either end, which does nothing to the face that comes up under
## it: the one that pressed USE does not hold the first line on, and the one
## that held the last answer does not press JUMP.

const GameScript := preload("res://app/game.gd")

var fails := 0
var game: Node
var pad: TouchPad
var npc: Npc
var player: Player

func check(ok: bool, what: String) -> void:
	if ok:
		print("[TALK] PASS ", what)
	else:
		fails += 1
		push_error("TALK FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout

func until(cond: Callable, most: int = 600) -> bool:
	for i in most:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

## A point in the 1280x720 the game is drawn at, where it lands on the window.
func on_glass(at: Vector2) -> Vector2:
	return get_window().get_final_transform() * at

## A finger landing, moving or lifting, sent the way the system sends one.
func touch(index: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = on_glass(at)
	e.pressed = pressed
	Input.parse_input_event(e)

func drag(index: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = on_glass(at)
	Input.parse_input_event(e)

## Down and straight back up, well inside a hold.
func tap(at: Vector2) -> void:
	touch(0, at, true)
	await frames(2)
	touch(0, at, false)
	await frames(3)

## Down, and kept there past a hold.
func held(at: Vector2) -> void:
	touch(0, at, true)
	await seconds(TouchPad.HOLD + 0.15)
	await frames(2)

func screen() -> Vector2:
	return get_viewport().get_visible_rect().size

## The middle of whichever control on the face that is up presses `action`.
func spot(action: String) -> Vector2:
	for c in TouchPad.CONTROLS:
		if pad.shown(c) and String(c.get("action", "")) == action:
			return TouchPad.area(TouchPad.placed(c, TouchPad.layout()), screen()).get_center()
	return Vector2(-1, -1)

## The box the conversation is drawn in, wherever the SAGE's view keeps it.
func box() -> DialogueBox:
	var stack: Array = [npc]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is DialogueBox:
			return n
		stack.append_array(n.get_children())
	return null

func _ready() -> void:
	var was_mode := Touch.mode
	var was_size := DisplayServer.window_get_size()
	# Not 1:1. A press sent at a design position proves nothing on the one
	# window where a design position and a window position are the same number.
	DisplayServer.window_set_size(Vector2i(1440, 810))
	Touch.set_mode(Touch.ON)
	TouchPad.set_layout({}, false)
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	pad = game.touch_pad
	game.goto_sandbox()
	await frames(12)
	var sandbox := game.current as Sandbox
	npc = sandbox.npc
	player = sandbox.player
	await _opening()
	await _reading()
	await _answering()
	Touch.set_mode(was_mode)
	DisplayServer.window_set_size(was_size)
	print("[TALK] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- opening ------------------------------------------------------------------

## USE opens it, and the thumb that pressed USE is still down as it does. Kept
## there and dragged, it neither hurries the first line nor holds it on.
func _opening() -> void:
	await until(func() -> bool: return npc.is_on_floor())
	# Where people stand to talk, so the press opens it at once.
	player.global_position = npc.global_position + Vector2(-Npc.TALK_SPOT, 0.0)
	player.velocity = Vector2.ZERO
	check(await until(func() -> bool: return pad.use_near), "by the SAGE, the weapon's button is USE")
	var use := spot("attack")
	touch(0, use, true)
	check(await until(func() -> bool: return npc.is_talking()), "and a thumb on it opens the conversation")
	await frames(3)
	check(pad.face == TouchPad.Face.TALK, "which turns the console into the two halves of the screen")
	drag(0, use + Vector2(-12.0, 6.0))
	await seconds(TouchPad.HOLD + 0.15)
	check(npc.node_id == "hello" and not npc.line_finished(),
		"the thumb that opened it, kept down, neither hurries the first line nor holds it on")
	check(not Input.is_action_pressed("hurry") and not Input.is_action_pressed("interact"),
		"and is holding nothing down")
	touch(0, use, false)
	await frames(3)

## --- reading ------------------------------------------------------------------

## The right of the screen: a tap brings the line out and does nothing else; a
## hold goes on, once.
func _reading() -> void:
	var page := spot("hurry")
	check(not npc.line_finished(), "the first line is still coming in")
	await tap(page)
	check(npc.node_id == "hello" and npc.line_finished(), "a tap on the right brings the rest of it out")
	await tap(page)
	await tap(page)
	check(npc.node_id == "hello", "and taps on a line that is out move nothing on (%s)" % npc.node_id)

	touch(0, page, true)
	await frames(2)
	check(pad._holds.size() == 1 and not bool(pad._holds.values()[0]["fired"]),
		"a thumb staying on the right is counted as a hold")
	await seconds(TouchPad.HOLD + 0.15)
	await frames(2)
	check(npc.node_id == "ask", "held there, it goes on to the next line (%s)" % npc.node_id)
	await seconds(TouchPad.HOLD + 0.15)
	check(npc.node_id == "ask", "and staying down does not go on again (%s)" % npc.node_id)
	touch(0, page, false)
	await frames(3)
	check(not Input.is_action_pressed("interact") and not Input.is_action_pressed("hurry")
			and pad._holds.is_empty(),
		"lifted, it lets go of both")

## --- answering ----------------------------------------------------------------

## The left of the screen: up and down, a tap a step, each half keeping the
## thumb that landed on it. Then the hold that gives the answer ends the
## conversation under the thumb, which, kept down and dragged over JUMP,
## presses nothing on the face that comes back.
func _answering() -> void:
	check(await until(func() -> bool: return npc.is_choosing()) and npc.choices().size() == 4,
		"the question is out, with four answers")
	var hint := box()._choice_hint() if box() != null else ""
	check(hint == Loc.t("hud.dialogue.choose_touch"),
		"the box says to tap the left and hold the right, not which key to press ('%s')" % hint)
	var up := spot("move_up")
	var down := spot("move_down")
	await tap(down)
	check(npc.selected == 1, "a tap on the bottom of the left moves the answer down (%d)" % npc.selected)
	await tap(up)
	check(npc.selected == 0, "one on the top moves it up (%d)" % npc.selected)
	await tap(up)
	check(npc.selected == 3, "and up past the first comes round to the last (%d)" % npc.selected)
	touch(0, up, true)
	await frames(2)
	drag(0, down)
	await frames(2)
	touch(0, down, false)
	await frames(3)
	check(npc.selected == 2,
		"a tap that strays onto the other half is still the half it landed on (%d)" % npc.selected)
	await tap(down)
	check(npc.selected == 3 and npc.is_talking(), "and the left never answers (%d)" % npc.selected)

	# The last answer, 'Nothing. Bye.', ends it on the spot.
	await held(spot("hurry"))
	check(not npc.is_talking(), "held on an answer, the right gives it — this one ending the conversation")
	await frames(3)
	check(pad.face == TouchPad.Face.PLAY, "and the console is the whole of it again")
	var jump := spot("jump")
	drag(0, jump)
	await frames(3)
	check(not Input.is_action_pressed("jump") and not Input.is_action_pressed("interact"),
		"the thumb that held it on, dragged over JUMP, presses nothing")
	touch(0, jump, false)
	await frames(3)
	touch(0, jump, true)
	await frames(2)
	check(Input.is_action_pressed("jump"), "until it has lifted and come down again")
	touch(0, jump, false)
	await frames(3)
