class_name Enemy
extends Actor

## One monster. Movement comes from its AI kind; its attacks come from a
## SkillBoard run through the same SkillRunner the player uses, and its body
## is an atlas character picked to read as that AI at a glance.

const GRAVITY := 1700.0
## AI kinds that leave the ground, and so need an airborne pose.
const AIRBORNE_AI := ["runner", "jumper", "boss"]

var kind: String = "CRAWLER"
var def: Dictionary = {}
var board: SkillBoard
var runner: SkillRunner
var room = null
var target: Actor = null
var modifier: String = ""

var _patrol_dir: int = 1
var _jump_cd: float = 0.0
var _bob: float = 0.0
var _phase: int = 1
var _telegraph: float = 0.0
var _sprite_id: String = "imp"
var _size: float = 14.0
var _aggro: bool = false
var _gravity_shots: bool = false
var _danger: int = 1

const MODIFIERS := {
	"swift": {"name": "Swift", "color": Color(0.6, 1.0, 0.8)},
	"armored": {"name": "Armored", "color": Color(0.75, 0.75, 0.85)},
	"volatile": {"name": "Volatile", "color": Color(1.0, 0.6, 0.3)},
	"glacial": {"name": "Glacial", "color": Color(0.6, 0.9, 1.0)},
}

func setup(id: String, danger: int = 1, mod_id: String = "") -> void:
	kind = id
	def = Monsters.get_def(id)
	modifier = mod_id
	_sprite_id = String(def["sprite"])
	_size = float(def["size"])
	_gravity_shots = bool(def.get("gravity", false))
	_danger = danger
	var scale_hp := 1.0 + 0.16 * float(max(danger - 1, 0))
	max_health = float(def["hp"]) * scale_hp
	body_color = def["color"]
	sprite_tint = def.get("tint", Color.WHITE)
	hurt_radius = _size
	if modifier == "armored":
		max_health *= 1.6
	if modifier == "swift":
		max_health *= 0.8
	health = max_health

func _ready() -> void:
	team = 1
	super._ready()
	add_to_group("enemies")
	z_index = 45
	_make_body(_size * 1.5, _size * 1.9)
	_make_sprite(_sprite_id, _size * 1.9)
	board = Monsters.build_board(kind)
	_make_runner()
	_patrol_dir = 1 if randf() < 0.5 else -1

func _make_runner() -> void:
	runner = SkillRunner.new(board)
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
	if _telegraph > 0.0:
		_telegraph -= delta
	_acquire()
	var want_attack := _aggro and target != null and _in_range()
	if def.get("boss", false):
		_boss_logic(delta)
		want_attack = _aggro and target != null
	runner.set_active(want_attack)
	runner.update(delta)
	_update_facing()
	_update_anim()
	queue_redraw()

## Monsters look at what they are hunting, and at where they are going
## otherwise — a patrolling Lobber should not moonwalk.
func _update_facing() -> void:
	if _aggro and target != null and is_instance_valid(target):
		face(signi(int(signf(target.global_position.x - global_position.x))))
	elif absf(velocity.x) > 4.0:
		face(signi(int(signf(velocity.x))))

func _update_anim() -> void:
	var ai := String(def["ai"])
	if AIRBORNE_AI.has(ai) and not is_on_floor():
		# No jump art in the pack: hold a stride instead of running on air.
		play_anim("run", 1.0, 2 if velocity.y < 0.0 else 0)
	elif absf(velocity.x) > 12.0 or (ai == "flyer" and velocity.length() > 24.0):
		play_anim("run", clampf(absf(velocity.x) / 110.0, 0.7, 1.8))
	else:
		play_anim("idle")

## The wind-up before a leap has to read before the leap lands.
func _update_sprite_status() -> void:
	super._update_sprite_status()
	if _sprite_mat != null and _telegraph > 0.0:
		_sprite_mat.set_shader_parameter("flash",
			maxf(clampf(flash, 0.0, 1.0), clampf(_telegraph / 0.2, 0.0, 1.0) * 0.75))

