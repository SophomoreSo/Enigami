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

## The silhouette the sprite has to stand on, and the reach of a hit against it.
const BODY := Vector2(20.0, 30.0)
const HURT_RADIUS := 13.0

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
## How much longer the weapon's own attack waits between swings than its board alone would.
## The innate boards are three or four cells long, so left alone they come round
## again in a fortieth of a second — a held button became a blur with no swing
## in it to read. The multiplier is what makes the basic a swing rather than a
## stream: at ten it lands about two and a half times a second, slow enough to
## see each one start and end, and still quick enough to combo off.
const BASIC_COOLDOWN_MUL := 10.0
const COYOTE := 0.10
const JUMP_BUFFER := 0.12
## A stick has no cursor to point at, so it aims at a point far enough down
## itself to be past anything's reach — which leaves gamepad lunges going their
## full distance, the way they always have.
const STICK_AIM_REACH := 2000.0

## Stamina is what a dash spends. The dash keeps its short cooldown, which is
## what makes chaining feel responsive; stamina is the separate question of how
## long you may keep chaining before you have to stop. Four dashes' worth, and
## a pause before it starts coming back, so a retreat is a decision rather than
## something held down.
const MAX_STAMINA := 100.0
const DASH_STAMINA := 25.0
const STAMINA_REGEN := 38.0    ## per second
const STAMINA_PAUSE := 0.45    ## quiet after a dash before any of it returns

## Mana is what charging spends, and the longer the hold the more of it goes.
## Holding the cast button builds the charge; releasing it is what casts, with
## whatever was built. Charging engages on every skill alike — nothing is
## special-cased on the shape of the board — and the life it buys is spent by
## whatever cycle the player put there to spend it.
## The first cast of a hold still goes out at once — charge is what the ones
## after it ride on, so holding is a decision about depth, not a wind-up that
## delays the opening shot.
const MAX_MANA := 100.0
const MANA_REGEN := 20.0          ## per second
const MANA_PAUSE := 0.6           ## quiet after charging before any returns
const CHARGE_TTL_RATE := 12.0     ## extra life bought per second of holding
const MANA_PER_TTL := 1.4
const MAX_CHARGE_TTL := float(SkillRunner.MAX_TTL_BONUS)
const CHARGE_DECAY := 150.0       ## how fast an unspent charge bleeds off
const CAST_BUFFER := 0.18         ## grace for a release landing on a cooldown

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
var stamina: float = MAX_STAMINA
var _stamina_pause: float = 0.0
var mana: float = MAX_MANA
## Extra life being built up while the button is held, in TTL.
var charge: float = 0.0
## What the last release actually paid for, carried by the cast it bought.
var cast_charge: float = 0.0
var _cast_buffer: float = 0.0
var _mana_pause: float = 0.0
## True while the cast button is actually buying life. Read rather than
## announced: it is a state that lasts, not a moment that happens.
var charging: bool = false
var parry_time: float = 0.0
var parry_slot: int = -1
## Set while a screen over the game takes the keys — the skill editor.
var input_locked: bool = false
## Set by an NPC for as long as they are talking to this player: the talk key
## still moves the conversation on, but nothing else the player does acts.
var talk_locked: bool = false

## Movement runs as a state machine. Every frame the senses are read, the state
## is re-picked from them, and only then does that state act — so the state an
## action runs in describes this frame, not the one before a jump or a ledge.
var fsm_idle: FSMNode
var fsm_run: FSMNode
var fsm_rise: FSMNode
var fsm_fall: FSMNode
var fsm_wall_slide: FSMNode
var fsm_dash: FSMNode
var current_state: FSMNode
## Log state transitions.
var debug_mode: bool = false
## Horizontal input this frame, -1..1.
var _dir: float = 0.0

func _ready() -> void:
	team = 0
	max_health = GameState.max_health()
	super._ready()
	hurt_radius = HURT_RADIUS
	_make_body(BODY.x, BODY.y)
	add_to_group("player")
	_setup_fsm()
	current_state = fsm_idle

