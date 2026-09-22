class_name TouchPad
extends Control

## The console the game draws on the glass: a movement cross under the left
## thumb, the hand that fights under the right, the four slots under the health
## bars and the three screens in the far corner.
##
## Drawn rather than built, in UiKit's pixel look — `PixelDraw`, Silkscreen at
## its own size, square unsmoothed edges a PIXEL wide — so a phone is playing
## the same game a desk is, and not a mobile port of it laid over the top. It
## is translucent for the same reason the HUD is sparse: the fight is behind it.
##
## What it does to the game is not decided here. A key says which action it is
## holding and `Touch` (`app/touch.gd`) sends that action, so this file knows
## nothing about jumping and the player knows nothing about thumbs.
##
## **Where the keys sit is the whole design.** The screen is 1280x720 whatever
## the window is doing — `canvas_items` stretch, aspect kept — so the layout is
## written out in that space, once, and checked against the HUD rather than
## guessed at. The HUD owns two bands of the screen and neither is negotiable:
## the bars and the weapon down the top-left corner, and the row of slot cards
## with its hint line across the bottom, which begins at y=592. So the thumbs
## sit higher than they would on a phone with nothing else on the screen —
## y=380 to y=580 — and `tests/graphics/touch_pad_test` holds them there.
##
## The cross is four keys and not eight. Movement in this game is left and
## right — `Player` reads one axis — and up and down are aim, so a thumb that
## wants to shoot upwards stops walking, the way it has in every game shaped
## like this one. Two thumbs on the cross still press two of them.

## Which keys are on the screen. The shell picks it — `Game._touch_face` — since
## which of these the player is standing in is the shell's question and not the
## picture's.
##
##   PLAY    somebody has the controls: everything.
##   TALK    a conversation or a scene has them: the two keys that pick an
##           answer, and the one that turns the page.
##   SCREEN  a screen has them — the map, the assembly bench. Only the keys that
##           close it again, or a phone would have no way out of a window it
##           opened.
enum Face { NONE, PLAY, TALK, SCREEN }

## One arrow, turned four ways by `PixelDraw.turn`: 0 up, 1 right, 2 down, 3 left.
const ARROW := [
	"...#...",
	"..###..",
	".#####.",
	"#######",
	"...#...",
	"...#...",
	"...#...",
]
## How many PIXELs an arrow pixel covers. 7 art pixels at 3 is 42 across a 64
## key — read at arm's length, and still whole blocks.
const ARROW_ZOOM := 3

## How far outside its edge a key still answers. Half the gap between two of
## them, so the cross has no dead line down the middle of it and no two keys
## overlap. Larger than that and a thumb on the gap would press whichever key
## the table happens to list first.
const SLOP := 2.0

## The mouse, as a finger. A desk has one pointer and no index to tell it by.
const MOUSE := -1

## Every key: the action it holds down, where it sits in the 1280x720 the game
## is drawn at, what is written on it, and which faces it appears on.
##
## What is written on a key is an arrow, a slot number, or — where it is neither
## — the word `controls.pad` gives that action. The HUD reads the same words
## through `Controls.short_label_for`, so a key and everything that tells the
## player to press it say the same thing.
const KEYS := [
	# The movement cross, under the left thumb.
	{"action": "move_up", "rect": Rect2(92, 380, 64, 64), "arrow": 0,
		"faces": [Face.PLAY, Face.TALK]},
	{"action": "move_left", "rect": Rect2(24, 448, 64, 64), "arrow": 3,
		"faces": [Face.PLAY]},
	{"action": "move_right", "rect": Rect2(160, 448, 64, 64), "arrow": 1,
		"faces": [Face.PLAY]},
	{"action": "move_down", "rect": Rect2(92, 516, 64, 64), "arrow": 2,
		"faces": [Face.PLAY, Face.TALK]},
	# The hand that fights, under the right. CAST is above JUMP rather than
	# beside it because it is held: a charge lasts, and a thumb holding one
	# should not be sitting on the key it jumps with.
	{"action": "cast_skill", "rect": Rect2(1124, 380, 64, 64),
		"faces": [Face.PLAY]},
	{"action": "interact", "rect": Rect2(1192, 380, 64, 64),
		"faces": [Face.PLAY, Face.TALK]},
	{"action": "dash", "rect": Rect2(1056, 448, 64, 64),
		"faces": [Face.PLAY]},
	{"action": "attack", "rect": Rect2(1192, 448, 64, 64),
		"faces": [Face.PLAY]},
	{"action": "jump", "rect": Rect2(1124, 516, 64, 64),
		"faces": [Face.PLAY]},
	# The four slots, in a row under the health bars. They say the same numbers
	# the cards along the bottom of the screen say, because they are the same
	# four slots and the cards are what they arm.
	{"action": "skill_1", "rect": Rect2(24, 150, 52, 48), "text": "1", "faces": [Face.PLAY]},
	{"action": "skill_2", "rect": Rect2(84, 150, 52, 48), "text": "2", "faces": [Face.PLAY]},
	{"action": "skill_3", "rect": Rect2(144, 150, 52, 48), "text": "3", "faces": [Face.PLAY]},
	{"action": "skill_4", "rect": Rect2(204, 150, 52, 48), "text": "4", "faces": [Face.PLAY]},
	# The screens, in the far corner where nothing is reached for by accident.
	{"action": "open_editor", "rect": Rect2(1048, 24, 64, 44),
		"faces": [Face.PLAY, Face.SCREEN]},
	{"action": "open_map", "rect": Rect2(1120, 24, 64, 44),
		"faces": [Face.PLAY, Face.SCREEN]},
	{"action": "pause", "rect": Rect2(1192, 24, 64, 44),
		"faces": [Face.PLAY, Face.SCREEN]},
]

