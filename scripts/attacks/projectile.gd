class_name Projectile
extends Node2D

## A travelling bolt. Collision is resolved analytically against actor radii and
## the room's solid grid, so attacks need no physics bodies of their own.

var payload: Payload
var velocity: Vector2 = Vector2.RIGHT * 400.0
var team: int = 0
var attacker: Actor = null
var room = null
var radius: float = 5.0
var life: float = 2.6
var hits_left: int = 1
var gravity: float = 0.0
var homing_strength: float = 0.0
var reverse_at: float = -1.0
var _reversed: bool = false
var _hit: Array = []
var color: Color = Color(0.98, 0.85, 0.4)
var on_hit_cb: Callable = Callable()
var trail: Array[Vector2] = []

func setup(p: Payload, pos: Vector2, dir: Vector2, t: int, atk: Actor, rm) -> void:
	payload = p
	position = pos
	team = t
	attacker = atk
	room = rm
	radius = 5.0 * p.size
	velocity = dir.normalized() * 420.0 * p.speed
	hits_left = 1 + p.pierce
	homing_strength = 5.0 if p.homing else 0.0
	if p.reverse:
		reverse_at = 0.35
	z_index = 40
	color = _element_color(p)

static func _element_color(p: Payload) -> Color:
	if p.has_element("FIRE"):
		return Color(1.0, 0.5, 0.22)
	if p.has_element("ICE"):
		return Color(0.5, 0.85, 1.0)
	return Color(0.98, 0.85, 0.4)

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_expire()
		return
	if reverse_at > 0.0:
		reverse_at -= delta
		if reverse_at <= 0.0 and not _reversed:
			_reversed = true
			velocity = -velocity
	if homing_strength > 0.0:
		var t := Attacks.nearest_target(global_position, team, 520.0)
		if t != null:
			var want := (t.global_position - global_position).normalized() * velocity.length()
			velocity = velocity.lerp(want, clampf(homing_strength * delta, 0.0, 1.0))
	velocity.y += gravity * delta
	var step := velocity * delta
	position += step
	trail.append(position)
	if trail.size() > 8:
		trail.pop_front()

	if room != null and room.has_method("is_solid_at") and room.is_solid_at(global_position):
		Fx.burst(global_position, color, 5, 110.0)
		queue_free()
		return
	if room != null and room.has_method("out_of_bounds") and room.out_of_bounds(global_position):
		queue_free()
		return

	for a in Attacks.targets(team):
		if _hit.has(a):
			continue
		if global_position.distance_to(a.global_position) <= radius + a.hurt_radius:
			_hit.append(a)
			Attacks.resolve_hit(payload, a, global_position, velocity.normalized(), attacker, room, team)
			hits_left -= 1
			if hits_left <= 0:
				Fx.burst(global_position, color, 6, 130.0)
				queue_free()
				return
	queue_redraw()

func _expire() -> void:
	queue_free()

func _draw() -> void:
	for i in trail.size():
		var t := float(i) / float(maxi(trail.size(), 1))
		var c := color
		c.a = t * 0.4
		draw_circle(to_local(trail[i]), radius * (0.3 + t * 0.7), c)
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius * 0.5, Color(1, 1, 1, 0.9))