func _notification(what: int) -> void:
	# Not _exit_tree: a player carried between rooms leaves the tree and comes
	# back without _ready running again, and would return with no states.
	if what == NOTIFICATION_PREDELETE and current_state != null:
		for s in [fsm_idle, fsm_run, fsm_rise, fsm_fall, fsm_wall_slide, fsm_dash]:
			s.cleanup()

func _setup_fsm() -> void:
	fsm_idle = FSMNode.new(_action_idle)
	fsm_run = FSMNode.new(_action_run)
	fsm_rise = FSMNode.new(_action_air)
	fsm_fall = FSMNode.new(_action_air)
	fsm_wall_slide = FSMNode.new(_action_wall_slide)
	fsm_dash = FSMNode.new(_action_dash)

	# What it takes to be in each state. They are exclusive, so at most one holds
	# on any frame, and every state can reach every other: a dash can end in the
	# air or on the ground, a wall kick can go straight up, a ledge drops into a
	# fall from a standstill.
	var entry := {
		fsm_dash: func() -> bool: return _dash_time > 0.0,
		fsm_wall_slide: func() -> bool: return _airborne() and _wall_dir != 0,
		fsm_run: func() -> bool: return _grounded() and _dir != 0.0,
		fsm_idle: func() -> bool: return _grounded() and _dir == 0.0,
		fsm_rise: func() -> bool: return _airborne() and _wall_dir == 0 and velocity.y < 0.0,
		fsm_fall: func() -> bool: return _airborne() and _wall_dir == 0 and velocity.y >= 0.0,
	}
	for from: FSMNode in entry:
		for to: FSMNode in entry:
			if to != from:
				from.add_next_node(entry[to], to)

func _grounded() -> bool:
	return _dash_time <= 0.0 and is_on_floor()

func _airborne() -> bool:
	return _dash_time <= 0.0 and not is_on_floor()

func setup(weapon: String, boards: Array) -> void:
	weapon_id = weapon
	# Runners are rebuilt wholesale; the old ones go away with their signals.
	runners.clear()
	for i in boards.size():
		runners.append(_make_runner(boards[i], i))
	basic_runner = _make_runner(Weapons.make_innate_board(weapon_id), -1)
	basic_runner.cooldown_mul = BASIC_COOLDOWN_MUL
	selected_slot = clampi(selected_slot, 0, maxi(runners.size() - 1, 0))

func _make_runner(board: SkillBoard, slot: int) -> SkillRunner:
	var runner := SkillRunner.new(board)
	runner.base_payload_provider = func() -> Payload: return Weapons.base_payload(weapon_id)
	runner.fired.connect(_on_fired.bind(slot))
	runner.dilation_requested.connect(func(sec: float) -> void: TimeCtl.dilate(sec, 0.42))
	runner.parry_opened.connect(_on_parry_opened.bind(slot))
	return runner

## Whether the weapon in hand will carry what is on this slot's board. The
## hideout already refuses to equip a board a weapon rejects, but a board can
## turn incompatible after it is equipped — edited mid-raid, or carried onto a
## different weapon in the sandbox — so the rule is applied again at the moment
## of firing rather than trusted from when the loadout was built.
func stamina_ratio() -> float:
	return clampf(stamina / MAX_STAMINA, 0.0, 1.0)

func mana_ratio() -> float:
	return clampf(mana / MAX_MANA, 0.0, 1.0)

## Mana taken back off an enemy by a MANA DRAIN attack. It lands whatever the
## charge is doing, unlike regeneration: `_mana_pause` exists to stop a hold
## refilling itself the moment it is released, and this was earned by landing a
## hit rather than by waiting.
func gain_mana(amount: float) -> void:
	mana = minf(MAX_MANA, mana + maxf(amount, 0.0))

func charge_ratio() -> float:
	return clampf(charge / MAX_CHARGE_TTL, 0.0, 1.0)

## One ceiling for every skill in the game. Nothing here asks what shape the
## board is: charging engages the same way on all of them, and what the life it
## buys is worth is then up to what the player built.
func charge_cap() -> float:
	return MAX_CHARGE_TTL

