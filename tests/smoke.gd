extends Node
## Drives every screen and every attack form once, with rendering on, so that
## draw-time and runtime errors surface in CI-style runs.

const GameScript := preload("res://scripts/core/game.gd")
var game: Node
var log_lines: Array[String] = []

func say(s: String) -> void:
	log_lines.append(s)
	print("[SMOKE] ", s)

func _ready() -> void:
	# Start from a clean profile so runs are repeatable.
	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	GameState.reset_profile()
	seed(20260911)  # deterministic map and loot for repeatable runs
	await _run()
	print("[SMOKE] ---- complete ----")
	get_tree().quit()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _run() -> void:
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(5)
	say("title ok, state=%d" % game.state)

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
	Input.action_press("skill_1")
	Input.action_press("skill_2")
	await frames(120)
	Input.action_release("skill_1")
	Input.action_release("skill_2")
	say("circuits fired %d times across %d slots" % [fire_count[0], raid.player.runners.size()])
	if fire_count[0] <= 0:
		push_error("SMOKE FAIL: holding a skill produced no output")

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
	raid._open_editor()
	await frames(4)
	var red: SkillEditor = raid.editor
	red.selected = "HOMING"
	red._hover_cell = Vector2i(1, 1)
	red._click_left()
	red._update_hover(Vector2(300, 200))
	if not GameState.raid_boards[0].comp_at(Vector2i(1, 1)).has("id"):
		push_error("SMOKE FAIL: mid-raid placement did not land on the board")
	await frames(6)
	raid._close_editor()
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
		push_error("SMOKE FAIL: raid loot leaked into the stash")
	if loot_here > 0 and GameState.raid_bag.size() <= 1 and GameState.raid_scrap <= 0:
		push_error("SMOKE FAIL: loot on the floor could not be picked up")

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
		push_error("SMOKE FAIL: holding interact at a free exit did not extract")

	await frames(5)
	if game.current is ResultsScreen:
		(game.current as ResultsScreen).continued.emit()
	await frames(6)
	say("results ok, stash=%s scrap=%d" % [str(GameState.stash), GameState.scrap])
	if not GameState.skill_library[0].comp_at(Vector2i(1, 1)).has("id"):
		push_error("SMOKE FAIL: a board edited mid-raid did not come home")
	else:
		say("mid-raid edit survived extraction")

	# Sandbox.
	game.goto_sandbox()
	await frames(10)
	var sb: Sandbox = game.current
	sb.spawn_monster("CRAWLER")
	sb.spawn_monster("ARBITER")
	sb.cycle_weapon()
	sb._open_editor()
	await frames(20)
	sb._close_editor()
	Input.action_press("skill_1")
	await frames(60)
	Input.action_release("skill_1")
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
	Input.action_press("skill_1")
	for i in 120:
		sb.player.global_position = dummy.global_position + Vector2(-30, 0)
		sb.player.aim = Vector2.RIGHT
		await get_tree().process_frame
	Input.action_release("skill_1")
	var hp_lost := dummy.max_health - dummy.health
	say("melee damage landed: %.1f (dps %.1f)" % [hp_lost, sb.dps()])
	if hp_lost <= 0.0:
		push_error("SMOKE FAIL: no damage was dealt")

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
		push_error("SMOKE FAIL: the skill carried into a lost raid survived")
	else:
		say("death consumed the equipped skill '%s' (library %d -> %d)" % [
			doomed, lib_before, GameState.skill_library.size()])
	game.goto_title()
	await frames(5)
