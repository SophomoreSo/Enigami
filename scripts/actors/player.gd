class_name Player
extends Actor

## Platforming plus a rack of live skill circuits.
##
## The number keys pick which circuit is armed; holding the cast button keeps
## that one board's INPUT firing, and the board's own length decides the
## cadence. The attack button runs the weapon's own innate board instead — that
## one is not part of the loadout and cannot be lost, so a raid that goes badly
## leaves the player poorer but never unarmed.

signal slot_fired(slot: int)   ## -1 for the weapon's own attack
signal parry_success()

const RUN_SPEED := 250.0
const AIR_ACCEL := 1800.0
const GROUND_ACCEL := 2600.0
const FRICTION := 2400.0
const GRAVITY := 1900.0
const MAX_FALL := 900.0
const JUMP_VELOCITY := -610.0
## The air jump is a touch shorter than the first, so the second hop reads as
## a recovery rather than as the better of the two.
const DOUBLE_JUMP_VELOCITY := -540.0
const WALL_SLIDE_SPEED := 120.0
const WALL_JUMP_PUSH := 300.0
## The dash is a movement tool first: it wants to be over almost before it has
## registered, and to be there again the moment it is wanted. Speed carries the
## reach so the window can stay short, and the recovery is deliberately shorter
## than the dash is long, which is what makes chaining them feel free.
const DASH_SPEED := 880.0
const DASH_TIME := 0.13
const DASH_COOLDOWN := 0.30
const COYOTE := 0.10
const JUMP_BUFFER := 0.12
## A stick has no cursor to point at, so it aims at a point far enough down
## itself to be past anything's reach — which leaves gamepad lunges going their
## full distance, the way they always have.
const STICK_AIM_REACH := 2000.0

var weapon_id: String = "SWORD"
var runners: Array[SkillRunner] = []
## The weapon's innate attack, on its own button and outside the loadout.
var basic_runner: SkillRunner
## Which loadout slot the number keys have armed.
var selected_slot: int = 0
var room = null
var aim: Vector2 = Vector2.RIGHT
## Where the player is pointing, in world space, as opposed to `aim` which is
## only the direction. A lunge lands here rather than a fixed distance out.
var aim_point: Vector2 = Vector2.ZERO
var weapon_sprite: Sprite2D
## Whether the player has an air jump at all. Clear it to take the move away —
## for an upgrade that grants it, a debuff, or a room that asks for precision.
var can_double_jump: bool = true

var _coyote: float = 0.0
var _buffer: float = 0.0
var _dash_time: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _wall_dir: int = 0
var _air_jump_used: bool = false
var parry_time: float = 0.0
var parry_slot: int = -1
var input_locked: bool = false
var _trail: Array = []

func _ready() -> void:
	team = 0
	max_health = GameState.max_health()
	super._ready()
	body_color = Color(0.65, 0.9, 1.0)
	hurt_radius = 13.0
	_make_body(20.0, 30.0)
	_make_sprite(Sprites.PLAYER, 30.0)
	_make_weapon_sprite()
	add_to_group("player")
	z_index = 50

## The weapon is a separate tile so it can swing to the aim direction while the
## body keeps running. Every weapon in the atlas points up.
const WEAPON_GRIP := 0.82  ## share of the tile that hangs past the hand
const WEAPON_HAND := 10.0  ## how far out of the body the hand holds it

func _make_weapon_sprite() -> void:
	weapon_sprite = Sprite2D.new()
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.centered = false
	weapon_sprite.scale = Vector2.ONE * Sprites.PIXEL_SCALE
	weapon_sprite.z_index = 1
	add_child(weapon_sprite)
	_refresh_weapon_sprite()

func _refresh_weapon_sprite() -> void:
	if weapon_sprite == null:
		return
	var tex := Sprites.texture(String(Sprites.WEAPONS.get(weapon_id, "weapon_regular_sword")))
	weapon_sprite.texture = tex
	if tex != null:
		# Pivot at the grip, so aiming rotates the blade around the hand.
		weapon_sprite.offset = Vector2(-tex.region.size.x * 0.5, -tex.region.size.y * WEAPON_GRIP)

func setup(weapon: String, boards: Array) -> void:
	weapon_id = weapon
	_refresh_weapon_sprite()
	# Runners are rebuilt wholesale; the old ones go away with their signals.
	runners.clear()
	for i in boards.size():
		runners.append(_make_runner(boards[i], i))
	basic_runner = _make_runner(Weapons.make_innate_board(weapon_id), -1)
	selected_slot = clampi(selected_slot, 0, maxi(runners.size() - 1, 0))

