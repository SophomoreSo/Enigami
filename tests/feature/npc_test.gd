extends Node2D
## Talking to an NPC: interact only works up close, a press finishes a line
## still coming in before it moves on, the last press ends the conversation, and
## walking away ends it too. Attacks never treat a bystander as a target.

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

## Presses interact the way a player does. A synthetic press only reads as
## just-pressed on the physics frame after it, so give it two.
func press() -> void:
	Input.action_press("interact")
	await phys(2)
	Input.action_release("interact")
	await phys(1)

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
	n.conversation_ended.connect(func(_n: Npc) -> void: ended[0] += 1)
	await phys(40)

	check(n.is_on_floor(), "the NPC stands on the floor")
	check(not n.is_in_group("actors"), "and is no target for attacks")

	# Too far away.
	await press()
	check(not n.in_range and not n.is_talking(), "a press from across the room does nothing")

	# Up close, on the NPC's left.
	p.global_position = Vector2(560, n.global_position.y)
	await phys(2)
	check(n.in_range, "standing next to them is in range")
	check(n.facing == -1, "and they turn to face the player")
	await press()
	check(n.line_index == 0, "a press starts the conversation on the first line (%d)" % n.line_index)
	check(not n.line_finished(), "which types out rather than appearing at once")

	# A press mid-line finishes it without skipping ahead.
	await press()
	check(n.line_index == 0 and n.line_finished(), "a press mid-line finishes that line")
	await press()
	check(n.line_index == 1 and n.revealed < 3.0, "the next press moves on to the next line")

	# Letting a line finish on its own.
	await phys(int(float(n.current_line().length()) / Npc.REVEAL_RATE * 60.0) + 10)
	check(n.line_finished(), "a line finishes revealing on its own")

	# Through to the end.
	var guard := 0
	while n.is_talking() and guard < 20:
		await press()
		guard += 1
	check(not n.is_talking() and ended[0] == 1,
		"a press on the last line ends it (%d presses, ended %d)" % [guard, ended[0]])
	await press()
	check(n.line_index == 0, "and talking again starts over")

	# Walking away mid-conversation.
	p.global_position = Vector2(300, n.global_position.y)
	await phys(2)
	check(not n.is_talking() and ended[0] == 2, "walking away ends the conversation")

	# Locked input, like the skill editor being open.
	p.global_position = Vector2(560, n.global_position.y)
	p.input_locked = true
	await phys(2)
	await press()
	check(not n.is_talking(), "no conversation starts while the player's input is locked")
	p.input_locked = false

	print("[NPC] ---- %d failures ----" % fails)
	get_tree().quit()