## Charging runs only while the cast button is held on a slot that could be cast
## right now, and only while there is mana to pay for it. Released, it bleeds
## off quickly: the depth is bought for this burst, not banked.
func _update_charge(delta: float, casting: bool) -> void:
	# While the button is down the charge only ever holds or grows. Letting the
	# decay branch run once it reached the cap made the two fight each other
	# frame by frame — charge sat just under the cap while mana drained away
	# into the gap being refilled.
	if casting and can_charge(selected_slot):
		charging = true
		var cap := charge_cap()
		if charge < cap and mana > 0.0:
			var want := CHARGE_TTL_RATE * delta
			var afford := mana / MANA_PER_TTL
			var gained := minf(minf(want, afford), cap - charge)
			charge += gained
			mana = maxf(0.0, mana - gained * MANA_PER_TTL)
		_mana_pause = MANA_PAUSE
		return
	# Let go, or hold something that cannot take a charge — a slot the weapon
	# refuses, or one still recovering — and it bleeds off.
	charging = false
	charge = maxf(0.0, charge - CHARGE_DECAY * delta)
	if _mana_pause > 0.0:
		_mana_pause = maxf(0.0, _mana_pause - delta)
	elif mana < MAX_MANA:
		mana = minf(MAX_MANA, mana + MANA_REGEN * delta)

func can_dash() -> bool:
	return _dash_cd <= 0.0 and stamina >= DASH_STAMINA

func can_cast(slot: int) -> bool:
	if slot < 0 or slot >= runners.size():
		return false
	return Weapons.accepts_board(weapon_id, runners[slot].board)

## A skill still recovering cannot be charged. The wait is the board's own
## cadence, and letting a hold run alongside it would buy the next cast's life
## out of time already being spent — a long board would come back charged for
## free, and the hold would stop being a decision made against the cooldown.
## Holding through the wait is not punished: the charge simply starts building
## the moment the slot comes free.
func can_charge(slot: int) -> bool:
	return can_cast(slot) and runners[slot].is_ready()

## Arms a slot. Out-of-range numbers are ignored rather than clamped, so a
## weapon with two slots simply does not answer to "3".
func select_slot(slot: int) -> void:
	if slot < 0 or slot >= runners.size() or slot == selected_slot:
		return
	selected_slot = slot
	Cues.emit_cue(&"ui", {"kind": "arm"})

func rebuild_runner(slot: int) -> void:
	if slot < 0 or slot >= runners.size():
		return
	runners[slot].refresh()

## Say why, once, on the press. A skill the weapon will not carry doing nothing
## at all is indistinguishable from the game having missed the input.
func _refuse_cast() -> void:
	if selected_slot < 0 or selected_slot >= runners.size():
		return
	Cues.at(&"refused", global_position, {"kind": "weapon",
		"text": Weapons.rejection_note(weapon_id, runners[selected_slot].board)})

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

## Whether the player's own input is ignored: a screen has the keys, or someone
## is talking to them.
func controls_locked() -> bool:
	return input_locked or talk_locked

