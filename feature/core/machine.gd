class_name Machine
extends RefCounted

## A state machine's shape, read from the content database and built into
## `FSMNode`s: the rows of `machines`, `states` and `transitions` (see
## `data/db/README.md`), over the actions and conditions its owner hands in.
##
## The split is the one ARCHITECTURE.md draws everywhere else. The graph —
## which states there are, which can follow which, in what order they are
## tried, and how a way out splits — is content, and lives in the table. What
## a state does each frame, and what it takes for a way out to be open, is
## code: the owner names each one, and a row refers to it by that name. So the
## player keeps `_action_dash` and `_dash_time > 0.0`, and the table says that
## every state has a way into the dash, called `dashing`.
##
## Nothing here falls back. A machine that is not in the database, or that
## names an action or a condition its owner does not have, comes back with
## `faults` and without those parts, and the owner is expected to say so
## loudly. The player cannot move without one, and there is no version of it
## that half moves.

## The machine's id in the table.
var id: String = ""
## The state it begins in, or null when it could not be built.
var start: FSMNode = null
## Every state by id.
var states: Dictionary = {}
## What is wrong with it, in words. Empty when the machine is whole.
var faults: Array = []

## Every machine in the database, by id.
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for r in Db.rows("SELECT id FROM machines ORDER BY id"):
		out.append(String(r["id"]))
	return out

## A machine as the database has it, in the shape `problems_in` checks and
## `build` builds from: the `machines` row, with `states` under it by id and
## `transitions` as a list in the order they are tried. Empty when there is
## no such machine.
static func source(id: String) -> Dictionary:
	var found := Db.records("machines", "id = ?", [id])
	if found.is_empty():
		return {}
	var def: Dictionary = found[0]
	var states: Dictionary = {}
	for s in Db.records("states", "machine_id = ?", [id], "rowid"):
		states[String(s["id"])] = s
	def["states"] = states
	def["transitions"] = Db.records("transitions", "machine_id = ?", [id], "from_id, position, rowid")
	return def

## Builds `id` over `actions` — name to Callable, what a state does — and
## `conditions` — name to Callable answering bool, when a way out is open.
static func build(id: String, actions: Dictionary, conditions: Dictionary) -> Machine:
	var m := Machine.new()
	m.id = id
	var def := source(id)
	if def.is_empty():
		m.faults.append("no machine called '%s' in %s" % [id, Db.PATH])
		return m
	m.faults = problems_in(def)
	var rows: Dictionary = def["states"]
	for sid in rows:
		var row: Dictionary = rows[sid]
		var action_name := String(row.get("action", ""))
		if not actions.has(action_name):
			m.faults.append("state %s does %s, which the owner cannot" % [sid, action_name])
			continue
		var node := FSMNode.new(actions[action_name])
		node.id = String(sid)
		node.label = String(row.get("label", sid))
		m.states[String(sid)] = node
	# Rows sharing a from and a position are one way out, split between them.
	var ways: Dictionary = {}
	var order: Array = []
	for t in def["transitions"]:
		var from_id := String(t.get("from_id", ""))
		var to_id := String(t.get("to_id", ""))
		var condition := String(t.get("condition", ""))
		if not m.states.has(from_id) or not m.states.has(to_id):
			continue   # said already, by problems_in or the state above
		if not conditions.has(condition):
			m.faults.append("%s -> %s asks %s, which the owner cannot answer" % [from_id, to_id, condition])
			continue
		var key := "%s\n%d" % [from_id, int(t.get("position", 0))]
		if not ways.has(key):
			ways[key] = {"from": m.states[from_id], "condition": conditions[condition], "destinations": []}
			order.append(key)
		(ways[key]["destinations"] as Array).append({
			"node": m.states[to_id], "probability": float(t.get("probability", 1.0))})
	for key in order:
		var way: Dictionary = ways[key]
		var from: FSMNode = way["from"]
		var destinations: Array = way["destinations"]
		if destinations.size() == 1:
			from.add_next_node(way["condition"], destinations[0]["node"])
		else:
			from.add_probabilistic_transition(way["condition"], destinations)
	var start_id := String(def.get("start", ""))
	m.start = m.states.get(start_id, null)
	if m.start == null and rows.has(start_id):
		m.faults.append("the start, %s, could not be built" % start_id)
	return m

## Mistakes in a machine that would otherwise show as a state nobody leaves,
## a way out nobody takes, or a split that does not add up. Phrased the way
## `Dialogue.problems` phrases them, and checked by `tests/feature/machine_test`.
static func problems(id: String) -> Array:
	var def := source(id)
	if def.is_empty():
		return ["no machine called '%s' in %s" % [id, Db.PATH]]
	return problems_in(def)

## The same check against a machine already in hand, in the shape `source`
## returns — so the checker itself can be put in front of a deliberately
## broken one without a broken row having to live in the database.
static func problems_in(def: Dictionary) -> Array:
	var found: Array = []
	var states = def.get("states", {})
	if not states is Dictionary or states.is_empty():
		return ["no states"]
	if not states.has(String(def.get("start", ""))):
		found.append("start -> %s" % def.get("start", ""))
	for sid in states:
		if not states[sid] is Dictionary or String((states[sid] as Dictionary).get("action", "")) == "":
			found.append("%s does nothing" % sid)
	var transitions = def.get("transitions", [])
	if not transitions is Array:
		transitions = []
	# Each way out: how much of a whole its rows add up to, and their condition.
	var ways: Dictionary = {}
	for t in transitions:
		if not t is Dictionary:
			found.append("a way out that is not a row")
			continue
		var from_id := String(t.get("from_id", ""))
		var to_id := String(t.get("to_id", ""))
		var where := "%s -> %s" % [from_id, to_id]
		if not states.has(from_id):
			found.append("%s leaves a state that does not exist" % where)
		if not states.has(to_id):
			found.append("%s leads to a state that does not exist" % where)
		var condition := String(t.get("condition", ""))
		if condition == "":
			found.append("%s has no condition" % where)
		var p := float(t.get("probability", 1.0))
		if p <= 0.0 or p > 1.0:
			found.append("%s has a probability of %s" % [where, str(p)])
		var at := int(t.get("position", 0))
		var key := "%s\n%d" % [from_id, at]
		if not ways.has(key):
			ways[key] = {"from": from_id, "at": at, "sum": 0.0, "condition": condition}
		var way: Dictionary = ways[key]
		way["sum"] = float(way["sum"]) + p
		if String(way["condition"]) != condition:
			found.append("the ways out of %s at %d disagree on their condition" % [from_id, at])
	for key in ways:
		var way: Dictionary = ways[key]
		if absf(float(way["sum"]) - 1.0) > 0.001:
			found.append("the ways out of %s at %d add up to %.2f, not 1" % [way["from"], way["at"], way["sum"]])
	return found

## Breaks the cycles the states hold each other in. Call when the owner goes.
func cleanup() -> void:
	for s in states.values():
		(s as FSMNode).cleanup()
	states.clear()
	start = null
