class_name SkillRunner
extends RefCounted

## Runs a SkillBoard as a live circuit.
##
## A pulse starts at the board's root — the weapon's own part, which is the
## first thing it enters — carrying a base payload, spends one tick inside each
## cell of every component it enters, and mutates the payload on entry.
## Reaching an OUTPUT turns the payload into a real effect. The root only
## restarts once every pulse of the previous cycle has resolved, so board length
## *is* the cooldown.
##
## Board length is the cooldown, though — not the cast time. The walk from the
## root to the first OUTPUT is spent the moment a cycle starts and charged back
## onto the cooldown at the end, so the attack lands on the press and the
## cadence is unchanged. See `_spend_lead`.

signal fired(payload: Payload)
signal dilation_requested(seconds: float)
signal parry_opened(seconds: float)
signal cycle_started()

## Seconds one cell of board costs at the base clock. It sets the pace of every
## skill in the game, the player's and the monsters' alike, because it is the
## only thing converting a board's length into time.
##
## Costs denominated in real seconds — the overclock settling delay and the
## parry window — deliberately do not move with it, so changing it shifts the
## balance between walking a board and paying those: at half the tick, a board's
## own length is half as expensive while an overclock's settling delay costs
## exactly what it did, which makes stacking overclocks a worse trade than it
## was.
const BASE_TICK := 0.005
const BASE_COOLDOWN_TICKS := 3
const HEAT_TO_TICKS := 2.2
## Ticks one `update` may run. It stops a long frame turning into an unbounded
## catch-up; the ceiling is taken from the frame rather than fixed because a
## fixed one is a throttle at some clock speed or other. A flat 8 was headroom
## at a hundredth of a second per tick and a limit at half that, where an
## overclocked board wants a dozen ticks inside a sixtieth of a second and would
## quietly have run slower than its own preview promised.
const MAX_TICKS_PER_UPDATE := 64
## Every pulse carries a time to live, counted in parts it may still enter, and
## dies when it runs out. That is what keeps a cycle in the board from running
## forever. It is per pulse rather than shared across the cast on purpose: with
## one pool between them, two branches leaving a TEE race for the last of it and
## which one starves depends on the order they happen to be stepped in.
##
## A pulse starts with one full pass of this board, so an uncharged cast does
## what it always did — one pass, and never truncated for being long.
##
## CHARGE adds to that life. It never adds a pass and never adds a loop: a board
## with no cycle in it walks to its OUTPUT and stops there whatever life it was
## given, so it fires once charged exactly as it fires once uncharged. What the
## life is for is a cycle the player built — that is what has somewhere to spend
## it, and it spends it going round again.
const MAX_TTL_BONUS := 36
## Seconds the "ready again" flash takes to fade.
const READY_FLASH := 0.45

class Pulse extends RefCounted:
	var cell: Vector2i
	var timer: int
	var total: int
	var payload: Payload
	var ttl: int    ## parts this pulse may still enter before it dies
	## What the part this pulse stands in did to its flow, for an INVERT straight
	## after it to take back: the part's `id`, and what every field its effects
	## name held `before` it entered (`SkillRunner._before`).
	var undo: Dictionary = {}
	func _init(c: Vector2i, t: int, p: Payload, life: int) -> void:
		cell = c
		timer = t
		total = max(t, 1)
		payload = p
		ttl = life
	## 0..1 progress through the component, for the editor's flow visual.
	func progress() -> float:
		return clampf(1.0 - float(timer) / float(total), 0.0, 1.0)

var board: SkillBoard
var active: bool = false          ## true while the player holds the skill button
var pulses: Array[Pulse] = []
var cooldown: int = 0
## Stretches the whole wait between casts — the walk and the recovery together —
## so a runner can be made slower without touching its board.
var cooldown_mul: float = 1.0
## Ticks advanced by the cycle now running, lead included.
var _cycle_ticks: int = 0
var cycle_heat: float = 0.0
var accum: float = 0.0
var base_payload_provider: Callable = Callable()
## Trigger branches that have resolved; attached to attacks fired afterwards.
var trigger_payloads: Dictionary = {}
## Branches resolved by the cycle now running. Promoted into `trigger_payloads`
## when it ends, so a chain is whatever one cycle built and never accumulates
## across cycles.
var pending_triggers: Dictionary = {}
## Extra life added to a cast, bought by charging.
var ttl_bonus: int = 0
## What one full pass of this board costs, in parts entered.
var pass_cost: int = 1

