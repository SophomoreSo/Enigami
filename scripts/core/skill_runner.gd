class_name SkillRunner
extends RefCounted

## Runs a SkillBoard as a live circuit.
##
## A pulse starts at INPUT carrying a base payload, spends each component's tick
## cost inside it, and mutates the payload on entry. Reaching an OUTPUT turns the
## payload into a real effect. The INPUT only restarts once every pulse of the
## previous cycle has resolved, so board length *is* the cooldown.
##
## Board length is the cooldown, though — not the cast time. The walk from
## INPUT to the first OUTPUT is spent the moment a cycle starts and charged back
## onto the cooldown at the end, so the attack lands on the press and the
## cadence is unchanged. See `_spend_lead`.

signal fired(payload: Payload)
signal dilation_requested(seconds: float)
signal parry_opened(seconds: float)
signal cycle_started()

const BASE_TICK := 0.045
const BASE_COOLDOWN_TICKS := 3
const HEAT_TO_TICKS := 2.2
const MAX_PULSES := 64
## A flow may now enter a part from any side, which makes rings easy to build.
## Without a budget a pulse could circle forever: the cycle would never end, so
## the cooldown would never start and a ring past an OUTPUT would fire free.
##
## The budget counts how often a cycle may enter the *same* part, not how far a
## pulse has travelled. A chain that never doubles back is unaffected however
## long it is, while a ring stops after a few laps — and it is the same rule
## `simulate()` uses, so the cycle time the editor previews is the one the board
## actually runs. A total-distance budget could not do both: it has to be long
## enough for a board-spanning chain, which leaves a small ring circling for
## dozens of ticks with INPUT unable to restart behind it.
const MAX_VISITS := 4
## How many follow-up attacks one trigger branch may queue in a cycle. A branch
## can only resolve as often as the visit budget lets the flow reach its OUTPUT,
## so this matches MAX_VISITS; it is named separately because it guards a
## different thing — the length of the chain, not the length of the walk.
const MAX_TRIGGER_CHAIN := 4
## Seconds the "ready again" flash takes to fade.
const READY_FLASH := 0.45
## What one SPEED part multiplies a bolt's velocity by.
const SPEED_MUL := 1.5
## Ceiling on the up-front walk, so a pathological board cannot spin a frame.
const MAX_LEAD := 96

class Pulse extends RefCounted:
	var cell: Vector2i
	var timer: int
	var total: int
	var payload: Payload
	func _init(c: Vector2i, t: int, p: Payload) -> void:
		cell = c
		timer = t
		total = max(t, 1)
		payload = p
	## 0..1 progress through the component, for the editor's flow visual.
	func progress() -> float:
		return clampf(1.0 - float(timer) / float(total), 0.0, 1.0)

var board: SkillBoard
var active: bool = false          ## true while the player holds the skill button
var pulses: Array[Pulse] = []
var cooldown: int = 0
var cycle_heat: float = 0.0
var accum: float = 0.0
var base_payload_provider: Callable = Callable()
## Trigger branches that have resolved; attached to attacks fired afterwards.
var trigger_payloads: Dictionary = {}
## Branches resolved by the cycle now running. Promoted into `trigger_payloads`
## when it ends, so a chain is whatever one cycle built and never accumulates
## across cycles.
var pending_triggers: Dictionary = {}
## "cell:branch" -> times entered this cycle, against MAX_VISITS.
var cycle_visits: Dictionary = {}
var _analysis: Dictionary = {}
## Ticks of this cycle already burnt by `_spend_lead`, repaid to the cooldown.
## Seconds the last full cycle took, from firing to ready again. The slot wipe
## fills against this: a board cannot change mid-cycle, so the previous cycle
## predicts the current one almost exactly, and the first is seeded from the
## offline walk.
var cycle_seconds: float = 0.0
## Fades from 1 the moment the skill comes back, so a slot can flash without
## every piece of UI having to watch for the transition itself.
var ready_flash: float = 0.0

var _elapsed: float = 0.0
var _lead: int = 0
var _primed: bool = false
var _had_effect: bool = false
var _reaches_output: bool = false

func _init(b: SkillBoard) -> void:
	board = b
	refresh()

func refresh() -> void:
	_analysis = board.analyze()
	_reaches_output = bool(board.trace().get("reaches_output", false))
	_primed = false

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
	ready_flash = 1.0

