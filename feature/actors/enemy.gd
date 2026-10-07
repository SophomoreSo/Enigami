class_name Enemy
extends Actor

## One monster. Movement comes from its AI kind and its attacks come from a
## SkillBoard run through the same SkillRunner the player uses. What it looks
## like is `graphics/views/enemy_view.gd`, which reads the state below.
##
## A monster can be possessed (`Player.possess`): while it is, its `pilot` is
## the player, it is on their side, and it does what their input line says
## rather than what its own mind would — walks and jumps at its own pace, and
## attacks with its own attack when they press. The rest of the monsters take
## it for one of them until it has hurt one of them (`revealed`), and hunt it
## after.

const GRAVITY := 1700.0

## How much longer a monster waits between attacks than its board alone would.
##
## Monster boards are short by design — a Crawler is a SLASH and nothing else —
## and a short board comes round again almost immediately, so every monster in
## the game was attacking twelve to thirty times a second: a Sentry held down a
## wall of bolts, and walking into a Crawler was a death with no blow in it to
## read. The player's own casts are paced the same way, by
## `Player.CAST_COOLDOWN_MUL`.
##
## It is one number for every monster on purpose. What separates a Crawler's
## slash from an Arbiter's volley is already in their boards — length and heat —
## so scaling the whole cadence keeps those differences and only sets the pace
## they play out at.
const ATTACK_COOLDOWN_MUL := 20.0

## A monster only notices what is in front of it. Something standing this close
## behind its back is noticed anyway: that is not being crept up on, that is
## being stood on.
const BLIND_MARGIN := 10.0
## A monster standing idle looks over its shoulder now and then, somewhere
## between these many seconds apart, so one that happened to stop facing a wall
## is not blind for the rest of the raid — and so the moment its back is turned
## is something to wait for.
const GLANCE_MIN := 2.0
const GLANCE_MAX := 4.0

var kind: String = "CRAWLER"
var def: Dictionary = {}
var board: SkillBoard
var runner: SkillRunner
var room = null
var target: Actor = null
var modifier: String = ""

## Half the silhouette: the hurt radius, and what the collider is built from.
var size: float = 14.0
## Whether the monster has seen its target. A view marks it; the AI acts on it.
## Seeing takes the target in front of it (see `_in_front`); once it has, it
## turns to keep them there, so it stays seen until range or a wall breaks it.
var aggro: bool = false
## Counts down through the wind-up before a leap, so the leap can be read
## before it lands.
var telegraph: float = 0.0
## 1 until a boss changes form, then 2.
var phase: int = 1

var _patrol_dir: int = 1
var _glance: float = 0.0
var _jump_cd: float = 0.0
var _bob: float = 0.0
var _gravity_shots: bool = false
var _danger: int = 1

## A possessed monster, under the player's keys. The least pace it walks at,
## so a monster that never walks of its own accord — a Sentry — still can,
## what a jump lifts it by, and for anything that flies, the beat of a flap and
## the slow fall between them.
const PILOTED_PACE := 110.0
const PILOTED_JUMP := -560.0
const PILOTED_FLAP := -360.0
const PILOTED_FALL := 700.0
## A monster after one thing turns on another it can see in front of it only
## when that one is this much nearer: nearer by a little is not worth a turn,
## and two things the same distance off would have it swinging between them.
const SWITCH_NEARER := 0.6

## The player whose hands are in this monster, or null while it runs its own
## mind — see `Player.possess`.
var pilot: Player = null
## Whether a possessed monster has shown itself: until a hit of its hurts one of
## them it passes for one of them, and none of them hunts it. Attacking is not
## enough — a swing at nothing, a throw that misses — and a hit that puts the
## player's hands into the next one lets go of this one as it lands
## (`Attacks.resolve_hit`).
var revealed: bool = false
## Whether its pilot is attacking with its own attack, this frame. The pilot
## says so (`Player._attack_as_monster`).
var attacking: bool = false

