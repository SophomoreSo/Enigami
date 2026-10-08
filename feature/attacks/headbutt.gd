class_name Headbutt
extends DashSlash

## A short lunge along the aim that drives the head into the first enemy in the
## way, and stops there, short of it: SWIFT STRIKE's lunge cut off at what it
## meets rather than carried on through. PIERCE carries it on into the next
## one, and it stops against the last it strikes. It is the one attack with no
## weapon in it (`Weapons.BARE_FORMS`). It is a lunge for all that, and goes
## where a lunge goes: it draws as one (`DashSlashView`), and the attacker
## lands where it ends.

## Which way the head goes. `to` is no use for it: against a wall it can be
## `from` itself.
var aim: Vector2 = Vector2.RIGHT

func _cut() -> void:
	var length := from.distance_to(to)
	# The head is out in front of the body by the body's own reach, so what it
	# meets is whatever stands that close to the end of the line it travels.
	var front: float = attacker.hurt_radius if attacker != null and is_instance_valid(attacker) else 0.0
	var met: Array = []
	for a in Attacks.targets(team):
		var off: Vector2 = a.global_position - from
		var along := off.dot(aim)
		if along < -a.hurt_radius:
			continue   # behind it
		if absf(off.cross(aim)) > thickness + a.hurt_radius:
			continue   # beside the line
		if along - a.hurt_radius - front > length:
			continue   # further than it goes
		met.append([along, a])
	met.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var hits_left := 1 + payload.pierce
	var stop := length
	for entry in met:
		var a: Actor = entry[1]
		Attacks.resolve_hit(payload, a, a.global_position, aim, attacker, room, team)
		hits_left -= 1
		if hits_left <= 0:
			# Spent on this one: the head stops against it.
			stop = clampf(float(entry[0]) - a.hurt_radius - front, 0.0, length)
			break
	to = from + aim * stop
	if attacker != null and is_instance_valid(attacker):
		attacker.global_position = to
		# As at the end of any lunge: arriving does not carry the fall that got
		# it there (`DashSlash._cut`).
		attacker.velocity.y = 0.0
		if attacker.has_method("on_dashed"):
			attacker.on_dashed()
