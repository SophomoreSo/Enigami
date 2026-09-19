class_name CutsceneActor
extends CharacterBody2D

## Someone standing on the stage of a directed scene. It has a body and falls
## like anything else, so it stands on the floor and walks along it, and it has
## no will of its own: where it goes is whatever the beat running now told it.
##
## Deliberately not an `Actor`, for the same reason an `Npc` is not one: attacks
## find their targets through the "actors" group, and nobody in a cutscene
## should ever be a target. Nothing here is drawn —
## `story/view/cutscene_actor_view.gd` shows it.

const GRAVITY := 1700.0
const MAX_FALL := 900.0
const BODY := Vector2(18.0, 28.0)
## How fast a `move` walks when the direction does not say.
const WALK_SPEED := 70.0
## Near enough to a mark to have arrived. Wider than a pixel because a walk is
## stepped in whole frames and would otherwise tremble on the spot forever.
const ARRIVE := 3.0

## Who this is in the scene file — the key in `cast`.
var cast_id: String = ""
## The whole cast entry, passed straight through from the file. The rules read
## nothing out of it; the view reads `sprite`, exactly as a view reads an NPC's.
var cast: Dictionary = {}

var facing: int = 1
var body_size: Vector2 = BODY
## What the view must play regardless of motion, set by an `anim` direction, or
## "" to let the view choose from how fast this is moving.
var forced_anim: String = ""
## Off stage: still cast, not yet walked on. Nothing draws or moves.
var on_stage: bool = true

var _walk_to: float = 0.0
var _walk_speed: float = 0.0
var _walking: bool = false

func setup(id: String, entry: Dictionary) -> void:
	cast_id = id
	cast = entry
	if entry.has("facing"):
		face(-1 if String(entry["facing"]) == "left" else 1)

func _ready() -> void:
	add_to_group("cutscene_cast")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	shape.shape = rect
	add_child(shape)

func _physics_process(delta: float) -> void:
	if not on_stage:
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	if _walking:
		var gap := _walk_to - global_position.x
		if absf(gap) <= ARRIVE:
			# Land exactly on the mark rather than near it, so two cast members
			# sent to the same spot on different days end up in the same place.
			global_position.x = _walk_to
			stop()
		else:
			velocity.x = signf(gap) * _walk_speed
			face(int(signf(gap)))
	else:
		velocity.x = 0.0
	move_and_slide()

## Walks to `x` at `speed`, facing the way it is going. The beat that asked
## waits on `arrived`.
func walk_to(x: float, speed: float = WALK_SPEED) -> void:
	_walk_to = x
	_walk_speed = maxf(speed, 1.0)
	_walking = true

## Puts them down somewhere with no walk at all.
func place_at(point: Vector2) -> void:
	global_position = point
	velocity = Vector2.ZERO
	_walking = false

func stop() -> void:
	_walking = false
	velocity.x = 0.0

## Cuts a walk short by putting them where it was headed. What a press does to
## a beat still playing out: the scene never makes anyone wait for a walk.
func finish_walk() -> void:
	if _walking:
		global_position.x = _walk_to
		stop()

func walking() -> bool:
	return _walking

func arrived() -> bool:
	return not _walking

func face(dir: int) -> void:
	if dir != 0:
		facing = signi(dir)
