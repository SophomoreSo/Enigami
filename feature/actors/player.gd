class_name Player
extends Actor

## Platforming plus one live skill circuit: the weapon's graph.
##
## One board, the weapon's own — its attack form on the root, and whatever the
## player has built on after it — and two ways to fire it. The attack button
## runs the graph as it is, again and again for as long as it is held, and
## costs nothing. Holding the cast button charges it instead: mana buys the
## cast life, which a graph with a cycle in it spends on laps, and letting go
## casts it with whatever the hold paid for. The graph's own length decides
## the cadence either way.

signal cast_fired()
signal parry_success()

## The silhouette the sprite has to stand on, and the reach of a hit against it.
const BODY := Vector2(20.0, 30.0)
const HURT_RADIUS := 13.0
## How long a blow that gets through leaves the player untouchable. A full
## second is room to pick the body up and walk it out of whatever landed the
## hit, rather than be chain-hit where they stand. It is also the gate a
## monster leaning on the player deals its contact damage through, so it sets
## how fast being stood on wears the health bar down.
const HURT_INVULN := 1.0

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
## reach so the window can stay short, and the recovery runs from the press
## rather than from the end of the move, so a third of it is gone before the
## dash has even let go — which is what makes chaining them feel free.
##
## It goes left or right and nothing else. A dash that could be aimed upward was
## a second way to fly, and it left the key meaning two different things — "get
## past that" on the ground, "climb" in the air. Flat, it reads as one move, and
## the jump stays the only way up.
##
## The reach is about two and a half cells of the room grid: far enough to be
## through something and out the other side, short enough to be a step rather
## than a jump across the room.
const DASH_SPEED := 880.0
const DASH_TIME := 0.09
const DASH_COOLDOWN := 0.30
## What a dash is worth as a dodge, counted from the press. It is set a hair
## longer than the dash itself so the move is covered end to end, and a blow
## arriving as the dash finishes still passes through.
const DASH_INVULN := 0.10
## How much longer the weapon waits between casts than its graph alone would.
## A bare graph is three or four cells long, so left alone it comes round again
## in a fortieth of a second — a held button became a blur with no swing in it
## to read. The multiplier is what makes a cast a swing rather than a stream:
## at ten a bare sword lunges about two and a half times a second, slow enough
## to see each one start and end, and still quick enough to chain. A graph with
## more built on it waits proportionally longer, and every OVERCLOCK on it
## shortens the wait as it always did.
const CAST_COOLDOWN_MUL := 10.0
const COYOTE := 0.10
const JUMP_BUFFER := 0.12
## A stick has no cursor to point at, so it aims at a point far enough down
## itself to be past anything's reach. How far a lunge actually goes is how far
## the stick is pushed — see `aim_reach`.
const STICK_AIM_REACH := 2000.0
## How far the right stick has to be pushed before it aims at all. Past it, how
## much further says how far the attack reaches (`reach_of`).
const STICK_DEAD := 0.35

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
## The weapon's graph, run live. There is one: the weapon is the skill.
var runner: SkillRunner = null
var room = null
var aim: Vector2 = Vector2.RIGHT
## Where the player is pointing, in world space, as opposed to `aim` which is
## only the direction. A lunge lands here rather than a fixed distance out.
var aim_point: Vector2 = Vector2.ZERO
## How far the attack being aimed should go, 0 to 1: how far past its dead zone
## the right stick is pushed, a gamepad's or the touch console's. 0 still goes
## `Attacks.REACH_MIN` of the attack's own distance; 1 goes all of it. The
## pointer always asks for all of it — a mouse points at a place, and a lunge
## already lands on that place (`aim_point`).
var aim_reach: float = 1.0
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
## Set while a screen over the game takes the keys — the skill editor.
var input_locked: bool = false
## Set by an NPC for as long as they are talking to this player: the talk key
## still moves the conversation on, but nothing else the player does acts.
var talk_locked: bool = false

## Movement runs as a state machine. Every frame the senses are read, the state
## is re-picked from them, and only then does that state act — so the state an
## action runs in describes this frame, not the one before a jump or a ledge.
## All of it — the states, what each does, which can follow which and what
## opens each way — is the `player` machine in the content database
## (`data/db/machines/player.sql`). What is left here is what its rows name:
## the actions a state takes and the senses a condition reads, handed over in
## `_setup_fsm`.
var machine: Machine
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
	current_state = machine.start

