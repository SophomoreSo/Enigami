class_name Npc
extends CharacterBody2D

## Someone to talk to. Walk up and press interact: a line appears over their
## head, each further press moves the conversation on, and a press on the last
## line — or walking away — ends it. Nothing here is drawn;
## `graphics/views/npc_view.gd` turns the current line into a speech bubble.
##
## An NPC is deliberately not an Actor. Attacks find their targets through the
## "actors" group, so a bystander outside it can stand in the line of fire
## without ever being hit.

signal line_started(npc: Npc, index: int)
signal conversation_ended(npc: Npc)

const BODY := Vector2(18.0, 28.0)
const GRAVITY := 1900.0
const MAX_FALL := 900.0
## How close the player has to stand for a press to count, centre to centre.
const TALK_RANGE := 64.0
## Letters a line reveals per second. A press while one is still coming in
## finishes it rather than skipping it unread.
const REVEAL_RATE := 45.0

## Who each NPC is and what they say, in order.
const CATALOGUE := {
	"SAGE": {
		"name": "Old Tinker",
		"lines": [
			"Ah, a new face. Nothing you break in here stays broken.",
			"Every skill is a circuit. The longer the path, the longer you wait for the next shot.",
			"Build a loop, then hold the cast button. Charge buys the pulse more laps.",
			"Go on. The dummy won't mind.",
		],
	},
}

var npc_id: String = "SAGE"
var display_name: String = ""
var lines: Array = []
## +1 right, -1 left. They turn to whoever is close enough to talk to.
var facing: int = 1
var body_size: Vector2 = BODY
## Which line is up, or -1 when nobody is talking.
var line_index: int = -1
## How many letters of the current line are out so far.
var revealed: float = 0.0
## True while the player stands close enough to talk.
var in_range: bool = false

func setup(id: String) -> void:
	npc_id = id
	var def: Dictionary = CATALOGUE.get(id, CATALOGUE["SAGE"])
	display_name = String(def["name"])
	lines = (def["lines"] as Array).duplicate()

func _ready() -> void:
	if lines.is_empty():
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
	if in_range and not player.input_locked and Input.is_action_just_pressed("interact"):
		interact()

## One press of interact: start talking, finish the line coming in, move to the
## next line, or — on the last one — stop.
func interact() -> void:
	if lines.is_empty():
		return
	if is_talking() and not line_finished():
		revealed = float(current_line().length())
		return
	if not has_more():
		end_conversation()
		return
	line_index += 1
	revealed = 0.0
	Cues.at(&"talk", global_position, {"npc": npc_id})
	line_started.emit(self, line_index)

func end_conversation() -> void:
	if not is_talking():
		return
	line_index = -1
	revealed = 0.0
	conversation_ended.emit(self)

func is_talking() -> bool:
	return line_index >= 0

func current_line() -> String:
	return String(lines[line_index]) if is_talking() else ""

## The part of the current line revealed so far.
func visible_text() -> String:
	return current_line().left(int(revealed))

func line_finished() -> bool:
	return int(revealed) >= current_line().length()

## Whether another press would bring up another line rather than end it. Before
## the conversation starts that is the first line.
func has_more() -> bool:
	return line_index + 1 < lines.size()

func face(dir: int) -> void:
	if dir != 0:
		facing = signi(dir)

func _player() -> Player:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and not p.dead:
			return p
	return null