## Set when a cast ran out of life with flow still to go.
var expired: bool = false
## Heat of the last completed cast, kept because `cycle_heat` is cleared.
var last_heat: float = 0.0
## True on the private copy the preview drives, which must not walk itself or
## fast-forward — it is counting ticks.
var dry_run: bool = false
var _analysis: Dictionary = {}
## Ticks of this cycle already burnt by `_spend_lead`, repaid to the cooldown.
## Seconds the cast now running takes, from firing to ready again. The slot wipe
## fills against this, so it has to describe *this* cast: the cycle before it
## stopped predicting it the moment charging became a way to buy laps, and a
## charged cast followed by an uncharged one had the slot reading four tenths
## full at the instant the skill was castable again.
var cycle_seconds: float = 0.0
## Fades from 1 the moment the skill comes back, so a slot can flash without
## every piece of UI having to watch for the transition itself.
var ready_flash: float = 0.0

## Seconds a cast takes, keyed by the life it was given. A cast's length is a
## property of the board and that life, so it is known when the cycle starts
## rather than guessed from the cycle before it. Seeded from the offline walk,
## corrected by what the cast really took, and thrown away when the board
## changes — the only thing that can make either wrong.
var _cycle_at_life: Dictionary = {}
## What a cast's trigger branches come to, keyed by the life it was given, off
## the same walk. Thrown away with it when the board changes.
var _triggers_at_life: Dictionary = {}
## The life the cycle now running started with, so the correction lands on the
## right entry however the charge has moved since.
var _cycle_life: int = 0

var _elapsed: float = 0.0
var _lead: int = 0
var _had_effect: bool = false
var _reaches_output: bool = false

func _init(b: SkillBoard) -> void:
	board = b
	refresh()

func refresh() -> void:
	_analysis = board.analyze()
	var t := board.trace()
	_reaches_output = bool(t.get("reaches_output", false))
	# One pass costs one entry per part the flow can actually get to. Taking it
	# from the board rather than from a constant is what lets the base cast be
	# exactly one pass on a four-part board and on a thirty-part one alike, so
	# length alone never costs a board its shot.
	pass_cost = maxi(1, int((t.get("reachable", {}) as Dictionary).size()))
	_cycle_at_life.clear()
	_triggers_at_life.clear()

func tick_time() -> float:
	return BASE_TICK / maxf(float(_analysis.get("speed_mul", 1.0)), 0.05)

## The settling delay overclocking charges, converted into ticks of the current
## (faster) clock so that it stays the same number of real seconds.
func _penalty_ticks() -> int:
	var secs := float(_analysis.get("penalty_seconds", 0.0))
	if secs <= 0.0:
		return 0
	return int(round(secs / tick_time()))

func is_idle() -> bool:
	return pulses.is_empty()

## The wait is over. Called the instant the last cooldown tick burns off, which
## is before a held button spends the skill again — so a slot still flashes on
## a skill being fired on repeat, where "ready" and "fired again" are the same
## moment. Banking the elapsed time here is also what makes the next fill
## accurate, since it is the only place that knows a full cycle just ended.
func _recovered() -> void:
	if _elapsed > 0.0:
		cycle_seconds = _elapsed
		# What it really took beats what the walk predicted — but only for a
		# cast of the same life, which is what the next one gets measured on.
		_cycle_at_life[_cycle_life] = _elapsed
	ready_flash = 1.0

## True when a press would start a new cycle right now.
## The life every pulse of a cast starts with: one full pass of this board, plus
## whatever charge has bought on top of it.
func cycle_ttl() -> int:
	return maxi(1, pass_cost + ttl_bonus)