const FILL := Color(0.05, 0.06, 0.09, 0.55)
const FILL_HELD := Color(0.16, 0.34, 0.44, 0.82)
const EDGE := Color(0.45, 0.85, 1.0, 0.38)
const EDGE_HELD := Color(0.6, 0.95, 1.0, 0.95)
const INK := Color(0.74, 0.84, 0.95, 0.8)
const INK_HELD := Color(1, 1, 1, 1)

## Which keys are up. Set by the shell every frame; changing it lets go of
## everything, so a key that was being held when the screen changed does not
## stay down behind the screen that replaced it.
var face: int = Face.NONE:
	set(value):
		if value == face:
			return
		face = value
		_let_go()

## Finger (or MOUSE) -> the index into KEYS it is resting on.
var _down: Dictionary = {}
## Whether this machine has ever reported a finger. The system turns a touch
## into a mouse click as well as reporting the touch, and answering both would
## press every key twice; once there are fingers the mouse is one of them.
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
	Touch.aim(_aim())
	queue_redraw()

## --- fingers ----------------------------------------------------------------

## Handled here rather than in `_gui_input` for two reasons: the GUI hands one
## pointer to one Control, and the pad needs two thumbs at once; and a press
## that lands on a key is marked handled so it reaches nothing behind the pad.
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
## first, so the first finger of all lands on its key twice: once as itself and
## once as a mouse that is not there. The phantom would then never lift — every
## mouse event after this one is ignored — and a key something is still holding
## is a key the finger that really lifted cannot let go of.
##
## So the key is handed over rather than let go of. Releasing it and pressing it
## again would be a release inside the same frame as the press, and on the key
## that casts a skill, a release is a cast.
func _saw_a_finger(index: int) -> void:
	if _fingers:
		return
	_fingers = true
	if _down.has(MOUSE):
		_down[index] = _down[MOUSE]
		_down.erase(MOUSE)

## One finger, where it is now and whether it is still down. A finger that slides
## off one key and onto another lets go of the first and presses the second,
## which is what makes the cross playable without lifting a thumb off the glass.
func _finger(index: int, at: Vector2, pressed: bool) -> void:
	var was: int = _down.get(index, -1)
	var now: int = _key_at(at) if pressed else -1
	if now == was:
		if now >= 0:
			get_viewport().set_input_as_handled()
		return
	if now < 0:
		_down.erase(index)
	else:
		_down[index] = now
	# Let go first, then press: a second thumb already on the key being left
	# keeps it down, and a key being taken up is never released by this one.
	if was >= 0 and not _held_by_a_finger(was):
		Touch.release(String(KEYS[was]["action"]))
	if now >= 0:
		Touch.press(String(KEYS[now]["action"]))
		Audio.play("ui")
	if now >= 0 or was >= 0:
		get_viewport().set_input_as_handled()

func _held_by_a_finger(key: int) -> bool:
	for other in _down.values():
		if int(other) == key:
			return true
	return false

## The key under `at`, or -1. Only the keys on the face that is up answer: a
## thumb on the corner where JUMP sits during a conversation presses nothing.
func _key_at(at: Vector2) -> int:
	for i in KEYS.size():
		if not on_face(KEYS[i]):
			continue
		if (KEYS[i]["rect"] as Rect2).grow(SLOP).has_point(at):
			return i
	return -1

func _let_go() -> void:
	_down.clear()
	Touch.release_all()

## --- aiming -----------------------------------------------------------------

## Where the player is pointing, as a stick: the cross while a thumb is on it,
## and the way they are facing while none is.
##
## A pointer is the one control a phone cannot offer — there is nothing on the
## glass until a finger lands, and where it lands is where it is going. So the
## pad aims the way a gamepad does, which the game already understands, and the
## keys that say "aim up" and "aim down" on the rebinding screen finally do.
## Facing is the fallback so a shot always goes somewhere the player meant:
## forwards, where they are walking.
func _aim() -> Vector2:
	var v := Vector2(
		(1.0 if Touch.holding("move_right") else 0.0)
			- (1.0 if Touch.holding("move_left") else 0.0),
		(1.0 if Touch.holding("move_down") else 0.0)
			- (1.0 if Touch.holding("move_up") else 0.0))
	if v == Vector2.ZERO:
		v = Vector2(_facing(), 0.0)
	return v.normalized()

func _facing() -> float:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Actor:
			return float((p as Actor).facing)
	return 1.0

## --- the picture ------------------------------------------------------------

## Whether `key` is on the face that is up.
func on_face(key: Dictionary) -> bool:
	return (key["faces"] as Array).has(face)

## What is written on a key: an arrow draws itself, a slot says its number, and
## everything else is a word short enough to fit — checked, not hoped for.
static func label_of(key: Dictionary) -> String:
	if key.has("arrow"):
		return ""
	if key.has("text"):
		return String(key["text"])
	return Controls.word_for(String(key["action"]))

func _draw() -> void:
	for key in KEYS:
		if on_face(key):
			_draw_key(key)

func _draw_key(key: Dictionary) -> void:
	var r: Rect2 = key["rect"]
	var held := Touch.holding(String(key["action"]))
	_px.rect(r, FILL_HELD if held else FILL)
	_px.frame(r, EDGE_HELD if held else EDGE)
	var ink := INK_HELD if held else INK
	if key.has("arrow"):
		_px.icon_centered(r.get_center(), PixelDraw.turn(ARROW, int(key["arrow"])),
			ink, ARROW_ZOOM)
		return
	# Capitals stand 10 high in this face and nothing descends, so a baseline
	# five below the middle puts a word in the middle of its key.
	_px.text_centered(r.position + Vector2(0, r.size.y * 0.5 + 5.0),
		label_of(key), ink, r.size.x)
