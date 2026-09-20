extends Node2D
## Dying drops the kit rather than destroying it, and the next deployment can go
## back for it: the same map, the same room, the spot the player fell on.
##
## Both halves are here because they are one rule seen from two sides — what
## `GameState` writes down when a run ends, and what the next `Raid` puts back
## on the floor because of it.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[KIT] PASS ", what)
	else:
		fails += 1
		push_error("KIT FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	# A profile of its own, like the smoke test: deploying and dying are written
	# to disk, so a run has to start from something known.
	GameState.reset_profile()
	for n in range(1, GameState.SAVE_SLOTS + 1):
		GameState.delete_slot(n)
	seed(20260920)

	_same_floor()
	await _rules()
	await _floor()

	print("[KIT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the promise the whole thing rests on -----------------------------------
## One seed, one floor. A drop is an address on a map that has not been built
## yet, so a seed that grew a different map the second time would leave every
## kit stranded — and would already have been quietly moving the rooms under a
## parked raid. The global generator is the way that happens: `randomize()` runs
## at boot, so anything drawing on it is a different answer every session.
func _same_floor() -> void:
	seed(1)
	var a := RaidMap.new()
	a.generate(9876543)
	var first: Array = a.rooms.keys()
	var kinds := first.map(func(c: Vector2i) -> String: return String(a.rooms[c]["kind"]))
	# A different global seed, deliberately: the map must not be able to tell.
	seed(2)
	randomize()
	var b := RaidMap.new()
	b.generate(9876543)
	check(b.rooms.size() == a.rooms.size() and first.all(func(c: Vector2i) -> bool: return b.rooms.has(c)),
		"the same seed grows the same rooms, whatever the global generator is doing (%d)"
			% a.rooms.size())
	check(kinds == first.map(func(c: Vector2i) -> String: return String(b.rooms[c]["kind"])),
		"and puts the entry, the boss and the treasure in the same places")
	check(a.entry == b.entry, "and the way in is the same way in")

## --- what a death writes down -----------------------------------------------
func _rules() -> void:
	var skill_name: String = GameState.skill_library[0].skill_name
	var library := GameState.skill_library.size()
	GameState.deploy("SWORD", [0])
	GameState.add_component("FIRE", 2, GameState.raid_bag)
	GameState.raid_scrap = 17
	var seed_used := GameState.raid_seed

	var lost := GameState.die({"room": [2, 3], "pos": [640.0, 320.0]})
	check(bool(lost.get("dropped", false)), "a death with somewhere to fall leaves the kit there")
	check(GameState.has_lost_kit(), "and the drop outlives the raid that made it")
	check(GameState.skill_library.size() == library - 1,
		"the skill is out of the library (%d -> %d)" % [library, GameState.skill_library.size()])
	check(not GameState.owned_weapons.has("SWORD"), "and the weapon is off the rack")

	var kit: Dictionary = GameState.lost_kit
	check(int(kit.get("seed", 0)) == seed_used, "the drop remembers which map it is in")
	check((kit.get("room", []) as Array) == [2, 3] and (kit.get("pos", []) as Array).size() == 2,
		"and the room and the spot in it (%s)" % str(kit.get("room", [])))
	check((kit.get("boards", []) as Array).size() == 1
			and (kit.get("weapons", []) as Array) == ["SWORD"],
		"it holds the skill and the weapon")
	check(int((kit.get("bag", {}) as Dictionary).get("FIRE", 0)) == 2
			and int(kit.get("scrap", 0)) == 17,
		"the bag and the scrap that were being carried")

	# Through disk, the way the next session will find it. A drop is the one
	# thing a run leaves for a later one, so it has to survive the app closing.
	GameState.save_game()
	GameState.load_slot(GameState.slot)
	check(GameState.has_lost_kit(), "the drop is written out and read back")
	check(int(GameState.lost_kit.get("seed", 0)) == seed_used
			and (GameState.lost_kit.get("room", []) as Array).size() == 2,
		"with the map and the room it belongs to intact")
	check((GameState.lost_kit.get("boards", []) as Array).size() == 1,
		"and the skill still in it")

	# The map a kit is lying in is the map the next deployment walks into.
	GameState.deploy("ROCK", [])
	check(GameState.raid_seed == seed_used,
		"deploying again goes back to the same floor (%d)" % GameState.raid_seed)

	# Picking it up puts it back into the run, not into the vault.
	var got := GameState.recover_lost_kit()
	check(not got.is_empty() and not GameState.has_lost_kit(), "recovering it clears the drop")
	check(int(GameState.raid_bag.get("FIRE", 0)) == 2 and GameState.raid_scrap == 17,
		"the bag and the scrap are being carried again")
	check(GameState.raid_carried_boards.size() == 1 and GameState.raid_carried_weapons == ["SWORD"],
		"the skill and the weapon ride along as cargo")
	check(GameState.skill_library.size() == library - 1,
		"and are not home yet — the library is untouched")

	var stash_before := int(GameState.stash.get("FIRE", 0))
	var result := GameState.extract()
	check(GameState.skill_library.size() == library,
		"walking out puts the skill back in the library (%d)" % GameState.skill_library.size())
	check(GameState.skill_library[GameState.skill_library.size() - 1].skill_name == skill_name,
		"the same skill, by name (%s)" % skill_name)
	check(GameState.owned_weapons.has("SWORD"), "and the weapon back on the rack")
	check(int(GameState.stash.get("FIRE", 0)) == stash_before + 2, "the bag goes to the stash")
	check((result.get("recovered", []) as Array).size() == 1,
		"and the results sheet is told what came back out")

## --- what the next raid puts back on the floor ------------------------------
## Somewhere in this room a body could be standing: open floor, with something
## solid under it, and clear of `away_from` — the door the next run walks in
## through. A drop left underfoot would be picked up before it was ever seen.
func standing_spot(r: Room, away_from: Vector2) -> Vector2:
	for x in range(3, Room.W - 4):
		for y in range(3, Room.H - 3):
			if r.is_solid(x, y) or r.is_solid(x, y - 1) or not r.is_solid(x, y + 1):
				continue
			var p := r.cell_center(x, y)
			if p.distance_to(away_from) > 260.0:
				return p
	return away_from

## A raid that tidies itself up the way the game does: the screen that owns one
## frees it the moment it finishes, and without that the view keeps reading a
## player who is no longer there.
func start_raid() -> Raid:
	var r := Raid.new()
	r.finished.connect(func(_result: String, _payload: Dictionary) -> void: r.queue_free())
	add_child(r)
	await frames(4)
	return r

func _floor() -> void:
	GameState.deploy("SWORD", [0])
	var raid := await start_raid()
	var died_in: Vector2i = raid.room.coord
	var died_at := standing_spot(raid.room, raid.room.spawn_point())
	raid.player.global_position = died_at
	await frames(2)
	raid.player.apply_damage(99999.0)
	await frames(4)
	check(GameState.has_lost_kit(), "dying in a real room leaves a drop")
	check((GameState.lost_kit.get("room", []) as Array) == [died_in.x, died_in.y],
		"in the room it happened in (%s)" % str(died_in))
	await frames(2)

	# Back in. The map is the same map, so the room is where it was.
	GameState.deploy("ROCK", [])
	var back := await start_raid()
	check(back.map.has_room(died_in), "the floor is the one that was died on")
	check((back.map.get_record(died_in) as Dictionary).has("lost_kit"),
		"and the room's own record is holding the kit for it")

	back._enter_room(died_in, -1)
	await frames(2)
	var on_floor: LostKit = null
	for c in back.room.get_children():
		if c is LostKit:
			on_floor = c
	check(on_floor != null, "walking in finds it lying there")
	if on_floor == null:
		return
	check(absf(on_floor.global_position.x - died_at.x) < 24.0,
		"on the spot it fell on (%.0f px across from it)"
			% absf(on_floor.global_position.x - died_at.x))
	check(on_floor.size() >= 1, "with what was in it (%d things)" % on_floor.size())
	check(GameState.has_lost_kit(), "and still waiting to be picked up")

	# And walking onto it is all it takes.
	back.player.global_position = on_floor.global_position
	await frames(3)
	check(not GameState.has_lost_kit(), "touching it picks it up")
	check(GameState.raid_carried_weapons.has("SWORD"), "the weapon is being carried again")
	check(not (back.map.get_record(died_in) as Dictionary).has("lost_kit"),
		"and the room is not holding it any more")
	back.queue_free()
	await frames(2)