func is_ready() -> bool:
	return pulses.is_empty() and cooldown <= 0

## How long a cast at `life` takes. Walked offline the first time it is asked
## for and remembered after that, so holding the button through every step of
## the charge costs one walk per step rather than one per press.
func _cycle_length(life: int) -> float:
	if not _cycle_at_life.has(life):
		_walk(life)
	return float(_cycle_at_life[life])

## Walks a cast at `life` offline and banks both things the walk knows: how long
## it takes, unless a real cast of that life has been timed already, and what its
## trigger branches resolve to. Called with `life` equal to `cycle_ttl()`, which
## is the life `simulate` walks.
func _walk(life: int) -> void:
	var pre := simulate()
	if not _cycle_at_life.has(life):
		_cycle_at_life[life] = float(pre.get("cycle_seconds", 0.0))
	_triggers_at_life[life] = pre["triggers"]

## How far the skill has recovered: 0 the instant it fires, 1 when it can fire
## again. This is one continuous run across both halves of the wait — the board
## still resolving, then the cooldown burning off — because the player only
## cares when the button works again, not which half they are in.
func ready_ratio() -> float:
	if is_ready():
		return 1.0
	if cycle_seconds <= 0.0:
		return 0.0
	return clampf(_elapsed / cycle_seconds, 0.0, 1.0)

func set_active(v: bool) -> void:
	active = v

func update(delta: float) -> void:
	if board == null or not _analysis.get("has_root", false):
		return
	# A press starts its cycle on the frame it lands, not on the next tick
	# boundary. Waiting for one is up to a whole tick of input lag and buys
	# nothing: the cadence is set by the cooldown, which this cannot shorten.
	if active and cooldown <= 0 and pulses.is_empty():
		_start_cycle()
	_elapsed += delta
	if ready_flash > 0.0:
		ready_flash = maxf(0.0, ready_flash - delta / READY_FLASH)
	accum += delta
	var tt := tick_time()
	var budget := clampi(int(ceil(delta / tt)) + 2, 8, MAX_TICKS_PER_UPDATE)
	var guard := 0
	while accum >= tt and guard < budget:
		accum -= tt
		guard += 1
		_tick()
	# A frame that could not run its whole share drops the remainder instead of
	# banking it. A backlog no later frame has the room to pay off only grows,
	# and the board would fall further behind the clock the longer it ran.
	accum = minf(accum, tt)


func _tick() -> void:
	if pulses.is_empty():
		# Recovery is wall-clock: it runs down whether or not the button is
		# still held. Gating it on `active` froze the timer the moment a player
		# let go, so a tapped skill charged the whole cooldown again on every
		# press — seconds of dead input on a board that was long ready.
		if cooldown > 0:
			cooldown -= 1
			if cooldown > 0:
				return
			_recovered()
		if not active:
			return
		_start_cycle()
		return
	_advance()

## One tick of every pulse in flight.
##
## However wide a board branches, every pulse it makes carries a life of its own
## and dies when that runs out, so a cast always ends. Nothing else bounds it:
## there is no ceiling on how many pulses may be in flight. Life limits how far
## a pulse walks rather than how many there are, so a ring that sends both of
## its outputs back into itself doubles the count every lap and pays for it out
## of the same life.
func _advance() -> void:
	_cycle_ticks += 1
	var next: Array[Pulse] = []
	for p in pulses:
		p.timer -= 1
		if p.timer > 0:
			next.append(p)
			continue
		for np in _exit(p):
			next.append(np)
	pulses = next

	if pulses.is_empty():
		cooldown = (BASE_COOLDOWN_TICKS + int(round(cycle_heat * HEAT_TO_TICKS))
			+ _penalty_ticks() + _lead)
		if cooldown_mul != 1.0:
			# The ticks already walked in real time are part of the wait too, so the
			# whole cycle is scaled and the walk is taken back off the remainder.
			var walked := _cycle_ticks - _lead
			cooldown = int(round(float(walked + cooldown) * cooldown_mul)) - walked
		last_heat = cycle_heat
		cycle_heat = 0.0
		_lead = 0
		# The cycle's branches have all resolved, so they become the triggers
		# this runner holds — which is how `simulate` reads a walk back. Promoting
		# at the boundary rather than as each branch lands is what stops a chain
		# growing cycle after cycle.
		for k in pending_triggers:
			trigger_payloads[k] = pending_triggers[k]

