class_name TouchPad
extends Control

## The console the game draws on the glass: a thumbstick under the left thumb,
## and under the right a stick per skill, one for the weapon, and the keys that
## take no direction.
##
## Laid out the way a phone MOBA is, because that is the scheme this game's
## controls actually fit:
##
##   * **The left thumb is a stick, and there is nothing there until it lands.**
##     The left of the screen is empty; a thumb put down anywhere in it grows
##     the stick under itself, and lifting takes it away again. So it is never
##     somewhere to reach for and never in the way of the fight. It is analog —
##     the game reads movement as the strength of two actions, so a stick half
##     over walks and a stick hard over runs, which a cross of four keys could
##     never say.
##   * **A skill button is a stick too.** Press it and the slot is armed and
##     begins to charge; drag and the charge aims; let go and it casts, where
##     you were pointing, with everything the hold paid for. The game's own
##     hold-to-charge is what a phone MOBA already asks a thumb to do — press,
##     drag, release — so the two are the same gesture and nothing had to be
##     invented. The weapon key is the same stick without the charge.
##   * **Everything else is a key.** Jump, dash, interact and the three screens
##     take no direction, so they are buttons and nothing more.
##
## Drawn rather than built, in UiKit's pixel look — `PixelDraw`, Silkscreen at
## its own size, whole blocks — so a phone is playing the same game a desk is.
## The sticks are round because a stick is round; `PixelDraw.disc` and `ring`
## rasterise a circle on the grid rather than drawing a smooth one.
##
## What a press does to the game is not decided here. A control says which
## actions it is holding and `Touch` (`app/touch.gd`) sends them, so this file
## knows nothing about charging and the player knows nothing about thumbs.
##
## **Where the controls sit is the whole design.** The screen is 1280x720
## whatever the window is doing — `canvas_items` stretch, aspect kept — so the
## layout is written out in that space, once, and checked against the HUD rather
## than guessed at. The HUD owns the top-left corner down to y=112 and
## everything below y=592, so the hand sits between them.
## `tests/graphics/touch_pad_test` holds it all there.

## What a control is.
##
##   KEY   a button. Pressed while a thumb is on it, and nothing more.
##   MOVE  the movement stick. It has a zone rather than a place: it is drawn
##         nowhere until a thumb lands somewhere in that zone, grows there, and
##         is gone again the moment the thumb lifts.
##   AIM   a button that is also a stick. It holds its action the whole time and
##         the drag off it is where the cast goes.
enum Kind { KEY, MOVE, AIM }

## Which controls are on the screen. The shell picks it — `Game._touch_face` —
## since which of these the player is standing in is the shell's question and
## not the picture's.
##
##   PLAY    somebody has the controls: everything.
##   TALK    a conversation or a scene has them: the stick, which picks an
##           answer, and the key that turns the page.
##   SCREEN  a screen has them — the map, the assembly bench. Only the keys that
##           close it again, or a phone would have no way out of a window it
##           opened.
enum Face { NONE, PLAY, TALK, SCREEN }