## Rolled onto a monster to make it more than its kind. The effects are applied
## below; what each one looks like is the graphics module's business.
const MODIFIERS := ["swift", "armored", "volatile", "glacial"]

func setup(id: String, danger: int = 1, mod_id: String = "") -> void:
	kind = id
	def = Monsters.get_def(id)
	modifier = mod_id
	size = float(def["size"])
	_gravity_shots = bool(def.get("gravity", false))
	_danger = danger
	var scale_hp := 1.0 + 0.16 * float(max(danger - 1, 0))
	max_health = float(def["hp"]) * scale_hp
	hurt_radius = size
	if modifier == "armored":
		max_health *= 1.6
	if modifier == "swift":
		max_health *= 0.8
	health = max_health

func _ready() -> void:
	team = 1
	super._ready()
	add_to_group("enemies")
	_make_body(size * 1.5, size * 1.9)
	board = Monsters.build_board(kind)
	_make_runner()
	_patrol_dir = 1 if randf() < 0.5 else -1
	# Found facing either way, not always to the right.
	face(_patrol_dir)
	_glance = randf_range(GLANCE_MIN, GLANCE_MAX)

func _make_runner() -> void:
	runner = SkillRunner.new(board)
	runner.cooldown_mul = ATTACK_COOLDOWN_MUL
	var dmg_scale := 1.0 + 0.14 * float(max(_danger - 1, 0))
	if modifier == "armored":
		dmg_scale *= 1.15
	# A quarter past the furthest it will ever shoot from, so a bolt loosed at
	# the edge of its range still lands on someone backing away — and never less
	# than an ordinary bolt carries, so the ones that fight up close are not
	# firing shorter shots than anybody else.
	var reach := maxf(float(def.get("attack_range", 0.0)) * 1.25, Payload.BASE_RANGE)
	# What one shot is worth and how fast it flies are the same for every
	# monster, unless its kind says otherwise: the Gunman's say so.
	var hit := float(def.get("damage", 7.0)) * dmg_scale
	var pace := float(def.get("shot_speed", 0.85))
	runner.base_payload_provider = func() -> Payload:
		var p := Payload.new()
		p.damage = hit
		p.speed = pace
		p.size = 1.0
		p.range_px = reach
		return p
	runner.fired.connect(_on_fired)

func _on_fired(p: Payload) -> void:
	var aim: Vector2
	if piloted():
		# Where the pilot is pointing. Going off gives nothing away; hurting one
		# of them does (`Attacks.resolve_hit`).
		aim = pilot.aim
	else:
		if target == null or not is_instance_valid(target):
			return
		aim = (target.global_position - global_position).normalized()
	if modifier == "glacial" and not p.elements.has("ICE"):
		p.elements.append("ICE")
	Attacks.spawn(p, {
		"attacker": self, "room": room, "team": team,
		"aim": aim, "origin": global_position, "gravity": _gravity_shots,
	})

func _process(delta: float) -> void:
	_process_status(delta)
	_bob += delta
	if telegraph > 0.0:
		telegraph -= delta
	if piloted():
		# The pilot's hands, not its own mind: it attacks when they say, with
		# its own attack, and a stun holds it as it holds any monster.
		runner.set_active(attacking and not stunned())
		if not stunned():
			runner.update(delta)
		return
	_acquire()
	var want_attack := aggro and target != null and _in_range()
	if def.get("boss", false):
		_boss_logic(delta)
		want_attack = aggro and target != null
	runner.set_active(want_attack and not stunned())
	# A stunned monster's board waits with it: a cast already on its way would
	# otherwise land while it stands there, and that is an attack.
	if not stunned():
		runner.update(delta)
	_update_facing(delta)

