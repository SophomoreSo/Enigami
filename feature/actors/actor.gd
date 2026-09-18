class_name Actor
extends CharacterBody2D

## Shared body for the player and every monster: health, elemental status and
## knockback. What an actor looks like is not here — `graphics/views/actor_view`
## attaches itself to every actor and reads the state below to draw it.

signal died(actor: Actor)
signal damaged(actor: Actor, amount: float)

@export var max_health: float = 40.0
var health: float = 40.0
var hurt_radius: float = 14.0
var team: int = 1  ## 0 = player, 1 = monsters
## Size of the collider, which is also what a sprite has to stand on.
var body_size: Vector2 = Vector2(20.0, 30.0)
## Which way the actor is facing: +1 right, -1 left. A dash with no direction
## held goes this way, so it is a rule and not only a flipped sprite.
var facing: int = 1

var burn_time: float = 0.0
var burn_dps: float = 0.0
var chill_time: float = 0.0
var invuln: float = 0.0
var dead: bool = false

func _ready() -> void:
	health = max_health
	add_to_group("actors")

func speed_scale() -> float:
	return 0.45 if chill_time > 0.0 else 1.0

func _process_status(delta: float) -> void:
	if invuln > 0.0:
		invuln -= delta
	if chill_time > 0.0:
		chill_time -= delta
	if burn_time > 0.0:
		burn_time -= delta
		apply_damage(burn_dps * delta, [], null, false)

## Returns the damage actually dealt (0 when blocked or already dead).
##
## `is_hit` separates a struck blow from a tick of damage over time: a tick
## ignores i-frames (it is already paid for) and does not count as a connection,
## so nothing reacts to it. Burning through an invulnerable roll still hurts.
func apply_damage(amount: float, elements: Array = [], _source: Node = null, is_hit: bool = true) -> float:
	if dead or amount <= 0.0:
		return 0.0
	if invuln > 0.0 and is_hit:
		return 0.0
	health -= amount
	if is_hit:
		damaged.emit(self, amount)
	for e in elements:
		if e == "FIRE":
			burn_time = maxf(burn_time, 2.5)
			burn_dps = maxf(burn_dps, amount * 0.22)
		elif e == "ICE":
			chill_time = maxf(chill_time, 2.0)
	if health <= 0.0:
		_kill()
	return amount

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)

## A push the world is putting on this actor — a knockback, GRAVITY's drag —
## kept apart from the motion the actor chooses for itself.
##
## Every body here assigns `velocity` outright each physics frame: a turret
## writes zero into it, a patroller writes its patrol speed, a runner walks it
## towards its quarry. A push added into `velocity` was therefore gone before it
## had moved anything — a Sentry or a Lobber did not budge at all, and GRAVITY,
## which is nothing but pushes, did nothing whatsoever. It has to live somewhere
## the movement code does not write.
var shove: Vector2 = Vector2.ZERO

## How fast a push bleeds off, in pixels per second per second. A shove reads as
## something that lands and is then over: at this rate a full-strength GRAVITY
## drag runs for about half a second and carries an enemy some seventy pixels,
## a good part of the way in from the edge of the field.
const SHOVE_DECAY := 620.0

## Below this there is no push left worth moving anything for.
const SHOVE_MIN := 8.0

func knockback(dir: Vector2, force: float) -> void:
	shove += dir.normalized() * force

## Moves the body by whatever the world is pushing it with, and lets that push
## die down. A body calls this once a physics frame, straight after its own
## `move_and_slide`, so the two motions stay separate and neither erases the
## other.
func apply_shove(delta: float) -> void:
	if shove.length() < SHOVE_MIN:
		shove = Vector2.ZERO
		return
	var hit := move_and_collide(shove * delta)
	if hit != null:
		# Run along whatever stopped it rather than sticking to it, so a drag
		# that meets a wall still gathers the room along that wall.
		shove = shove.slide(hit.get_normal())
	shove = shove.move_toward(Vector2.ZERO, SHOVE_DECAY * delta)

func _kill() -> void:
	if dead:
		return
	dead = true
	died.emit(self)
	Cues.at(&"death", global_position, {"actor": self})
	queue_free()

func health_ratio() -> float:
	return clampf(health / maxf(max_health, 1.0), 0.0, 1.0)

func face(dir: int) -> void:
	if dir != 0:
		facing = signi(dir)

## Adds a rectangular collider sized to the silhouette.
func _make_body(w: float, h: float) -> void:
	body_size = Vector2(w, h)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	shape.shape = rect
	add_child(shape)