func _make_runner(board: SkillBoard, slot: int) -> SkillRunner:
	var runner := SkillRunner.new(board)
	runner.base_payload_provider = func() -> Payload: return Weapons.base_payload(weapon_id)
	runner.fired.connect(_on_fired.bind(slot))
	runner.dilation_requested.connect(func(sec: float) -> void: Fx.dilate(sec, 0.42))
	runner.parry_opened.connect(_on_parry_opened.bind(slot))
	return runner

## Arms a slot. Out-of-range numbers are ignored rather than clamped, so a
## weapon with two slots simply does not answer to "3".
func select_slot(slot: int) -> void:
	if slot < 0 or slot >= runners.size() or slot == selected_slot:
		return
	selected_slot = slot
	Audio.play("ui", 1.2)

func rebuild_runner(slot: int) -> void:
	if slot < 0 or slot >= runners.size():
		return
	runners[slot].refresh()

func _on_parry_opened(seconds: float, slot: int) -> void:
	parry_time = maxf(parry_time, seconds)
	parry_slot = slot

func _on_fired(payload: Payload, slot: int) -> void:
	var p := Weapons.finalize(weapon_id, payload)
	Attacks.spawn(p, {
		"attacker": self, "room": room, "team": team,
		"aim": aim, "origin": global_position,
		"gravity": Weapons.uses_gravity_shots(weapon_id),
	})
	slot_fired.emit(slot)

func on_dashed() -> void:
	invuln = maxf(invuln, 0.12)

func _process(delta: float) -> void:
	_process_status(delta)
	if parry_time > 0.0:
		parry_time -= delta
	if not input_locked:
		for i in runners.size():
			if Input.is_action_just_pressed("skill_%d" % (i + 1)):
				select_slot(i)
	# Only the armed slot answers the cast button; the rest still tick, so their
	# cooldowns run down while another one is being used.
	var casting := not input_locked and Input.is_action_pressed("cast_skill")
	for i in runners.size():
		runners[i].set_active(casting and i == selected_slot)
		runners[i].update(delta)
	if basic_runner != null:
		basic_runner.set_active(not input_locked and Input.is_action_pressed("attack"))
		basic_runner.update(delta)
	_update_aim()
	_update_anim()
	queue_redraw()

func _update_anim() -> void:
	if flash > 0.55:
		# The knight ships a recoil pose; hold it for the front of the flash.
		play_anim("hit", 1.0, 0)
	elif _dash_time > 0.0:
		play_anim("run", 2.2)
	elif not is_on_floor():
		# The pack has no jump art: hold the stride that reads as rising or
		# falling instead of cycling a run cycle in mid-air.
		play_anim("run", 1.0, 2 if velocity.y < 0.0 else 0)
	elif absf(velocity.x) > 12.0:
		play_anim("run", clampf(absf(velocity.x) / RUN_SPEED, 0.65, 1.6))
	else:
		play_anim("idle")
	# I-frames blink the whole rig, weapon included.
	var lit := invuln <= 0.0 or int(invuln * 24.0) % 2 == 0
	sprite.self_modulate.a = 1.0 if lit else 0.35
	weapon_sprite.self_modulate.a = sprite.self_modulate.a
	weapon_sprite.position = aim * WEAPON_HAND
	weapon_sprite.rotation = aim.angle() + PI * 0.5

func _update_aim() -> void:
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.35:
		aim = stick.normalized()
		aim_point = global_position + aim * STICK_AIM_REACH
	else:
		var m := get_global_mouse_position() - global_position
		if m.length() > 4.0:
			aim = m.normalized()
		aim_point = get_global_mouse_position()

