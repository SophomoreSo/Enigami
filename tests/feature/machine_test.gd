extends Node2D
## The player's state machine, and the table it is read from.
##
## The states and the graph of ways between them are rows in the content
## database (`data/db/machines/player.sql`); what a state does and when a way
## out is open are the actions and conditions `Player` names. Three things can
## go wrong between the two and none says so at run time: a row can name an
## action or a condition the player does not have, the graph can leave a
## state with no way in, and a split can add up to more or less than one.
## Each is a failure here. Then a real player is stood up, to see that the
## machine it built is the one the table describes and that it moves on it.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[MACHINE] PASS ", what)
	else:
		fails += 1
		push_error("MACHINE FAIL: " + what)

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func solid(centre: Vector2, size: Vector2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = centre
	b.add_child(cs)
	add_child(b)

func land(p: Player) -> void:
	var guard := 0
	while not p.is_on_floor() and guard < 400:
		await get_tree().physics_frame
		guard += 1

## Presses an action the way a player does, and lets the machine re-pick.
func press(action: String, hold: int = 3) -> void:
	Input.action_press(action)
	await phys(hold)
	Input.action_release(action)

func _ready() -> void:
	# --- the table ------------------------------------------------------------
	check(Db.available(), "the database opens (%s)" % Db.PATH)
	for table in ["machines", "states", "transitions"]:
		check(Db.has_table(table), "there is a %s table" % table)
	var ids := Machine.ids()
	check(ids.has("player"), "the player has a machine (%s)" % str(ids))
	for id in ids:
		var found := Machine.problems(id)
		check(found.is_empty(), "the %s machine reads clean%s"
			% [id, "" if found.is_empty() else " — " + "; ".join(found)])
		var lost := _unreachable(Machine.source(id))
		check(lost.is_empty(), "every state of %s has a way in from its start%s"
			% [id, "" if lost.is_empty() else " — not " + ", ".join(lost)])

	var src := Machine.source("player")
	var states: Dictionary = src.get("states", {})
	check(String(src.get("start", "")) == "idle" and states.size() == 6,
		"the player starts idle and has six states (%s, %d)" % [src.get("start", ""), states.size()])
	var labels: Array = []
	for sid in states:
		labels.append(String(states[sid].get("label", "")))
	check(labels == ["Idle", "Run", "Rise", "Fall", "WallSlide", "Dash"],
		"named Idle, Run, Rise, Fall, WallSlide and Dash, in that order (%s)" % str(labels))
	var edges: Array = src.get("transitions", [])
	check(edges.size() == 30, "every state has a way into every other: thirty ways out (%d)" % edges.size())
	var pairs: Dictionary = {}
	for t in edges:
		pairs["%s>%s" % [t.get("from_id", ""), t.get("to_id", "")]] = true
	var complete := true
	for a in states:
		for b in states:
			if a != b and not pairs.has("%s>%s" % [a, b]):
				complete = false
	check(complete, "and no pair is missing")
	var out_of_idle: Array = []
	for t in edges:
		if String(t.get("from_id", "")) == "idle":
			out_of_idle.append(String(t.get("to_id", "")))
	check(out_of_idle == ["dash", "wall_slide", "run", "rise", "fall"],
		"the ways out of idle are asked dash first, then wall slide, run, rise, fall (%s)" % str(out_of_idle))

	# --- the checker catches what it is for -----------------------------------
	# Written out here rather than kept as broken rows in the database: these
	# are the mistakes a writer makes, and every one is silent at run time if
	# nothing goes looking.
	var base := {"id": "m", "start": "a",
		"states": {"a": {"label": "A", "action": "do_a"}, "b": {"label": "B", "action": "do_b"}},
		"transitions": [
			{"from_id": "a", "position": 0, "to_id": "b", "condition": "go", "probability": 1.0},
			{"from_id": "b", "position": 0, "to_id": "a", "condition": "back", "probability": 1.0},
		]}
	check(Machine.problems_in(base).is_empty(), "a sound machine has no problems (%s)" % str(Machine.problems_in(base)))
	check(_caught(base, {"start": "zz"}, "start -> zz"), "a start that names no state is caught")
	check(_caught(base, {"transitions": [{"from_id": "a", "position": 0, "to_id": "zz", "condition": "go"}]}, "does not exist"),
		"a way to a state that does not exist is caught")
	check(_caught(base, {"transitions": [{"from_id": "zz", "position": 0, "to_id": "a", "condition": "go"}]}, "leaves a state"),
		"a way out of a state that does not exist is caught")
	check(_caught(base, {"transitions": [{"from_id": "a", "position": 0, "to_id": "b", "condition": ""}]}, "no condition"),
		"a way with no condition is caught")
	check(_caught(base, {"transitions": [{"from_id": "a", "position": 0, "to_id": "b", "condition": "go", "probability": 0.5}]}, "add up to 0.50"),
		"a split that does not add up to one is caught")
	check(_caught(base, {"transitions": [
			{"from_id": "a", "position": 0, "to_id": "b", "condition": "go", "probability": 0.5},
			{"from_id": "a", "position": 0, "to_id": "a", "condition": "stay", "probability": 0.5}]}, "disagree"),
		"a split whose rows disagree on the condition is caught")
	check(_caught(base, {"states": {"a": {"label": "A", "action": ""}, "b": {"label": "B", "action": "do_b"}}}, "a does nothing"),
		"a state with no action is caught")
	check(Machine.problems_in({"start": "a", "states": {}}).has("no states"), "a machine with no states is caught")

	# --- building it over an owner --------------------------------------------
	var actions := {"idle": _nothing, "run": _nothing, "air": _nothing, "wall_slide": _nothing, "dash": _nothing}
	var conditions := {"dashing": _never, "wall_sliding": _never, "running": _never,
		"standing": _never, "rising": _never, "falling": _never}
	var whole := Machine.build("player", actions, conditions)
	check(whole.faults.is_empty() and whole.states.size() == 6 and whole.start == whole.states.get("idle"),
		"over an owner with every name, the whole machine is built (%s)" % str(whole.faults))
	var fewer := actions.duplicate()
	fewer.erase("dash")
	var short_one := Machine.build("player", fewer, conditions)
	check(short_one.faults.size() == 1 and String(short_one.faults[0]).contains("dash"),
		"a state whose action the owner lacks is reported (%s)" % str(short_one.faults))
	check(short_one.states.size() == 5 and short_one.start != null, "and the rest is still built")
	var mute := conditions.duplicate()
	mute.erase("running")
	var unanswered := Machine.build("player", actions, mute)
	check(unanswered.faults.size() == 5 and String(unanswered.faults[0]).contains("running"),
		"a way whose condition the owner cannot answer is reported, once per way (%d)" % unanswered.faults.size())
	var nobody := Machine.build("nobody", actions, conditions)
	check(nobody.start == null and nobody.states.is_empty() and not nobody.faults.is_empty(),
		"a machine not in the table is one with nothing in it, and a problem (%s)" % str(nobody.faults))
	whole.cleanup()
	short_one.cleanup()
	unanswered.cleanup()

	# --- and the real player runs on it ---------------------------------------
	solid(Vector2(600, 500), Vector2(2000, 200))
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = Vector2(300, 380)
	add_child(p)
	await land(p)
	await phys(2)
	check(p.machine != null and p.machine.faults.is_empty(),
		"the player builds its machine with nothing unresolved (%s)" % str(p.machine.faults if p.machine != null else "no machine"))
	check(p.machine.states.size() == 6 and p.current_state == p.machine.states.get("idle"),
		"and stands in idle (%s)" % p.state_name())
	check(p.state_name() == "Idle", "which it calls Idle (%s)" % p.state_name())
	var wired := true
	for sid in p.machine.states:
		var node: FSMNode = p.machine.states[sid]
		wired = wired and node.action.is_valid() and node.next_nodes.size() == 5
		for way in node.next_nodes:
			wired = wired and (way["condition"] as Callable).is_valid() and (way["destinations"] as Array).size() == 1
	check(wired, "every state acts, and has five certain ways out, each with a condition that answers")

	Input.action_press("move_right")
	await phys(6)
	check(p.state_name() == "Run", "holding right runs (%s)" % p.state_name())
	Input.action_release("move_right")
	await phys(12)
	check(p.state_name() == "Idle", "letting go stands (%s)" % p.state_name())
	await press("jump")
	check(p.state_name() == "Rise", "a jump rises (%s)" % p.state_name())
	var fell := false
	for i in 200:
		await phys(1)
		if p.state_name() == "Fall":
			fell = true
			break
	check(fell, "and comes down through Fall")
	await land(p)
	await phys(2)
	check(p.state_name() == "Idle", "back to Idle on the floor (%s)" % p.state_name())
	# The press is seen on the physics frame after it, the dash starts inside
	# that frame's action, and the state is re-picked at the top of the next.
	await press("dash", 2)
	await phys(2)
	check(p.state_name() == "Dash", "a dash is a Dash (%s)" % p.state_name())

	print("[MACHINE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _nothing() -> void:
	pass

func _never() -> bool:
	return false

## The states no path from the start reaches, by id.
func _unreachable(def: Dictionary) -> Array:
	var states: Dictionary = def.get("states", {})
	var out: Dictionary = {}
	for t in def.get("transitions", []):
		var from_id := String(t.get("from_id", ""))
		if not out.has(from_id):
			out[from_id] = []
		(out[from_id] as Array).append(String(t.get("to_id", "")))
	var seen := {}
	var open: Array = [String(def.get("start", ""))]
	while not open.is_empty():
		var at: String = open.pop_back()
		if at == "" or seen.has(at) or not states.has(at):
			continue
		seen[at] = true
		for to in out.get(at, []):
			open.append(to)
	var lost: Array = []
	for sid in states:
		if not seen.has(sid):
			lost.append(String(sid))
	return lost

## Whether checking `base` with `patch` laid over it, key by key, complains
## about `want`.
func _caught(base: Dictionary, patch: Dictionary, want: String) -> bool:
	var def := base.duplicate(true)
	for key in patch:
		def[key] = patch[key]
	for problem in Machine.problems_in(def):
		if String(problem).contains(want):
			return true
	return false
