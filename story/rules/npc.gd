class_name Npc
extends CharacterBody2D

## Someone to talk to, in one of two ways.
##
## **In the box** — `Mode.FREEZE`. Walk up and press interact and a
## conversation starts; each further press moves it on. Some lines end in a
## question — move up and down to pick an answer, interact to give it — and the
## answer decides what they say next. The player is held still while they
## listen — no walking, jumping, dashing or attacking — so a conversation ends
## by talking it through, or by something else carrying the player out of range.
##
## **Free** — `Mode.FREE`. What is said comes out in a bubble over whoever is
## saying it, and the player goes on playing: nothing is held, a line moves on
## by itself once it has been read, and a press up close only hurries it. It is
## never a fixed path. Every line is a rule that an event gets when the facts
## are right (see `FreeTalk`), and walking out of earshot in the middle of talk
## the player started cuts it off — to be picked up again next time.
##
## A press starts whichever `mode` says. What they notice — the player coming
## into earshot, a double jump, a blow — they answer free in either mode,
## whenever their rules have something to say about it. Nothing here is drawn:
## `story/view/npc_view.gd`, `dialogue_box.gd` and `speech_bubble.gd` show it.
##
## What each NPC says lives in the content database, as rows under their id
## (see `Dialogue`, and `data/db/README.md`).
##
## An NPC is deliberately not an Actor. Attacks find their targets through the
## "actors" group, so a bystander outside it can stand in the line of fire
## without ever being hit.

signal line_started(npc: Npc, node_id: String)
signal choice_made(npc: Npc, node_id: String, index: int)
signal conversation_ended(npc: Npc)

## What a press of interact starts: the conversation in the box, or free talk.
enum Mode { FREEZE, FREE }

const BODY := Vector2(18.0, 28.0)
const GRAVITY := 1900.0
const MAX_FALL := 900.0
## How close the player has to stand for a press to count, centre to centre.
const TALK_RANGE := 64.0
## How far a free talker's voice carries, centre to centre. They notice what the
## player does inside it, and talk the player started goes on only while the
## player stays in it: eight cells, far enough to try a move out in front of
## them.
const EARSHOT := 256.0
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
## True while the player is close enough to hear them talk free.
var in_earshot: bool = false
## What a press starts. A character with no conversation in the box talks free;
## whoever stages them may say otherwise, since which way a character talks
## where is the game's to decide.
var mode: int = Mode.FREEZE
## Their free talk, in either mode: see `FreeTalk`.
var free_talk: FreeTalk
## The player being talked to, held still until the conversation ends.
var _listener: Player = null

func setup(id: String) -> void:
	npc_id = id
	data = Dialogue.character(id)
	display_name = String(data.get("name", id))
	nodes = data.get("nodes", {})
	start = String(data.get("start", ""))
	mode = Mode.FREEZE if start != "" else Mode.FREE
	free_talk = FreeTalk.new(id, data)
	free_talk.started.connect(_on_free_line)

func _ready() -> void:
	if data.is_empty():
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
	var away := INF if player == null else global_position.distance_to(player.global_position)
	var was_in_earshot := in_earshot
	in_range = away <= TALK_RANGE
	in_earshot = away <= EARSHOT
	if in_range or (free_talk.is_talking() and in_earshot):
		face(int(signf(player.global_position.x - global_position.x)))
	if is_talking():
		# Walking off mid-sentence is how a player says they are done listening.
		if not in_range:
			end_conversation()
		else:
			var before := int(revealed)
			revealed = minf(revealed + reveal_rate() * delta, float(current_line().length()))
			_announce_letters(before)
	_talk_free(delta, player, was_in_earshot)
	if not in_range or player.input_locked or not _nearest(player):
		return
	if is_choosing():
		if Input.is_action_just_pressed("move_up"):
			move_selection(-1)
		if Input.is_action_just_pressed("move_down"):
			move_selection(1)
	if Input.is_action_just_pressed("interact"):
		if mode == Mode.FREEZE or is_talking():
			interact()
		elif answers_press() and not player.talk_locked:
			free_talk.press()

## Free talk, every frame: whether they can hear the game at all, the player
## coming into earshot or walking out of it, and the line being said moving on.
func _talk_free(delta: float, player: Player, was_in_earshot: bool) -> void:
	# A conversation in the box has all of the player's attention, theirs or
	# anybody's: free talk holds its tongue until it is over.
	var hushed := player == null or player.talk_locked
	free_talk.listening = in_earshot and not hushed
	if hushed:
		free_talk.cut()
		return
	if in_earshot and not was_in_earshot:
		free_talk.hear(FreeTalk.NEAR)
	elif was_in_earshot and not in_earshot and free_talk.is_talking() and free_talk.asked:
		# Walking off is how a player says they are done listening. What they
		# walked out on was never said, so it is what comes up again.
		free_talk.cut()
		free_talk.hear(FreeTalk.LEAVE)
	var saying := free_talk.line_id
	var before := int(free_talk.revealed)
	free_talk.step(delta)
	if saying != "" and free_talk.line_id == saying:
		_blip(free_talk.current_line(), free_talk.current_rule(), before, int(free_talk.revealed),
			free_speaker().global_position)

## Whether a press of interact here would get an answer: in the box, always;
## free, while a line is being said, or while there is something to say.
func answers_press() -> bool:
	if not in_range:
		return false
	if mode == Mode.FREEZE or is_talking():
		return true
	return free_talk.is_talking() or free_talk.would_answer(FreeTalk.TALK)

## Whoever is saying the free line: the player, or them.
func free_speaker() -> Node2D:
	if free_talk.speaker() == "player":
		var player := _player()
		if player != null:
			return player
	return self

## A free line starting. The cue carries the whole rule, the way the box's
## carries its line, so the sound bank plays what the rule names.
func _on_free_line(rule_id: String) -> void:
	Cues.at(&"talk", free_speaker().global_position,
		{"npc": npc_id, "rule": rule_id, "line": free_talk.current_rule()})

## Two NPCs in reach of the player: the nearer one hears the press.
func _nearest(player: Player) -> bool:
	var mine := global_position.distance_to(player.global_position)
	for n in get_tree().get_nodes_in_group("npcs"):
		if n != self and n is Npc and (n as Npc).in_range \
				and (n as Npc).global_position.distance_to(player.global_position) < mine:
			return false
	return true

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
	_blip(current_line(), current_node(), before, int(revealed), global_position)

## The same for any line, box or free: `text` came out from letter `from` up to
## `to`, said at `at`, and `line` is the row it came from.
func _blip(text: String, line: Dictionary, from: int, to: int, at: Vector2) -> void:
	for i in range(from, mini(to, text.length())):
		if i % 2 == 0 and not QUIET.contains(text[i]):
			Cues.at(&"talk_letter", at, {"npc": npc_id, "line": line, "index": i})
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
		return String(data.get("player_name", Loc.t("hud.dialogue.player")))
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

## The player, as long as they are staying. A world being swapped out is freed
## at the end of the frame, and until then its player is still in the group:
## the world coming in would otherwise meet them for a frame, standing wherever
## they stood in the old one — and a free talker would greet somebody who is
## not there.
func _player() -> Player:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and not p.dead and not _leaving(p):
			return p
	return null

static func _leaving(n: Node) -> bool:
	while n != null:
		if n.is_queued_for_deletion():
			return true
		n = n.get_parent()
	return false