func _process(delta: float) -> void:
	_process_status(delta)
	if parry_time > 0.0:
		parry_time -= delta
	if not controls_locked():
		for i in runners.size():
			if Input.is_action_just_pressed("skill_%d" % (i + 1)):
				select_slot(i)
	# Holding the cast button charges; letting go is what fires it. A tap is
	# simply a charge of nothing, so a quick press still casts as it always did.
	var holding := not controls_locked() and Input.is_action_pressed("cast_skill")
	if holding and Input.is_action_just_pressed("cast_skill") and not can_cast(selected_slot):
		_refuse_cast()
	# Taken before the charge is touched: on the frame of the release the button
	# already reads as up, and letting the bleed-off run first shaved a fifth
	# off what the player had actually paid for.
	if not controls_locked() and Input.is_action_just_released("cast_skill") and can_cast(selected_slot):
		cast_charge = charge
		charge = 0.0
		# Held over a few frames, so a release landing on the tail of the last
		# cooldown still goes off instead of being swallowed.
		_cast_buffer = CAST_BUFFER
	_update_charge(delta, holding)
	_cast_buffer = maxf(0.0, _cast_buffer - delta)
	for i in runners.size():
		var r: SkillRunner = runners[i]
		var armed := i == selected_slot
		# Whatever the release paid for stays with the cast it bought, right
		# through to the end of it, and only clears once the slot is free again.
		if armed and (_cast_buffer > 0.0 or not r.is_ready()):
			r.ttl_bonus = int(cast_charge)
		else:
			r.ttl_bonus = 0
		r.set_active(armed and _cast_buffer > 0.0 and can_cast(i))
		r.update(delta)
	if _cast_buffer > 0.0 and not runners[selected_slot].is_ready():
		_cast_buffer = 0.0      # it went off; stop asking
	if basic_runner != null:
		basic_runner.set_active(not controls_locked() and Input.is_action_pressed("attack"))
		basic_runner.update(delta)
	_update_aim()

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
	_dir = 0.0
	if not controls_locked():
		_dir = Input.get_axis("move_left", "move_right")
	if _dir != 0.0:
		face(int(signf(_dir)))
	if _dash_cd > 0.0:
		_dash_cd -= delta
	# A dash owns the body outright: nothing is sensed, buffered or refilled
	# while it runs.
	if _dash_time <= 0.0:
		_sense(delta)

	var next := current_state.find_next_node()
	if next != null:
		_change_state(next)
	current_state.perform()

	move_and_slide()

func _change_state(new_state: FSMNode) -> void:
	if debug_mode:
		print("State: %s → %s" % [_state_label(current_state), _state_label(new_state)])
	current_state = new_state

## Everything a state is picked from and acts on that is not the body itself.
func _sense(delta: float) -> void:
	if is_on_floor():
		_coyote = COYOTE
		_air_jump_used = false
	else:
		_coyote = maxf(0.0, _coyote - delta)
	_buffer = maxf(0.0, _buffer - delta)
	if not controls_locked() and Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER

	# Wall interaction: hugging a wall slows the fall and enables a kick-off.
	_wall_dir = 0
	if not is_on_floor() and is_on_wall_only():
		var normal := get_wall_normal()
		if absf(normal.x) > 0.5 and _dir != 0.0 and signf(_dir) == -signf(normal.x):
			_wall_dir = -int(signf(normal.x))

	# Stamina only comes back once the dashing stops.
	if _stamina_pause > 0.0:
		_stamina_pause = maxf(0.0, _stamina_pause - delta)
	elif stamina < MAX_STAMINA:
		stamina = minf(MAX_STAMINA, stamina + STAMINA_REGEN * delta)

## --- state actions ----------------------------------------------------------
func _action_idle() -> void:
	var delta := get_physics_process_delta_time()
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	_apply_gravity(delta)
	_jump_and_dash()

func _action_run() -> void:
	var delta := get_physics_process_delta_time()
	velocity.x = move_toward(velocity.x, _dir * RUN_SPEED * speed_scale(), GROUND_ACCEL * delta)
	_apply_gravity(delta)
	_jump_and_dash()

## Rising and falling steer the same; they are apart so the arc can be told.
func _action_air() -> void:
	var delta := get_physics_process_delta_time()
	_steer_air(delta)
	_apply_gravity(delta)
	_jump_and_dash()

func _action_wall_slide() -> void:
	var delta := get_physics_process_delta_time()
	_steer_air(delta)
	_apply_gravity(delta)
	if velocity.y > WALL_SLIDE_SPEED:
		velocity.y = WALL_SLIDE_SPEED
		Cues.at(&"wall_slide", global_position, {"dir": _wall_dir})
	_jump_and_dash()

func _action_dash() -> void:
	_dash_time -= get_physics_process_delta_time()
	velocity = _dash_dir * DASH_SPEED
	invuln = maxf(invuln, 0.05)