## Every control: what it presses, where it sits in the 1280x720 the game is
## drawn at, and which faces it appears on.
##
## A round control carries `at` and `radius`; the three screens carry a `rect`
## instead, because they are labelled plates rather than things a thumb rests
## on, and looking different is how they say so. An `arm` is an action pressed
## alongside the held one — a slot stick arms its slot and charges through
## `cast_skill`, which is what makes one button a whole skill. A `slot` is which
## of the player's slots it is, so a button for a slot they do not carry is not
## drawn and does not answer.
const CONTROLS := [
	# The stick. It has no place of its own — only a `zone` a thumb may summon
	# it anywhere inside, which is the whole left of the screen between the
	# health bars and the slot cards. That is the point of it: the hand goes
	# where it likes and the stick comes to the hand.
	{"kind": Kind.MOVE, "radius": 78.0, "knob": 30.0,
		"zone": Rect2(0, 120, 456, 472), "faces": [Face.PLAY, Face.TALK]},
	# One stick per slot, in a row above the hand. Press to arm and charge, drag
	# to aim, let go to cast.
	{"kind": Kind.AIM, "action": "cast_skill", "arm": "skill_1", "slot": 0,
		"at": Vector2(988, 320), "radius": 32.0, "text": "1", "faces": [Face.PLAY]},
	{"kind": Kind.AIM, "action": "cast_skill", "arm": "skill_2", "slot": 1,
		"at": Vector2(1064, 320), "radius": 32.0, "text": "2", "faces": [Face.PLAY]},
	{"kind": Kind.AIM, "action": "cast_skill", "arm": "skill_3", "slot": 2,
		"at": Vector2(1140, 320), "radius": 32.0, "text": "3", "faces": [Face.PLAY]},
	{"kind": Kind.AIM, "action": "cast_skill", "arm": "skill_4", "slot": 3,
		"at": Vector2(1216, 320), "radius": 32.0, "text": "4", "faces": [Face.PLAY]},
	# The hand. USE and DASH take no direction; the weapon does, so it is a
	# stick; JUMP is the biggest and sits where the thumb rests.
	{"kind": Kind.KEY, "action": "interact", "at": Vector2(1102, 430), "radius": 34.0,
		"faces": [Face.PLAY, Face.TALK]},
	{"kind": Kind.KEY, "action": "dash", "at": Vector2(1206, 430), "radius": 34.0,
		"faces": [Face.PLAY]},
	{"kind": Kind.AIM, "action": "attack", "at": Vector2(1084, 522), "radius": 42.0,
		"faces": [Face.PLAY]},
	{"kind": Kind.KEY, "action": "jump", "at": Vector2(1196, 522), "radius": 46.0,
		"faces": [Face.PLAY]},
	# The screens, in the far corner where nothing is reached for by accident.
	{"kind": Kind.KEY, "action": "open_editor", "rect": Rect2(1048, 24, 64, 44),
		"faces": [Face.PLAY, Face.SCREEN]},
	{"kind": Kind.KEY, "action": "open_map", "rect": Rect2(1120, 24, 64, 44),
		"faces": [Face.PLAY, Face.SCREEN]},
	{"kind": Kind.KEY, "action": "pause", "rect": Rect2(1192, 24, 64, 44),
		"faces": [Face.PLAY, Face.SCREEN]},
]

## How far a thumb rides out from a skill button before the cast has a direction
## of its own, and how far out the knob is drawn. Generous, because a short
## throw makes a fine aim impossible — the ring is drawn over whatever is beside
## it, which costs nothing for the moment it is up.
const AIM_DEAD := 16.0
const AIM_REACH := 92.0
const AIM_KNOB := 22.0

## How far the movement stick must be pushed before it says anything. Sideways
## it is small, since the strength past it is remapped back to a full range and
## a walk should start as soon as the thumb moves. Up and down it is firm: those
## two only pick an answer in a conversation, and a thumb running sideways
## wanders across them.
const STICK_DEAD := 0.22
const STICK_UPDOWN := 0.5

## How far outside its edge a control still answers.
const SLOP := 4.0

## The mouse, as a finger. A desk has one pointer and no index to tell it by.
const MOUSE := -1

const FILL := Color(0.05, 0.06, 0.09, 0.55)
const FILL_HELD := Color(0.16, 0.34, 0.44, 0.82)
const EDGE := Color(0.45, 0.85, 1.0, 0.38)
const EDGE_HELD := Color(0.6, 0.95, 1.0, 0.95)
const INK := Color(0.74, 0.84, 0.95, 0.8)
const INK_HELD := Color(1, 1, 1, 1)
## A slot the weapon refuses. The same red the slot cards use for it, quieted:
## the button is still there and still presses, it just says beforehand what the
## card below it says after.
const EDGE_OFF := Color(0.85, 0.42, 0.44, 0.34)
const INK_OFF := Color(0.82, 0.5, 0.52, 0.55)
## The ring a skill aims in, and the pips that walk out to the knob.
const AIM_EDGE := Color(0.55, 0.92, 1.0, 0.5)

