extends Node
## A conversation on the glass, read and answered with thumbs alone.
##
## While somebody talks the whole screen is the page, and it is not drawn: a
## tap anywhere brings the line coming in out whole and does nothing else, and
## a thumb held there goes on — once a landing, however long it stays.
##
## The box is mobile mode's: most of the width of the screen, its words twice
## the size, and each answer on a plate of its own under it. A plate is touched
## to pick its answer and held to give it, and a thumb on a plate is the
## plate's — it hurries nothing and holds nothing on.
##
## Played with the sandbox's SAGE, through the console's own `_input` and the
## box's, from the USE that opens the conversation to the hold that ends it —
## and with a thumb still down at either end, or resting on the glass through
## it, which does nothing to the face that comes up under it: the one that
## pressed USE does not hold the first line on, and the one that held the last
## answer does not press JUMP.

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

## The plate answer `i` is on, where it stands on the screen.
func plate(i: int) -> Rect2:
	var b := box()
	return b._plates[i] if b != null and i < b._plates.size() else Rect2()

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
	# A second thumb resting on the glass between the buttons, on nothing. The
	# page a conversation brings up is the whole screen, so it would be under it.
	var rest := Vector2(640, 300)
	touch(1, rest, true)
	await frames(2)
	check(not pad._down.has(1), "a thumb resting between the buttons is on no control")
	var use := spot("attack")
	touch(0, use, true)
	check(await until(func() -> bool: return npc.is_talking()), "and a thumb on USE opens the conversation")
	await frames(3)
	check(pad.face == TouchPad.Face.TALK, "which turns the whole screen into the page")
	drag(0, use + Vector2(-12.0, 6.0))
	drag(1, rest + Vector2(2.0, 1.0))
	await seconds(TouchPad.HOLD + 0.15)
	check(npc.node_id == "hello" and not npc.line_finished(),
		"the thumb that opened it, kept down, neither hurries the first line nor holds it on")
	check(not Input.is_action_pressed("hurry") and not Input.is_action_pressed("interact")
			and pad._holds.is_empty(),
		"and nor does the one that was resting: neither is holding anything down")
	touch(0, use, false)
	touch(1, rest, false)
	await frames(3)

## --- reading ------------------------------------------------------------------

## The page: a tap brings the line out and does nothing else; a hold goes on,
## once.
func _reading() -> void:
	var page := spot("hurry")
	var b := box()
	check(b != null and b.thumb(), "the box is laid out for a thumb")
	check(DialogueBox.HOLD == TouchPad.HOLD and DialogueBox.HOLD_SHOW == TouchPad.HOLD_SHOW,
		"and a hold on a plate is as long as a hold on the page")
	check(not npc.line_finished(), "the first line is still coming in")
	await tap(page)
	check(npc.node_id == "hello" and npc.line_finished(), "a tap brings the rest of it out")
	await tap(page)
	await tap(page)
	check(npc.node_id == "hello", "and taps on a line that is out move nothing on (%s)" % npc.node_id)

	touch(0, page, true)
	await frames(2)
	check(pad._holds.size() == 1 and not bool(pad._holds.values()[0]["fired"]),
		"a thumb staying down is counted as a hold")
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