func _acquire() -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		var ps := get_tree().get_nodes_in_group("player")
		target = ps[0] if ps.size() > 0 else null
	if target == null:
		_aggro = false
		return
	var d := global_position.distance_to(target.global_position)
	var sees := true
	if room != null and room.has_method("has_line_of_sight"):
		sees = room.has_line_of_sight(global_position, target.global_position)
	_aggro = d <= float(def["aggro"]) and sees

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
	_contact_damage(delta)

func _fall(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 1000.0)

func _ai_runner(delta: float, spd: float) -> void:
	_fall(delta)
	if _aggro and target != null:
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
		if _aggro and target != null and _jump_cd <= 0.0:
			_jump_cd = 1.3
			var dir := signf(target.global_position.x - global_position.x)
			velocity = Vector2(dir * spd * 1.4, -560.0)
			_telegraph = 0.2

func _ai_turret(_delta: float) -> void:
	velocity = Vector2.ZERO

func _ai_flyer(delta: float, spd: float) -> void:
	if _aggro and target != null:
		var to: Vector2 = target.global_position + Vector2(0, -60) - global_position
		var want := to.normalized() * spd
		want.y += sin(_bob * 3.0) * 40.0
		velocity = velocity.lerp(want, clampf(2.0 * delta, 0.0, 1.0))
	else:
		velocity = velocity.lerp(Vector2(0, sin(_bob * 2.0) * 20.0), clampf(2.0 * delta, 0.0, 1.0))

func _ai_boss(delta: float, spd: float) -> void:
	_fall(delta)
	if not _aggro or target == null:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		return
	var dir := signf(target.global_position.x - global_position.x)
	var dist := absf(target.global_position.x - global_position.x)
	# Phase one keeps its distance; phase two closes and pressures.
	var want := 0.0
	if _phase == 1:
		want = dir * spd * (-0.6 if dist < 200.0 else 0.7)
	else:
		want = dir * spd * 1.25
	velocity.x = move_toward(velocity.x, want, 1200.0 * delta)
	if is_on_floor() and (is_on_wall() or _gap_ahead(dir)):
		velocity.y = -600.0

func _boss_logic(_delta: float) -> void:
	if _phase == 1 and health_ratio() < 0.5:
		_phase = 2
		board = Monsters.build_board(kind, "board_phase2")
		_make_runner()
		body_color = Color(1.0, 0.5, 0.3)
		sprite_tint = Color(1.35, 0.7, 0.55)
		Fx.shake(14.0)
		Fx.ring(global_position, Color(1, 0.4, 0.4), 160.0)
		Fx.text(global_position + Vector2(0, -60), "ARBITER: SECOND FORM", Color(1, 0.6, 0.6))
		Audio.play("boss")

func _gap_ahead(dir: float) -> bool:
	if room == null or not room.has_method("is_solid_at"):
		return false
	var probe := global_position + Vector2(dir * (_size + 10.0), _size + 22.0)
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

func apply_damage(amount: float, elements: Array = [], source: Node = null, show_number: bool = true) -> float:
	if modifier == "armored":
		amount *= 0.7
	return super.apply_damage(amount, elements, source, show_number)

func _draw() -> void:
	# The sprite is the body; what is left here is the read-out layered over it.
	var s := _size
	if modifier != "":
		draw_arc(Vector2.ZERO, s + 6.0, 0, TAU, 24, MODIFIERS[modifier]["color"], 2.0)
	if def.get("elite", false) or def.get("boss", false):
		draw_arc(Vector2.ZERO, s + 10.0, 0, TAU, 28, Color(1, 0.9, 0.5, 0.7), 1.5)

	draw_health_bar(s * 2.4, -s - 12.0)
	if _aggro:
		draw_circle(Vector2(0, -s - 20.0), 2.5, Color(1, 0.4, 0.4, 0.9))
