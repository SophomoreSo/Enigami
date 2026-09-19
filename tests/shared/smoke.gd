extends Node
## Drives every screen and every attack form once, with rendering on, so that
## draw-time and runtime errors surface in CI-style runs.

const GameScript := preload("res://app/game.gd")
var game: Node
var log_lines: Array[String] = []
var fails := 0

func say(s: String) -> void:
	log_lines.append(s)
	print("[SMOKE] ", s)

## Counted as well as shouted: the count is what the exit code is made of.
func fail(what: String) -> void:
	fails += 1
	push_error("SMOKE FAIL: " + what)

func _ready() -> void:
	# Start from a clean profile so runs are repeatable.
	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	GameState.reset_profile()
	seed(20260911)  # deterministic map and loot for repeatable runs
	await _run()
	print("[SMOKE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## The cast button as an event rather than `Input.action_press`, which stamps the
## action with the current frame and so can have its release land in a frame the
## player has already processed — leaving `is_action_just_released` false and the
## cast never bought.
func _cast_button(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = down
	Input.parse_input_event(e)

func _run() -> void:
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(5)
	say("title ok, state=%d" % game.state)

	# The opening scene, which a wiped profile has not seen. Read a couple of
	# beats the way a player does, then skip out of it.
	game.goto_intro()
	await frames(5)
	var intro: Cutscene = game.current
	var beats := 0
	for i in 400:
		if intro.done or beats >= 3:
			break
		if intro.waiting_for_press() and intro.line_finished():
			intro.press()
			beats += 1
		await get_tree().process_frame
	say("intro ok, read %d beats, cast=%s" % [beats, str(intro.cast.keys())])
	intro.skip()
	await frames(6)
	say("intro handed over, state=%d (1 = hideout), seen=%s"
		% [game.state, str(GameState.intro_seen)])

	game.goto_hideout()
	await frames(5)
	say("hideout ok, weapons=%s" % str(GameState.owned_weapons))

	# Workbench editor over the hideout.
	game._edit_library_skill(0)
	await frames(3)
	var ed: SkillEditor = game.editor
	ed.selected = "DAMAGE"
	ed._hover_cell = Vector2i(2, 1)
	ed._click_left()
	ed._hover_pal = 3
	ed._update_hover(Vector2(720, 120))
	await frames(3)
	game._close_editor()
	await frames(3)
	say("workbench editor ok")

	# Deploy with every skill the library has.
	var slots: Array = []
	for i in mini(GameState.skill_library.size(), Weapons.slots("SWORD")):
		slots.append(i)
	game._deploy("SWORD", slots)
	await frames(6)
	var raid: Raid = game.current
	say("raid ok, rooms=%d entry=%s" % [raid.map.rooms.size(), str(raid.map.entry)])

	# Fire every slot for a while.
	var fire_count := [0]
	for r in raid.player.runners:
		r.fired.connect(func(_p: Payload) -> void: fire_count[0] += 1)
	# The number keys arm a slot and never fire it; the mouse buttons do the
	# firing, one for the weapon and one for whatever is armed.
	for slot in range(1, 5):
		var bound := Controls.short_label_for("skill_%d" % slot)
		if bound != str(slot):
			fail("skill_%d reads as '%s', not '%d'" % [slot, bound, slot])
		for ev in InputMap.action_get_events("skill_%d" % slot):
			if ev is InputEventMouseButton:
				fail("skill_%d must not be on a mouse button" % slot)
	if Controls.short_label_for("attack") != "LMB":
		fail("attack is on %s, not LMB" % Controls.short_label_for("attack"))
	if Controls.short_label_for("cast_skill") != "RMB":
		fail("cast_skill is on %s, not RMB" % Controls.short_label_for("cast_skill"))
	say("numbers arm a slot, LMB attacks, RMB casts")

	raid.player.basic_runner.fired.connect(func(_p: Payload) -> void: fire_count[0] += 1)
	# Arm each slot in turn and cast it. A slot the weapon will not carry fires
	# nothing on purpose, so it is skipped rather than counted as a failure.
	var castable := 0
	var refused := 0
	for i in raid.player.runners.size():
		raid.player.select_slot(i)
		await frames(4)
		if not raid.player.can_cast(i):
			refused += 1
			continue
		castable += 1
		Input.action_press("cast_skill")
		await frames(40)
		Input.action_release("cast_skill")
		await frames(4)
	Input.action_press("attack")
	await frames(40)
	Input.action_release("attack")
	say("circuits fired %d times across %d castable slot(s), %d refused by the weapon"
		% [fire_count[0], castable, refused])
	if castable <= 0:
		fail("the weapon accepted none of its own loadout")
	if fire_count[0] <= 0:
		fail("casting produced no output")

	# Every attack form, straight through the spawner.
	for form in ["PROJECTILE", "SLASH", "AREA", "DASHSLASH", "DASHSLASH_AUTO"]:
		var p := Payload.new()
		p.form = form
		p.damage = 5.0
		p.duplicates = 3
		p.elements = ["FIRE", "ICE"] as Array[String]
		p.pierce = 2
		p.homing = true
		p.dash = true
		p.blink = true
		var trig := Payload.new()
		trig.form = "AREA"
		trig.damage = 3.0
		p.on_hit = trig
		p.on_kill = trig
		Attacks.spawn(p, {"attacker": raid.player, "room": raid.room, "team": 0,
			"aim": Vector2.RIGHT, "origin": raid.player.global_position, "gravity": true})
		await frames(6)
	say("all attack forms ok")


	# Editor mid-raid, then a component placement from the bag.
	GameState.add_component("HOMING", 3, GameState.raid_bag)
	raid.set_editing(true)
	await frames(4)
	var red: SkillEditor = Views.of(raid).editor
	red.selected = "HOMING"
	red._hover_cell = Vector2i(1, 1)
	red._click_left()
	red._update_hover(Vector2(300, 200))
	if not GameState.raid_boards[0].comp_at(Vector2i(1, 1)).has("id"):
		fail("mid-raid placement did not land on the board")
	await frames(6)
	raid.set_editing(false)
	await frames(3)
	say("raid editor ok, bag=%s" % str(GameState.raid_bag))

	# Walk every door out of the entry room, and back.
	var visited := 0
	for dir in raid.room.doors.keys():
		var before: Vector2i = raid.room.coord
		raid._travel(int(dir))
		await frames(8)
		if raid.room.coord != before:
			visited += 1
	say("door travel ok, moved %d times, now at %s" % [visited, str(raid.room.coord)])

	# Sweep to a few more rooms so more generation paths run.
	for c in raid.map.rooms.keys():
		raid._enter_room(c, -1)
		await frames(3)
	say("visited all %d rooms" % raid.map.rooms.size())

	# Kill everything in the current room to exercise drops.
	raid._enter_room(raid.map.entry, -1)
	await frames(3)
	for c in raid.room.get_children():
		if c is Enemy:
			c.apply_damage(999999.0, [], null)
	await frames(10)
	say("kills ok")

	# Loot must land in the raid bag, not the safe stash. Find a room with loot.
	for c in raid.map.rooms.keys():
		if String(raid.map.rooms[c].get("kind", "")) == "treasure":
			raid._enter_room(c, -1)
			break
	await frames(4)
	var stash_before := GameState.stash.duplicate()
	var loot_here := 0
	for c in raid.room.get_children():
		if c is Pickup:
			loot_here += 1
	for i in 200:
		for c in raid.room.get_children():
			if c is Pickup:
				raid.player.global_position = c.global_position
				break
		await get_tree().process_frame
	say("loot in room %d -> bag=%s scrap=%d  stash untouched=%s" % [loot_here, str(GameState.raid_bag), GameState.raid_scrap, str(GameState.stash == stash_before)])
	if GameState.stash != stash_before:
		fail("raid loot leaked into the stash")
	if loot_here > 0 and GameState.raid_bag.size() <= 1 and GameState.raid_scrap <= 0:
		fail("loot on the floor could not be picked up")

	# Extraction at the entry gate.
	raid._enter_room(raid.map.entry, -1)
	await frames(4)
	for c in raid.room.get_children():
		if c is Enemy:
			c.queue_free()
	Input.action_press("interact")
	for i in 700:
		raid.player.global_position = raid.room.extraction_rect().get_center()
		await get_tree().process_frame
		if game.state != 2:
			break
	Input.action_release("interact")
	say("state after extraction=%d (4 = results)" % game.state)
	if game.state != 4:
		fail("holding interact at a free exit did not extract")

	await frames(5)
	if game.current is ResultsScreen:
		(game.current as ResultsScreen).continued.emit()
	await frames(6)
	say("results ok, stash=%s scrap=%d" % [str(GameState.stash), GameState.scrap])
	if not GameState.skill_library[0].comp_at(Vector2i(1, 1)).has("id"):
		fail("a board edited mid-raid did not come home")
	else:
		say("mid-raid edit survived extraction")

	# Sandbox.
	game.goto_sandbox()
	await frames(10)
	var sb: Sandbox = game.current
	sb.spawn_monster("CRAWLER")
	sb.spawn_monster("ARBITER")
	sb.cycle_weapon()
	sb.set_editing(true)
	await frames(20)
	sb.set_editing(false)
	Input.action_press("cast_skill")
	await frames(60)
	Input.action_release("cast_skill")
	say("sandbox ok, dps=%.1f weapon=%s" % [sb.dps(), sb.current_weapon()])

	# Damage has to actually land: stand on a dummy and hold the trigger.
	var dummy: Enemy = null
	for c in sb.get_children():
		if c is Enemy and c.kind == "DUMMY":
			dummy = c
	sb.weapon_index = 0
	sb._apply_weapon()
	sb.player.global_position = dummy.global_position + Vector2(-30, 0)
	sb.player.aim = Vector2.RIGHT
	Input.action_press("cast_skill")
	for i in 120:
		sb.player.global_position = dummy.global_position + Vector2(-30, 0)
		sb.player.aim = Vector2.RIGHT
		await get_tree().process_frame
	Input.action_release("cast_skill")
	var hp_lost := dummy.max_health - dummy.health
	say("melee damage landed: %.1f (dps %.1f)" % [hp_lost, sb.dps()])
	if hp_lost <= 0.0:
		fail("no damage was dealt")

	# The dragon test, off the bench: a charged cast down the tower, and the
	# floor setting itself again. What it comes to in numbers is
	# tests/feature/dragon_test.tscn; this is here to draw the screen.
	# A beat before the screen swaps. The release above is still the current
	# frame's edge, and the player the next screen builds reads the same input:
	# swapping on the same frame handed the dragon test a free uncharged cast
	# before anyone had touched a button.
	await frames(6)
	sb.open_dragon_test()
	await frames(12)
	var dragon: DragonTest = game.current
	# Held for as long as a player would hold it, and let go: the release is what
	# casts, and what it bought is what the chain is worth.
	_cast_button(true)
	var held := 0.0
	while dragon.player.charge < dragon.charge_to_clear() and held < 8.0:
		await get_tree().process_frame
		held += get_process_delta_time()
	_cast_button(false)
	await frames(3)
	say("held the cast button %.2fs for %.0f charge" % [held, dragon.player.cast_charge])
	for i in 400:
		await get_tree().process_frame
		if dragon.guards_left == 0:
			break
	say("dragon test ok, %d of %d guards down, best cast %d" % [
		dragon.total_guards - dragon.guards_left, dragon.total_guards, dragon.best_cast])
	if dragon.best_cast < dragon.total_guards:
		fail("one charged cast did not take the whole floor (%d of %d)"
			% [dragon.best_cast, dragon.total_guards])
	dragon.set_editing(true)
	await frames(6)
	dragon.set_editing(false)
	dragon.reset_floor()
	await frames(6)
	if dragon.guards_left != dragon.total_guards:
		fail("the dragon test did not set its floor again")
	dragon.leave()
	await frames(12)
	say("left the dragon test, state=%d (3 = sandbox)" % game.state)
	if game.state != 3:
		fail("leaving the dragon test did not return to the bench")

	# Death path.
	var lib_before := GameState.skill_library.size()
	var doomed := GameState.skill_library[1].skill_name
	game._deploy("GUN", [1])
	await frames(6)
	var raid2: Raid = game.current
	raid2.player.apply_damage(99999.0, [], null)
	await frames(10)
	say("death path ok, state=%d weapons=%s" % [game.state, str(GameState.owned_weapons)])
	if GameState.skill_library.size() != lib_before - 1:
		fail("the skill carried into a lost raid survived")
	else:
		say("death consumed the equipped skill '%s' (library %d -> %d)" % [
			doomed, lib_before, GameState.skill_library.size()])
	game.goto_title()
	await frames(5)