func _steer_air(delta: float) -> void:
	if _dir != 0.0:
		velocity.x = move_toward(velocity.x, _dir * RUN_SPEED * speed_scale(), AIR_ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

func _apply_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

## The moves every state but the dash can start. Which jump a press becomes is
## decided by what is available — ground or coyote time, a wall, the air jump —
## and a dash begun here takes over from the next frame.
func _jump_and_dash() -> void:
	if _buffer > 0.0:
		if _coyote > 0.0:
			velocity.y = JUMP_VELOCITY
			_buffer = 0.0
			_coyote = 0.0
			Cues.at(&"jump", global_position, {"kind": "ground"})
		elif _wall_dir != 0:
			velocity.y = JUMP_VELOCITY * 0.95
			velocity.x = -_wall_dir * WALL_JUMP_PUSH
			face(-_wall_dir)
			_buffer = 0.0
			# Kicking off a wall is a fresh launch, so it hands the air jump
			# back the way landing does.
			_air_jump_used = false
			Cues.at(&"jump", global_position, {"kind": "wall"})
		elif can_double_jump and not _air_jump_used:
			# Assigning the speed rather than adding to it is the point: the
			# air jump then lifts just as well out of a long fall as it does
			# off the top of a hop, instead of being eaten by gravity.
			_air_jump_used = true
			velocity.y = DOUBLE_JUMP_VELOCITY
			_buffer = 0.0
			Cues.at(&"jump", global_position, {"kind": "air"})
	# Releasing jump early cuts the arc short.
	if not controls_locked() and Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.45

	if not controls_locked() and Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		if stamina < DASH_STAMINA:
			# Nothing happening at all reads as a dropped input, so say why.
			Cues.at(&"refused", global_position, {"kind": "stamina", "text": "WINDED"})
		else:
			stamina -= DASH_STAMINA
			_stamina_pause = STAMINA_PAUSE
			var d := Vector2(_dir, Input.get_axis("move_up", "move_down"))
			if d.length() < 0.2:
				d = Vector2(facing, 0)
			_dash_dir = d.normalized()
			_dash_time = DASH_TIME
			_dash_cd = DASH_COOLDOWN
			Cues.at(&"dash", global_position)

## A guard window opened by ON PARRY swallows the hit and runs the branch flow.
func apply_damage(amount: float, elements: Array = [], source: Node = null, is_hit: bool = true) -> float:
	if parry_time > 0.0 and is_hit and amount > 0.0:
		parry_time = 0.0
		TimeCtl.hitstop(0.12)
		Cues.at(&"parry", global_position)
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
	var dealt := super.apply_damage(amount, elements, source, is_hit)
	# Damage over time ticks every frame, so the cue and the i-frames hang off
	# the blow that lit the burn rather than off the burning. Without `is_hit`
	# one Arbiter shot played its hurt sound a hundred and fifty times over the
	# 2.5s fire, and re-armed invulnerability every frame it did — which made
	# being on fire the safest place in the game.
	if dealt > 0.0 and is_hit:
		Cues.at(&"hurt", global_position, {"team": team})
		invuln = maxf(invuln, 0.45)
	return dealt

## --- read by the view -------------------------------------------------------
func is_dashing() -> bool:
	return _dash_time > 0.0

## The movement state, by name: Idle, Run, Rise, Fall, WallSlide or Dash.
func state_name() -> String:
	return _state_label(current_state)

func _state_label(state: FSMNode) -> String:
	if state == fsm_idle: return "Idle"
	if state == fsm_run: return "Run"
	if state == fsm_rise: return "Rise"
	if state == fsm_fall: return "Fall"
	if state == fsm_wall_slide: return "WallSlide"
	if state == fsm_dash: return "Dash"
	return "Unknown"

## 0 → 1 as the dash comes back; 1 when it is ready.
func dash_recovery() -> float:
	if _dash_cd <= 0.0:
		return 1.0
	return clampf(1.0 - _dash_cd / DASH_COOLDOWN, 0.0, 1.0)
