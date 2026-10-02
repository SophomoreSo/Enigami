class_name ComputerHands
extends InputMiddleware

## The computer's hands on a body, in the place of the player's own: a demo, a
## test, anything that plays the character for whoever is at the desk.
##
## It stands at the head of the line, straight after the player's `Hands`, and
## drops what they said — every key, button and stick — so the person watching
## moves nothing. What goes down the line instead is what it has been told:
## which way to walk, what is held, what was pressed. Everything after it is as
## it was. A hold still stops it and a walk still steers it: the computer plays
## by the rules the player does.
##
## It points with the game's own pointer and never the system's. `point_at`
## leads the crosshair to a place in the world (`Pointer.lead_to`) and the aim
## is read off where that lands, so a place off the screen is aimed at from the
## screen's edge, as a hand would have to. While it is on a line the body is
## taken over (`takes_over`), which is what tells `Pointer` to leave the
## crosshair to it and show the system pointer beside it.
##
## What is not on the line is not its to press: `interact`, the keys that open
## a screen and the pause menu are read off `Input` by whoever answers them, so
## the person at the desk can still pause a game the computer is playing.

## Which way to walk, -1 left to 1 right, and how hard.
var move: float = 0.0
## Crouching, for as long as it is set.
var crouch: bool = false
## The attack button, held.
var attack: bool = false
## The cast button, held: what charges. Letting go of it is the release that
## casts, which is raised here.
var cast: bool = false:
	set(on):
		if cast and not on:
			_raise(&"cast_released")
		cast = on

## Where it is pointing, in the world, once it has been told (`point_at`). Until
## then the pointer rests wherever it was when the computer took over.
var _at: Vector2 = Vector2.ZERO
var _pointing: bool = false
## The acts raised and not yet read by both kinds of frame — see `_happened`.
var _acts: Dictionary = {}

func takes_over() -> bool:
	return true

## Points at `at`, a place in the world the body stands in, and keeps pointing
## there until it is told somewhere else.
func point_at(at: Vector2) -> void:
	_at = at
	_pointing = true

## A press of jump. Let go of early (`let_go_of_jump`) it cuts the arc short.
func jump() -> void:
	_raise(&"jump_pressed")

func let_go_of_jump() -> void:
	_raise(&"jump_released")

func dash() -> void:
	_raise(&"dash_pressed")

func process(_said: InputState) -> InputState:
	var s := InputState.new()
	s.move = clampf(move, -1.0, 1.0)
	s.crouch = crouch
	s.attack = attack
	s.cast = cast
	s.jump_pressed = _happened(&"jump_pressed")
	s.jump_released = _happened(&"jump_released")
	s.dash_pressed = _happened(&"dash_pressed")
	s.cast_released = _happened(&"cast_released")
	if body != null:
		_aim(s)
	return s

## The game's pointer, led to wherever this has been told to point, and the aim
## read off where it landed the way the player's is read off theirs
## (`Hands._aim`) — never a stick, and never the system's pointer.
func _aim(s: InputState) -> void:
	var at := Pointer.lead_to(body, _at) if _pointing else Pointer.world_point(body)
	var m := at - body.global_position
	s.aiming = true
	s.aim_reach = 1.0
	s.aim = m.normalized() if m.length() > 4.0 else Vector2.ZERO
	s.aim_point = at

func _raise(act: StringName) -> void:
	_acts[act] = {"physics": true, "drawn": true, "physics_on": -1, "drawn_on": -1}

## Whether `act` happened, as the frame being asked in sees it. The body takes a
## jump in the physics frame it moves in and a cast's release in the drawn one
## (`InputState`), so each kind of frame has to see an act once and neither may
## see it twice. An act waits for each kind in turn, and the frame that reads
## it keeps it for every reading of that frame — the line may be read more than
## once in one.
func _happened(act: StringName) -> bool:
	if not _acts.has(act):
		return false
	var a: Dictionary = _acts[act]
	var physics := Engine.is_in_physics_frame()
	var kind := "physics" if physics else "drawn"
	var frame := Engine.get_physics_frames() if physics else Engine.get_process_frames()
	if a[kind]:
		a[kind] = false
		a[kind + "_on"] = frame
	return int(a[kind + "_on"]) == frame