func _physics_process(delta: float) -> void:
	if dead:
		return
	var dir := 0.0
	if not input_locked:
		dir = Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		face(int(signf(dir)))

	if _dash_cd > 0.0:
		_dash_cd -= delta
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_dir * DASH_SPEED
		invuln = maxf(invuln, 0.05)
		_trail.append({"p": global_position, "t": 0.22})
		move_and_slide()
		return

	var on_floor := is_on_floor()
	if on_floor:
		_coyote = COYOTE
		_air_jump_used = false
	else:
		_coyote = maxf(0.0, _coyote - delta)
	_buffer = maxf(0.0, _buffer - delta)
	if not input_locked and Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER

	# Wall interaction: hugging a wall slows the fall and enables a kick-off.
	_wall_dir = 0
	if not on_floor and is_on_wall_only():
		var normal := get_wall_normal()
		if absf(normal.x) > 0.5 and dir != 0.0 and signf(dir) == -signf(normal.x):
			_wall_dir = -int(signf(normal.x))

	var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * RUN_SPEED * speed_scale(), accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	velocity.y += GRAVITY * delta
	if _wall_dir != 0 and velocity.y > WALL_SLIDE_SPEED:
		velocity.y = WALL_SLIDE_SPEED
		if randf() < 0.3:
			Fx.burst(global_position + Vector2(_wall_dir * 10, 8), Color(0.6, 0.7, 0.8), 1, 40.0)
	velocity.y = minf(velocity.y, MAX_FALL)

	if _buffer > 0.0:
		if _coyote > 0.0:
			velocity.y = JUMP_VELOCITY
			_buffer = 0.0
			_coyote = 0.0
			Audio.play("jump")
			Fx.burst(global_position + Vector2(0, 14), Color(0.7, 0.85, 1.0), 4, 70.0)
		elif _wall_dir != 0:
			velocity.y = JUMP_VELOCITY * 0.95
			velocity.x = -_wall_dir * WALL_JUMP_PUSH
			face(-_wall_dir)
			_buffer = 0.0
			# Kicking off a wall is a fresh launch, so it hands the air jump
			# back the way landing does.
			_air_jump_used = false
			Audio.play("jump", 1.15)
		elif can_double_jump and not _air_jump_used:
			# Assigning the speed rather than adding to it is the point: the
			# air jump then lifts just as well out of a long fall as it does
			# off the top of a hop, instead of being eaten by gravity.
			_air_jump_used = true
			velocity.y = DOUBLE_JUMP_VELOCITY
			_buffer = 0.0
			Audio.play("jump", 1.3)
			Fx.ring(global_position + Vector2(0, 10), Color(0.7, 0.9, 1.0), 22.0)
			Fx.burst(global_position + Vector2(0, 12), Color(0.7, 0.85, 1.0), 6, 90.0)
	# Releasing jump early cuts the arc short.
	if not input_locked and Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.45

	if not input_locked and Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		var d := Vector2(dir, Input.get_axis("move_up", "move_down"))
		if d.length() < 0.2:
			d = Vector2(facing, 0)
		_dash_dir = d.normalized()
		_dash_time = DASH_TIME
		_dash_cd = DASH_COOLDOWN
		Audio.play("dash")

	for t in _trail:
		t["t"] -= delta
	_trail = _trail.filter(func(t: Dictionary) -> bool: return t["t"] > 0.0)

	move_and_slide()

## A guard window opened by ON PARRY swallows the hit and runs the branch flow.
func apply_damage(amount: float, elements: Array = [], source: Node = null, show_number: bool = true) -> float:
	if parry_time > 0.0 and show_number and amount > 0.0:
		parry_time = 0.0
		Audio.play("parry")
		Fx.hitstop(0.12)
		Fx.shake(8.0)
		Fx.ring(global_position, Color(1, 0.95, 0.6), 60.0)
		Fx.text(global_position + Vector2(0, -30), "PARRY", Color(1, 0.95, 0.6))
		invuln = maxf(invuln, 0.4)
		parry_success.emit()
		var guard: SkillRunner = null
		if parry_slot == -1:
			guard = basic_runner
		elif parry_slot >= 0 and parry_slot < runners.size():
			guard = runners[parry_slot]
		if guard != null:
			var p: Payload = guard.consume_parry()
			if p != null:
				_on_fired(p, parry_slot)
		return 0.0
	var dealt := super.apply_damage(amount, elements, source, show_number)
	if dealt > 0.0:
		Audio.play("hurt")
		Fx.shake(7.0)
		invuln = maxf(invuln, 0.45)
	return dealt

func _draw() -> void:
	for t in _trail:
		var a: float = clampf(t["t"] / 0.22, 0.0, 1.0)
		draw_circle(to_local(t["p"]), 10.0 * a, Color(0.6, 0.85, 1.0, a * 0.35))

	# The sprite is the body; these are the state read-outs drawn over it.
	if parry_time > 0.0:
		draw_arc(Vector2.ZERO, 24.0, 0, TAU, 24, Color(1, 0.95, 0.6, 0.9), 2.5)
	if _dash_cd > 0.0:
		draw_arc(Vector2(0, 22), 6.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - _dash_cd / DASH_COOLDOWN), 16, Color(0.7, 0.9, 1.0, 0.7), 2.0)