func _start_cycle() -> void:
	if board.find_root() == null:
		return
	_cycle_life = cycle_ttl()
	if not dry_run:
		# The wipe fills against the cast about to run, not the one before it.
		cycle_seconds = _cycle_length(_cycle_life)
		_arm_triggers(_cycle_life)
	pending_triggers.clear()
	_cycle_ticks = 0
	_elapsed = 0.0
	expired = false
	if not _begin_pass():
		return
	cycle_started.emit()
	_spend_lead()

## Puts the cast's one pulse on the root. The root is a part like any other
## — the weapon's DASHSLASH, a monster's SLASH — so the pulse enters it the way
## it enters everything after: its effects are applied on the way in, and its
## heat is counted.
func _begin_pass() -> bool:
	var start = board.find_root()
	if start == null:
		return false
	var entry: Dictionary = board.comp_origin_at(start)
	if entry.is_empty():
		return false
	var p := _base_payload()
	var id := String(entry["id"])
	var before := _before(id, p)
	_apply(id, p)
	var first := Pulse.new(start, Components.tick_cost(id), p, cycle_ttl())
	first.undo = {"id": id, "before": before}
	pulses = [first]
	return true

## What a trigger branch produces is a property of the board and the life it was
## given, not of history, but the branch is still walking behind the attack that
## would carry it. Taking the chain from whichever cycle ran last cost the first
## attack after equipping or editing a skill all of its follow-ups, and once
## charging bought laps it put every chain one cast behind the charge: a charged
## cast after a tap went out bare, and the taps after it kept its whole chain.
## The offline walk knows what the branches resolve to at exactly this life, so
## the cast is armed from it before its first attack fires.
func _arm_triggers(life: int) -> void:
	if not _triggers_at_life.has(life):
		_walk(life)
	trigger_payloads = (_triggers_at_life[life] as Dictionary).duplicate()

## Everything between the root and the cycle's first visible effect is time the
## player waits with nothing on screen: input lag, not cooldown. A cycle burns
## those ticks the instant it starts so the attack lands on the press, then
## charges exactly the same number back onto the cooldown when the cycle ends.
## The cadence is therefore untouched, and whatever the board does *after* that
## first effect still plays out in real time — DELAY goes on staggering
## branches and triggers against each other exactly as before.
##
## A board that never reaches an OUTPUT has no cast to bring forward, and
## running it dry here would collapse a whole circulating cycle into one frame,
## so it is left to tick in real time.
func _spend_lead() -> void:
	_lead = 0
	_had_effect = false
	if dry_run or not _reaches_output:
		return
	# The walk ends at the first effect, or — on a board that never produces one
	# — when the cast's life does.
	while not _had_effect and not pulses.is_empty():
		_lead += 1
		_advance()

func _base_payload() -> Payload:
	if base_payload_provider.is_valid():
		var p = base_payload_provider.call()
		if p is Payload:
			return p
	return Payload.new()

## Advance one pulse out of its component, producing the pulses that follow.
func _exit(p: Pulse) -> Array[Pulse]:
	var result: Array[Pulse] = []
	var entry: Dictionary = board.comp_origin_at(p.cell)
	if entry.is_empty():
		return result
	var id: String = entry["id"]
	var rot: int = entry["rot"]
	var ex: Vector2i = Components.exit_cell(id, p.cell, rot)

	var pay_dir := Components.world_payload_out(id, rot)
	if pay_dir >= 0:
		# A trigger's branch starts a flow of its own: it inherits the numbers
		# but not the attack form, so the branch defines its own payload.
		var bp := p.payload.clone()
		bp.branch = id
		bp.form = ""
		bp.duplicates = 1
		_try_enter(ex + Components.dir_to_vec(pay_dir), pay_dir, bp, result, p.ttl, p.undo)

	var outs := Components.world_outputs(id, rot)
	for d in outs:
		_try_enter(ex + Components.dir_to_vec(d), d, p.payload.clone(), result, p.ttl, p.undo)
	return result