func _notification(what: int) -> void:
	# Not _exit_tree: a player carried between rooms leaves the tree and comes
	# back without _ready running again, and would return with no states.
	if what == NOTIFICATION_PREDELETE and machine != null:
		machine.cleanup()

## The words the machine's rows are written in: the actions a state's steps
## take, and the senses its conditions read. Which states there are, what each
## does, which can follow which and when is the table's to say, and a row's to
## change; a row naming a word that is not here is reported, not guessed at.
func _setup_fsm() -> void:
	machine = Machine.build("player", {
		"brake": _action_brake,
		"run": _action_run,
		"steer": _action_steer,
		"gravity": _action_gravity,
		"cling": _action_cling,
		"jump": _action_jump,
		"dash": _action_dash,
		"rush": _action_rush,
	}, {
		"dashing": is_dashing,
		"on_floor": is_on_floor,
		"wall": func() -> int: return _wall_dir,
		"dir": func() -> float: return _dir,
		"velocity": func() -> Vector2: return velocity,
	})
	for fault in machine.faults:
		push_error("Player: the player machine — %s" % fault)
	if machine.start == null:
		push_error("Player: no state to start in, so the player will not move — is data/enigami.db built and shipped?")

## Hands the player a weapon and the graph on it. The runner is rebuilt
## wholesale; the old one goes away with its signals.
func setup(weapon: String, board: SkillBoard) -> void:
	weapon_id = weapon
	runner = SkillRunner.new(board)
	runner.cooldown_mul = CAST_COOLDOWN_MUL
	runner.base_payload_provider = func() -> Payload: return Weapons.base_payload(weapon_id)
	runner.fired.connect(_on_fired)
	runner.cycle_started.connect(_on_cycle_started)
	runner.dilation_requested.connect(func(sec: float) -> void: TimeCtl.dilate(sec, 0.42))
	runner.parry_opened.connect(_on_parry_opened)

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

## Charging runs only while the cast button is held on a graph that could be
## cast right now, and only while there is mana to pay for it. Released, it
## bleeds off quickly: the depth is bought for this burst, not banked.
func _update_charge(delta: float, casting: bool) -> void:
	# While the button is down the charge only ever holds or grows. Letting the
	# decay branch run once it reached the cap made the two fight each other
	# frame by frame — charge sat just under the cap while mana drained away
	# into the gap being refilled.
	if casting and can_charge():
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
	# Let go, or hold a graph still recovering, and it bleeds off.
	charging = false
	charge = maxf(0.0, charge - CHARGE_DECAY * delta)
	if _mana_pause > 0.0:
		_mana_pause = maxf(0.0, _mana_pause - delta)
	elif mana < MAX_MANA:
		mana = minf(MAX_MANA, mana + MANA_REGEN * delta)

func can_dash() -> bool:
	return _dash_cd <= 0.0 and stamina >= DASH_STAMINA

## A graph still recovering cannot be charged. The wait is the graph's own
## cadence, and letting a hold run alongside it would buy the next cast's life
## out of time already being spent — a long graph would come back charged for
## free, and the hold would stop being a decision made against the cooldown.
## Holding through the wait is not punished: the charge simply starts building
## the moment the graph comes free.
func can_charge() -> bool:
	return runner != null and runner.is_ready()

## The graph was edited under the runner: it walks it again.
func rebuild_runner() -> void:
	if runner != null:
		runner.refresh()

func _on_parry_opened(seconds: float) -> void:
	parry_time = maxf(parry_time, seconds)

## A cycle started. If a release was waiting for one, this is the cast it
## bought: the life it paid for went in with the cycle, and the wait is over.
func _on_cycle_started() -> void:
	_cast_buffer = 0.0

func _on_fired(payload: Payload) -> void:
	var p := Weapons.finalize(weapon_id, payload)
	Attacks.spawn(p, {
		"attacker": self, "room": room, "team": team,
		"aim": aim, "reach": aim_reach, "origin": global_position,
		"gravity": Weapons.uses_gravity_shots(weapon_id),
	})
	cast_fired.emit()

