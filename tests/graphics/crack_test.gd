extends Node
## A monster slammed into a wall by KNOCKBACK leaves a crack in it
## (`Fx.crack`, off the `wall_slam` cue), and the crack stays: it does not
## fade, it is the room's — next door there is none — and it is still there
## when the room is walked back into, drawn over the rock and under the bodies.
## And in the hideout's room, whose rock is drawn the old way, over that rock.
## A room keeps no more than CRACKS_A_ROOM; the oldest goes.

const GameScript := preload("res://app/game.gd")
var game: Node
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[CRACK] PASS ", what)
	else:
		fails += 1
		push_error("CRACK FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Until `cond` holds, or `seconds` have gone on the wall clock.
func until(cond: Callable, seconds: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > int(seconds * 1000.0):
			return false
		await get_tree().physics_frame
	return true

## A Crawler put down beside the player and thrown hard at the room's left wall.
func slam(room: Room, player: Player) -> bool:
	var at := player.global_position + Vector2(-40.0, 0.0)
	room._spawn_enemy({"kind": "CRAWLER", "mod": "", "pos": [at.x, at.y]})
	await get_tree().physics_frame
	var e: Enemy = null
	for c in room.get_children():
		if c is Enemy and not (c as Enemy).dead:
			e = c
	if e == null:
		return false
	var before := Fx.cracks_in(room).size()
	e.knockback(Vector2.LEFT, 1400.0, 0)
	return await until(func() -> bool: return Fx.cracks_in(room).size() > before, 4.0)

func _ready() -> void:
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)

	game._deploy("SWORD")
	await frames(10)
	var raid: Raid = game.current
	raid.player.invuln = 999.0
	await until(func() -> bool: return raid.player.is_on_floor(), 3.0)
	check(Fx.cracks_in(raid.room).is_empty(), "a raid's room starts with no cracks")
	check(await slam(raid.room, raid.player), "a monster slammed into its wall leaves a crack")
	var crack: Node2D = Fx.cracks_in(raid.room)[0]
	check(crack.get_parent() == Views.of(raid.room) and crack.z_index == -6,
		"in the room's picture, over the made room's ground and under the bodies (z %d)" % crack.z_index)
	var where := crack.global_position
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 7500:
		await get_tree().process_frame
	check(Fx.cracks_in(raid.room).size() == 1 and is_instance_valid(crack) and crack.visible
			and crack.modulate.a == 1.0,
		"and it is still there, whole, long after (once the old one would have faded)")
	var home := raid.room.coord
	var away: Vector2i = home + RaidMap.dir_delta(int(raid.map.doors_for(home).keys()[0]))
	raid._enter_room(away, -1)
	await frames(4)
	check(Fx.cracks_in(raid.room).is_empty(), "next door there is no crack")
	raid._enter_room(home, -1)
	await frames(4)
	var back := Fx.cracks_in(raid.room)
	check(back.size() == 1 and (back[0] as Node2D).global_position.distance_to(where) < 1.0,
		"walked back into, the room has it where it was")
	# No more than a room keeps.
	for i in Fx.CRACKS_A_ROOM + 3:
		Fx.crack(where + Vector2(0.0, -8.0 * i), Vector2.RIGHT, 1.0)
	await frames(2)
	check(Fx.cracks_in(raid.room).size() == Fx.CRACKS_A_ROOM,
		"a room keeps no more than %d (%d)" % [Fx.CRACKS_A_ROOM, Fx.cracks_in(raid.room).size()])
	raid._enter_room(away, -1)
	await frames(2)
	raid._enter_room(home, -1)
	await frames(2)
	check(Fx.cracks_in(raid.room).size() == Fx.CRACKS_A_ROOM, "and no more than that come back")

	# --- the hideout, whose rock is drawn the old way ------------------------
	game.goto_hideout()
	await frames(10)
	var h: HideoutWorld = game.hideout_ref
	h.player.invuln = 999.0
	h.player.global_position = Vector2(200.0, h.player.global_position.y)
	await until(func() -> bool: return h.player.is_on_floor(), 3.0)
	check(Fx.cracks_in(h.room).is_empty(), "the hideout has none of the raid's")
	check(await slam(h.room, h.player), "a slam in the hideout cracks its wall too")
	var hc: Node2D = Fx.cracks_in(h.room)[0]
	check(hc.z_index == -1 and hc.get_index() > (Views.of(h.room) as RoomView)._tiles.get_index(),
		"drawn after the rock, at its depth")

	print("[CRACK] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