## `came` is the part the flow is leaving and what it did (`Pulse.undo`), for
## an INVERT it walks into.
func _try_enter(cell: Vector2i, from_dir: int, payload: Payload,
		result: Array[Pulse], ttl: int, came: Dictionary = {}) -> void:
	if ttl <= 0:
		expired = true
		return  # out of life; a ring winds down here
	if not board.in_bounds(cell):
		return
	var target: Dictionary = board.comp_origin_at(cell)
	if target.is_empty():
		return  # a flow that leaks into empty space simply stops
	var tid: String = target["id"]
	var trot: int = target["rot"]
	if not Components.world_inputs(tid, trot).has(Components.opposite(from_dir)):
		return
	var before := _before(tid, payload)
	_apply(tid, payload, came)
	if tid == "OUTPUT":
		_resolve(payload)
	var next := Pulse.new(cell, Components.tick_cost(tid), payload, ttl - 1)
	next.undo = {"id": tid, "before": before}
	result.append(next)

## Mutate the payload as it enters a component: its heat, then each of its
## effects in turn — the part's rows of `effects`, which `Components` has held
## to the payload already, so every one fits the field it names. `came` is the
## part the flow came from and what it did, which only INVERT reads.
func _apply(id: String, p: Payload, came: Dictionary = {}) -> void:
	var def := Components.get_def(id)
	p.heat += float(def.get("heat", 0.0))
	cycle_heat += float(def.get("heat", 0.0))
	for e: Dictionary in def.get("effects", []):
		match String(e["op"]):
			"dilate":
				_had_effect = true
				dilation_requested.emit(float(e["value"]))
			"guard":
				_had_effect = true
				parry_opened.emit(float(e["value"]))
			"invert":
				_invert(p, came)
			_:
				_do(p, e)

## One change to one field of `p`, an effect's or an opposite's: set, add,
## multiply, toggle or include.
static func _do(p: Payload, e: Dictionary) -> void:
	var field: StringName = e["field"]
	match String(e["op"]):
		"set":
			p.set(field, e["value"])
		"add":
			p.set(field, p.get(field) + e["value"])
		"multiply":
			p.set(field, p.get(field) * e["value"])
		"toggle":
			p.set(field, not p.get(field))
		"include":
			var list: Array = p.get(field)
			if not list.has(e["value"]):
				list.append(e["value"])

## INVERT: takes back what the part the flow came from did to it, and does that
## part's opposite instead — its rows of `inversions`. Every field the part's
## effects name goes back to what it held before the part (`came["before"]`),
## so only that part is turned round: FIRE after FIRE keeps the first one's.
## A part with no opposite is left as it was, so an INVERT after a form, a
## trigger, SPLIT, TEE or another INVERT does nothing.
func _invert(p: Payload, came: Dictionary) -> void:
	var opposite := Components.inversions_of(String(came.get("id", "")))
	if opposite.is_empty():
		return
	var before: Dictionary = came.get("before", {})
	for field in before:
		p.set(field, _kept(before[field]))
	for e: Dictionary in opposite:
		_do(p, e)

## What every field `id`'s effects name holds in `p`, taken before they change
## it: what an INVERT straight after puts back.
static func _before(id: String, p: Payload) -> Dictionary:
	var out := {}
	for e: Dictionary in Components.effects_of(id):
		var field: StringName = e["field"]
		if field != &"" and not out.has(field):
			out[field] = _kept(p.get(field))
	return out