## Which controls are up. Set by the shell every frame; changing it lets go of
## everything, so a key that was being held when the screen changed does not
## stay down behind the screen that replaced it.
var face: int = Face.NONE:
	set(value):
		if value == face:
			return
		face = value
		_let_go()

## Finger (or MOUSE) -> the index into CONTROLS it is resting on.
var _down: Dictionary = {}
## Where the thumb that summoned the movement stick landed, where the ring is
## drawn, and how far it is pushed, -1 to 1. All meaningless while no thumb is
## on it: see `stick_showing`.
##
## The two places are usually the same one and are not always: a thumb landing
## within a radius of the edge of the zone would draw a ring half off the screen
## or over the slot cards, so the ring slides in to fit. **The push is measured
## from where the thumb landed either way**, or a stick summoned in the corner
## would read as shoved the moment it appeared, and the player would walk off
## without having asked to.
var _stick_from: Vector2 = Vector2.ZERO
var _stick_at: Vector2 = Vector2.ZERO
var _stick: Vector2 = Vector2.ZERO
## The skill or weapon stick being aimed, and the thumb's throw off its middle.
var _aim_from: int = -1
var _aim_off: Vector2 = Vector2.ZERO
## Whoever is being played and how many slots they carry, read once a frame
## rather than once per control: the pad asks three questions of them while it
## draws, and walking the tree for each would be three walks a frame.
var _player: Player = null
var _slots: int = 0
## Whether this machine has ever reported a finger. The system turns a touch
## into a mouse click as well as reporting the touch, and answering both would
## press every control twice; once there are fingers the mouse is one of them.
var _fingers: bool = false
var _px := PixelDraw.new(self)

func _ready() -> void:
	# Kept running while the tree is stopped, so the pad can take itself off the
	# screen — and let go of what it was holding — when the game pauses.
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.fill_screen(self)
	# Answered in `_input`, which sees a press whether or not a Control under
	# the cursor would have: nothing here is a button in the GUI's sense.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

## Handed back on the way out: a pad freed while it was up would leave the mouse
## in its drawer and an action pressed, with nothing left to release either.
func _exit_tree() -> void:
	if visible:
		visible = false
		Touch.set_up(false)

func _process(_delta: float) -> void:
	UiKit.sync_screen(self)
	var up: bool = Touch.wanted() and face != Face.NONE and not get_tree().paused
	if up != visible:
		visible = up
		if not up:
			_down.clear()
		# `Touch` puts the mouse away while the pad has the screen and lets go
		# of every key when it leaves. Told here because this is the only thing
		# that knows whether the pad is on the screen.
		Touch.set_up(up)
	if not up:
		return
	_player = _find_player()
	_slots = 0 if _player == null else _player.runners.size()
	_drive()
	Touch.aim(aim())
	queue_redraw()

## --- what the sticks say ----------------------------------------------------

## The movement stick, as the four actions the game reads movement through.
##
## Sideways is analog: the strength is how far the stick is over, remapped so it
## runs the whole way from nothing to everything past the deadzone rather than
## jumping to a fifth the moment it is felt. Up and down are not — they only
## pick an answer in a conversation, and an answer is picked or it is not.
func _drive() -> void:
	_lean("move_right", _stick.x, STICK_DEAD)
	_lean("move_left", -_stick.x, STICK_DEAD)
	_lean("move_down", _stick.y, STICK_UPDOWN)
	_lean("move_up", -_stick.y, STICK_UPDOWN)

func _lean(action: String, amount: float, dead: float) -> void:
	if amount < dead:
		Touch.release(action)
		return
	Touch.press(action, clampf((amount - dead) / (1.0 - dead), 0.0, 1.0))

