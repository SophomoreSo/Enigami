class_name Enemy
extends Actor

## One monster. Movement comes from its AI kind and its attacks come from a
## SkillBoard run through the same SkillRunner the player uses. What it looks
## like is `graphics/views/enemy_view.gd`, which reads the state below.

const GRAVITY := 1700.0

## How much longer a monster waits between attacks than its board alone would.
##
## Monster boards are short by design — a Crawler is INPUT, SLASH, OUTPUT — and
## a short board comes round again almost immediately, so every monster in the
## game was attacking twelve to thirty times a second: a Sentry held down a wall
## of bolts, and walking into a Crawler was a death with no blow in it to read.
## The player's own basic is paced the same way, by `Player.BASIC_COOLDOWN_MUL`.
##
## It is one number for every monster on purpose. What separates a Crawler's
## slash from an Arbiter's volley is already in their boards — length and heat —
## so scaling the whole cadence keeps those differences and only sets the pace
## they play out at.
const ATTACK_COOLDOWN_MUL := 20.0

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
var aggro: bool = false
## Counts down through the wind-up before a leap, so the leap can be read
## before it lands.
var telegraph: float = 0.0
## 1 until a boss changes form, then 2.
var phase: int = 1

var _patrol_dir: int = 1
var _jump_cd: float = 0.0
var _bob: float = 0.0
var _gravity_shots: bool = false
var _danger: int = 1

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

func _make_runner() -> void:
	runner = SkillRunner.new(board)
	runner.cooldown_mul = ATTACK_COOLDOWN_MUL
	var dmg_scale := 1.0 + 0.14 * float(max(_danger - 1, 0))
	if modifier == "armored":
		dmg_scale *= 1.15
	runner.base_payload_provider = func() -> Payload:
		var p := Payload.new()
		p.damage = 7.0 * dmg_scale
		p.speed = 0.85
		p.size = 1.0
		return p
	runner.fired.connect(_on_fired)

func _on_fired(p: Payload) -> void:
	if target == null or not is_instance_valid(target):
		return
	var aim: Vector2 = (target.global_position - global_position).normalized()
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
	_acquire()
	var want_attack := aggro and target != null and _in_range()
	if def.get("boss", false):
		_boss_logic(delta)
		want_attack = aggro and target != null
	runner.set_active(want_attack)
	runner.update(delta)
	_update_facing()

## Monsters look at what they are hunting, and at where they are going
## otherwise — a patrolling Lobber should not moonwalk.
func _update_facing() -> void:
	if aggro and target != null and is_instance_valid(target):
		face(signi(int(signf(target.global_position.x - global_position.x))))
	elif absf(velocity.x) > 4.0:
		face(signi(int(signf(velocity.x))))

## Which movement script this monster runs. A view reads it to decide what an
## airborne pose or a hover should look like.
func ai() -> String:
	return String(def["ai"])

func _acquire() -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		var ps := get_tree().get_nodes_in_group("player")
		target = ps[0] if ps.size() > 0 else null
	if target == null:
		aggro = false
		return
	var d := global_position.distance_to(target.global_position)
	var sees := true
	if room != null and room.has_method("has_line_of_sight"):
		sees = room.has_line_of_sight(global_position, target.global_position)
	aggro = d <= float(def["aggro"]) and sees

func _in_range() -> bool:
	return global_position.distance_to(target.global_position) <= float(def["attack_range"])

func _physics_process(delta: float) -> void:
	if dead:
		return
	var spd := float(def["speed"]) * speed_scale()
	if modifier == "swift":
		spd *= 1.5
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
	_contact_damage(delta)

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
		Cues.at(&"boss_phase", global_position,
			{"actor": self, "text": "%s: SECOND FORM" % String(def["name"]).to_upper()})

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
		p.form = "AREA"
		p.elements = ["FIRE"] as Array[String]
		Attacks.spawn(p, {"attacker": null, "room": room, "team": team, "aim": Vector2.RIGHT, "origin": global_position})
	if room != null and room.has_method("on_enemy_died"):
		room.on_enemy_died(self)
	super._kill()

func apply_damage(amount: float, elements: Array = [], source: Node = null, is_hit: bool = true) -> float:
	if modifier == "armored":
		amount *= 0.7
	return super.apply_damage(amount, elements, source, is_hit)
