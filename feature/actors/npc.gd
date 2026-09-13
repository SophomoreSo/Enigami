class_name Npc
extends CharacterBody2D

## Someone to talk to. Walk up and press interact: a line appears over their
## head and each further press moves the conversation on. Some lines end in a
## question — move up and down to pick an answer, interact to give it — and the
## answer decides what they say next. Walking away ends it. Nothing here is
## drawn; `graphics/views/npc_view.gd` turns it into a speech bubble.
##
## An NPC is deliberately not an Actor. Attacks find their targets through the
## "actors" group, so a bystander outside it can stand in the line of fire
## without ever being hit.

signal line_started(npc: Npc, node_id: String)
signal choice_made(npc: Npc, node_id: String, index: int)
signal conversation_ended(npc: Npc)

const BODY := Vector2(18.0, 28.0)
const GRAVITY := 1900.0
const MAX_FALL := 900.0
## How close the player has to stand for a press to count, centre to centre.
const TALK_RANGE := 64.0
## Letters a line reveals per second. A press while one is still coming in
## finishes it rather than skipping it unread.
const REVEAL_RATE := 45.0

## Who each NPC is and what they say.
##
## A conversation is a set of named nodes, entered at `start`. Each node says
## its `text`, then either goes on to `next` or offers `choices`, each of which
## names the node it leads to. A `next` that is empty or missing ends the
## conversation, so a goodbye is just a node that leads nowhere.
const CATALOGUE := {
	"SAGE": {
		"name": "Old Tinker",
		"start": "hello",
		"nodes": {
			"hello": {"text": "Ah, a new face. Nothing you break in here stays broken.", "next": "ask"},
			"ask": {"text": "What would you like to know?", "choices": [
				{"text": "How do skills work?", "next": "circuits"},
				{"text": "What does charging do?", "next": "charge"},
				{"text": "Who are you?", "next": "who"},
				{"text": "Nothing. Bye.", "next": ""},
			]},
			"circuits": {"text": "Every skill is a circuit. The longer the path, the longer you wait for the next shot.", "next": "ask_again"},
			"charge": {"text": "Build a loop, then hold the cast button. Charge buys the pulse more laps.", "next": "ask_again"},
			"who": {"text": "I tinker. Mostly with things that explode.", "choices": [
				{"text": "Sounds dangerous.", "next": "danger"},
				{"text": "Back to my questions.", "next": "ask"},
			]},
			"danger": {"text": "Only out on a raid. In here, the dummy won't mind.", "next": "ask_again"},
			"ask_again": {"text": "Anything else?", "choices": [
				{"text": "How do skills work?", "next": "circuits"},
				{"text": "What does charging do?", "next": "charge"},
				{"text": "That's all, thanks.", "next": "bye"},
			]},
			"bye": {"text": "Go on, then. Break something."},
		},
	},
}

var npc_id: String = "SAGE"
var display_name: String = ""
var nodes: Dictionary = {}
var start: String = ""
## +1 right, -1 left. They turn to whoever is close enough to talk to.
var facing: int = 1
var body_size: Vector2 = BODY
## The node being said, or "" when nobody is talking.
var node_id: String = ""
## How many letters of the current line are out so far.
var revealed: float = 0.0
## Which answer is highlighted while a question is open.
var selected: int = 0
## True while the player stands close enough to talk.
var in_range: bool = false

func setup(id: String) -> void:
	npc_id = id
	var def: Dictionary = CATALOGUE.get(id, CATALOGUE["SAGE"])
	display_name = String(def["name"])
	nodes = def["nodes"]
	start = String(def["start"])

## Every link in a conversation that points at a node that does not exist. A
## typo in the catalogue would otherwise only show up as a conversation cut
## short, and only for whoever happened to pick that answer.
static func broken_links(id: String) -> Array:
	var def: Dictionary = CATALOGUE[id]
	var all: Dictionary = def["nodes"]
	var broken: Array = []
	if not all.has(def["start"]):
		broken.append("start -> %s" % def["start"])
	for key in all:
		var node: Dictionary = all[key]
		var links: Array = [node.get("next", "")]
		for c in node.get("choices", []):
			links.append(c.get("next", ""))
		for to in links:
			if String(to) != "" and not all.has(to):
				broken.append("%s -> %s" % [key, to])
	return broken

func _ready() -> void:
	if nodes.is_empty():
		setup(npc_id)
	add_to_group("npcs")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	shape.shape = rect
	add_child(shape)

func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()

	var player := _player()
	in_range = player != null and global_position.distance_to(player.global_position) <= TALK_RANGE
	if in_range:
		face(int(signf(player.global_position.x - global_position.x)))
	if is_talking():
		# Walking off mid-sentence is how a player says they are done listening.
		if not in_range:
			end_conversation()
		else:
			revealed = minf(revealed + REVEAL_RATE * delta, float(current_line().length()))
	if not in_range or player.input_locked:
		return
	if is_choosing():
		if Input.is_action_just_pressed("move_up"):
			move_selection(-1)
		if Input.is_action_just_pressed("move_down"):
			move_selection(1)
	if Input.is_action_just_pressed("interact"):
		interact()

## One press of interact: start talking, finish the line coming in, give the
## highlighted answer, move on to the next line, or — where there is none — stop.
func interact() -> void:
	if not is_talking():
		_go(start)
		return
	if not line_finished():
		revealed = float(current_line().length())
		return
	if not choices().is_empty():
		choose(selected)
		return
	_go(String(current_node().get("next", "")))

## Gives answer `index` to the question now open.
func choose(index: int) -> void:
	if not is_choosing() or index < 0 or index >= choices().size():
		return
	var from := node_id
	var to := String(choices()[index].get("next", ""))
	choice_made.emit(self, from, index)
	_go(to)

## Moves the highlight, wrapping at either end so the last answer is one press
## away from the first.
func move_selection(step: int) -> void:
	if not is_choosing():
		return
	selected = wrapi(selected + step, 0, choices().size())
	Cues.emit_cue(&"ui", {"kind": "arm"})

func end_conversation() -> void:
	if not is_talking():
		return
	node_id = ""
	revealed = 0.0
	selected = 0
	conversation_ended.emit(self)

func _go(to: String) -> void:
	if to == "":
		end_conversation()
		return
	if not nodes.has(to):
		push_warning("NPC %s has no dialogue node '%s'" % [npc_id, to])
		end_conversation()
		return
	node_id = to
	revealed = 0.0
	selected = 0
	Cues.at(&"talk", global_position, {"npc": npc_id})
	line_started.emit(self, node_id)

func is_talking() -> bool:
	return node_id != ""

func current_node() -> Dictionary:
	return nodes.get(node_id, {})

func current_line() -> String:
	return String(current_node().get("text", ""))

## The part of the current line revealed so far.
func visible_text() -> String:
	return current_line().left(int(revealed))

func line_finished() -> bool:
	return int(revealed) >= current_line().length()

## The answers the current line offers; empty when it is not a question.
func choices() -> Array:
	return current_node().get("choices", [])

## True once a question has been asked in full and is waiting for an answer.
## Answers cannot be picked while the question is still coming in.
func is_choosing() -> bool:
	return is_talking() and line_finished() and not choices().is_empty()

## Whether a press on a plain line brings up another line rather than ending.
func has_more() -> bool:
	return is_talking() and choices().is_empty() and String(current_node().get("next", "")) != ""

func face(dir: int) -> void:
	if dir != 0:
		facing = signi(dir)

func _player() -> Player:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and not p.dead:
			return p
	return null
