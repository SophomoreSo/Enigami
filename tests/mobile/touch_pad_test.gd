extends Node
## The console the game draws on the glass, and the setting that puts it there.
##
## It is laid out the way a phone MOBA is — a floating stick under the left
## thumb, a stick per skill under the right — so what is checked here is what
## that scheme has to get right.
##
## **Where the controls sit.** The HUD owns the top-left corner and the whole
## bottom of the screen, and a control standing on either covers the health bar
## or the slot cards for as long as the game is played. Every one is measured
## against those bands, against every other control, and against its own word in
## both languages — on the design's 16:9 and on the shapes a phone or a tablet
## gives the screen instead, where each has to keep its distance from its own
## corner.
##
## **What a thumb does.** Against a real raid, with a real player carrying real
## slots: the stick moves them and moves them *analog*, a half push walking and
## a full one running; a stick keeps the finger that started it however far it
## is dragged; a skill button arms its slot, charges while it is held, aims
## where it is thrown and casts on release; a slot the player is not carrying is
## not on the pad at all.
##
## **What it costs the rest of the game.** While the pad is up the mouse is in a
## drawer, because the system turns every touch into a click and `attack` is
## bound to one. The bindings still read and still save while they are in there.

const GameScript := preload("res://app/game.gd")

## The two bands the HUD keeps, out of `graphics/ui/hud.gd`: the bars and the
## weapon down the top-left corner, and the slot cards with the hint line over
## them and the footer under them across the bottom.
const HUD_BARS := Rect2(24, 24, 264, 88)
const HUD_CARDS := Rect2(0, 592, 1280, 128)

## The shapes of screen the layout is checked on: the design, phones longer
## than 16:9 — the one it was reported on is about 20.5:9, and some go past
## 21:9 — and a 4:3 tablet. `expand` stretch keeps the height at 720 on the
## first kind and the width at 1280 on the second.
const SHAPES := [Vector2(1280, 720), Vector2(1642, 720), Vector2(1728, 720), Vector2(1280, 960)]

var fails := 0
var game: Node
var pad: TouchPad
var raid: Raid
var player: Player
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

func switch_under(root: Node) -> UiKit.Switch:
	for c in controls_under(root):
		if c is UiKit.Switch:
			return c
	return null

