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
		if String(c.get("action", "")) == id or String(c.get("arm", "")) == id or String(c.get("alt", "")) == id:
			return c
	return {}

## Where a control is on the screen as it is now, whatever shape the window has
## given it.
func spot(id: String) -> Vector2:
	return TouchPad.area(control_of(id), screen()).get_center()

func slopped(c: Dictionary, s: Vector2) -> Rect2:
	var r := TouchPad.area(c, s)
	return r if c.has("zone") else r.grow(TouchPad.SLOP)

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
	# The buttons where the design puts them, whatever this machine's player
	# has moved them to — in force here only, and nothing kept.
	TouchPad.set_layout({}, false)
	await _layout()
	await _the_setting()
	await _into_a_raid()
	await _the_stick()
	await _the_skills()
	await _the_reach()
	await _the_faces()
	await _hit_is_use()
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
	# smallest anybody recommends, and on a phone's glass it was still smaller
	# than the thumb: the buttons are twice what they were, so twice that is the
	# floor, and the plates' height is the smallest here.
	var small: Array = []
	for c in TouchPad.CONTROLS:
		var r := TouchPad.area(c)
		if r.size.x < 88.0 or r.size.y < 88.0:
			small.append("%s %s" % [c.get("action", "move"), str(r.size)])
	check(small.is_empty(), "every control is at least 88 across (%s)" % str(small))

	var unknown: Array = []
	for c in TouchPad.CONTROLS:
		for key in ["action", "arm", "alt", "hold"]:
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
			# At the size the console writes its words, twice the menus'.
			var room := TouchPad.area(c).size.x
			if PixelDraw.clip(label, room, TouchPad.LABEL_SIZE) != label:
				clipped.append("%s '%s' (%.0f of %.0f)" % [c.get("action", "move"), label,
					PixelDraw.text_width(label, TouchPad.LABEL_SIZE), room])
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
		# Only what is up while the HUD is. The page in a conversation is the
		# whole screen, and lies over a HUD that has stepped aside for it.
		var beside_hud: bool = (c["faces"] as Array).has(TouchPad.Face.PLAY) \
			or (c["faces"] as Array).has(TouchPad.Face.SCREEN)
		if beside_hud and (r.intersects(HUD_BARS) or r.intersects(hud_cards(s))):
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
				# A zone answers only to a thumb inside it, so it gets no slop; two
			# zones may share an edge, and a press on it lands in one of them.
			var a := slopped(TouchPad.CONTROLS[i], s)
			var b := slopped(TouchPad.CONTROLS[j], s)
			# Two controls never up at once cannot be pressed at once: the page
			# in a conversation covers the hand, which is not there then.
			var together := false
			for f in TouchPad.CONTROLS[i]["faces"]:
				together = together or (TouchPad.CONTROLS[j]["faces"] as Array).has(f)
			if together and a.intersects(b):
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
	var switch := switch_under(title._controls)
	check(switch != null, "it offers mobile mode as a switch")
	var named := false
	for c in controls_under(title._controls):
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
	# The page is laid out for the mode in force, so it is built again whenever
	# the mode changes — and the switch on it is a new one each time.
	switch = switch_under(title._controls)
	check(switch != null and switch.button_pressed == Touch.wanted(),
		"and the switch shows what AUTO came to (%s)" % str(Touch.wanted()))

	# Thrown by a click, the way a mouse or a thumb throws it, both ways.
	Touch.set_mode(Touch.OFF)
	await frames(3)
	switch = switch_under(title._controls)
	await click(switch.get_global_rect().get_center())
	await frames(3)
	switch = switch_under(title._controls)
	check(Touch.mode == Touch.ON and Touch.wanted() and switch != null and switch.button_pressed,
		"a click throws it on, and puts the console on (mode %d)" % Touch.mode)
	check(title._controls.visible and title._controls.thumb,
		"and the page it is on is laid out again, for a thumb, and still up")
	await click(switch.get_global_rect().get_center())
	await frames(3)
	switch = switch_under(title._controls)
	check(Touch.mode == Touch.OFF and not Touch.wanted() and switch != null and not switch.button_pressed,
		"and another throws it off again (mode %d)" % Touch.mode)
	check(title._controls.visible and not title._controls.thumb, "and the page is a desk's again")
	await click(switch.get_global_rect().get_center())
	await frames(3)
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