## Where the player is pointing, as a stick: the skill being aimed if one is,
## the movement stick if it is pushed, and the way they are facing otherwise.
##
## A pointer is the one control a phone cannot offer — there is nothing on the
## glass until a finger lands, and where it lands is where it is going. So the
## pad aims the way a gamepad does, which the game already understands and
## `Player._update_aim` needed no line changed for.
##
## The skill being aimed wins, which is the whole of the scheme: a thumb can run
## right and throw a skill up and to the left in the same moment. Facing is the
## last resort, so a tap with no throw in it still goes somewhere the player
## meant — forwards, where they are walking.
func aim() -> Vector2:
	if _aim_from >= 0 and _aim_off.length() >= AIM_DEAD:
		return _aim_off.normalized()
	if _stick.length() >= STICK_DEAD:
		return _stick.normalized()
	return Vector2(_facing(), 0.0)

func _facing() -> float:
	return 1.0 if _player == null else float(_player.facing)

func _find_player() -> Player:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player:
			return p as Player
	return null

## --- fingers ----------------------------------------------------------------

## Handled here rather than in `_gui_input` for two reasons: the GUI hands one
## pointer to one Control, and the pad needs two thumbs at once; and a press
## that lands on a control is marked handled so it reaches nothing behind it.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		_saw_a_finger(touch.index)
		_finger(touch.index, touch.position, touch.pressed)
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		_saw_a_finger(drag.index)
		_finger(drag.index, drag.position, true)
		return
	if _fingers:
		return          # the mouse under a finger is that finger again
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		_finger(MOUSE, click.position, click.pressed)
		return
	var moved := event as InputEventMouseMotion
	if moved != null and _down.has(MOUSE):
		_finger(MOUSE, moved.position, true)

## The first finger this machine has ever reported.
##
## The system turns a touch into a click as well, and hands over the click
## first, so the first finger of all lands on its control twice: once as itself
## and once as a mouse that is not there. The phantom would then never lift —
## every mouse event after this one is ignored — and a control something is
## still holding is one the finger that really lifted cannot let go of.
##
## So the control is handed over rather than let go of. Releasing it and pressing
## it again would be a release inside the same frame as the press, and on a
## skill stick a release is a cast.
func _saw_a_finger(index: int) -> void:
	if _fingers:
		return
	_fingers = true
	if _down.has(MOUSE):
		_down[index] = _down[MOUSE]
		_down.erase(MOUSE)

## One finger: where it is now, and whether it is still down.
func _finger(index: int, at: Vector2, pressed: bool) -> void:
	var was: int = _down.get(index, -1)
	# A stick keeps the finger that started it, however far out it is dragged —
	# that is what makes it a stick rather than a button you slid off. A key
	# lets go the moment the thumb leaves it, and may take the next key along.
	if pressed and was >= 0 and _is_stick(was):
		_drag(was, at)
		get_viewport().set_input_as_handled()
		return
	var now: int = _under(at) if pressed else -1
	if now == was:
		if now >= 0:
			get_viewport().set_input_as_handled()
		return
	if now < 0:
		_down.erase(index)
	else:
		_down[index] = now
	# Let go first, then take: a second thumb already on what is being left
	# keeps it down, and what is being taken up is never released by this one.
	if was >= 0:
		_drop(was)
	if now >= 0:
		_take(now, at)
	if now >= 0 or was >= 0:
		get_viewport().set_input_as_handled()

func _is_stick(i: int) -> bool:
	return int(CONTROLS[i]["kind"]) != Kind.KEY

## A thumb has landed on `i`.
func _take(i: int, at: Vector2) -> void:
	var c: Dictionary = CONTROLS[i]
	match int(c["kind"]):
		Kind.MOVE:
			# The stick grows under the thumb. The ring slides in where it must
			# to stay on the screen; what the thumb is asking for is measured
			# from the thumb regardless — see `_stick_from`.
			var r: float = c["radius"]
			var zone: Rect2 = c["zone"]
			_stick_from = at
			_stick_at = Vector2(
				clampf(at.x, zone.position.x + r, zone.end.x - r),
				clampf(at.y, zone.position.y + r, zone.end.y - r))
			_stick = Vector2.ZERO
			return          # a stick makes no click; a thumb resting is not a press
		Kind.AIM:
			if c.has("arm"):
				Touch.press(String(c["arm"]))
			Touch.press(String(c["action"]))
			_aim_from = i
			_aim_off = Vector2.ZERO
		_:
			Touch.press(String(c["action"]))
	Audio.play("ui")

