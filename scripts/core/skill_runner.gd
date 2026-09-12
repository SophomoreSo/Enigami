class_name SkillRunner
extends RefCounted

## Runs a SkillBoard as a live circuit.
##
## A pulse starts at INPUT carrying a base payload, spends each component's tick
## cost inside it, and mutates the payload on entry. Reaching an OUTPUT turns the
## payload into a real effect. The INPUT only restarts once every pulse of the
## previous cycle has resolved, so board length *is* the cooldown.

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
const MAX_HOPS := 64

class Pulse extends RefCounted:
	var cell: Vector2i
	var timer: int
	var total: int
	var payload: Payload
	var hops: int
	func _init(c: Vector2i, t: int, p: Payload, h: int = 0) -> void:
		cell = c
		timer = t
		total = max(t, 1)
		payload = p
		hops = h
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
var _analysis: Dictionary = {}

func _init(b: SkillBoard) -> void:
	board = b
	refresh()

func refresh() -> void:
	_analysis = board.analyze()

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

## Fraction of the cooldown still to burn, for the HUD.
func cooldown_ratio() -> float:
	if cooldown <= 0:
		return 0.0
	return clampf(float(cooldown) / float(BASE_COOLDOWN_TICKS + 12), 0.0, 1.0)

func set_active(v: bool) -> void:
	active = v

func update(delta: float) -> void:
	if board == null or not board.analyze().get("has_input", false):
		return
	accum += delta
	var tt := tick_time()
	var guard := 0
	while accum >= tt and guard < 8:
		accum -= tt
		guard += 1
		_tick()

func _tick() -> void:
	if pulses.is_empty():
		if not active:
			return
		if cooldown > 0:
			cooldown -= 1
			return
		_start_cycle()
		return

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
		cooldown = BASE_COOLDOWN_TICKS + int(round(cycle_heat * HEAT_TO_TICKS)) + _penalty_ticks()
		cycle_heat = 0.0

func _start_cycle() -> void:
	var input_cell = board.find_input()
	if input_cell == null:
		return
	var p := _base_payload()
	var entry: Dictionary = board.comp_origin_at(input_cell)
	pulses = [Pulse.new(input_cell, int(Components.get_def(entry["id"])["cost"]), p, 0)]
	cycle_started.emit()

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
		_try_enter(ex + Components.dir_to_vec(pay_dir), pay_dir, bp, result, p.hops)

	var outs := Components.world_outputs(id, rot)
	for d in outs:
		var np := p.payload.clone()
		if id == "SPLIT":
			np.damage *= 0.5
		_try_enter(ex + Components.dir_to_vec(d), d, np, result, p.hops)
	return result

func _try_enter(cell: Vector2i, from_dir: int, payload: Payload, result: Array[Pulse], hops: int = 0) -> void:
	if hops >= MAX_HOPS:
		return  # a ring that never resolves; let it burn out
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
	result.append(Pulse.new(cell, int(Components.get_def(tid)["cost"]), payload, hops + 1))

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
			dilation_requested.emit(1.4)
		"ON_PARRY":
			parry_opened.emit(float(def["cost"]) * tick_time() * 1.5)

func _resolve(p: Payload) -> void:
	if p.branch != "":
		var stored := p.clone()
		stored.branch = ""
		trigger_payloads[p.branch] = stored
		return
	if not p.is_productive():
		return
	var out := p.clone()
	out.on_hit = trigger_payloads.get("ON_HIT", null)
	out.on_kill = trigger_payloads.get("ON_KILL", null)
	out.on_parry = trigger_payloads.get("ON_PARRY", null)
	fired.emit(out)

## Fired by the owner when a guard window actually absorbed a hit.
func consume_parry() -> Payload:
	var p = trigger_payloads.get("ON_PARRY", null)
	if p == null:
		return null
	var out: Payload = (p as Payload).clone()
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
		var key := "%s:%s" % [cell, payload.branch]
		visits[key] = int(visits.get(key, 0)) + 1
		if visits[key] > 4:
			continue  # a loop in the board; stop expanding it
		t += int(Components.get_def(id)["cost"])
		max_ticks = max(max_ticks, t)
		var ex := Components.exit_cell(id, cell, rot)

		var pay_dir := Components.world_payload_out(id, rot)
		if pay_dir >= 0:
			var bp := payload.clone()
			bp.branch = id
			bp.form = ""
			frontier.append([ex + Components.dir_to_vec(pay_dir), bp, t])
		for d in Components.world_outputs(id, rot):
			var np := payload.clone()
			if id == "SPLIT":
				np.damage *= 0.5
			var ncell: Vector2i = ex + Components.dir_to_vec(d)
			var tgt: Dictionary = board.comp_origin_at(ncell)
			if tgt.is_empty():
				continue
			if not Components.world_inputs(tgt["id"], tgt["rot"]).has(Components.opposite(d)):
				continue
			var before := np.heat
			_sim_apply(tgt["id"], np)
			sim_heat += np.heat - before
			if tgt["id"] == "OUTPUT":
				if np.branch != "":
					var s := np.clone()
					s.branch = ""
					triggers[np.branch] = s
				elif np.is_productive():
					outputs.append(np)
			frontier.append([ncell, np, t])

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
		"PIERCE": p.pierce += 2
		"DASH": p.dash = true
		"BLINK": p.blink = true
		"HOMING": p.homing = true
		"REVERSE": p.reverse = not p.reverse
		"DUPLICATE": p.duplicates *= 3
