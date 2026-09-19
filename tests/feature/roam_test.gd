extends Node2D
## Monsters are rolled once a raid and never topped up again: a room walked out
## of and back into holds the monsters that were left in it, still carrying the
## wounds they were left with. What can change is where a monster is standing —
## one that walks into a doorway leaves for the room next door, and one that is
## chasing the player when they go through a door comes through after them.
##
## A monster is the only thing that may cross between rooms. Nothing an attack
## put in the world does — every bolt, arc, lunge and burst, and every follow-up
## still waiting to become one, is gone the moment the door is crossed.
##
## Only the live room is simulated, so a monster that has left is a record on
## the map rather than a node: `listed` below reads it there, which is the only
## way to see a monster in a room nobody is standing in.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[ROAM] PASS ", what)
	else:
		fails += 1
		push_error("ROAM FAIL: " + what)

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Every monster the map says is in `c`. A room that has been opened keeps them
## under "enemies"; one that has not keeps anything that has walked into it
## under "arrivals" until it is.
func listed(raid: Raid, c: Vector2i) -> Array:
	var rec: Dictionary = raid.map.get_record(c)
	var out: Array = []
	out.append_array(rec.get("enemies", []))
	out.append_array(rec.get("arrivals", []))
	return out

## How many of the test's own monsters the map says are in `c`.
##
## A monster is followed by the tag written into its record rather than by its
## kind, because the rooms roll their own and a room next door is perfectly
## entitled to hold another Hopper. The record is what travels between rooms,
## so a mark on it is the one thing that identifies a particular monster.
func count_in(raid: Raid, c: Vector2i, tag: String) -> int:
	var n := 0
	for e in listed(raid, c):
		if String((e as Dictionary).get("tag", "")) == tag:
			n += 1
	return n

## Everything `team` has in the world that an attack put there: bolts, arcs,
## lunges, bursts, and the follow-ups waiting to become one.
##
## Counted by team so that a monster in the room being walked into cannot be
## mistaken for something that came along: the player fires nothing of their own
## here, no button being held, so team 0 is only ever what this test loosed.
func in_air(raid: Raid, team: int) -> int:
	var n := 0
	for c in raid.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is Projectile or c is MeleeArc or c is DashSlash or c is AreaBurst \
				or c is Attacks.Deferred:
			if int(c.get("team")) == team:
				n += 1
	return n

func live(raid: Raid) -> Array:
	var out: Array = []
	for n in raid.room.get_children():
		if n is Enemy and not (n as Enemy).dead:
			out.append(n)
	return out

## The live monster carrying `tag`, or null once it has left the room.
func find(raid: Raid, tag: String) -> Enemy:
	for e in live(raid):
		var n := e as Enemy
		if n.has_meta("record") and String((n.get_meta("record") as Dictionary).get("tag", "")) == tag:
			return n
	return null

## Puts a monster in the live room the way the room itself does, record and all,
## so the test's own subjects are indistinguishable from rolled ones.
func plant(raid: Raid, kind: String, cell: Vector2i, tag: String) -> Enemy:
	var at := raid.room.cell_center(cell.x, cell.y)
	var rec := {"kind": kind, "mod": "", "pos": [at.x, at.y], "tag": tag}
	(raid.room.data["enemies"] as Array).append(rec)
	raid.room._spawn_enemy(rec)
	return find(raid, tag)

## A direction out of the live room that has a room on the other side.
func way_out(raid: Raid) -> int:
	for dir in raid.room.doors:
		if raid.map.has_room(raid.room.coord + RaidMap.dir_delta(int(dir))):
			return int(dir)
	return -1