## The thumb on `i` has gone. Called after the finger has been taken out of
## `_down`, so what is left there is what is still being held.
func _drop(i: int) -> void:
	var c: Dictionary = CONTROLS[i]
	match int(c["kind"]):
		Kind.MOVE:
			_stick = Vector2.ZERO
			_stick_at = Vector2.ZERO
			_stick_from = Vector2.ZERO
			_drive()
		Kind.AIM:
			_let_go_of(String(c["action"]))
			if c.has("arm"):
				_let_go_of(String(c["arm"]))
			if _aim_from == i:
				_aim_from = -1
				_aim_off = Vector2.ZERO
		_:
			_let_go_of(String(c["action"]))

## The thumb on `i` has moved to `at`.
func _drag(i: int, at: Vector2) -> void:
	var c: Dictionary = CONTROLS[i]
	if int(c["kind"]) == Kind.MOVE:
		var v: Vector2 = (at - _stick_from) / float(c["radius"])
		_stick = v if v.length() <= 1.0 else v.normalized()
	else:
		_aim_from = i
		_aim_off = at - Vector2(c["at"])

## Lets go of `action` unless some other finger is still holding it. Two
## controls can press the same one: every slot stick charges through
## `cast_skill`, so one thumb lifting must not cast another thumb's skill.
func _let_go_of(action: String) -> void:
	for f in _down.values():
		var c: Dictionary = CONTROLS[int(f)]
		if String(c.get("action", "")) == action or String(c.get("arm", "")) == action:
			return
	Touch.release(action)

## The control under `at`, or -1. Only what is on the face that is up answers: a
## thumb where JUMP sits during a conversation presses nothing. The stick is
## asked last, so its zone never takes a press meant for a button inside it.
func _under(at: Vector2) -> int:
	var stick := -1
	for i in CONTROLS.size():
		var c: Dictionary = CONTROLS[i]
		if not shown(c):
			continue
		if int(c["kind"]) == Kind.MOVE:
			if (c["zone"] as Rect2).has_point(at):
				stick = i
		elif c.has("rect"):
			if (c["rect"] as Rect2).grow(SLOP).has_point(at):
				return i
		elif at.distance_to(Vector2(c["at"])) <= float(c["radius"]) + SLOP:
			return i
	return stick

func _let_go() -> void:
	_down.clear()
	_stick = Vector2.ZERO
	_stick_at = Vector2.ZERO
	_stick_from = Vector2.ZERO
	_aim_from = -1
	_aim_off = Vector2.ZERO
	Touch.release_all()

## --- the picture ------------------------------------------------------------

## Whether the movement stick is on the screen at all, which is exactly whether
## a thumb is on it. There is nothing drawn where it waits, because it does not
## wait anywhere — see `_draw_stick`.
func stick_showing() -> bool:
	for f in _down.values():
		if int(CONTROLS[int(f)]["kind"]) == Kind.MOVE:
			return true
	return false

## Whether `c` can do anything if it is pressed. A weapon refuses some boards,
## and a button that means "cast" should say so before the thumb goes down
## rather than after — the slot card below it only says so once it is armed.
func usable(c: Dictionary) -> bool:
	if not c.has("slot") or _player == null:
		return true
	return _player.can_cast(int(c["slot"]))

## Whether `c` is on the screen: on the face that is up, and, for a slot stick,
## a slot the player is actually carrying. A slot they carry but cannot cast is
## still drawn — see `usable` — because it is theirs and a weapon away from
## working.
func shown(c: Dictionary) -> bool:
	if not (c["faces"] as Array).has(face):
		return false
	if c.has("slot"):
		return int(c["slot"]) < _slots
	return true