## Monsters look at what they are hunting, and at where they are going
## otherwise — a patrolling Lobber should not moonwalk. One with nothing to
## hunt and nowhere to go looks the other way every few seconds.
func _update_facing(delta: float) -> void:
	if aggro and target != null and is_instance_valid(target):
		_face_target()
	elif absf(velocity.x) > 4.0:
		face(signi(int(signf(velocity.x))))
	elif not stunned():
		_glance -= delta
		if _glance <= 0.0:
			_glance = randf_range(GLANCE_MIN, GLANCE_MAX)
			face(-facing)

func _face_target() -> void:
	face(signi(int(signf(target.global_position.x - global_position.x))))

## Something loud at `at` — somebody digging (`DigSpot`). One with nothing to
## hunt, that is not the player's, turns to look that way and keeps looking for
## a while rather than glancing straight back. Whether it then sees anybody is
## noticing's business (`_acquire`), so a wall between still hides them.
func hear(at: Vector2) -> void:
	if dead or piloted() or aggro or stunned():
		return
	face(signi(int(signf(at.x - global_position.x))))
	_glance = GLANCE_MAX

## Whether the target is on the side this monster is looking at. A boss is
## never crept up on: its room is its own, and it knows who is in it.
func _in_front() -> bool:
	return _faces(target.global_position)

## Whether `at` is on the side this monster is looking at — or right on its
## back, which is being stood on rather than crept up on.
func _faces(at: Vector2) -> bool:
	if def.get("boss", false):
		return true
	return (at.x - global_position.x) * float(facing) >= -BLIND_MARGIN

## Which movement script this monster runs. A view reads it to decide what an
## airborne pose or a hover should look like.
func ai() -> String:
	return String(def["ai"])

## --- possessed -------------------------------------------------------------

## Whether the player's hands are in this monster.
func piloted() -> bool:
	return pilot != null and is_instance_valid(pilot)

## The player's hands go in: it is on their side, sees nobody and hunts nobody,
## and a stun it was standing in is over, so it answers them at once.
func take_pilot(p: Player) -> void:
	pilot = p
	team = 0
	revealed = false
	attacking = false
	aggro = false
	target = null
	telegraph = 0.0
	runner.ttl_bonus = 0
	runner.set_active(false)
	if stunned():
		stun_time = 0.0

## The player's hands come out: it is one of them again, and stands stunned for
## `stun_for` — however recently it came round from the last stun.
func release_pilot(stun_for: float) -> void:
	pilot = null
	team = 1
	revealed = false
	attacking = false
	aggro = false
	target = null
	runner.set_active(false)
	velocity.x = 0.0
	stun_guard = 0.0
	stun(stun_for)

## Mana a MANA DRAIN hit gives back: a possessed monster's goes to its pilot.
func gain_mana(amount: float) -> void:
	if piloted():
		pilot.gain_mana(amount)

## Walks and jumps as the pilot's line says, at its own pace — or, for one that
## flies, flaps.
func _ai_piloted(delta: float, spd: float) -> void:
	var s := pilot.input.state()
	var pace := maxf(spd, PILOTED_PACE * speed_scale())
	if s.sprint:
		pace *= Player.SPRINT_SPEED / Player.RUN_SPEED
	if s.move != 0.0:
		face(int(signf(s.move)))
	face(s.turn)
	if ai() == "flyer":
		velocity.x = move_toward(velocity.x, s.move * pace, 1400.0 * delta)
		velocity.y = minf(velocity.y + PILOTED_FALL * delta, 300.0)
		if s.jump_pressed:
			velocity.y = PILOTED_FLAP
		return
	_fall(delta)
	velocity.x = move_toward(velocity.x, s.move * pace, 1800.0 * delta)
	if s.jump_pressed and is_on_floor():
		velocity.y = PILOTED_JUMP
	if s.jump_released and velocity.y < 0.0:
		velocity.y *= 0.45

## --- hunting ----------------------------------------------------------------

