class_name Attacks
extends RefCounted

## Turns a resolved Payload into real things in the world, and resolves the
## hits those things cause (including trigger payloads).

## Every living actor that `team` is allowed to hurt.
static func targets(team: int) -> Array:
	var out: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return out
	for a in tree.get_nodes_in_group("actors"):
		if a is Actor and not a.dead and a.team != team:
			out.append(a)
	return out

static func nearest_target(pos: Vector2, team: int, max_dist: float = 1e9) -> Actor:
	var best: Actor = null
	var best_d := max_dist
	for a in targets(team):
		var d: float = pos.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best

static func container() -> Node:
	return Arena.current()

## A trigger's follow-up waits this long rather than going off inside the hit
## that caused it. Fired inline, a whole chain ran within a single frame, and
## every link read the attacker's position from before the current attack had
## moved them — so four chained dash-slashes computed the same start and the
## same destination and landed exactly on top of each other, reading as one
## dash that happened to hit four times. A beat between links lets each one
## start from where the last finished, and gives each its own dash to watch.
##
## What that needs is the frame after the hit, not a seventh of a second. At
## 0.14 a nine-link chain spent a second working through a room one metronome
## beat at a time, which is a chain of separate strikes rather than one long
## one; this is a few frames, enough to read each link and to let the lunge
## before it land the attacker.
const TRIGGER_DELAY := 0.045

## What one connection takes off the clock.
##
## A chain's links take the lighter one: the whole chain is a single blow, and
## stopping the clock in full for each of nine of them reads as a stutter rather
## than as a strike — and spends most of a second of real time doing it, because
## every stop slams the scale down and then eases back over the best part of ten
## frames.
const HITSTOP := 0.035
const CHAIN_HITSTOP := 0.010

## The lunge the DASH component adds to an attack. Its own number rather than
## the player's dash speed: this one rides on a skill that has already paid for
## itself in ticks and heat, so it is tuned against the board, not against the
## movement button.
const DASH_LUNGE_SPEED := 620.0

## How far a lunge travels at size 1. For DASHSLASH this is the cap on aiming
## it: the cursor decides where inside that range it lands.
const DASH_SLASH_REACH := 170.0

## Staggered follow-ups (DUPLICATE, multi-hit forms, triggers) are scheduled by
## a small node rather than a captured lambda: an attacker can die between the
## first strike and the last, and a node can re-check that before it fires.
class Deferred extends Node:
	var t: float = 0.0
	var kind: String = ""
	var payload: Payload
	var aim: Vector2 = Vector2.RIGHT
	var pos: Vector2 = Vector2.ZERO
	var team: int = 0
	## Untyped for the same reason `resolve_hit` takes it loose: the attacker
	## can be torn down while this is still counting down.
	var attacker = null
	var room: Node = null
	var ctx: Dictionary = {}

	func _process(delta: float) -> void:
		t -= delta
		if t > 0.0:
			return
		var atk: Actor = attacker if is_instance_valid(attacker) and attacker is Actor else null
		match kind:
			"melee":
				Attacks._melee(payload, aim, team, atk, room)
			"burst":
				Attacks._burst(payload, pos, team, atk, room)
			"dash":
				Attacks._dash_slash(payload, aim, team, atk, room)
			"spawn":
				# The full spawn path, so a trigger's attack behaves exactly as
				# it would fired straight off the board.
				var c := ctx.duplicate()
				c["attacker"] = atk
				# The attack that caused this has moved the attacker since, so
				# a follow-up aims where they are aiming now rather than down
				# the hit that triggered it: a chain of lunges kept on the old
				# heading walks past the target and every link after the first
				# misses. The origin stays at the impact point, so an ON HIT
				# burst or bolt still comes from where the hit landed.
				if atk != null:
					var live_aim = atk.get("aim")
					if live_aim is Vector2 and (live_aim as Vector2).length() > 0.01:
						c["aim"] = live_aim
				Attacks.spawn(payload, c)
		queue_free()

static func _schedule(seconds: float, kind: String, p: Payload, aim: Vector2, pos: Vector2,
		team: int, attacker: Actor, room) -> void:
	var w := container()
	if w == null or not is_instance_valid(w):
		return
	var d := Deferred.new()
	d.t = seconds
	d.kind = kind
	d.payload = p
	d.aim = aim
	d.pos = pos
	d.team = team
	d.attacker = attacker
	d.room = room
	w.add_child(d)