func _ready() -> void:
	GameState.reset_profile()
	GameState.raid_seed = 20260919
	GameState.deploy("GUN", [])
	var raid := Raid.new()
	add_child(raid)
	await phys(2)

	var home := raid.room.coord
	var dir := way_out(raid)
	check(dir >= 0, "the entry room %s has a way out of it" % [home])
	var away: Vector2i = home + RaidMap.dir_delta(dir)

	var wounded := plant(raid, "CRAWLER", Vector2i(int(Room.W / 2), 4), "wounded")
	plant(raid, "HOPPER", Vector2i(int(Room.W / 2) + 3, 4), "rover")
	var max_hp := wounded.max_health
	wounded.apply_damage(max_hp * 0.5, [], null, false)
	var left := wounded.health
	var before := listed(raid, home).size()
	check(before == 2, "two monsters in the room to start with (%d)" % before)

	# --- nothing is topped up, and a wound is remembered ---------------------
	raid._travel(dir)
	await phys(2)
	raid._travel(RaidMap.opposite(dir))
	await phys(4)
	check(raid.room.coord == home, "walked out of %s and back in" % [home])
	check(listed(raid, home).size() == before,
		"the room holds the monsters it held, no more (%d, was %d)"
		% [listed(raid, home).size(), before])
	var back := find(raid, "wounded")
	check(back != null and absf(back.health - left) < 0.5,
		"and the one that was hurt is still hurt (%.0f of %.0f)"
		% [back.health if back != null else -1.0, max_hp])

	# --- a monster in a doorway leaves for the room next door ----------------
	var wanderer := find(raid, "rover")
	var was := listed(raid, away).size()
	var here := listed(raid, home).size()
	wanderer.global_position = raid.room.to_global(raid.room.door_rect(dir).get_center())
	await phys(2)
	check(listed(raid, home).size() == here - 1,
		"a monster standing in the doorway is gone from this room (%d of %d left)"
		% [listed(raid, home).size(), here])
	check(listed(raid, away).size() == was + 1,
		"and the map has it in the room it walked into (%d, was %d)"
		% [listed(raid, away).size(), was])
	check(find(raid, "rover") == null, "with nothing of it left here")

	# --- and it is the same monster when that room is opened -----------------
	raid._travel(dir)
	await phys(4)
	check(find(raid, "rover") != null,
		"which is standing there when the player walks in after it")

	# --- something on the player's heels follows them through ----------------
	var chaser := find(raid, "rover")
	var door := raid.room.door_rect(RaidMap.opposite(dir)).get_center()
	chaser.aggro = true
	chaser.global_position = raid.room.to_global(door) + Vector2(RaidMap.dir_delta(dir)) * 60.0
	var home_had := listed(raid, home).size()
	raid._travel(RaidMap.opposite(dir))
	await phys(4)
	check(raid.room.coord == home, "the player goes back through the door")
	check(find(raid, "rover") != null,
		"and what was chasing them comes through after them")
	# Anything else of that room's own that was on the player's heels is
	# entitled to come through too, so what is checked is that the one being
	# followed is one monster and not two: it is in the room it arrived in,
	# once, and no longer in the room it left.
	check(count_in(raid, home, "rover") == 1,
		"counted once in the room it arrived in (%d)" % count_in(raid, home, "rover"))
	check(count_in(raid, away, "rover") == 0,
		"and gone from the one it left (%d)" % count_in(raid, away, "rover"))
	check(listed(raid, home).size() > home_had,
		"which is more than the room held before (%d, was %d)"
		% [listed(raid, home).size(), home_had])

	# --- but nothing that was in the air crosses with them ------------------
	var shot := Payload.new()
	shot.form = "PROJECTILE"
	var ctx := {"attacker": raid.player, "room": raid.room, "team": 0,
		"aim": Vector2.UP, "origin": raid.player.global_position}
	for i in 3:
		Attacks.spawn(shot, ctx)
	# And one follow-up that comes due on the very frame the door is crossed.
	# It hangs off the raid, so it takes its turn after the raid has taken its
	# own — the same window the room being left would fire through.
	Attacks._schedule_spawn(0.0, shot, ctx)
	check(in_air(raid, 0) == 4,
		"four attacks of the player's own in the air (%d)" % in_air(raid, 0))
	var out := way_out(raid)
	raid._travel(out)
	var worst := 0
	for i in 6:
		await get_tree().process_frame
		worst = maxi(worst, in_air(raid, 0))
	check(worst == 0, "and not one of them is still around a room later (%d)" % worst)

	print("[ROAM] ---- %d failures ----" % fails)
	get_tree().quit()
