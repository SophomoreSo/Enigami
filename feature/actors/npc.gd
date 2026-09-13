class_name Npc
extends CharacterBody2D

## Someone to talk to. Walk up and press interact and a conversation starts;
## each further press moves it on. Some lines end in a question — move up and
## down to pick an answer, interact to give it — and the answer decides what
## they say next. The player is held still while they listen — no walking,
## jumping, dashing or attacking — so a conversation ends by talking it through,
## or by something else carrying the player out of range. Nothing here is drawn:
## `graphics/views/npc_view.gd` and `graphics/ui/dialogue_box.gd` show it.
##
## What each NPC says lives in their dialogue file, `data/dialogue/<id>.json`
## (see `Dialogue`).
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
## Letters a line reveals per second, unless it sets its own `speed`. A press
## while one is still coming in finishes it rather than skipping it unread.
const REVEAL_RATE := 45.0
## Letters that make no sound as they type.
const QUIET := " .,!?;:'\"-…()"

var npc_id: String = "SAGE"
var display_name: String = ""
## The whole dialogue file, as `Dialogue` read it.
var data: Dictionary = {}
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
## The player being talked to, held still until the conversation ends.
var _listener: Player = null

func setup(id: String) -> void:
	npc_id = id
	data = Dialogue.character(id)
	display_name = String(data.get("name", id))
	nodes = data.get("nodes", {})
	start = String(data.get("start", ""))

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
			var before := int(revealed)
			revealed = minf(revealed + reveal_rate() * delta, float(current_line().length()))
			_announce_letters(before)
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
	_release_listener()
	node_id = ""
	revealed = 0.0
	selected = 0
	conversation_ended.emit(self)

## The cue carries the whole line, so whatever it says about how it looks and
## sounds reaches the picture and the sound bank without this reading it.
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
	if _listener == null:
		_listener = _player()
		if _listener != null:
			_listener.talk_locked = true
	Cues.at(&"talk", global_position, {"npc": npc_id, "node": to, "line": current_node()})
	line_started.emit(self, node_id)

## An NPC taken away mid-sentence must not leave the player frozen.
func _exit_tree() -> void:
	_release_listener()

func _release_listener() -> void:
	if _listener != null and is_instance_valid(_listener):
		_listener.talk_locked = false
	_listener = null

## Letters coming out are a moment a voice can blip along with. At most one a
## frame, so a fast line is a patter rather than a buzz, and never for spaces or
## punctuation.
func _announce_letters(before: int) -> void:
	var line := current_line()
	for i in range(before, int(revealed)):
		if i % 2 == 0 and not QUIET.contains(line[i]):
			Cues.at(&"talk_letter", global_position, {"npc": npc_id, "line": current_node(), "index": i})
			return

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

## Letters per second for the current line.
func reveal_rate() -> float:
	return maxf(float(current_node().get("speed", REVEAL_RATE)), 1.0)

## Who says the current line: "npc" or "player".
func speaker() -> String:
	return String(current_node().get("speaker", "npc"))

func speaker_name() -> String:
	var node := current_node()
	if node.has("name"):
		return String(node["name"])
	if speaker() == "player":
		return String(data.get("player_name", "You"))
	return display_name

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