## Everything below runs against a real raid: a player who really charges and
## really casts. A stick that presses the right action and changes nothing
## would pass every check written against the pad alone.
func _into_a_raid() -> void:
	game._deploy("SWORD")
	await frames(20)
	raid = game.current as Raid
	player = raid.player
	check(player != null, "a raid, with somebody in it to control")
	check(player != null and player.runner != null,
		"carrying the weapon's graph")
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

## --- the cast -----------------------------------------------------------------

func _the_skills() -> void:
	# One cast stick, whatever the weapon: there are no slots to carry or not.
	check(pad.shown(control_of("cast_skill")), "the cast stick is on the pad")
	var where := spot("cast_skill")
	# A cast's first attack goes off the moment it is let go of; whatever the
	# board does after that plays out in real time. This board's second attack
	# comes a good five frames later — by which time a console that did not
	# hold the aim would be aiming with the other thumb.
	var later := one_now_one_later()
	var dry := SkillRunner.new(later).simulate()
	check(String(dry["error"]) == "" and (dry["outputs"] as Array).size() == 2,
		"the board runs clean, to two attacks (%s)" % dry["error"])
	player.setup(player.weapon_id, later)
	await frames(2)

	# Press: the charge starts.
	touch(0, where, true)
	await frames(4)
	check(Input.is_action_pressed("cast_skill"), "pressing it holds the cast down")
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
	#
	# The thumb that aimed it is gone the moment it casts, and a board fires
	# ticks later — so the left thumb runs right as the right one lets go, and
	# every attack the cast fires is watched for where it went.
	var went: Array = []
	var watch := func() -> void: went.append(player.aim)
	player.cast_fired.connect(watch)
	touch(1, landed, true)
	drag(1, landed + Vector2(radius * 2.0, 0.0))
	await frames(1)
	var paid := player.charge
	touch(0, where + Vector2(0.0, -TouchPad.AIM_REACH), false)
	await frames(3)
	check(not Input.is_action_pressed("cast_skill"), "letting go lets go of the cast")
	check(paid > 0.0 and player.cast_charge >= paid
			and player.cast_charge <= player.charge_cap() + 0.001,
		"the cast carries what the hold paid for (%.1f, at least the %.1f on the meter)"
			% [player.cast_charge, paid])
	var waited := 0
	while player.casting() and waited < 600:
		await get_tree().process_frame
		waited += 1
	await frames(3)
	player.cast_fired.disconnect(watch)
	check(went.size() == 2 and went.all(func(a: Vector2) -> bool: return a.y < -0.9),
		"both attacks the cast fires go up, where it was thrown — the later one too, though the left thumb is running right (%s)"
			% str(went))
	check(pad.aim().is_equal_approx(Vector2.RIGHT),
		"and once it has gone off the aim is the left stick's again (%s)" % str(pad.aim()))
	touch(1, landed + Vector2(radius * 2.0, 0.0), false)
	await frames(2)

	# A tap with no throw in it still goes somewhere: forwards.
	player.face(-1)
	await frames(2)
	check(pad.aim().is_equal_approx(Vector2.LEFT),
		"with nothing held the pad aims the way the player faces (%s)" % str(pad.aim()))

	# The weapon is the same stick without the charge.
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

## --- how far ------------------------------------------------------------------