## The square of screen a control covers, for anything that has to know it does
## not cover something else.
static func area(c: Dictionary) -> Rect2:
	if c.has("rect"):
		return c["rect"]
	if int(c["kind"]) == Kind.MOVE:
		return c["zone"]
	var r: float = c["radius"]
	return Rect2(Vector2(c["at"]) - Vector2.ONE * r, Vector2.ONE * r * 2.0)

## What is written on a control: a slot says its number, and everything else is
## the word `controls.pad` gives its action — the same word the HUD prints
## through `Controls.short_label_for`, so a key and everything that tells the
## player to press it say the same thing. The stick says nothing; it is a stick.
static func label_of(c: Dictionary) -> String:
	if int(c["kind"]) == Kind.MOVE:
		return ""
	if c.has("text"):
		return String(c["text"])
	return Controls.word_for(String(c["action"]))

func _draw() -> void:
	for i in CONTROLS.size():
		var c: Dictionary = CONTROLS[i]
		if not shown(c):
			continue
		match int(c["kind"]):
			Kind.MOVE:
				if stick_showing():
					_draw_stick(c)
			_:
				_draw_button(c, _held(c), usable(c))
	# The throw is drawn last and over everything, since it reaches across
	# whatever is beside the button it came from.
	if _aim_from >= 0 and _aim_off.length() >= AIM_DEAD:
		_draw_throw(CONTROLS[_aim_from])

func _held(c: Dictionary) -> bool:
	for f in _down.values():
		if CONTROLS[int(f)] == c:
			return true
	return false

## The movement stick: the ring it swings in, and the knob inside it — drawn
## only while a thumb is on it, and only where that thumb put it. Nothing is
## drawn while none is, which is the whole of the design: an empty left half is
## a left half you can see the fight through, and a stick that grows under the
## thumb is never a stick anybody has to find first.
func _draw_stick(c: Dictionary) -> void:
	var r: float = c["radius"]
	var knob: float = c["knob"]
	_px.disc(_stick_at, r, FILL)
	_px.ring(_stick_at, r, PixelDraw.PX, EDGE_HELD)
	var at := _stick_at + _stick * (r - knob)
	_px.disc(at, knob, FILL_HELD)
	_px.ring(at, knob, PixelDraw.PX * 2, EDGE_HELD)

## A button, round or plated, with its word in the middle of it.
func _draw_button(c: Dictionary, held: bool, live: bool) -> void:
	var ink := INK_HELD if held else (INK if live else INK_OFF)
	var edge := EDGE_HELD if held else (EDGE if live else EDGE_OFF)
	if c.has("rect"):
		var r: Rect2 = c["rect"]
		_px.rect(r, FILL_HELD if held else FILL)
		_px.frame(r, edge)
		_px.text_centered(r.position + Vector2(0, r.size.y * 0.5 + 5.0),
			label_of(c), ink, r.size.x)
		return
	var at := Vector2(c["at"])
	var radius: float = c["radius"]
	_px.disc(at, radius, FILL_HELD if held else FILL)
	_px.ring(at, radius, PixelDraw.PX, edge)
	# Capitals stand 10 high in this face and nothing descends, so a baseline
	# five below the middle puts a word in the middle of its button.
	_px.text_centered(at - Vector2(radius, -5.0), label_of(c), ink, radius * 2.0)

## Where a held skill is pointing: the ring it is thrown within, a few pips
## walking out along the throw, and the knob at the end of it. Big enough to
## read out of the corner of an eye during a fight, which is the only time it
## is ever up.
func _draw_throw(c: Dictionary) -> void:
	var at := Vector2(c["at"])
	var d := _aim_off.normalized()
	_px.ring(at, AIM_REACH, PixelDraw.PX, AIM_EDGE)
	var step := (AIM_REACH - float(c["radius"])) / 4.0
	for i in 3:
		_px.disc(at + d * (float(c["radius"]) + step * float(i + 1)), 7.0, AIM_EDGE)
	var knob := at + d * AIM_REACH
	_px.disc(knob, AIM_KNOB, FILL_HELD)
	_px.ring(knob, AIM_KNOB, PixelDraw.PX * 2, EDGE_HELD)
