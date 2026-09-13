class_name FSMNode
extends RefCounted

## One state of a finite state machine.
##
## A state is an action to run and an ordered list of ways out of it. Each way
## out is a condition and where it leads; the first condition that holds wins.
## A transition may also split between several destinations by probability.

var action: Callable
var next_nodes: Array = []

func _init(action_func: Callable) -> void:
	action = action_func

## Runs this state's action.
func perform() -> void:
	if action.is_valid():
		action.call()

## A deterministic transition: when `condition` holds, go to `node`.
func add_next_node(condition: Callable, node: FSMNode, probability: float = 1.0) -> void:
	next_nodes.append({
		"condition": condition,
		"destinations": [{"node": node, "probability": probability}],
	})

## A transition that picks one of several destinations when `condition` holds.
## `destinations` is an array of {"node": FSMNode, "probability": float} whose
## probabilities sum to 1.
func add_probabilistic_transition(condition: Callable, destinations: Array) -> void:
	var total := 0.0
	for dest in destinations:
		total += float(dest.get("probability", 0.0))
	if absf(total - 1.0) > 0.001:
		push_warning("Probabilistic transition probabilities sum to %f, expected 1.0" % total)
	next_nodes.append({
		"condition": condition,
		"destinations": destinations,
	})

## The state the first holding condition leads to, or null when none holds.
func find_next_node() -> FSMNode:
	for transition in next_nodes:
		if transition["condition"].call():
			return _select_destination(transition["destinations"])
	return null

func _select_destination(destinations: Array) -> FSMNode:
	if destinations.is_empty():
		return null
	if destinations.size() == 1 or float(destinations[0]["probability"]) >= 1.0:
		return destinations[0]["node"]
	var roll := randf()
	var cumulative := 0.0
	for dest in destinations:
		cumulative += float(dest["probability"])
		if roll <= cumulative:
			return dest["node"]
	# Floating point can leave the roll just past the last bucket.
	return destinations[destinations.size() - 1]["node"]

## States that lead to each other hold each other alive; this breaks the cycle.
func cleanup() -> void:
	next_nodes.clear()
	action = Callable()