## How far a cast goes is how far its thumb drags, measured from where it came
## down — and a thumb that comes down anywhere on the button without dragging is
## a tap, which goes the way the left stick does, all the way.
func _the_reach() -> void:
	var where := spot("cast_skill")
	touch(0, where, true)
	await frames(3)
	var half := TouchPad.AIM_DEAD + (TouchPad.AIM_REACH - TouchPad.AIM_DEAD) * 0.5
	drag(0, where + Vector2(half, 0.0))
	await frames(3)
	check(absf(pad.throw_reach() - 0.5) < 0.02,
		"a thumb dragged half way to the ring asks for half the distance (%.2f)" % pad.throw_reach())
	check(absf(player.aim_reach - 0.5) < 0.02 and player.aim.x > 0.9,
		"and the player aims that way, half as far (%.2f %s)" % [player.aim_reach, str(player.aim)])
	drag(0, where + Vector2(TouchPad.AIM_REACH * 1.5, 0.0))
	await frames(3)
	check(player.aim_reach > 0.99,
		"past the ring is all of it (%.2f)" % player.aim_reach)
	drag(0, where + Vector2(TouchPad.AIM_DEAD + 2.0, 0.0))
	await frames(3)
	check(player.aim_reach < 0.05 and player.aim.x > 0.9,
		"just past the dead zone, next to nothing — but still that way (%.2f)" % player.aim_reach)
	touch(0, where + Vector2(TouchPad.AIM_DEAD + 2.0, 0.0), false)
	await _cast_done()

	# A tap off the button's middle, with the left thumb pushing right. The
	# thumb trembles as thumbs do; it does not drag.
	var zone := TouchPad.area(TouchPad.CONTROLS[0], screen())
	var radius: float = TouchPad.CONTROLS[0]["radius"]
	var landed := zone.position + Vector2.ONE * (radius + 20.0)
	touch(1, landed, true)
	drag(1, landed + Vector2(radius * 2.0, 0.0))
	await frames(2)
	var off := where + Vector2(-40.0, 24.0)
	touch(0, off, true)
	await frames(2)
	drag(0, off + Vector2(3.0, -2.0))
	await frames(3)
	check(pad.aim().is_equal_approx(Vector2.RIGHT) and player.aim.x > 0.9,
		"a thumb that lands off the button's middle and does not drag goes the way the left stick pushes (%s)"
			% str(pad.aim()))
	check(player.aim_reach > 0.99, "and all the way (%.2f)" % player.aim_reach)
	touch(0, off + Vector2(3.0, -2.0), false)
	await _cast_done()
	touch(1, landed + Vector2(radius * 2.0, 0.0), false)
	await frames(2)

## A DELAY on the root, a SLASH and a TEE: the main line leaves the board at
## once, as a cast's first attack always does, and the branch walks the rest of
## the board — down, round the bottom, up the left side and along the top — to
## come back into the DELAY against the way out and leave eighteen ticks later.
func one_now_one_later() -> SkillBoard:
	var b := SkillBoard.new(7, 5, "one now, one later")
	b.set_root("DELAY", Vector2i(3, 2), 0)
	b.place("SLASH", Vector2i(4, 2), 0)
	b.place("TEE", Vector2i(5, 2), 0)
	b.place("DELAY", Vector2i(6, 2), 0)
	var walk: Array = [[Vector2i(5, 3), 1], [Vector2i(5, 4), 2]]
	for x in range(4, 0, -1):
		walk.append([Vector2i(x, 4), 2])
	for y in range(4, 0, -1):
		walk.append([Vector2i(0, y), 3])
	for x in 6:
		walk.append([Vector2i(x, 0), 0])
	walk.append([Vector2i(6, 0), 1])
	walk.append([Vector2i(6, 1), 1])
	for step in walk:
		b.place("DELAY", step[0], step[1])
	return b