## A click where `at` is in the 1280x720 the game is drawn at, pressed and let
## go, sent the way the system sends one.
func click(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = on_glass(at)
	m.global_position = m.position
	Input.parse_input_event(m)
	await frames(2)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = m.position
		e.global_position = e.position
		Input.parse_input_event(e)
		await frames(2)

func button_named(root: Node, text: String) -> Button:
	for c in controls_under(root):
		if c is Button and (c as Button).text == text:
			return c
	return null

## The control that presses `id` — the action it holds, or, for a slot stick,
## the slot it arms.
func control_of(id: String) -> Dictionary:
	for c in TouchPad.CONTROLS:
		if String(c.get("action", "")) == id or String(c.get("arm", "")) == id:
			return c
	return {}

## Where a control is on the screen as it is now, whatever shape the window has
## given it.
func spot(id: String) -> Vector2:
	return TouchPad.area(control_of(id), screen()).get_center()

func screen() -> Vector2:
	return get_viewport().get_visible_rect().size

## The HUD's band along the bottom, on a screen of `s`: it goes wherever the
## bottom does.
func hud_cards(s: Vector2) -> Rect2:
	return Rect2(0, s.y - HUD_CARDS.size.y, s.x, HUD_CARDS.size.y)

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
	await _into_a_raid()
	await _the_stick()
	await _the_skills()
	await _the_faces()
	await _another_window()
	await _the_drawer()
	Touch.set_mode(was_mode)
	print("[TOUCH] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- where the controls sit -------------------------------------------------

func _layout() -> void:
	for s: Vector2 in SHAPES:
		_placed_on(s)

	# A control too small for a thumb is one that gets missed. 44 is the
	# smallest anybody recommends and the smallest here.
	var small: Array = []
	for c in TouchPad.CONTROLS:
		var r := TouchPad.area(c)
		if r.size.x < 44.0 or r.size.y < 44.0:
			small.append("%s %s" % [c.get("action", "move"), str(r.size)])
	check(small.is_empty(), "every control is at least 44 across (%s)" % str(small))

	var unknown: Array = []
	for c in TouchPad.CONTROLS:
		for key in ["action", "arm"]:
			var a := String(c.get(key, ""))
			if a != "" and not InputMap.has_action(a):
				unknown.append(a)
	check(unknown.is_empty(), "every control presses an action the game has (%s)" % str(unknown))
	# Movement is the stick's, and it presses all four itself.
	var missing: Array = []
	for entry in Controls.ACTIONS:
		var a := String(entry[0])
		if a.begins_with("move_"):
			continue
		if control_of(a).is_empty():
			missing.append(a)
	check(missing.is_empty(),
		"and every other action on the rebinding screen has a control (%s)" % str(missing))

	# The words, in each language. Silkscreen is proportional and Hangul is
	# drawn from a face of its own at its own size, so a word that fits in
	# English says nothing about the same word in Korean.
	var was_language := Loc.language
	for lang in Loc.languages():
		Loc.set_language(lang)
		await frames(2)
		var clipped: Array = []
		for c in TouchPad.CONTROLS:
			var label := TouchPad.label_of(c)
			if label == "":
				continue
			var room := TouchPad.area(c).size.x
			if PixelDraw.clip(label, room) != label:
				clipped.append("%s '%s' (%.0f of %.0f)" % [c.get("action", "move"), label,
					PixelDraw.text_width(label), room])
		check(clipped.is_empty(), "every word fits its control in %s (%s)" % [lang, str(clipped)])
	Loc.set_language(was_language)
	await frames(2)

## Where the controls land on a screen of `s`: every one on it, none on the HUD
## and none on another — and each its own distance from its own corner, which
## is the design's answer to a screen of another shape. A thumb reaches no
## further on a longer phone, so the hand stays as far from the bottom-right
## corner as the design puts it, the plates as far from the top-right, and the
## stick's zone keeps the left edge and runs down to the HUD's band.
func _placed_on(s: Vector2) -> void:
	var shape := "%dx%d" % [s.x, s.y]
	var screen_rect := Rect2(Vector2.ZERO, s)
	var off: Array = []
	var on_hud: Array = []
	var strayed: Array = []
	for c in TouchPad.CONTROLS:
		var r := TouchPad.area(c, s)
		var name := String(c.get("action", "move"))
		if not screen_rect.encloses(r):
			off.append(name)
		if r.intersects(HUD_BARS) or r.intersects(hud_cards(s)):
			on_hud.append(name)
		# Each axis measured from the side the control is pinned to.
		var pin := Vector2(c.get("pin", Vector2.ZERO))
		var design := TouchPad.area(c)
		var here := Vector2(s.x - r.end.x if pin.x > 0.0 else r.position.x,
			s.y - r.end.y if pin.y > 0.0 else r.position.y)
		var there := Vector2(TouchPad.DESIGN.x - design.end.x if pin.x > 0.0 else design.position.x,
			TouchPad.DESIGN.y - design.end.y if pin.y > 0.0 else design.position.y)
		if here.distance_to(there) > PixelDraw.PX * 1.5:
			strayed.append("%s %s, not %s" % [name, str(here), str(there)])
	check(off.is_empty(), "%s: every control is on the screen (off: %s)" % [shape, str(off)])
	check(on_hud.is_empty(),
		"%s: and none stands on the health bars or the slot cards (on: %s)" % [shape, str(on_hud)])
	check(strayed.is_empty(),
		"%s: and each keeps its distance from its own corner (%s)" % [shape, str(strayed)])
	var zone := TouchPad.area(TouchPad.CONTROLS[0], s)
	check(is_equal_approx(zone.end.y, hud_cards(s).position.y),
		"%s: the stick's zone runs down to the HUD's band (%.0f, the band at %.0f)"
			% [shape, zone.end.y, hud_cards(s).position.y])

	# The stick's zone is most of the lower-left of the screen, so this is the
	# check that says the right hand stays out of it.
	var overlap: Array = []
	for i in TouchPad.CONTROLS.size():
		for j in range(i + 1, TouchPad.CONTROLS.size()):
			var a := TouchPad.area(TouchPad.CONTROLS[i], s).grow(TouchPad.SLOP)
			var b := TouchPad.area(TouchPad.CONTROLS[j], s).grow(TouchPad.SLOP)
			if a.intersects(b):
				overlap.append("%s/%s" % [TouchPad.CONTROLS[i].get("action", "move"),
					TouchPad.CONTROLS[j].get("action", "move")])
	check(overlap.is_empty(), "%s: no two controls overlap, slop and all (%s)" % [shape, str(overlap)])

## --- the setting ------------------------------------------------------------

## It is mobile mode, a switch on the controls page, which the title's settings
## and the pause menu both hold — so putting it there puts it in both, and
## throwing it in one has to show in the other.
func _the_setting() -> void:
	GameState.reset_profile()
	game = Node.new()
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
		return
	var switch := switch_under(panel)
	check(switch != null, "it offers mobile mode as a switch")
	var named := false
	for c in controls_under(panel):
		if c is Label and (c as Label).text == Loc.t("controls.mobile"):
			named = true
	check(named, "under the name the row is given")
	if switch == null:
		return

	# AUTO is what a fresh install is in, and on a desk it comes to nothing. The
	# switch shows what it came to, set as the page comes on screen.
	Touch.set_mode(Touch.AUTO)
	check(Touch.wanted() == Touch.touch_device(),
		"AUTO is on exactly where the machine is one you touch (here: %s)"
			% str(Touch.touch_device()))
	title._toggle_controls()
	await frames(2)
	title._toggle_controls()
	await frames(4)
	check(switch.button_pressed == Touch.wanted(),
		"and the switch shows what AUTO came to (%s)" % str(switch.button_pressed))

	# Thrown by a click, the way a mouse or a thumb throws it, both ways.
	Touch.set_mode(Touch.OFF)
	switch.show_on(false)
	await click(switch.get_global_rect().get_center())
	check(Touch.mode == Touch.ON and Touch.wanted() and switch.button_pressed,
		"a click throws it on, and puts the console on (mode %d)" % Touch.mode)
	await click(switch.get_global_rect().get_center())
	check(Touch.mode == Touch.OFF and not Touch.wanted() and not switch.button_pressed,
		"and another throws it off again (mode %d)" % Touch.mode)
	await click(switch.get_global_rect().get_center())
	check(Touch.mode == Touch.ON, "and on again")

	Touch.mode = Touch.OFF
	Touch.load_saved()
	check(Touch.mode == Touch.ON, "the mode is kept in a file of its own and read back")

	# The pause menu's copy was built at boot, before any of that, and has to
	# come on screen showing what is in force now rather than what was then.
	game.pause_menu.visible = true
	game._pause_controls(true)
	await frames(4)
	var paused := switch_under(game.pause_controls)
	check(paused != null and paused.button_pressed,
		"the pause menu's switch shows it on too (%s)"
			% ("none" if paused == null else str(paused.button_pressed)))
	game._pause_controls(false)
	game.pause_menu.visible = false
	title._toggle_controls()
	title._toggle_settings()
	await frames(4)

	pad = game.touch_pad
	check(pad != null, "the shell builds a pad that outlives every screen")
	check(pad != null and not pad.visible,
		"which stays off the title screen, where there is nothing to play")

## --- a raid to play with ----------------------------------------------------

## Everything below runs against a real raid: a player who really arms, really
## charges and really casts. A stick that presses the right action and changes
## nothing would pass every check written against the pad alone.
func _into_a_raid() -> void:
	game._deploy("SWORD", [0, 1, 2])
	await frames(20)
	raid = game.current as Raid
	player = raid.player
	check(player != null, "a raid, with somebody in it to control")
	check(player != null and player.runners.size() == 3,
		"carrying three slots (%d)" % (0 if player == null else player.runners.size()))
	await frames(4)
	check(pad.visible, "and with the console on, the pad is on the screen")

## --- the stick --------------------------------------------------------------

func _the_stick() -> void:
	var zone := TouchPad.area(TouchPad.CONTROLS[0], screen())
	var radius: float = TouchPad.CONTROLS[0]["radius"]
	# There is nothing there until a thumb lands and drags, and then it is where
	# the thumb landed.
	check(not pad.stick_showing(), "with no thumb down there is no stick on the screen")
	var landed := Vector2(zone.position.x + radius + 40.0, zone.position.y + radius + 30.0)
	touch(0, landed, true)
	await frames(2)
	check(not pad.stick_showing(), "a thumb that only touches the left of the screen grows nothing")
	# A thumb coming down is never quite still, and a tremble is not a drag.
	drag(0, landed + Vector2(TouchPad.STICK_OUT * 0.5, 0.0))
	await frames(2)
	check(not pad.stick_showing(), "nor does one that only trembles")
	check(absf(Input.get_axis("move_left", "move_right")) < 0.001, "and neither moves anybody")
	# Past the slop and still inside the dead zone: on the screen, and nobody
	# moved by it yet.
	var out := TouchPad.STICK_OUT + 2.0
	drag(0, landed + Vector2(out, 0.0))
	await frames(2)
	check(pad.stick_showing(), "a thumb that drags grows one")
	check(pad._stick_at.is_equal_approx(landed),
		"where the thumb landed, not where it was dragged to or where it was last time (%s)"
			% str(pad._stick_at))
	check(absf(Input.get_axis("move_left", "move_right")) < 0.001,
		"and it asks for nothing until it is pushed past its dead zone")

	# Analog: how far it is pushed is how fast they walk.
	drag(0, landed + Vector2(radius * 0.5, 0.0))
	await frames(2)
	var half := Input.get_axis("move_left", "move_right")
	drag(0, landed + Vector2(radius * 2.0, 0.0))
	await frames(2)
	var full := Input.get_axis("move_left", "move_right")
	check(half > 0.05 and half < 0.9, "a half push walks (%.2f)" % half)
	check(is_equal_approx(full, 1.0), "and a full one runs (%.2f)" % full)
	check(full > half, "which is more than the half push asked for")
	check(player.velocity.x > 0.0, "the player is really moving (%.0f)" % player.velocity.x)

	# A stick keeps the finger that started it: dragged across the screen and
	# over the jump button, it is still the stick and JUMP is not pressed.
	drag(0, spot("jump"))
	await frames(2)
	check(not Input.is_action_pressed("jump"),
		"a stick dragged over a button does not press it")
	check(Input.get_axis("move_left", "move_right") > 0.0,
		"it is still the stick being held")

	drag(0, landed - Vector2(radius, 0.0))
	await frames(2)
	check(Input.get_axis("move_left", "move_right") < -0.9,
		"pushed the other way it goes the other way (%.2f)"
			% Input.get_axis("move_left", "move_right"))

	touch(0, landed, false)
	await frames(2)
	check(absf(Input.get_axis("move_left", "move_right")) < 0.001,
		"lifting lets go of the lot")
	check(not pad.stick_showing(), "and takes the stick off the screen with it")

	# And the next thumb down is where the next stick is, wherever that is.
	var again := Vector2(zone.end.x - radius - 30.0, zone.end.y - radius - 20.0)
	touch(0, again, true)
	drag(0, again + Vector2(0.0, -out))
	await frames(2)
	check(pad.stick_showing() and pad._stick_at.is_equal_approx(again),
		"the next one grows under the next thumb, somewhere else entirely (%s)"
			% str(pad._stick_at))
	touch(0, again, false)
	await frames(2)
	check(not pad.stick_showing(), "and goes again")

	# A thumb in the very corner of the zone: the ring has to slide in to stay
	# on the screen, and the push has to go on being measured from the thumb.
	# Measured from the ring instead, a stick summoned in the corner would read
	# as shoved the moment it appeared and walk the player off on its own.
	var corner := Vector2(zone.position.x + 2.0, zone.end.y - 2.0)
	touch(0, corner, true)
	# Dragged just far enough to bring it out. The ring it grows is a radius in
	# from the corner, so measured from the ring this would read as a shove the
	# moment it appeared; measured from the thumb it is a nudge.
	drag(0, corner + Vector2(out, 0.0))
	await frames(3)
	check(pad.stick_showing(), "a thumb in the corner of the zone still grows a stick")
	check(absf(Input.get_axis("move_left", "move_right")) < 0.001
			and not Input.is_action_pressed("move_down")
			and not Input.is_action_pressed("move_up"),
		"and it asks for nothing until it is pushed (ring %s, thumb %s)"
			% [str(pad._stick_at), str(corner)])
	var ring := Rect2(pad._stick_at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	check(not ring.intersects(HUD_BARS) and not ring.intersects(hud_cards(screen()))
			and Rect2(Vector2.ZERO, screen()).encloses(ring),
		"the ring it drew is on the screen and clear of the HUD (%s)" % str(ring))
	drag(0, corner + Vector2(radius, 0.0))
	await frames(3)
	check(Input.get_axis("move_left", "move_right") > 0.9,
		"and pushing it from there still runs (%.2f)"
			% Input.get_axis("move_left", "move_right"))
	touch(0, corner, false)
	await frames(2)

## --- the skills -------------------------------------------------------------

func _the_skills() -> void:
	# The player is carrying three, so the fourth button is not there to press.
	check(pad.shown(control_of("skill_3")), "a slot the player carries is on the pad")
	check(not pad.shown(control_of("skill_4")),
		"and one they do not carry is not")
	touch(0, spot("skill_4"), true)
	await frames(2)
	check(not Input.is_action_pressed("cast_skill"),
		"a thumb where it would have been presses nothing")
	touch(0, spot("skill_4"), false)
	await frames(2)

	# A slot this weapon can actually cast. The kit is dealt out of the profile
	# and a sword refuses some boards; a slot it refuses cannot be charged
	# either, which is the rules' business and not the pad's.
	var slot := -1
	for i in player.runners.size():
		if player.can_cast(i):
			slot = i
			break
	check(slot >= 0, "the kit has a slot this weapon can cast (%d)" % slot)
	if slot < 0:
		return
	var key := "skill_%d" % (slot + 1)
	var where := spot(key)

	# Press: the slot is armed and the charge starts.
	player.select_slot((slot + 1) % player.runners.size())
	await frames(2)
	touch(0, where, true)
	await frames(4)
	check(player.selected_slot == slot,
		"pressing a slot arms it (%d)" % player.selected_slot)
	check(Input.is_action_pressed("cast_skill"), "and holds the cast down")
	var charged_for := 0.0
	for i in 20:
		await get_tree().process_frame
		charged_for = maxf(charged_for, player.charge)
	check(charged_for > 0.0, "holding it charges the skill (%.1f)" % charged_for)

	# Throw: where the thumb goes is where the cast goes.
	drag(0, where + Vector2(0.0, -TouchPad.AIM_REACH))
	await frames(3)
	check(pad.aim().is_equal_approx(Vector2.UP),
		"throwing the thumb up aims up (%s)" % str(pad.aim()))
	check(player.aim.y < -0.9, "and the player is really aiming there (%s)" % str(player.aim))
	# The throw beats the stick: you can run one way and cast the other.
	var zone := TouchPad.area(TouchPad.CONTROLS[0], screen())
	var radius: float = TouchPad.CONTROLS[0]["radius"]
	var landed := zone.position + Vector2.ONE * (radius + 20.0)
	touch(1, landed, true)
	drag(1, landed + Vector2(radius * 2.0, 0.0))
	await frames(3)
	check(Input.get_axis("move_left", "move_right") > 0.9 and player.aim.y < -0.9,
		"running one way while aiming another (%s)" % str(player.aim))
	touch(1, landed, false)
	await frames(2)

	# Release: it casts, and what the hold paid for goes with it. The meter is
	# read a few frames before the thumb lifts and the hold goes on paying in
	# between, so what the cast carries is at least that and no more than the
	# ceiling.
	var paid := player.charge
	touch(0, where + Vector2(0.0, -TouchPad.AIM_REACH), false)
	await frames(3)
	check(not Input.is_action_pressed("cast_skill"), "letting go lets go of the cast")
	check(not Input.is_action_pressed(key), "and of the slot it armed")
	check(paid > 0.0 and player.cast_charge >= paid
			and player.cast_charge <= player.charge_cap() + 0.001,
		"the cast carries what the hold paid for (%.1f, at least the %.1f on the meter)"
			% [player.cast_charge, paid])

	# A tap with no throw in it still goes somewhere: forwards.
	player.face(-1)
	await frames(2)
	check(pad.aim().is_equal_approx(Vector2.LEFT),
		"with nothing held the pad aims the way the player faces (%s)" % str(pad.aim()))

	# The weapon is the same stick without the arming.
	touch(0, spot("attack"), true)
	await frames(3)
	check(Input.is_action_pressed("attack"), "the weapon button swings the weapon")
	drag(0, spot("attack") + Vector2(TouchPad.AIM_REACH, 0.0))
	await frames(3)
	check(pad.aim().is_equal_approx(Vector2.RIGHT),
		"and throwing it aims the swing (%s)" % str(pad.aim()))
	touch(0, spot("attack"), false)
	await frames(2)
	check(not Input.is_action_pressed("attack"), "lifting stops swinging")

## --- what is on the pad, and when -------------------------------------------

func _the_faces() -> void:
	player.talk_locked = true
	await frames(3)
	check(pad.face == TouchPad.Face.TALK, "somebody talking leaves the pad its TALK face")
	var shown: Array = []
	for c in TouchPad.CONTROLS:
		if pad.shown(c):
			shown.append(String(c.get("action", "move")))
	shown.sort()
	check(shown == ["interact", "move"],
		"which is the stick that picks an answer and the key that turns the page (%s)" % str(shown))
	touch(0, spot("jump"), true)
	await frames(2)
	check(not Input.is_action_pressed("jump"), "a thumb where JUMP was presses nothing")
	touch(0, spot("jump"), false)
	touch(0, spot("interact"), true)
	await frames(2)
	check(Input.is_action_pressed("interact"), "but USE still turns the page")
	touch(0, spot("interact"), false)
	player.talk_locked = false
	await frames(3)

	player.input_locked = true
	await frames(3)
	check(pad.face == TouchPad.Face.SCREEN, "a window that has taken the controls leaves SCREEN")
	shown = []
	for c in TouchPad.CONTROLS:
		if pad.shown(c):
			shown.append(String(c.get("action", "move")))
	shown.sort()
	check(shown == ["open_editor", "open_map", "pause"],
		"which is only the keys that close it again (%s)" % str(shown))
	player.input_locked = false
	await frames(3)

	# PAUSE is answered in `_unhandled_input`, so the press has to travel the
	# tree and not merely set a flag somebody polls.
	touch(0, spot("pause"), true)
	await frames(4)
	check(game.pause_menu.visible and get_tree().paused,
		"and MENU really opens the pause menu")
	touch(0, spot("pause"), false)
	game._unpause()
	await frames(4)

## --- the window is not the screen -------------------------------------------

func _another_window() -> void:
	# A finger touches the window, and has to arrive on the screen the game is
	# drawn on or every control is in the wrong place on every window but a 1:1
	# one: the window scaled, and on a window of another shape than 16:9 a
	# screen of another shape too, with the hand moved into its corner. Checked
	# on a window that is only scaled, on one squarer than the design, and on one
	# the shape of a long phone — the last two are where a control is somewhere
	# the design does not write it.
	var was_size := DisplayServer.window_get_size()
	for size in [Vector2i(1600, 900), Vector2i(1000, 700), Vector2i(1480, 640)]:
		DisplayServer.window_set_size(size)
		await frames(4)
		touch(0, spot("dash"), true)
		await frames(3)
		check(Input.is_action_pressed("dash"),
			"a control is under the same thumb on a %dx%d window (at %s on a %s screen)"
				% [size.x, size.y, str(spot("dash")), str(screen())])
		touch(0, spot("dash"), false)
		await frames(2)
	DisplayServer.window_set_size(was_size)
	await frames(4)

	# Nothing left held when the console is switched off under a thumb that is
	# still on it: a key lifted by the game rather than by its owner must not
	# leave the player running into the next screen.
	touch(0, spot("jump"), true)
	await frames(2)
	check(Input.is_action_pressed("jump"), "a key held as the console is switched off")
	Touch.set_mode(Touch.OFF)
	await frames(3)
	check(not pad.visible, "turning it off takes the pad off the screen mid-raid")
	check(not Input.is_action_pressed("jump") and not Touch.holding("jump"),
		"and lets go of everything it was holding")
	check(Touch.aiming() == Vector2.ZERO, "and stops aiming")

## --- the mouse in its drawer ------------------------------------------------

func _the_drawer() -> void:
	check(not Controls.mouse_aside(), "with the pad off the screen the mouse is a mouse")
	var before := Controls.label_for("attack")
	var keyboard := Controls.short_label_for("attack")
	Touch.set_mode(Touch.ON)
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
	# the extract prompt, the hint over an NPC — asks the same question, so the
	# console answering it is the whole of the fix.
	check(Controls.short_label_for("attack") == Controls.word_for("attack")
			and Controls.word_for("attack") != "",
		"a HUD asking what attacks is told the key on the glass ('%s')"
			% Controls.short_label_for("attack"))
	check(Controls.short_label_for("skill_1") == "1",
		"a slot is its own number either way ('%s')" % Controls.short_label_for("skill_1"))

	Touch.set_mode(Touch.OFF)
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
