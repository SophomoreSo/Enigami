extends Node2D
## The map creator's rules: a map is laid a mark at a time, in three layers —
## the ground and what stands on it, what stands behind, what is put about it —
## and every stroke can be taken back; SAVE keeps it as a scene Godot loads and
## anything can pick up as a room, layers, tileset and all; and PLAY stands
## that room up with a body in it — solid wherever there is ground of any kind,
## shut in on every side, with the monsters at their posts and the box where
## it was laid — and sets it again when the body falls.
##
## No renderer needed: nothing here draws. Maps are kept in a scratch folder
## for the length of the test, never in the project's own.

const SCRATCH := "user://map_maker_test"

var fails := 0
var maker: MapMaker

func check(ok: bool, what: String) -> void:
	if ok:
		print("[MAPS] PASS ", what)
	else:
		fails += 1
		push_error("MAPS FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func monsters() -> Array:
	return maker.room.get_children().filter(func(c: Node) -> bool: return c is Enemy and not c.dead)

func _ready() -> void:
	Maps.scratch_dir = SCRATCH
	_sweep()
	MapMaker.forget()
	maker = MapMaker.new()
	add_child(maker)
	await frames(2)

	# --- a new map ------------------------------------------------------------
	check(maker.cols == Room.W and maker.rows == Room.H, "a new map is a raid's room across and down (%dx%d)" % [maker.cols, maker.rows])
	check(maker.cells_marked(MadeRoom.START).size() == 1, "with one place for the player to start")
	check(maker.mark_at(Vector2i(0, 5)) == "|" and maker.mark_at(Vector2i(Room.W - 1, 5)) == "|"
			and maker.mark_at(Vector2i(5, 0)) == "*" and maker.mark_at(Vector2i(5, Room.H - 1)) == "%"
			and maker.mark_at(Vector2i(5, 5)) == MadeRoom.OPEN,
		"a clearing: a tree either side, leaves overhead, earth underfoot, and open between")
	check(["|", "*", "%", MadeRoom.ROCK, "=", "o", "@"].all(func(m: String) -> bool: return MadeRoom.is_ground(m))
			and not MadeRoom.is_ground(MadeRoom.OPEN) and not MadeRoom.is_ground(MadeRoom.START),
		"every kind of ground is ground, and nothing else is")
	check(maker.mark_at(Vector2i(-1, 5)) == MadeRoom.ROCK and maker.mark_at(Vector2i(5, 999)) == MadeRoom.ROCK,
		"and off the plan there is only rock")
	check(maker.tileset == MapMaker.NEW_TILESET and maker.back().size() == Room.H and maker.dressing()[0] == MadeRoom.OPEN.repeat(Room.W),
		"drawn in the tileset a new map is, with nothing behind it and nothing put about it")
	check(not maker.unsaved and not maker.can_undo(), "nothing to save yet and nothing to take back")

	# --- laying, and taking it back -----------------------------------------------
	maker.begin_stroke()
	check(maker.lay(Vector2i(10, 10), MadeRoom.ROCK), "a mark is laid in an open cell")
	check(not maker.lay(Vector2i(10, 10), MadeRoom.ROCK), "and laying what is there already changes nothing")
	check(not maker.lay(Vector2i(-3, 10), MadeRoom.ROCK), "nor does laying off the plan")
	check(maker.lay_line(Vector2i(10, 10), Vector2i(16, 10), MadeRoom.ROCK), "a line is laid cell by cell")
	check(maker.cells_marked(MadeRoom.ROCK).has(Vector2i(13, 10)) and maker.mark_at(Vector2i(17, 10)) == MadeRoom.OPEN,
		"from its first cell to its last and no further")
	check(maker.unsaved, "and the map has something to save")
	maker.begin_stroke()
	maker.lay_box(Vector2i(20, 8), Vector2i(22, 9), MadeRoom.ROCK)
	check(maker.mark_at(Vector2i(21, 9)) == MadeRoom.ROCK and maker.mark_at(Vector2i(23, 9)) == MadeRoom.OPEN,
		"a box is laid corner to corner")
	check(maker.undo() and maker.mark_at(Vector2i(21, 9)) == MadeRoom.OPEN and maker.mark_at(Vector2i(13, 10)) == MadeRoom.ROCK,
		"a step back takes the last stroke and leaves the one before it")
	check(maker.undo() and maker.mark_at(Vector2i(13, 10)) == MadeRoom.OPEN and not maker.can_undo(),
		"and another takes the whole of that one, however many cells it was")
	check(maker.redo() and maker.mark_at(Vector2i(13, 10)) == MadeRoom.ROCK and maker.redo()
			and maker.mark_at(Vector2i(21, 9)) == MadeRoom.ROCK and not maker.can_redo(),
		"what was taken back can be laid again")

	# One of each, for the marks a room holds one of.
	maker.begin_stroke()
	maker.lay(Vector2i(30, 19), MadeRoom.START)
	check(str(maker.cells_marked(MadeRoom.START)) == str([Vector2i(30, 19)]),
		"the start is moved, not laid twice (%s)" % str(maker.cells_marked(MadeRoom.START)))
	maker.lay(Vector2i(8, 19), MadeRoom.BOX)
	maker.lay(Vector2i(12, 3), MadeRoom.BOX)
	check(str(maker.cells_marked(MadeRoom.BOX)) == str([Vector2i(12, 3)]), "and so is the box")
	maker.lay(Vector2i(25, 19), "c")
	maker.lay(Vector2i(27, 19), "c")
	maker.lay(Vector2i(18, 4), "d")
	maker.lay(Vector2i(34, 19), MadeRoom.DIG)
	check(maker.cells_marked("c").size() == 2, "but a monster can be posted as often as it is laid")

	# --- the other two layers -------------------------------------------------------
	maker.begin_stroke()
	check(maker.lay(Vector2i(8, 12), "|", MapMaker.BACK) and maker.mark_at(Vector2i(8, 12)) == MadeRoom.OPEN
			and maker.mark_at(Vector2i(8, 12), MapMaker.BACK) == "|",
		"what stands behind is laid in a layer of its own, and the ground there is as it was")
	check(maker.lay(Vector2i(9, 12), "L", MapMaker.DRESSING) and maker.mark_at(Vector2i(9, 12), MapMaker.DRESSING) == "L"
			and maker.mark_at(Vector2i(9, 12), MapMaker.BACK) == MadeRoom.OPEN,
		"and what is put about it in another")
	check(maker.lay(Vector2i(31, 19), MadeRoom.START, MapMaker.DRESSING) and maker.cells_marked(MadeRoom.START).size() == 1
			and maker.mark_at(Vector2i(30, 19)) == MadeRoom.START,
		"a mark the plan holds one of is held to one in the plan alone")
	maker.lay(Vector2i(31, 19), MadeRoom.OPEN, MapMaker.DRESSING)
	check(maker.mark_at(Vector2i(-1, 5), MapMaker.BACK) == MadeRoom.OPEN and maker.mark_at(Vector2i(5, 99), MapMaker.DRESSING) == MadeRoom.OPEN,
		"off the map neither has anything in it")
	check(maker.undo() and maker.mark_at(Vector2i(8, 12), MapMaker.BACK) == MadeRoom.OPEN
			and maker.mark_at(Vector2i(9, 12), MapMaker.DRESSING) == MadeRoom.OPEN,
		"a stroke across layers is one step to take back")
	check(maker.redo() and maker.mark_at(Vector2i(8, 12), MapMaker.BACK) == "|"
			and maker.mark_at(Vector2i(9, 12), MapMaker.DRESSING) == "L", "and to lay again")
	# Ground of every kind, in a row up by the right wall.
	maker.begin_stroke()
	for kind in ["%", "=", "*", "|"]:
		maker.lay(Vector2i(34 + ["%", "=", "*", "|"].find(kind), 5), kind)
	# And glass, clear and a mirror, beside them — and a pane of each behind,
	# under them.
	maker.lay(Vector2i(32, 5), "o")
	maker.lay(Vector2i(33, 5), "@")
	maker.lay(Vector2i(32, 7), "o", MapMaker.BACK)
	maker.lay(Vector2i(33, 7), "@", MapMaker.BACK)
	check(maker.mark_at(Vector2i(35, 5)) == "=" and maker.mark_at(Vector2i(37, 5)) == "|"
			and maker.mark_at(Vector2i(32, 5)) == "o" and maker.mark_at(Vector2i(33, 5)) == "@",
		"every kind of ground is laid the same way, glass too")
	check(maker.mark_at(Vector2i(33, 7), MapMaker.BACK) == "@" and maker.mark_at(Vector2i(33, 7)) == MadeRoom.OPEN,
		"and glass behind is laid behind, the ground there as it was")
	# Another tileset, and back.
	maker.set_tileset("rock")
	check(maker.tileset == "rock" and maker.unsaved, "the map can be drawn in another tileset")
	check(maker.undo() and maker.tileset == MapMaker.NEW_TILESET and maker.mark_at(Vector2i(35, 5)) == "=",
		"and that is a step to take back like any other")

	# --- growing and cutting ------------------------------------------------------
	check(maker.resize(Vector2i(Room.W + 6, Room.H + 3)) and maker.cols == Room.W + 6 and maker.rows == Room.H + 3,
		"a map grows to its right and under it")
	check(maker.mark_at(Vector2i(Room.W + 5, 5)) == MadeRoom.OPEN and maker.mark_at(Vector2i(5, Room.H + 2)) == MadeRoom.OPEN,
		"with open cells")
	check(maker.plan().size() == maker.rows and maker.plan()[0].length() == maker.cols
			and maker.plan()[maker.rows - 1].length() == maker.cols, "and every row the same length")
	check(maker.back().size() == maker.rows and maker.back()[maker.rows - 1].length() == maker.cols
			and maker.dressing().size() == maker.rows and maker.dressing()[0].length() == maker.cols
			and maker.mark_at(Vector2i(8, 12), MapMaker.BACK) == "|",
		"in every layer, and what was in them stays")
	check(maker.resize(Vector2i(2, 2)) and maker.cols == MapMaker.MIN_SIZE.x and maker.rows == MapMaker.MIN_SIZE.y
			and MapMaker.MIN_SIZE.x < Room.W and MapMaker.MIN_SIZE.y < Room.H,
		"it can be cut smaller than a screen, but no smaller than the least a map may be (%dx%d)" % [maker.cols, maker.rows])
	check(maker.undo() and maker.cols == Room.W + 6, "and a change of size is a step to take back too")
	maker.resize(Vector2i(9999, 9999))
	check(maker.cols == MapMaker.MAX_SIZE.x and maker.rows == MapMaker.MAX_SIZE.y, "nor grown past the most a map may be")
	maker.resize(Vector2i(Room.W + 6, Room.H))
	# Grown at its left and its top: what is on it moves along with them.
	check(maker.resize(Vector2i(maker.cols + 3, maker.rows + 2), Vector2i(3, 2)) and maker.cols == Room.W + 9 and maker.rows == Room.H + 2
			and maker.mark_at(Vector2i(11, 14), MapMaker.BACK) == "|" and maker.mark_at(Vector2i(38, 7)) == "="
			and maker.mark_at(Vector2i(1, 1)) == MadeRoom.OPEN and maker.mark_at(Vector2i(1, 1), MapMaker.BACK) == MadeRoom.OPEN,
		"a map grows at its left and its top too, with open cells there and what was on it moved over")
	check(maker.resize(Vector2i(maker.cols - 3, maker.rows - 2), Vector2i(-3, -2)) and maker.cols == Room.W + 6 and maker.rows == Room.H
			and maker.mark_at(Vector2i(8, 12), MapMaker.BACK) == "|" and maker.mark_at(Vector2i(35, 5)) == "=",
		"and is cut there, what was on it moved back")

	# --- keeping it -----------------------------------------------------------------
	check(Maps.id_for("  Ice Keep!! ") == "ice_keep" and Maps.id_for("a--b  c") == "a_b_c" and Maps.id_for("...") == ""
			and Maps.id_for("얼음") == "", "a name is filed in lower case, a word at a time, or not at all")
	check(maker.save_as("   ") == "name" and Maps.ids().is_empty(), "a map with no name to file it under is not kept")
	var laid := maker.plan()
	check(maker.save_as("Test Keep") == "" and maker.map_id == "test_keep" and not maker.unsaved,
		"SAVE keeps it under its name")
	var path := Maps.path_of("test_keep")
	check(path == SCRATCH.path_join("test_keep.tscn") and FileAccess.file_exists(path), "as a scene of its own (%s)" % path)
	check(Maps.ids() == PackedStringArray(["test_keep"]) and Maps.exists("test_keep") and not Maps.exists("nowhere"),
		"which the list of maps finds")
	var text := FileAccess.get_file_as_string(path)
	check(text.begins_with("[gd_scene") and text.contains("res://feature/world/made_room.gd") and text.contains("plan = PackedStringArray("),
		"a text scene, of one node, carrying its rows of cells")
	check(text.contains("back = PackedStringArray(") and text.contains("dressing = PackedStringArray(")
			and text.contains('tileset = "%s"' % MapMaker.NEW_TILESET),
		"in all three layers, and the tileset it is drawn in")

	# Picked up the way anything in Godot picks a scene up.
	var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	check(scene != null and scene.get_state().get_node_count() == 1, "Godot loads it as a scene of one node")
	var picked := scene.instantiate() if scene != null else null
	check(picked is MadeRoom and (picked as MadeRoom).plan == laid and picked.name == "TestKeep",
		"and instancing it is the room that was laid, named for the map")
	check(picked is MadeRoom and (picked as MadeRoom).back == maker.back() and (picked as MadeRoom).dressing == maker.dressing()
			and (picked as MadeRoom).tileset == MapMaker.NEW_TILESET and (picked as MadeRoom).back_at(8, 12) == "|"
			and (picked as MadeRoom).dressing_at(9, 12) == "L" and (picked as MadeRoom).dressing_at(-1, 0) == MadeRoom.OPEN,
		"what stands behind it, what is put about it and its tileset with it")
	if picked != null:
		var made := picked as MadeRoom
		check(made.cols == Room.W + 6 and made.rows == Room.H and made.cells_marked("c").size() == 2,
			"which knows its size and its marks before it is stood")
		picked.free()

	# Saved over, it is the new one that comes back.
	maker.begin_stroke()
	maker.lay(Vector2i(3, 3), MadeRoom.ROCK)
	maker.set_region(2)
	check(maker.unsaved and maker.save_as("test keep") == "", "a map changed and saved again goes over the old one")
	var again := Maps.load_room("test_keep")
	check(again != null and again.mark_at(3, 3) == MadeRoom.ROCK and again.region == 2,
		"and what is read back is what was saved last")
	if again != null:
		again.free()

	# Another map, and back to the first.
	maker.new_map()
	check(maker.cols == Room.W and maker.map_id == "" and not maker.unsaved and maker.cells_marked("c").is_empty(),
		"NEW clears the table")
	check(maker.save_as("other") == "" and Maps.ids() == PackedStringArray(["other", "test_keep"]), "a second map is kept beside the first")
	check(maker.open("test_keep") and maker.cols == Room.W + 6 and maker.region == 2 and maker.cells_marked("c").size() == 2
			and maker.map_id == "test_keep" and not maker.unsaved and maker.mark_at(Vector2i(8, 12), MapMaker.BACK) == "|"
			and maker.mark_at(Vector2i(9, 12), MapMaker.DRESSING) == "L" and maker.tileset == MapMaker.NEW_TILESET,
		"LOAD puts a kept map back on the table as it was saved, every layer of it")
	check(maker.undo() and maker.cols == Room.W and maker.map_id == "other" and maker.cells_marked("c").is_empty(),
		"and a step back is the map that was on the table before, under its own name")
	check(maker.redo() and maker.cols == Room.W + 6 and maker.map_id == "test_keep", "and a step forward the one that was loaded")
	check(not maker.open("nowhere") and maker.map_id == "test_keep", "and a map that is not there leaves the table alone")
	check(Maps.remove("other") == OK and Maps.ids() == PackedStringArray(["test_keep"]), "a map thrown away is gone from the list")

	# --- playing it -------------------------------------------------------------------
	var changes: Array = []
	maker.playing_changed.connect(func(on: bool) -> void: changes.append(on))
	maker.play()
	await frames(3)
	await physics(3)
	var room := maker.room
	check(maker.playing and changes == [true] and room != null and maker.player != null, "PLAY stands the map up with a body in it")
	check(room.cols == maker.cols and room.rows == maker.rows and room.is_solid(3, 3) and not room.is_solid(5, 5)
			and int(room.data.get("region", -1)) == 2,
		"the room is the plan, cell for cell, in its region's rock")
	check(room.is_solid(34, 5) and room.is_solid(35, 5) and room.is_solid(36, 5) and room.is_solid(37, 5)
			and room.is_solid(32, 5) and room.is_solid(33, 5)
			and room.is_solid(0, 8) and room.is_solid(8, 0) and room.is_solid(8, Room.H - 1),
		"solid wherever there is ground of any kind: earth, planks, leaves, bark, and glass of either kind")
	check(not room.is_solid(32, 7) and not room.is_solid(33, 7) and room.back_at(32, 7) == "o" and room.back_at(33, 7) == "@",
		"glass behind the ground is no ground: only there for the picture")
	check(not room.is_solid(8, 12) and not room.is_solid(9, 12) and room.back_at(8, 12) == "|"
			and room.dressing_at(9, 12) == "L" and room.tileset == MapMaker.NEW_TILESET,
		"and what stands behind and what is put about it are no ground at all, only there for the picture")
	var start := maker.cells_marked(MadeRoom.START)[0]
	var p := maker.player
	check(absf(p.global_position.x - (start.x + 0.5) * Room.CELL) < 1.0
			and absf(p.global_position.y - ((start.y + 1) * Room.CELL - Player.BODY.y * 0.5)) < 4.0,
		"the body stands in the start (%s, cell %s)" % [str(p.global_position), str(start)])
	check(p.weapons.size() == mini(Player.MAX_WEAPONS, Weapons.ids().size()) and p.weapon_id == maker.current_weapon(),
		"carrying a kit's worth off the rack, the map's weapon in hand (%s)" % str(p.weapons))
	check(p.runner.board == maker.graphs[p.weapon_id] and p.runner.board != GameState.weapon_board(p.weapon_id),
		"on a copy of the profile's graph, as on the bench")
	var found := monsters()
	var kinds: Array = found.map(func(e: Enemy) -> String: return e.kind)
	kinds.sort()
	check(kinds == ["CRAWLER", "CRAWLER", "DRIFTER"], "every monster posted is in it (%s)" % str(kinds))
	var posted := Vector2.ZERO
	for rec: Dictionary in room.data["enemies"]:
		if String(rec["kind"]) == "DRIFTER":
			posted = Vector2(float(rec["pos"][0]), float(rec["pos"][1]))
	check(posted.is_equal_approx(Vector2(18.5, 4.5) * Room.CELL),
		"the one that flies posted in the middle of its cell (%s)" % str(posted))
	# Laid at (12, 3), over the ledge the line above put along row 10.
	check(room.box != null and room.box.position.is_equal_approx(Vector2(12.5, 9.5) * Room.CELL)
			and not room.box.contents.is_empty(),
		"the box laid in the air stands on the ledge under it, with something in it (%s)" % str(room.box.position if room.box != null else Vector2.ZERO))
	check(room.digs.size() == 1 and not room.digs[0].is_dug(), "and the ground to dig is there to dig")
	check(room.box.player == p and room.digs[0].player == p, "both answering to the body in the room")

	# Shut in on every side, whatever the outermost cells hold: the cells the
	# resize added on the right are open, and nothing walks out through them.
	check(not room.is_solid(room.cols - 1, 10), "the map's own edge is open on the right, where it grew")
	p.global_position = Vector2((room.cols - 0.5) * Room.CELL, (Room.H - 3 + 0.5) * Room.CELL)
	p.velocity = Vector2(900.0, 0.0)
	for i in 40:
		p.velocity.x = 900.0
		await get_tree().physics_frame
	check(p.global_position.x < room.cols * Room.CELL and not room.out_of_bounds(p.global_position),
		"and a body run at it stops at the rock past the edge (x %.0f of %d)" % [p.global_position.x, room.cols * Room.CELL])

	# The body falls: the floor is set again as it was laid.
	var resets: Array = []
	maker.floor_reset.connect(func() -> void: resets.append(true))
	var first_room := maker.room
	for e in monsters():
		if (e as Enemy).kind == "CRAWLER":
			(e as Enemy).apply_damage(99999.0)
	await frames(2)
	check(monsters().size() == 1, "a monster cut down stays down while the map is played")
	p.invuln = 0.0
	p.apply_damage(99999.0)
	await frames(2)
	check(maker.reset_in > 0.0 and resets.is_empty() and maker.player == null,
		"a fallen body is let go of, and the floor waits a moment")
	maker.reset_in = 0.01
	await frames(4)
	check(resets.size() == 1 and maker.room != first_room and maker.player != null and is_instance_valid(maker.player)
			and not maker.player.dead and monsters().size() == 3,
		"then the floor is set again: a fresh body, and every monster back at its post")
	maker.reset_floor()
	await frames(2)
	check(resets.size() == 2 and monsters().size() == 3, "R sets it again at once")

	# The assembly board over it holds the body still, and only over a played map.
	maker.set_editing(true)
	check(maker.editing and maker.player.input_locked, "the board over a played map holds the body still")
	maker.set_editing(false)
	check(not maker.editing and not maker.player.input_locked, "and lets it go again")

	# Back to laying.
	var was := maker.plan()
	maker.stop()
	await frames(2)
	check(not maker.playing and changes == [true, false] and maker.room == null and maker.player == null
			and get_tree().get_nodes_in_group("player").is_empty(),
		"leaving play strikes the room and the body with it")
	check(maker.plan() == was and maker.mark_at(Vector2i(3, 3)) == MadeRoom.ROCK, "and the plan is as it was laid")
	maker.set_editing(true)
	check(not maker.editing, "there is no board to open over a map being laid")

	# A map with no start still has somewhere to stand.
	maker.begin_stroke()
	maker.lay(maker.cells_marked(MadeRoom.START)[0], MadeRoom.OPEN)
	maker.play()
	await frames(2)
	var at := maker.player.global_position
	check(not maker.room.is_solid_at(at) and maker.room.is_solid_at(at + Vector2(0, Room.CELL)),
		"with no start laid, the body stands on the floor nearest the middle (%s)" % str(at))
	maker.stop()

	# --- kept between visits ----------------------------------------------------------
	maker.begin_stroke()
	maker.lay(Vector2i(6, 6), MadeRoom.ROCK)
	var left := maker.plan()
	maker.queue_free()
	await frames(2)
	maker = MapMaker.new()
	add_child(maker)
	await frames(2)
	check(maker.plan() == left and maker.unsaved and maker.map_id == "test_keep",
		"the map on the table is still there when the creator is come back to, unsaved as it was")
	maker.queue_free()
	await frames(2)
	MapMaker.forget()
	maker = MapMaker.new()
	add_child(maker)
	await frames(2)
	check(maker.plan() != left and maker.map_id == "", "and forgotten, the next visit starts on a new one")

	maker.queue_free()
	await frames(2)
	_sweep()
	Maps.scratch_dir = ""
	MapMaker.forget()
	print("[MAPS] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Empties the scratch folder, and takes it away.
func _sweep() -> void:
	if not DirAccess.dir_exists_absolute(SCRATCH):
		return
	for file in DirAccess.get_files_at(SCRATCH):
		DirAccess.remove_absolute(SCRATCH.path_join(file))
	DirAccess.remove_absolute(SCRATCH)