## Schedules a whole `spawn` — used for trigger follow-ups, which need the form
## re-resolved from scratch rather than one fixed attack kind.
static func _schedule_spawn(seconds: float, p: Payload, ctx: Dictionary) -> void:
	var w := container()
	if w == null or not is_instance_valid(w):
		return
	var d := Deferred.new()
	d.t = seconds
	d.kind = "spawn"
	d.payload = p
	d.ctx = ctx.duplicate()
	d.attacker = ctx.get("attacker", null)
	w.add_child(d)

## ctx keys: attacker (Actor), room (Node), aim (Vector2), team (int),
##           origin (Vector2), gravity (bool)
static func spawn(payload: Payload, ctx: Dictionary) -> void:
	var w := container()
	if w == null or not is_instance_valid(w):
		return
	var attacker: Actor = ctx.get("attacker", null)
	var team: int = int(ctx.get("team", 0))
	var room = ctx.get("room", null)
	var aim: Vector2 = ctx.get("aim", Vector2.RIGHT)
	if aim.length() < 0.01:
		aim = Vector2.RIGHT
	aim = aim.normalized()
	var origin: Vector2 = ctx.get("origin", attacker.global_position if attacker != null else Vector2.ZERO)

	# Movement effects run first: they decide where the attack comes from.
	if payload.blink and attacker != null and is_instance_valid(attacker):
		var t := nearest_target(attacker.global_position, team, 460.0)
		if t != null:
			var behind: Vector2 = t.global_position - aim * (t.hurt_radius + 26.0)
			if room == null or not room.has_method("is_solid_at") or not room.is_solid_at(behind):
				var was: Vector2 = attacker.global_position
				attacker.global_position = behind
				origin = behind
				Cues.emit_cue(&"blink", {"from": was, "to": behind})
	if payload.dash and attacker != null and is_instance_valid(attacker):
		attacker.velocity = aim * DASH_LUNGE_SPEED
		if attacker.has_method("on_dashed"):
			attacker.on_dashed()
		Cues.at(&"lunge", attacker.global_position)

	var count: int = clampi(payload.duplicates, 1, 9)
	# One announcement per cast, whatever the duplicate count: the form is what
	# the moment sounds like, and three bolts are one volley.
	Cues.at(&"attack", origin, {"form": payload.form, "payload": payload, "aim": aim})
	match payload.form:
		"PROJECTILE":
			for i in count:
				var spread := 0.0 if count == 1 else deg_to_rad(lerpf(-16.0, 16.0, float(i) / float(count - 1)))
				_projectile(payload, origin, aim.rotated(spread), team, attacker, room, bool(ctx.get("gravity", false)))
		"SLASH":
			for i in count:
				var delay := float(i) * 0.07
				var off := 0.0 if count == 1 else deg_to_rad(lerpf(-22.0, 22.0, float(i) / float(count - 1)))
				if delay <= 0.0:
					_melee(payload, aim.rotated(off), team, attacker, room)
				else:
					_schedule(delay, "melee", payload, aim.rotated(off), origin, team, attacker, room)
		"AREA":
			for i in count:
				var pos: Vector2 = origin + (Vector2.ZERO if i == 0 else Vector2(randf_range(-70, 70), randf_range(-40, 40)))
				if i == 0:
					_burst(payload, pos, team, attacker, room)
				else:
					_schedule(float(i) * 0.1, "burst", payload, aim, pos, team, attacker, room)
		"DASHSLASH", "DASHSLASH_AUTO":
			for i in count:
				if i == 0:
					_dash_slash(payload, aim, team, attacker, room)
				else:
					_schedule(float(i) * 0.12, "dash", payload, aim, origin, team, attacker, room)
		_:
			pass

static func _projectile(p: Payload, pos: Vector2, dir: Vector2, team: int, atk: Actor, room, gravity: bool) -> void:
	var n := Projectile.new()
	n.setup(p, pos, dir, team, atk, room)
	if gravity:
		n.gravity = 620.0
		n.velocity *= 0.85
	container().add_child(n)

static func _melee(p: Payload, dir: Vector2, team: int, atk: Actor, room) -> void:
	if atk == null or not is_instance_valid(atk):
		return
	if room != null and not is_instance_valid(room):
		room = null
	var n := MeleeArc.new()
	n.setup(p, dir, team, atk, room)
	container().add_child(n)
	Cues.at(&"melee_arc", n.global_position, {"payload": p})