func _cast_done() -> void:
	var waited := 0
	while player.casting() and waited < 600:
		await get_tree().process_frame
		waited += 1
	await frames(3)

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
	check(shown == ["hurry"],
		"which is the page and nothing else (%s)" % str(shown))
	var page := TouchPad.area(control_of("hurry"), screen())
	check(page.is_equal_approx(Rect2(Vector2.ZERO, screen())),
		"and the page is the whole of the screen (%s)" % str(page))
	var drawn: Array = []
	for c in TouchPad.CONTROLS:
		if pad.shown(c) and (not c.has("zone") or TouchPad.label_of(c) != "" or TouchPad.movable(c)):
			drawn.append(String(c.get("action", "move")))
	check(drawn.is_empty(), "none of them with a picture, and none of them movable (%s)" % str(drawn))

	# The right: a tap hurries the line and nothing else, and a thumb that stays
	# presses interact as well, once, until it lifts.
	touch(0, spot("jump"), true)
	await frames(2)
	check(Input.is_action_pressed("hurry") and not Input.is_action_pressed("jump")
			and not Input.is_action_pressed("interact"),
		"a thumb where JUMP was hurries the line, and is neither JUMP nor a turn of the page")
	touch(0, spot("jump"), false)
	await frames(2)
	check(not Input.is_action_pressed("hurry") and not Input.is_action_pressed("interact"),
		"and lifted, it has let go")
	touch(0, Vector2(700, 300), true)
	await frames(2)
	check(Input.is_action_pressed("hurry") and not Input.is_action_pressed("attack"),
		"so does one on the empty right of the screen")
	await get_tree().create_timer(TouchPad.HOLD + 0.1).timeout
	await frames(2)
	check(Input.is_action_pressed("interact") and Input.is_action_pressed("hurry"),
		"and kept there past a hold, it presses interact as well")
	drag(0, Vector2(300, 300))
	await frames(2)
	check(Input.is_action_pressed("interact") and not Input.is_action_pressed("move_up")
			and not Input.is_action_pressed("move_down"),
		"still holding it when it wanders to the left, which is the same page")
	touch(0, Vector2(300, 300), false)
	await frames(2)
	check(not Input.is_action_pressed("interact") and not Input.is_action_pressed("hurry"),
		"and lifted, it lets go of both")

	# The left is the page too: where the stick grows while there is somebody to
	# play, a thumb reads. Picking an answer is not the console's — the box puts
	# each on a plate of its own (`tests/mobile/talk_touch_test`).
	touch(0, Vector2(200, 400), true)
	await frames(3)
	check(Input.is_action_pressed("hurry") and not pad.stick_showing()
			and not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_down"),
		"a thumb on the left hurries the line like any other, and grows no stick")
	touch(0, Vector2(200, 400), false)
	await frames(2)
	check(not Input.is_action_pressed("hurry"), "until it lifts")

	# The faces coming and going under a thumb that stays down: what it was
	# doing was the face's, and it does nothing on the next until it lifts.
	touch(0, Vector2(700, 300), true)
	await get_tree().create_timer(TouchPad.HOLD + 0.1).timeout
	await frames(2)
	player.talk_locked = false
	await frames(3)
	check(pad.face == TouchPad.Face.PLAY and not Input.is_action_pressed("interact"),
		"a hold still down as the conversation ends is let go of")
	drag(0, spot("jump"))
	await frames(2)
	check(not Input.is_action_pressed("jump"), "and its thumb, dragged over JUMP, presses nothing")
	touch(0, spot("jump"), false)
	await frames(2)
	touch(0, spot("jump"), true)
	await frames(2)
	check(Input.is_action_pressed("jump"), "until it has lifted and come down again")
	touch(0, spot("jump"), false)
	await frames(2)

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

## --- HIT is USE by something to use --------------------------------------------

## The weapon's button is the interact key while the player stands where
## interacting would do something — here, in a raid's exit — and the weapon's
## again a step away. A thumb already down keeps what it pressed.
func _hit_is_use() -> void:
	var room: Room = raid.room
	check(room != null and not room.extraction.is_empty(), "the room has an exit to stand in")
	if room == null or room.extraction.is_empty():
		return
	var exit_at := room.extraction_rect().get_center()
	var away := exit_at + Vector2(-300.0, 0.0)
	player.global_position = away
	player.velocity = Vector2.ZERO
	await frames(4)
	check(not pad.use_near and TouchPad.label_of(control_of("attack"), pad.uses(control_of("attack"))) == Controls.word_for("attack"),
		"away from anything to use the button is HIT")
	touch(0, spot("attack"), true)
	await frames(3)
	check(Input.is_action_pressed("attack") and not Input.is_action_pressed("interact"), "and swings")
	# Walked into the exit with the thumb still down: still swinging.
	player.global_position = exit_at
	await frames(4)
	check(pad.use_near, "standing in the exit, USE would do something")
	check(Input.is_action_pressed("attack") and not Input.is_action_pressed("interact"),
		"but a thumb already down keeps swinging")
	touch(0, spot("attack"), false)
	await frames(3)
	check(TouchPad.label_of(control_of("attack"), pad.uses(control_of("attack"))) == Controls.word_for("interact"),
		"lifted, the button reads USE")
	var held_before := room.extract_hold
	touch(0, spot("attack"), true)
	await frames(6)
	check(Input.is_action_pressed("interact") and not Input.is_action_pressed("attack"),
		"and a thumb on it holds USE, not the weapon")
	check(room.extract_hold > held_before, "which is really extracting (%.2f)" % room.extract_hold)
	# Walked out of the exit with the thumb still down: still holding USE.
	player.global_position = away
	await frames(4)
	check(Input.is_action_pressed("interact") and not Input.is_action_pressed("attack"),
		"walking out with the thumb down keeps holding USE")
	touch(0, spot("attack"), false)
	await frames(3)
	check(not Input.is_action_pressed("interact") and not pad.use_near, "until it lifts, and then it is HIT again")

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
	check(Controls.short_label_for("cast_skill") == Controls.word_for("cast_skill")
			and Controls.word_for("cast_skill") != "",
		"and what casts, the same way ('%s')" % Controls.short_label_for("cast_skill"))

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