## How far the right stick asks an attack to reach, from how hard it is pushed:
## nothing at the edge of its dead zone, all of it at the rim.
static func reach_of(push: float) -> float:
	return clampf(inverse_lerp(STICK_DEAD, 1.0, push), 0.0, 1.0)

## The push that asks for `reach`, for whatever aims through the stick without a
## hand on one — the touch console. A hair past the dead zone at nothing, so the
## shortest reach still aims.
static func push_for(reach: float) -> float:
	return lerpf(STICK_DEAD + 0.01, 1.0, clampf(reach, 0.0, 1.0))

## Whether a cast asked for has still to go off, or is going off: the release
## is in the buffer, or the graph's pulse is still out. For whatever has to
## keep aiming a cast until it has gone — the touch console, whose thumb leaves
## the stick in the same moment it casts.
func casting() -> bool:
	return _cast_buffer > 0.0 or (runner != null and not runner.is_ready())

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
	# Holding the cast button charges; letting go is what fires it. A tap is
	# simply a charge of nothing, so a quick press still casts as it always did.
	var holding := not controls_locked() and Input.is_action_pressed("cast_skill")
	# Taken before the charge is touched: on the frame of the release the button
	# already reads as up, and letting the bleed-off run first shaved a fifth
	# off what the player had actually paid for.
	if not controls_locked() and Input.is_action_just_released("cast_skill"):
		cast_charge = charge
		charge = 0.0
		# Held over a few frames, so a release landing on the tail of the last
		# cooldown still goes off instead of being swallowed.
		_cast_buffer = CAST_BUFFER
	_update_charge(delta, holding)
	_cast_buffer = maxf(0.0, _cast_buffer - delta)
	# The attack button runs the graph as it is, for as long as it is held and
	# as often as the graph comes round — and never while a charge is being
	# built, which would spend the cast the hold is paying for on nothing.
	var attacking := not controls_locked() and not holding and Input.is_action_pressed("attack")
	if runner != null:
		# Whatever a release paid for rides on the cast it bought, and on no
		# other: the life is read once, as a cycle starts, so it is offered only
		# while the release is still waiting for one.
		runner.ttl_bonus = int(cast_charge) if _cast_buffer > 0.0 else 0
		runner.set_active(_cast_buffer > 0.0 or attacking)
		runner.update(delta)
	# Aiming is the player's hand as much as walking is: while a screen has the
	# controls, the weapon stays where it was pointing instead of following the
	# pointer round a menu.
	if not controls_locked():
		_update_aim()

func _update_aim() -> void:
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > STICK_DEAD:
		aim = stick.normalized()
		aim_reach = reach_of(stick.length())
		aim_point = global_position + aim * STICK_AIM_REACH
	else:
		aim_reach = 1.0
		# `Pointer` rather than the viewport: while the player has the controls
		# the game is doing the pointing, at whatever speed the setting asks
		# for. It answers the system's own pointer the rest of the time, and at
		# 1.0 the two are the same thing.
		var at := Pointer.world_point(self)
		var m := at - global_position
		if m.length() > 4.0:
			aim = m.normalized()
		aim_point = at

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

	if current_state != null:
		var next := current_state.find_next_node()
		if next != null:
			_change_state(next)
		current_state.perform()

	move_and_slide()
	# The state that just ran set `velocity` from the controls; a knockback is
	# not something the player asked for, so it moves them on its own.
	apply_shove(delta)

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
## What a state's steps can take, by the names `_setup_fsm` gives them. Each is
## one thing the body does on a frame; which a state takes, and in what order,
## is the table's.

## Slows to a stop along the ground.
func _action_brake() -> void:
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * get_physics_process_delta_time())

## Speeds up toward the direction held, along the ground.
func _action_run() -> void:
	var delta := get_physics_process_delta_time()
	velocity.x = move_toward(velocity.x, _dir * RUN_SPEED * speed_scale(), GROUND_ACCEL * delta)