## True when a press would start a new cycle right now.
func is_ready() -> bool:
	return pulses.is_empty() and cooldown <= 0

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
	if board == null or not _analysis.get("has_input", false):
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
	var guard := 0
	while accum >= tt and guard < 8:
		accum -= tt
		guard += 1
		_tick()


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
func _advance() -> void:
	var next: Array[Pulse] = []
	for p in pulses:
		p.timer -= 1
		if p.timer > 0:
			next.append(p)
			continue
		for np in _exit(p):
			if next.size() < MAX_PULSES:
				next.append(np)
	pulses = next

	if pulses.is_empty():
		cooldown = (BASE_COOLDOWN_TICKS + int(round(cycle_heat * HEAT_TO_TICKS))
			+ _penalty_ticks() + _lead)
		cycle_heat = 0.0
		_lead = 0
		# The cycle's branches have all resolved, so they become the triggers
		# the next attacks carry. Promoting at the boundary rather than as each
		# branch lands is what stops a chain growing cycle after cycle.
		for k in pending_triggers:
			trigger_payloads[k] = pending_triggers[k]

func _start_cycle() -> void:
	var input_cell = board.find_input()
	if input_cell == null:
		return
	_prime()
	var p := _base_payload()
	var entry: Dictionary = board.comp_origin_at(input_cell)
	cycle_visits.clear()
	pending_triggers.clear()
	_elapsed = 0.0
	pulses = [Pulse.new(input_cell, int(Components.get_def(entry["id"])["cost"]), p)]
	cycle_started.emit()
	_spend_lead()

## What a trigger branch produces is a property of the board, not of history,
## but the branch is still walking behind the attack that would carry it — so
## the first attack after equipping or editing a skill went out with no
## follow-ups at all, and on a board whose whole point is its trigger that read
## as the skill simply not working. The offline walk already knows what the
## branch resolves to, so the chain is seeded from it once per board and every
## attack from the first onwards behaves the same.
func _prime() -> void:
	if _primed:
		return
	_primed = true
	var pre := simulate()
	# The slot has to fill sensibly on the very first press too, before any
	# cycle has been timed.
	if cycle_seconds <= 0.0:
		cycle_seconds = float(pre.get("cycle_seconds", 0.0))
	if not trigger_payloads.is_empty():
		return
	for k in pre["triggers"]:
		trigger_payloads[k] = pre["triggers"][k]

## Everything between INPUT and the cycle's first visible effect is time the
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
	if not _reaches_output:
		return
	while not _had_effect and not pulses.is_empty() and _lead < MAX_LEAD:
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
		_try_enter(ex + Components.dir_to_vec(pay_dir), pay_dir, bp, result)

	var outs := Components.world_outputs(id, rot)
	for d in outs:
		var np := p.payload.clone()
		if id == "SPLIT":
			np.damage *= 0.5
		_try_enter(ex + Components.dir_to_vec(d), d, np, result)
	return result

func _try_enter(cell: Vector2i, from_dir: int, payload: Payload, result: Array[Pulse]) -> void:
	if not board.in_bounds(cell):
		return
	var target: Dictionary = board.comp_origin_at(cell)
	if target.is_empty():
		return  # a flow that leaks into empty space simply stops
	var tid: String = target["id"]
	var trot: int = target["rot"]
	if not Components.world_inputs(tid, trot).has(Components.opposite(from_dir)):
		return
	_apply(tid, payload)
	if tid == "OUTPUT":
		_resolve(payload)
	# The part still does its work on the visit that spends the last of the
	# budget; it just does not carry the flow onward, so a ring winds down
	# instead of holding the cycle open.
	var key := "%s:%s" % [cell, payload.branch]
	cycle_visits[key] = int(cycle_visits.get(key, 0)) + 1
	if int(cycle_visits[key]) > MAX_VISITS:
		return
	result.append(Pulse.new(cell, int(Components.get_def(tid)["cost"]), payload))

## Mutate the payload as it enters a component.
func _apply(id: String, p: Payload) -> void:
	var def := Components.get_def(id)
	p.heat += float(def.get("heat", 0.0))
	cycle_heat += float(def.get("heat", 0.0))
	match id:
		"PROJECTILE", "SLASH", "AREA", "DASHSLASH", "DASHSLASH_AUTO":
			p.form = id
		"FIRE":
			if not p.elements.has("FIRE"):
				p.elements.append("FIRE")
		"ICE":
			if not p.elements.has("ICE"):
				p.elements.append("ICE")
		"DAMAGE":
			p.damage += 8.0
		"SIZE":
			p.size *= 1.6
		"SPEED":
			p.speed *= SPEED_MUL
		"PIERCE":
			p.pierce += 2
		"DASH":
			p.dash = true
		"BLINK":
			p.blink = true
		"HOMING":
			p.homing = true
		"REVERSE":
			p.reverse = not p.reverse
		"DUPLICATE":
			p.duplicates *= 3
		"TIME_DILATION":
			_had_effect = true
			dilation_requested.emit(1.4)
		"ON_PARRY":
			_had_effect = true
			parry_opened.emit(float(def["cost"]) * tick_time() * 1.5)

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
	var depth := 1
	while tail.on_hit != null:
		tail = tail.on_hit
		depth += 1
		if depth >= MAX_TRIGGER_CHAIN:
			return  # the chain is as long as a cycle is allowed to make it
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