## A field's value to keep aside or put back. A list is copied, since `include`
## adds to the one the payload is holding.
static func _kept(v: Variant) -> Variant:
	return (v as Array).duplicate() if v is Array else v

## A branch reaching an OUTPUT defines a follow-up attack rather than firing
## one. A loop can bring the same branch round several times in a single cycle,
## and each pass is its own attack: they are chained head to tail so they land
## one after another, which is how the board reads. Overwriting instead — which
## is what this did — collapsed every lap into one payload carrying all of
## their stat gains, so a ring through four DAMAGE parts produced a single
## enormous strike where the player had drawn four separate ones.
func _chain_trigger(into: Dictionary, p: Payload) -> void:
	var stored := p.clone()
	stored.branch = ""
	stored.on_hit = null
	var head = into.get(p.branch, null)
	if head == null:
		into[p.branch] = stored
		return
	var tail: Payload = head
	while tail.on_hit != null:
		tail = tail.on_hit
	tail.on_hit = stored

func _resolve(p: Payload) -> void:
	if p.branch != "":
		_chain_trigger(pending_triggers, p)
		return
	if not p.is_productive():
		return
	var out := p.clone()
	out.on_hit = trigger_payloads.get("ON_HIT", null)
	out.on_kill = trigger_payloads.get("ON_KILL", null)
	out.on_parry = trigger_payloads.get("ON_PARRY", null)
	_had_effect = true
	fired.emit(out)

## Fired by the owner when a guard window actually absorbed a hit.
func consume_parry() -> Payload:
	var p = trigger_payloads.get("ON_PARRY", null)
	if p == null:
		return null
	var out: Payload = (p as Payload).clone()
	# A chained parry branch already carries its own follow-ups; only lend it
	# the ON HIT rider when it has none, so the chain is not truncated.
	if out.on_hit == null:
		out.on_hit = trigger_payloads.get("ON_HIT", null)
	return out

## What one full cast of this board comes to, for the editor preview.
##
## It runs the board rather than describing it: a private copy of the runner is
## driven through a whole cast with the real code, and what it fires is what is
## reported. Walking the board a second way — a breadth-first sweep beside the
## tick loop — is what kept letting the editor and the game disagree, and once a
## cast shared one pool of life between its pulses the two even disagreed about
## which pulse got the last of it. There is only one walk now, so they cannot.
##
## `error` is "" when the board ran, or the id of what stopped it — `no_root`
## — for a screen to spell in the language being played. Nothing here names a
## word.
func simulate() -> Dictionary:
	var a := board.analyze()
	var speed := maxf(float(a.get("speed_mul", 1.0)), 0.05)
	var penalty := float(a.get("penalty_seconds", 0.0))
	var blank := {
		"outputs": [] as Array[Payload], "triggers": {}, "ticks": 0,
		"speed_mul": speed, "penalty_seconds": penalty,
		"overclock": int(a.get("overclock", 0)), "cycle_seconds": 0.0, "heat": 0.0,
		"ttl": cycle_ttl(), "expired": false, "error": "",
	}
	if board.find_root() == null:
		blank["error"] = "no_root"
		return blank

	var dry := SkillRunner.new(board)
	dry.dry_run = true
	dry.base_payload_provider = base_payload_provider
	dry.ttl_bonus = ttl_bonus
	dry.cooldown_mul = cooldown_mul
	var outs: Array[Payload] = []
	dry.fired.connect(func(p: Payload) -> void: outs.append(p))
	dry.active = true
	dry._start_cycle()
	# The dry run ends where the real cast would: when the last pulse has spent
	# its life and the cooldown is set.
	var ticks := 0
	while dry.cooldown <= 0:
		if dry.pulses.is_empty():
			break
		dry._advance()
		ticks += 1

	var total := ticks + dry.cooldown
	blank["outputs"] = outs
	blank["triggers"] = dry.trigger_payloads
	blank["ticks"] = total
	blank["heat"] = dry.last_heat
	blank["expired"] = dry.expired
	blank["cycle_seconds"] = float(total) * BASE_TICK / speed
	return blank