## Whether `a` is something a monster hunts: whatever stands for the player —
## their own body — or a monster the player is in that has shown itself.
func _hunts(a) -> bool:
	if a == null or not is_instance_valid(a) or a == self or (a as Actor).dead:
		return false
	if (a as Node).is_in_group("player"):
		return true
	return a is Enemy and (a as Enemy).piloted() and (a as Enemy).revealed

## The nearest thing there is to hunt, or null. With `noticed`, only what it
## would notice where it stands: in reach, in sight, and in front of it.
func _nearest_quarry(noticed: bool = false) -> Actor:
	var best: Actor = null
	var best_d := INF
	for group in ["player", "enemies"]:
		for a in get_tree().get_nodes_in_group(group):
			if not _hunts(a):
				continue
			var at := (a as Actor).global_position
			var d := global_position.distance_to(at)
			if d >= best_d:
				continue
			if noticed and (d > float(def["aggro"]) or not _sees(at) or not _faces(at)):
				continue
			best_d = d
			best = a
	return best

## What it is after. Having noticed something it keeps after it — unless
## something else it can see in front of it is much nearer, a monster the player
## is in giving itself away beside it, say. Until then it looks for the nearest
## thing to hunt: the player's body, or a monster the player is in that has
## given itself away.
func _acquire() -> void:
	if aggro and _hunts(target):
		var other := _nearest_quarry(true)
		if other != null and other != target and global_position.distance_to(other.global_position) \
				< global_position.distance_to(target.global_position) * SWITCH_NEARER:
			target = other
	else:
		target = _nearest_quarry()
	if target == null:
		aggro = false
		return
	var d := global_position.distance_to(target.global_position)
	# Noticing takes the target in front; having noticed, it only has to keep
	# them in reach and in sight, since it turns to follow them.
	aggro = d <= float(def["aggro"]) and _sees(target.global_position) and (aggro or _in_front())

## Whether nothing solid stands between it and `at`.
func _sees(at: Vector2) -> bool:
	if room != null and room.has_method("has_line_of_sight"):
		return room.has_line_of_sight(global_position, at)
	return true

func _in_range() -> bool:
	return global_position.distance_to(target.global_position) <= float(def["attack_range"])

func _physics_process(delta: float) -> void:
	if dead:
		return
	var spd := float(def["speed"]) * speed_scale()
	if modifier == "swift":
		spd *= 1.5
	if stunned():
		_stand_stunned(delta)
	elif piloted():
		_ai_piloted(delta, spd)
	else:
		match String(def["ai"]):
			"runner": _ai_runner(delta, spd)
			"walker": _ai_walker(delta, spd)
			"jumper": _ai_jumper(delta, spd)
			"turret": _ai_turret(delta)
			"flyer": _ai_flyer(delta, spd)
			"boss": _ai_boss(delta, spd)
	move_and_slide()
	# The AI above has just written `velocity` outright, so anything the world
	# is pushing this monster with is carried separately and applied here.
	apply_shove(delta)
	# Standing stunned is doing nothing, and that includes hurting by touch; so
	# is being somebody else's hands.
	if not stunned() and not piloted():
		_contact_damage(delta)

## A stunned monster does nothing of its own: it stops where it is, mid-stride,
## falling if it walks and hanging where it was if it flies. A shove still
## carries it, since that is the world's and not its own.
func _stand_stunned(delta: float) -> void:
	if String(def["ai"]) == "flyer":
		velocity = Vector2.ZERO
	else:
		_fall(delta)
		velocity.x = 0.0

func _fall(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 1000.0)

func _ai_runner(delta: float, spd: float) -> void:
	_fall(delta)
	if aggro and target != null:
		var dir := signf(target.global_position.x - global_position.x)
		velocity.x = move_toward(velocity.x, dir * spd, 1400.0 * delta)
		# Hop over anything in the way, including gaps in the floor.
		if is_on_floor() and (is_on_wall() or _gap_ahead(dir)):
			velocity.y = -520.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)