## The plates: a touch picks, a hold gives, and neither is the page's. Then the
## hold that gives the last answer ends the conversation under the thumb, which,
## kept down and dragged over JUMP, presses nothing on the face that comes back.
func _answering() -> void:
	check(await until(func() -> bool: return npc.is_choosing()) and npc.choices().size() == 4,
		"the question is out, with four answers")
	await frames(2)
	var b := box()
	check(b._plates.size() == 4, "each on a plate of its own (%d)" % b._plates.size())
	var on_screen := Rect2(Vector2.ZERO, screen())
	var sound := true
	for i in b._plates.size():
		var r := plate(i)
		sound = sound and on_screen.encloses(r) and r.size.y >= DialogueBox.PLATE \
			and r.size.x >= screen().x * 0.6
		if i > 0:
			sound = sound and r.position.y >= plate(i - 1).end.y
	check(sound, "every one on the screen, a thumb tall, most of its width, and none on another")
	check(b._choice_hint() == Loc.t("hud.dialogue.choose_touch"),
		"under them the box says to tap and to hold, not which key to press ('%s')" % b._choice_hint())

	# A touch picks, wherever the highlight was, and gives nothing.
	await tap(plate(1).get_center())
	check(npc.selected == 1 and npc.node_id == "ask" and npc.is_choosing(),
		"a tap on a plate picks its answer, and gives nothing (%d)" % npc.selected)
	await tap(plate(3).get_center())
	check(npc.selected == 3, "a tap on another picks that one (%d)" % npc.selected)
	await tap(plate(0).get_center())
	await tap(plate(0).get_center())
	check(npc.selected == 0 and npc.node_id == "ask", "and tapped twice it is still only picked")
	check(not Input.is_action_pressed("hurry") and not Input.is_action_pressed("interact")
			and pad._holds.is_empty(),
		"a thumb on a plate is not on the page: it hurries nothing and holds nothing on")

	# The page goes on with whatever is picked, as it does on a line.
	await tap(plate(2).get_center())
	await tap(Vector2(40, 660))
	check(npc.selected == 2 and npc.node_id == "ask", "a tap off the plates picks nothing and gives nothing")
	await held(Vector2(40, 660))
	check(npc.node_id == "who", "a hold on the page gives the answer picked (%s)" % npc.node_id)
	touch(0, Vector2(40, 660), false)
	await frames(3)

	# 'Who are you?' asks a question of its own: its second answer goes back.
	check(await until(func() -> bool: return npc.is_choosing()) and npc.choices().size() == 2,
		"the next question is out, with two")
	await frames(2)
	check(b._plates.size() == 2, "on two plates")
	# A thumb that slides off its plate has not held it.
	var first := plate(0).get_center()
	touch(0, first, true)
	await frames(3)
	check(not b._press.is_empty(), "a thumb down on a plate starts its hold")
	drag(0, Vector2(40, 660))
	await seconds(TouchPad.HOLD + 0.15)
	check(npc.node_id == "who" and b._press.is_empty(), "slid off the plate, the hold is off")
	check(not Input.is_action_pressed("hurry") and pad._holds.is_empty(),
		"and the thumb is still not the page's, where it would be a hold that goes on")
	touch(0, Vector2(40, 660), false)
	await frames(3)
	# Held where it landed, the plate gives its answer — once it has been held.
	var back := plate(1).get_center()
	touch(0, back, true)
	await seconds(TouchPad.HOLD * 0.5)
	check(npc.node_id == "who" and npc.selected == 1, "half a hold on a plate picks it and has not given it")
	await seconds(TouchPad.HOLD * 0.5 + 0.15)
	await frames(2)
	check(npc.node_id == "ask", "held, the plate gives its answer (%s)" % npc.node_id)
	touch(0, back, false)
	await frames(3)

	# The last answer, 'Nothing. Bye.', ends it on the spot.
	check(await until(func() -> bool: return npc.is_choosing()), "back at the first question")
	await frames(2)
	touch(0, plate(3).get_center(), true)
	await seconds(TouchPad.HOLD + 0.15)
	await frames(2)
	check(not npc.is_talking(), "held, the last plate gives its answer — this one ending the conversation")
	await frames(3)
	check(pad.face == TouchPad.Face.PLAY, "and the console is the whole of it again")
	var jump := spot("jump")
	drag(0, jump)
	await frames(3)
	check(not Input.is_action_pressed("jump") and not Input.is_action_pressed("interact"),
		"the thumb that held it, dragged over JUMP, presses nothing")
	touch(0, jump, false)
	await frames(3)
	touch(0, jump, true)
	await frames(2)
	check(Input.is_action_pressed("jump"), "until it has lifted and come down again")
	touch(0, jump, false)
	await frames(3)
