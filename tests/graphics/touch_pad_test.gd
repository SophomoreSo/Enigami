extends Node
## The console the game draws on the glass, and the setting that puts it there.
##
## Three things are checked, and the first is the one a phone cannot recover
## from: **where the keys sit**. The HUD owns the top-left corner and the whole
## bottom of the screen, and a key standing on either of them is a key that
## covers the health bar or the slot cards for as long as the game is played.
## So every key is measured against those bands, against every other key, and
## against its own label in both languages — a word wider than the key it is
## written on comes back with an ellipsis through it.
##
## Then **what a thumb does**: a touch presses the action a keyboard would, a
## lift releases it, a finger sliding off one key and onto the next swaps them,
## two fingers hold two keys, and the pad leaving the screen lets go of
## everything. The pad aims as a stick, so a shot goes where the cross is
## pointing and forwards when it is not.
##
## And **what it costs the rest of the game**: while the pad is up the mouse is
## in its drawer, because the system turns every touch into a click and `attack`
## is bound to one — a thumb on the movement keys would swing the weapon. The
## bindings still read and still save while they are in there, and they are back
## in the InputMap the moment the pad goes.

const GameScript := preload("res://app/game.gd")

## The two bands the HUD keeps, out of `graphics/ui/hud.gd`: the bars and the
## weapon down the top-left corner, and the slot cards with the hint line over
## them and the footer under them across the bottom.
const HUD_BARS := Rect2(24, 24, 264, 88)
const HUD_CARDS := Rect2(0, 592, 1280, 128)

var fails := 0
var pad: TouchPad
var layer: CanvasLayer
var was_mode: int