## The same in the air, and easing off when nothing is held.
func _action_steer() -> void:
	var delta := get_physics_process_delta_time()
	if _dir != 0.0:
		velocity.x = move_toward(velocity.x, _dir * RUN_SPEED * speed_scale(), AIR_ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

## Falls faster, up to the fastest fall.
func _action_gravity() -> void:
	velocity.y = minf(velocity.y + GRAVITY * get_physics_process_delta_time(), MAX_FALL)

## A hugged wall holds the fall to a slide.
func _action_cling() -> void:
	if velocity.y > WALL_SLIDE_SPEED:
		velocity.y = WALL_SLIDE_SPEED
		Cues.at(&"wall_slide", global_position, {"dir": _wall_dir})

## A press becomes a jump — which one is decided by what is available: ground
## or coyote time, a wall, the air jump — and letting go early cuts it short.
func _action_jump() -> void:
	if _buffer > 0.0:
		if _coyote > 0.0:
			velocity.y = JUMP_VELOCITY
			_buffer = 0.0
			_coyote = 0.0
			Cues.at(&"jump", global_position, {"kind": "ground"})
		elif _wall_dir != 0:
			velocity.y = JUMP_VELOCITY * 0.95
			velocity.x = -_wall_dir * WALL_JUMP_PUSH
			# The push goes away from the wall, but the player keeps facing the
			# way they hold, which is still into it: turning round is theirs to
			# do, not the kick's.
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

## A press starts a dash, when the stamina and the cooldown allow. It takes
## over from the next frame, when the machine sees it under way.
func _action_dash() -> void:
	if not controls_locked() and Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		if stamina < DASH_STAMINA:
			# Nothing happening at all reads as a dropped input, so say why.
			Cues.at(&"refused", global_position, {"kind": "stamina"})
		else:
			stamina -= DASH_STAMINA
			_stamina_pause = STAMINA_PAUSE
			# Whichever way they are held, or the way they last faced if they are
			# not: `facing` is set from `_dir` at the top of the frame, so it is
			# already what a moving player is asking for. Up and down are not read
			# at all — they aim, they do not steer a dash.
			_dash_dir = Vector2(facing, 0)
			_dash_time = DASH_TIME
			_dash_cd = DASH_COOLDOWN
			# Armed once, at the press, rather than topped up every frame of the
			# dash: what the move is worth as a dodge is then a window of its own
			# length, and not the dash's length plus whatever the top-up was.
			invuln = maxf(invuln, DASH_INVULN)
			Cues.at(&"dash", global_position)

## A dash under way carries the body until its time runs out.
func _action_rush() -> void:
	_dash_time -= get_physics_process_delta_time()
	velocity = _dash_dir * DASH_SPEED

## A guard window opened by ON PARRY swallows the hit and runs the branch flow.
func apply_damage(amount: float, elements: Array = [], source: Node = null, is_hit: bool = true) -> float:
	if parry_time > 0.0 and is_hit and amount > 0.0:
		parry_time = 0.0
		TimeCtl.hitstop(0.12)
		Cues.at(&"parry", global_position)
		invuln = maxf(invuln, 0.4)
		parry_success.emit()
		if runner != null:
			var p: Payload = runner.consume_parry()
			if p != null:
				_on_fired(p)
		return 0.0
	var dealt := super.apply_damage(amount, elements, source, is_hit)
	# Damage over time ticks every frame, so the cue and the i-frames hang off
	# the blow that lit the burn rather than off the burning. Without `is_hit`
	# one Arbiter shot played its hurt sound a hundred and fifty times over the
	# 2.5s fire, and re-armed invulnerability every frame it did — which made
	# being on fire the safest place in the game.
	if dealt > 0.0 and is_hit:
		Cues.at(&"hurt", global_position, {"team": team})
		invuln = maxf(invuln, HURT_INVULN)
	return dealt

## --- read by the view -------------------------------------------------------
func is_dashing() -> bool:
	return _dash_time > 0.0

## The movement state, by name: Idle, Run, Rise, Fall, WallSlide or Dash.
func state_name() -> String:
	return _state_label(current_state)

func _state_label(state: FSMNode) -> String:
	return state.label if state != null else "Unknown"

## 0 → 1 as the dash comes back; 1 when it is ready.
func dash_recovery() -> float:
	if _dash_cd <= 0.0:
		return 1.0
	return clampf(1.0 - _dash_cd / DASH_COOLDOWN, 0.0, 1.0)
