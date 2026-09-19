extends Node2D
## Talking to an NPC: interact only works up close, a press finishes a line
## still coming in before it moves on, a question waits for an answer picked
## with up and down, the answer decides what comes next, and walking away ends
## it. Attacks never treat a bystander as a target. Every dialogue file reads
## cleanly.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[NPC] PASS ", what)
	else:
		fails += 1
		push_error("NPC FAIL: " + what)

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

## Presses an action the way a player does. A synthetic press only reads as
## just-pressed on the physics frame after it, so give it two.
func press(action: String = "interact") -> void:
	Input.action_press(action)
	await phys(2)
	Input.action_release(action)
	await phys(1)

## Waits for the current line to finish typing by itself.
func listen(n: Npc) -> void:
	var guard := 0
	while n.is_talking() and not n.line_finished() and guard < 600:
		await get_tree().physics_frame
		guard += 1

func _ready() -> void:
	solid(Vector2(600, 500), Vector2(2000, 200))
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = Vector2(300, 380)
	add_child(p)
	var n := Npc.new()
	n.setup("SAGE")
	n.collision_layer = 0
	n.collision_mask = 1
	n.position = Vector2(600, 380)
	add_child(n)
	var ended := [0]
	var picks: Array = []
	var letters := [0]
	n.conversation_ended.connect(func(_n: Npc) -> void: ended[0] += 1)
	n.choice_made.connect(func(_n: Npc, from: String, i: int) -> void: picks.append([from, i]))
	Cues.fired.connect(func(cue: StringName, _d: Dictionary) -> void:
		if cue == &"talk_letter":
			letters[0] += 1)
	await phys(40)

	check(n.is_on_floor(), "the NPC stands on the floor")
	check(not n.is_in_group("actors"), "and is no target for attacks")

	# The files.
	check(Dialogue.ids().has("SAGE"), "the SAGE's lines are read from a dialogue file (%s)" % str(Dialogue.ids()))
	for id in Dialogue.ids():
		check(Dialogue.problems(id).is_empty(),
			"%s's dialogue file has no broken links or empty lines %s" % [id, str(Dialogue.problems(id))])
	var sage := Dialogue.character("SAGE")
	var filled := true
	for key in sage["nodes"]:
		for k in sage.get("defaults", {}):
			filled = filled and sage["nodes"][key].has(k)
	check(filled, "every line picks up the file's defaults")
	check(Dialogue.character("NOBODY") == sage, "an NPC with no file talks like the SAGE")

	# Too far away.
	await press()
	check(not n.in_range and not n.is_talking(), "a press from across the room does nothing")

	# Up close, on the NPC's left.
	p.global_position = Vector2(560, n.global_position.y)
	await phys(2)
	check(n.in_range, "standing next to them is in range")
	check(n.facing == -1, "and they turn to face the player")
	await press()
	check(n.node_id == "hello", "a press starts the conversation at the start (%s)" % n.node_id)
	check(not n.line_finished(), "which types out rather than appearing at once")
	check(n.speaker() == "npc" and n.speaker_name() == n.display_name, "and the NPC is the one saying it")

	# Held still while listening.
	check(p.controls_locked(), "the player is held while the conversation lasts")
	var stood := p.global_position
	Input.action_press("move_left")
	Input.action_press("jump")
	await phys(12)
	Input.action_release("move_left")
	Input.action_release("jump")
	await phys(2)
	check(p.global_position.distance_to(stood) < 1.0 and n.is_talking(),
		"walking and jumping do nothing mid-conversation (moved %.1f)" % p.global_position.distance_to(stood))

	# A press mid-line finishes it without skipping ahead.
	await press()
	check(n.node_id == "hello" and n.line_finished(), "a press mid-line finishes that line")
	await press()
	check(n.node_id == "ask", "the next press follows the line on to the question")

	# A question can't be answered before it has been asked.
	await press("move_down")
	check(not n.is_choosing() and n.selected == 0, "the answers wait until the question is out")
	await listen(n)
	check(letters[0] > 0, "letters typing out are announced for a voice to follow (%d)" % letters[0])
	check(n.is_choosing() and n.choices().size() == 4, "then four answers are open (%d)" % n.choices().size())

	# Moving the highlight, wrapping both ways.
	await press("move_down")
	check(n.selected == 1, "down moves to the next answer (%d)" % n.selected)
	await press("move_up")
	await press("move_up")
	check(n.selected == 3, "up past the first wraps to the last (%d)" % n.selected)
	await press("move_down")
	check(n.selected == 0, "down past the last wraps to the first (%d)" % n.selected)

	# The answer decides what comes next.
	await press("move_down")
	await press()
	check(n.node_id == "charge", "picking 'What does charging do?' leads to its answer (%s)" % n.node_id)
	check(picks.size() == 1 and picks[0] == ["ask", 1], "and reports which answer was given (%s)" % str(picks))
	check(n.selected == 0, "a new line starts with the highlight back on top")
	check(n.reveal_rate() == float(n.current_node()["speed"]), "a line types at the speed its file gives it")
	await listen(n)
	await press()
	check(n.node_id == "ask_again", "a plain line after it carries on (%s)" % n.node_id)

	# An answer can lead into another question.
	p.global_position = Vector2(300, n.global_position.y)
	await phys(2)
	check(not n.is_talking() and ended[0] == 1, "being carried away mid-question ends the conversation")
	check(not p.controls_locked(), "and lets the player move again")
	p.global_position = Vector2(560, n.global_position.y)
	await phys(2)
	await press()
	check(n.node_id == "hello", "and talking again starts over")
	await listen(n)
	await press()
	await listen(n)
	await press("move_down")
	await press("move_down")
	await press()
	check(n.node_id == "who", "picking 'Who are you?' leads to its line (%s)" % n.node_id)
	await listen(n)
	check(n.is_choosing() and n.choices().size() == 2, "which asks a question of its own")
	await press("move_down")
	await press()
	check(n.node_id == "ask", "'Back to my questions' returns to the first question (%s)" % n.node_id)

	# An answer that leads nowhere ends it on the spot.
	await listen(n)
	await press("move_up")
	await press()
	check(not n.is_talking() and ended[0] == 2, "'Nothing. Bye.' ends the conversation at once")

	# A goodbye line ends it on the press after.
	await press()
	await listen(n)
	await press()
	await listen(n)
	await press("move_down")
	await press()
	await listen(n)
	await press()
	check(n.node_id == "ask_again", "reached 'Anything else?' (%s)" % n.node_id)
	await listen(n)
	await press("move_up")
	await press()
	check(n.node_id == "bye" and not n.has_more(), "'That's all' leads to a last line (%s)" % n.node_id)
	await listen(n)
	await press()
	check(not n.is_talking() and ended[0] == 3, "and a press on it ends the conversation")

	# The player can have lines of their own.
	n.node_id = "danger_reply"
	check(n.speaker() == "player" and n.speaker_name() == String(sage["player_name"]),
		"a line the file gives the player is said by the player, under their name")
	n.end_conversation()

	# Locked input, like the skill editor being open.
	p.input_locked = true
	await press()
	check(not n.is_talking(), "no conversation starts while the player's input is locked")
	p.input_locked = false

	print("[NPC] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