func check(ok: bool, what: String) -> void:
	if ok:
		print("[TOUCH] PASS ", what)
	else:
		fails += 1
		push_error("TOUCH FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Every Control under `root`, scrollbars included.
func controls_under(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			out.append(n)
		for c in n.get_children(true):
			stack.append(c)
	return out

func button_named(root: Node, text: String) -> Button:
	for c in controls_under(root):
		if c is Button and (c as Button).text == text:
			return c
	return null

func key_of(action: String) -> Dictionary:
	for k in TouchPad.KEYS:
		if String(k["action"]) == action:
			return k
	return {}

func middle_of(action: String) -> Vector2:
	return (key_of(action)["rect"] as Rect2).get_center()

## A finger landing, moving or lifting, sent the way the system sends one so the
## pad answers through its own `_input` rather than through a back door.
##
## `at` is where it lands in the 1280x720 the game is drawn at, and is put back
## into the window's own coordinates on the way in — a finger touches glass, not
## a design, and the engine is what turns one into the other. Sending the design
## position straight in would only pass on a window that happens to be 1:1.
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

func on_glass(at: Vector2) -> Vector2:
	return get_window().get_final_transform() * at

func _ready() -> void:
	was_mode = Touch.mode
	await _layout()
	await _the_setting()
	await _thumbs()
	await _the_drawer()
	Touch.set_mode(was_mode)
	print("[TOUCH] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- where the keys sit -----------------------------------------------------

func _layout() -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var off: Array = []
	var on_hud: Array = []
	for k in TouchPad.KEYS:
		var r: Rect2 = k["rect"]
		if not screen.encloses(r):
			off.append(String(k["action"]))
		if r.intersects(HUD_BARS) or r.intersects(HUD_CARDS):
			on_hud.append(String(k["action"]))
	check(off.is_empty(), "every key is on the screen (off: %s)" % str(off))
	check(on_hud.is_empty(),
		"and none of them stands on the health bars or the slot cards (on: %s)" % str(on_hud))

	# Grown by the slop each one answers to, so two keys never argue over a
	# thumb on the gap between them.
	var overlap: Array = []
	for i in TouchPad.KEYS.size():
		for j in range(i + 1, TouchPad.KEYS.size()):
			var a := (TouchPad.KEYS[i]["rect"] as Rect2).grow(TouchPad.SLOP)
			var b := (TouchPad.KEYS[j]["rect"] as Rect2).grow(TouchPad.SLOP)
			if a.intersects(b):
				overlap.append("%s/%s" % [TouchPad.KEYS[i]["action"], TouchPad.KEYS[j]["action"]])
	check(overlap.is_empty(), "no two keys overlap, slop and all (%s)" % str(overlap))

	# A key too small for a thumb is a key that gets missed. 44 is the smallest
	# anybody recommends and the smallest here.
	var small: Array = []
	for k in TouchPad.KEYS:
		var r: Rect2 = k["rect"]
		if r.size.x < 44.0 or r.size.y < 44.0:
			small.append("%s %s" % [k["action"], str(r.size)])
	check(small.is_empty(), "every key is at least 44 across (%s)" % str(small))

	# Every action the pad claims to press is one the game has, and the actions
	# a player cannot do without are all on it.
	var unknown: Array = []
	for k in TouchPad.KEYS:
		if not InputMap.has_action(String(k["action"])):
			unknown.append(String(k["action"]))
	check(unknown.is_empty(), "every key presses an action the game has (%s)" % str(unknown))
	var missing: Array = []
	for entry in Controls.ACTIONS:
		if key_of(String(entry[0])).is_empty():
			missing.append(String(entry[0]))
	check(missing.is_empty(),
		"and every action on the rebinding screen has a key (%s)" % str(missing))

	# The words, in each language. Silkscreen is proportional and Hangul is
	# drawn from a face of its own at its own size, so a word that fits in
	# English says nothing about the same word in Korean.
	var was_language := Loc.language
	for lang in Loc.languages():
		Loc.set_language(lang)
		await frames(2)
		var clipped: Array = []
		for k in TouchPad.KEYS:
			var label := TouchPad.label_of(k)
			if label == "":
				continue
			if PixelDraw.clip(label, (k["rect"] as Rect2).size.x) != label:
				clipped.append("%s '%s' (%.0f of %.0f)" % [k["action"], label,
					PixelDraw.text_width(label), (k["rect"] as Rect2).size.x])
		check(clipped.is_empty(), "every word fits its key in %s (%s)" % [lang, str(clipped)])
	Loc.set_language(was_language)
	await frames(2)

## --- the setting ------------------------------------------------------------

## It lives on the controls page, which the title's settings and the pause menu
## both hold, so putting it there puts it in both.
func _the_setting() -> void:
	GameState.reset_profile()
	var game := Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(10)

	var title: TitleScreen = game.current
	title._toggle_settings()
	await frames(4)
	title._toggle_controls()
	await frames(6)
	var panel: ControlsPanel = null
	for c in controls_under(title._controls):
		if c is ControlsPanel:
			panel = c
	check(panel != null, "the controls page carries the settings panel")
	if panel == null:
		game.queue_free()
		return
	var offered: Array = []
	for m in Touch.MODE_KEYS.size():
		if button_named(panel, Touch.mode_name(m)) != null:
			offered.append(Touch.MODE_KEYS[m])
	check(offered.size() == Touch.MODE_KEYS.size(),
		"it offers every console mode (%s)" % str(offered))
	check(button_named(panel, Loc.t("controls.touch.label")) == null
			and _label_on(panel, Loc.t("controls.touch.label")),
		"under the name the row is given")

	# AUTO is what a fresh install is in, and on a desk it comes to nothing.
	Touch.set_mode(Touch.AUTO)
	check(Touch.wanted() == Touch.touch_device(),
		"AUTO is on exactly where the machine is one you touch (here: %s)"
			% str(Touch.touch_device()))

	var on := button_named(panel, Touch.mode_name(Touch.ON))
	check(on != null, "and the ON button is there to press")
	if on != null:
		on.emit_signal("pressed")
		await frames(4)
	check(Touch.mode == Touch.ON and Touch.wanted(), "pressing ON puts the console on")
	# The panel is rebuilt by the press, so the button that is now the answer is
	# the disabled one.
	for c in controls_under(title._controls):
		if c is ControlsPanel:
			panel = c
	var now := button_named(panel, Touch.mode_name(Touch.ON))
	check(now != null and now.disabled, "and the row comes back with ON as the one it is on")

	# It outlives the run: the console is a property of the machine, like the
	# pointer speed and the language beside it.
	Touch.mode = Touch.OFF
	Touch.load_saved()
	check(Touch.mode == Touch.ON, "the mode is kept in a file of its own and read back")

	# And the pad the shell built follows it, with the face the shell picks.
	check(game.touch_pad != null, "the shell builds a pad that outlives every screen")
	check(game.touch_pad != null and not game.touch_pad.visible,
		"which stays off the title screen, where there is nothing to play")
	game.queue_free()
	await frames(4)
	Touch.set_mode(Touch.OFF)

func _label_on(root: Node, text: String) -> bool:
	for c in controls_under(root):
		if c is Label and (c as Label).text == text:
			return true
	return false

## --- what a thumb does ------------------------------------------------------

func _thumbs() -> void:
	layer = CanvasLayer.new()
	add_child(layer)
	pad = TouchPad.new()
	layer.add_child(pad)
	Touch.set_mode(Touch.ON)
	pad.face = TouchPad.Face.PLAY
	await frames(3)
	check(pad.visible, "with the console on and somebody playing, the pad is on the screen")

	# The very first touch of all, and it lands on the key that casts. The
	# system reports it twice — once as a finger, once as a click it invented —
	# and the two have to end up as one thumb on one key: a key let go of and
	# taken again inside a frame is a release, and a release of this one is a
	# skill cast for nothing.
	_lets_go = 0
	touch(0, middle_of("cast_skill"), true)
	await frames(2)
	check(Input.is_action_pressed("cast_skill"), "the first touch of all presses its key")
	check(pad._down.size() == 1,
		"as one thumb and not two (%d)" % pad._down.size())
	check(_lets_go == 0, "and nothing was let go of on the way (%d)" % _lets_go)
	touch(0, middle_of("cast_skill"), false)
	await frames(2)
	check(_lets_go == 1, "lifting it is the one release (%d)" % _lets_go)

	touch(0, middle_of("jump"), true)
	await frames(2)
	check(Input.is_action_pressed("jump") and Touch.holding("jump"),
		"a thumb on JUMP presses jump")
	touch(0, middle_of("jump"), false)
	await frames(2)
	check(not Input.is_action_pressed("jump"), "and lifting it lets go")

	# Two thumbs, which is the whole point of a pad: you run while you fight.
	touch(0, middle_of("move_right"), true)
	touch(1, middle_of("attack"), true)
	await frames(2)
	check(Input.is_action_pressed("move_right") and Input.is_action_pressed("attack"),
		"two fingers hold two keys at once")
	check(is_equal_approx(Input.get_axis("move_left", "move_right"), 1.0),
		"and the cross moves the player, as the keyboard does")

	# Sliding rather than lifting: a thumb that runs along the cross changes
	# direction without leaving the glass.
	drag(0, middle_of("move_left"))
	await frames(2)
	check(Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"),
		"a finger sliding to the next key swaps which one is down")
	drag(0, Vector2(640, 300))
	await frames(2)
	check(not Input.is_action_pressed("move_left"),
		"and sliding off the pad altogether lets go of it")
	touch(0, Vector2(640, 300), false)

	# Aiming. The cross points, and where it does not, the player's own facing
	# does — so a shot always goes somewhere they meant.
	check(is_equal_approx(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), 1.0)
			and is_equal_approx(Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y), 0.0),
		"with nothing on the cross the pad aims the way the player faces (%s)"
			% str(Touch.aiming()))
	touch(2, middle_of("move_up"), true)
	await frames(2)
	check(Touch.aiming().is_equal_approx(Vector2.UP),
		"a thumb on the up key aims up (%s)" % str(Touch.aiming()))
	touch(2, middle_of("move_up"), false)
	touch(1, middle_of("attack"), false)
	await frames(2)

	var body := Actor.new()
	body.add_to_group("player")
	add_child(body)
	body.facing = -1
	await frames(2)
	check(Touch.aiming().is_equal_approx(Vector2.LEFT),
		"a player facing left aims left (%s)" % str(Touch.aiming()))
	body.queue_free()
	await frames(2)

	# The faces. A conversation has the two keys that pick an answer and the one
	# that turns the page; a screen has only the keys that close it again.
	pad.face = TouchPad.Face.TALK
	await frames(2)
	touch(0, middle_of("jump"), true)
	await frames(2)
	check(not Input.is_action_pressed("jump"),
		"a thumb where JUMP was presses nothing while somebody is talking")
	touch(0, middle_of("jump"), false)
	touch(0, middle_of("interact"), true)
	await frames(2)
	check(Input.is_action_pressed("interact"), "but USE still turns the page")
	touch(0, middle_of("interact"), false)
	await frames(2)

	pad.face = TouchPad.Face.SCREEN
	await frames(2)
	var shown: Array = []
	for k in TouchPad.KEYS:
		if pad.on_face(k):
			shown.append(String(k["action"]))
	shown.sort()
	check(shown == ["open_editor", "open_map", "pause"],
		"a screen leaves only the keys that close it again (%s)" % str(shown))
	# PAUSE is answered in `_unhandled_input`, so the press has to travel the
	# tree and not merely set a flag somebody polls.
	_heard_pause = false
	touch(0, middle_of("pause"), true)
	await frames(2)
	check(_heard_pause, "and a key whose answer listens for an event is heard")
	touch(0, middle_of("pause"), false)
	await frames(2)

	# The window is not the screen: the game is drawn at 1280x720 whatever size
	# the window is, and a finger has to arrive in that space or every key is in
	# the wrong place on every window but a 1:1 one. Checked at a size that is
	# scaled and at one that is letterboxed as well, since only the second has
	# an offset in it to get wrong.
	var was_size := DisplayServer.window_get_size()
	for size in [Vector2i(1600, 900), Vector2i(1000, 700)]:
		DisplayServer.window_set_size(size)
		await frames(4)
		pad.face = TouchPad.Face.PLAY
		await frames(2)
		touch(0, middle_of("dash"), true)
		await frames(2)
		check(Input.is_action_pressed("dash"),
			"a key is under the same thumb on a %dx%d window" % [size.x, size.y])
		touch(0, middle_of("dash"), false)
		await frames(2)
	DisplayServer.window_set_size(was_size)
	await frames(4)

	# Nothing left held when the pad goes: a thumb lifted by the game rather
	# than by its owner must not walk into the next screen still running.
	touch(0, middle_of("move_right"), true)
	await frames(2)
	check(Input.is_action_pressed("move_right"), "a key held as the pad is taken away")
	pad.face = TouchPad.Face.NONE
	await frames(3)
	check(not pad.visible, "the pad goes when there is nothing to play")
	check(not Input.is_action_pressed("move_right") and not Touch.holding("move_right"),
		"and lets go of everything it was holding")
	check(Touch.aiming() == Vector2.ZERO, "and stops aiming")

var _heard_pause := false
var _lets_go := 0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_heard_pause = true
	if event.is_action_released("cast_skill"):
		_lets_go += 1

## --- the mouse in its drawer ------------------------------------------------

func _the_drawer() -> void:
	check(not Controls.mouse_aside(), "with the pad off the screen the mouse is a mouse")
	var before := Controls.label_for("attack")
	var keyboard := Controls.short_label_for("attack")
	pad.face = TouchPad.Face.PLAY
	await frames(3)
	check(Controls.mouse_aside(), "the pad coming up puts the mouse away")
	var bound := false
	for e in InputMap.action_get_events("attack"):
		if e is InputEventMouseButton:
			bound = true
	check(not bound, "a click no longer attacks, so a thumb on the glass does not swing")
	check(Controls.label_for("attack") == before,
		"but the rebinding screen still shows the binding ('%s')" % Controls.label_for("attack"))
	var kept := false
	for e in Controls.events_for("attack"):
		if e is InputEventMouseButton:
			kept = true
	check(kept, "and what gets saved still carries it")

	# Everything that tells the player which control does what — the slot cards,
	# the hint over them, the footer, the prompt over an NPC — asks the same
	# question, so the console answering it is the whole of the fix.
	check(Controls.short_label_for("attack") == Controls.word_for("attack")
			and Controls.word_for("attack") != "",
		"a HUD asking what attacks is told the key on the glass ('%s')"
			% Controls.short_label_for("attack"))
	check(Controls.short_label_for("skill_1") == "1",
		"a slot is its own number either way ('%s')" % Controls.short_label_for("skill_1"))

	pad.face = TouchPad.Face.NONE
	await frames(3)
	check(not Controls.mouse_aside(), "the pad going hands the mouse straight back")
	bound = false
	for e in InputMap.action_get_events("attack"):
		if e is InputEventMouseButton:
			bound = true
	check(bound, "and a click attacks again")
	check(Controls.label_for("attack") == before,
		"with nothing about the binding changed ('%s')" % Controls.label_for("attack"))
	check(Controls.short_label_for("attack") == keyboard,
		"and a HUD is told the key again ('%s')" % Controls.short_label_for("attack"))