## Offline walk of the board used by the editor preview: reports what a full
## cycle would produce and how long it takes, without running in real time.
func simulate() -> Dictionary:
	var input_cell = board.find_input()
	if input_cell == null:
		return {"outputs": [], "ticks": 0, "heat": 0.0, "error": "No INPUT placed"}
	var sim_heat := 0.0
	var outputs: Array[Payload] = []
	var triggers: Dictionary = {}
	var frontier: Array = [[input_cell, _base_payload(), 0]]
	var visits: Dictionary = {}
	var max_ticks := 0
	var steps := 0
	while not frontier.is_empty() and steps < 400:
		steps += 1
		var item: Array = frontier.pop_front()
		var cell: Vector2i = item[0]
		var payload: Payload = item[1]
		var t: int = item[2]
		var entry: Dictionary = board.comp_origin_at(cell)
		if entry.is_empty():
			continue
		var id: String = entry["id"]
		var rot: int = entry["rot"]
		t += int(Components.get_def(id)["cost"])
		max_ticks = max(max_ticks, t)
		var ex := Components.exit_cell(id, cell, rot)

		# A trigger's branch and the ordinary outputs leave the part the same
		# way, so they are gathered and then walked by one piece of code that
		# mirrors `_exit` and `_try_enter`. Giving the branch its own shortened
		# path here is what made the editor disagree with the game: it skipped
		# the port check, the visit budget, and `_sim_apply` on the first part
		# of every branch, so a trigger previewed one part weaker than it ran.
		var exits: Array = []
		var pay_dir := Components.world_payload_out(id, rot)
		if pay_dir >= 0:
			var bp := payload.clone()
			bp.branch = id
			bp.form = ""
			bp.duplicates = 1
			exits.append([pay_dir, bp])
		for d in Components.world_outputs(id, rot):
			var np := payload.clone()
			if id == "SPLIT":
				np.damage *= 0.5
			exits.append([d, np])

		for e in exits:
			var edir: int = int(e[0])
			var ep: Payload = e[1]
			var ncell: Vector2i = ex + Components.dir_to_vec(edir)
			if not board.in_bounds(ncell):
				continue
			var tgt: Dictionary = board.comp_origin_at(ncell)
			if tgt.is_empty():
				continue
			if not Components.world_inputs(tgt["id"], tgt["rot"]).has(Components.opposite(edir)):
				continue
			var before := ep.heat
			_sim_apply(tgt["id"], ep)
			sim_heat += ep.heat - before
			if tgt["id"] == "OUTPUT":
				if ep.branch != "":
					_chain_trigger(triggers, ep)
				elif ep.is_productive():
					outputs.append(ep)
			# Counted on entry, exactly as `_try_enter` counts it: the part
			# still does its work on the visit that spends the last of the
			# budget, it just carries the flow no further.
			var key := "%s:%s" % [ncell, ep.branch]
			visits[key] = int(visits.get(key, 0)) + 1
			if int(visits[key]) > MAX_VISITS:
				continue  # a loop in the board; stop expanding it
			frontier.append([ncell, ep, t])

	var a := board.analyze()
	var total_ticks := max_ticks + BASE_COOLDOWN_TICKS + int(round(sim_heat * HEAT_TO_TICKS))
	var speed := maxf(float(a.get("speed_mul", 1.0)), 0.05)
	var cycle := float(total_ticks) * BASE_TICK / speed + float(a.get("penalty_seconds", 0.0))
	return {
		"outputs": outputs,
		"triggers": triggers,
		"ticks": total_ticks,
		"speed_mul": speed,
		"penalty_seconds": float(a.get("penalty_seconds", 0.0)),
		"overclock": int(a.get("overclock", 0)),
		"cycle_seconds": cycle,
		"heat": sim_heat,
		"error": "",
	}

## Same mutations as _apply, minus the live signals.
func _sim_apply(id: String, p: Payload) -> void:
	var def := Components.get_def(id)
	p.heat += float(def.get("heat", 0.0))
	match id:
		"PROJECTILE", "SLASH", "AREA", "DASHSLASH", "DASHSLASH_AUTO":
			p.form = id
		"FIRE":
			if not p.elements.has("FIRE"):
				p.elements.append("FIRE")
		"ICE":
			if not p.elements.has("ICE"):
				p.elements.append("ICE")
		"DAMAGE": p.damage += 8.0
		"SIZE": p.size *= 1.6
		"SPEED": p.speed *= SPEED_MUL
		"PIERCE": p.pierce += 2
		"DASH": p.dash = true
		"BLINK": p.blink = true
		"HOMING": p.homing = true
		"REVERSE": p.reverse = not p.reverse
		"DUPLICATE": p.duplicates *= 3