func _ai_walker(delta: float, spd: float) -> void:
	_fall(delta)
	if is_on_wall() or (is_on_floor() and _gap_ahead(float(_patrol_dir))):
		_patrol_dir *= -1
	velocity.x = float(_patrol_dir) * spd

func _ai_jumper(delta: float, spd: float) -> void:
	_fall(delta)
	_jump_cd -= delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
		if aggro and target != null and _jump_cd <= 0.0:
			_jump_cd = 1.3
			var dir := signf(target.global_position.x - global_position.x)
			velocity = Vector2(dir * spd * 1.4, -560.0)
			telegraph = 0.2

## A turret holds its ground, but it is not nailed to the air: dropped in above
## the floor — which is how the bench puts its dummy down, and how a stray gets
## placed — it falls until something holds it up. Writing a flat zero into the
## whole of `velocity` left the dummy hanging exactly where it was spawned.
func _ai_turret(delta: float) -> void:
	velocity.x = 0.0
	_fall(delta)

func _ai_flyer(delta: float, spd: float) -> void:
	if aggro and target != null:
		var to: Vector2 = target.global_position + Vector2(0, -60) - global_position
		var want := to.normalized() * spd
		want.y += sin(_bob * 3.0) * 40.0
		velocity = velocity.lerp(want, clampf(2.0 * delta, 0.0, 1.0))
	else:
		velocity = velocity.lerp(Vector2(0, sin(_bob * 2.0) * 20.0), clampf(2.0 * delta, 0.0, 1.0))

func _ai_boss(delta: float, spd: float) -> void:
	_fall(delta)
	if not aggro or target == null:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		return
	var dir := signf(target.global_position.x - global_position.x)
	var dist := absf(target.global_position.x - global_position.x)
	# Phase one keeps its distance; phase two closes and pressures.
	var want := 0.0
	if phase == 1:
		want = dir * spd * (-0.6 if dist < 200.0 else 0.7)
	else:
		want = dir * spd * 1.25
	velocity.x = move_toward(velocity.x, want, 1200.0 * delta)
	if is_on_floor() and (is_on_wall() or _gap_ahead(dir)):
		velocity.y = -600.0

func _boss_logic(_delta: float) -> void:
	if phase == 1 and health_ratio() < 0.5:
		phase = 2
		board = Monsters.build_board(kind, "board_phase2")
		_make_runner()
		# The monster and the phase it has entered, not a line about them: the
		# picture spells that, in the language being played.
		Cues.at(&"boss_phase", global_position, {"kind": kind, "phase": phase})

func _gap_ahead(dir: float) -> bool:
	if room == null or not room.has_method("is_solid_at"):
		return false
	var probe := global_position + Vector2(dir * (size + 10.0), size + 22.0)
	return not room.is_solid_at(probe)

func _contact_damage(delta: float) -> void:
	var dmg := float(def["contact"])
	if dmg <= 0.0 or target == null or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) <= hurt_radius + target.hurt_radius:
		target.apply_damage(dmg * delta * 4.0, [], self)

func _kill() -> void:
	if dead:
		return
	if modifier == "volatile":
		var p := Payload.new()
		p.damage = 18.0
		p.size = 1.3
		# No form, so the EXPLODE is the attack: a burst where it died.
		p.explode = 1
		p.elements = ["FIRE"] as Array[String]
		Attacks.spawn(p, {"attacker": null, "room": room, "team": team, "aim": Vector2.RIGHT, "origin": global_position})
	if room != null and room.has_method("on_enemy_died"):
		room.on_enemy_died(self)
	super._kill()

func apply_damage(amount: float, elements: Array = [], source: Node = null, is_hit: bool = true) -> float:
	if modifier == "armored":
		amount *= 0.7
	# A blow in the back is the end of not having noticed: it turns round to
	# whoever it is hunting, and sees them if they are near enough to be seen.
	if is_hit and not aggro and target != null and is_instance_valid(target):
		_face_target()
	return super.apply_damage(amount, elements, source, is_hit)