static func _burst(p: Payload, pos: Vector2, team: int, atk: Actor, room) -> void:
	if atk != null and not is_instance_valid(atk):
		atk = null
	if room != null and not is_instance_valid(room):
		room = null
	var n := AreaBurst.new()
	n.setup(p, pos, team, atk, room)
	container().add_child(n)
	Cues.at(&"area_blast", pos, {"payload": p})

static func _dash_slash(p: Payload, aim: Vector2, team: int, atk: Actor, room) -> void:
	if atk == null or not is_instance_valid(atk):
		return
	if room != null and not is_instance_valid(room):
		room = null
	var start: Vector2 = atk.global_position
	var reach := DASH_SLASH_REACH * p.size
	var dest: Vector2
	if p.form == "DASHSLASH_AUTO":
		var t := nearest_target(start, team, 520.0)
		if t == null:
			dest = start + aim * reach
		else:
			# The shortest lunge that still carries the cut past the target:
			# out to its centre, then just clear of its far side. Overshooting
			# by a fixed margin threw the attacker further away than the strike
			# needed and left the next one further to travel.
			var to: Vector2 = t.global_position - start
			var away: Vector2 = to.normalized() if to.length() > 0.01 else aim
			dest = start + away * (to.length() + t.hurt_radius + atk.hurt_radius)
	else:
		# Land on what the attacker is pointing at rather than a fixed distance
		# down the aim, so the lunge goes where it is aimed. Past the skill's
		# reach it still stops at the reach, which is what SIZE buys. An
		# attacker with nothing to point at — every monster — keeps the aim.
		var want := start + aim * reach
		var pt = atk.get("aim_point")
		if pt is Vector2:
			want = pt
		dest = start + (want - start).limit_length(reach)
	if room != null and room.has_method("clamp_dash"):
		dest = room.clamp_dash(start, dest)
	var n := DashSlash.new()
	n.setup(p, start, dest, team, atk, room)
	container().add_child(n)
	Cues.at(&"lunge_cut", start, {"payload": p, "to": dest})

## A single connection: damage, feedback, and any trigger flows it unlocks.
##
## `attacker` is deliberately untyped: a projectile or a burst outlives whoever
## fired it, and a monster torn down mid-flight leaves behind a node that still
## passes `is_instance_valid` for a moment with its script already released.
## Declaring the parameter as `Actor` made the engine reject the whole call at
## that moment, so a shot from a dying enemy silently did no damage at all.
## Taking it loose and narrowing here costs the kill credit and any trigger
## flow that needs a live owner, and lands the hit.
static func resolve_hit(p: Payload, target: Actor, pos: Vector2, dir: Vector2, attacker, room, team: int) -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		return
	# Both halves are needed: a fully deleted node fails `is_instance_valid`,
	# and one still being torn down passes it but no longer answers to `is`.
	var atk: Actor = attacker if is_instance_valid(attacker) and attacker is Actor else null
	var dealt := target.apply_damage(p.damage, p.elements, atk)
	if dealt <= 0.0:
		return
	target.knockback(dir, 120.0 + p.damage * 2.0)
	# A connection stops the clock for a frame. That is a rule — everything in
	# the fight feels it — so it is applied here and not left to the screen.
	TimeCtl.hitstop(CHAIN_HITSTOP if p.follow_up else HITSTOP)

	var killed := target.dead
	if killed and atk != null and atk.team == 0:
		GameState.register_kill()
	Cues.at(&"hit", pos, {"payload": p, "killed": killed, "target_team": target.team})

	var ctx := {
		"attacker": atk, "room": room, "team": team,
		"aim": dir, "origin": pos, "gravity": false,
	}
	if p.on_hit != null:
		_schedule_spawn(TRIGGER_DELAY, _follow(p.on_hit), ctx)
	if killed and p.on_kill != null:
		_schedule_spawn(TRIGGER_DELAY, _follow(p.on_kill), ctx)

## A link of a chain, marked as belonging to the blow that caused it rather than
## being one of its own. A parry's riposte is deliberately not marked: that is a
## separate answer to a separate event, and it should land like one.
static func _follow(p: Payload) -> Payload:
	var f: Payload = (p as Payload).clone()
	f.follow_up = true
	return f
