extends Node2D
## The story maker's rules: a conversation is written a line at a time — who
## says it, and what — put in, changed, moved and taken away; kept as a plain
## file and read back; handed to a character in the shape the database's
## conversations come in, and to a scene; and played on a map stood up empty,
## in each of its three ways: in the box with the player held still, free in
## bubbles with the player's hands their own, and as a novel read a press at a
## time with nobody playing.
##
## No renderer needed: nothing here draws. Stories, and the map they are
## played on, are kept in scratch folders for the length of the test, never
## in the project's own.

const SCRATCH := "user://story_maker_test"
const MAPS := "user://story_maker_test_maps"

var fails := 0
var maker: StoryMaker

func check(ok: bool, what: String) -> void:
	if ok:
		print("[STORY] PASS ", what)
	else:
		fails += 1
		push_error("STORY FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## A press the way a player makes one: a synthetic press only reads as
## just-pressed on the physics frame after it.
func press(action: String = "interact") -> void:
	Input.action_press(action)
	await physics(2)
	Input.action_release(action)
	await physics(1)

func until(cond: Callable, limit: int = 300) -> bool:
	for i in limit:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())

## Waits for the line in the box to finish typing by itself.
func listen(n: Npc) -> void:
	await until(func() -> bool: return not n.is_talking() or n.line_finished(), 600)

## A map to play on: the clearing a new map is, with a monster posted in it,
## a box and ground to dig, to show a story leaves them out.
func stage() -> MadeRoom:
	var r := MadeRoom.new()
	var plan := PackedStringArray()
	for y in Room.H:
		if y == 0:
			plan.append("*".repeat(Room.W))
		elif y >= Room.H - 2:
			plan.append("%".repeat(Room.W))
		else:
			plan.append("|" + MadeRoom.OPEN.repeat(Room.W - 2) + "|")
	var floor_row := plan[Room.H - 3]
	for mark: Array in [[4, MadeRoom.START], [10, MadeRoom.BOX], [14, MadeRoom.DIG], [20, "c"]]:
		floor_row = floor_row.left(int(mark[0])) + String(mark[1]) + floor_row.substr(int(mark[0]) + 1)
	plan[Room.H - 3] = floor_row
	r.plan = plan
	r.tileset = "grove"
	return r

func enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")

func _ready() -> void:
	Stories.scratch_dir = SCRATCH
	Maps.scratch_dir = MAPS
	_sweep(SCRATCH)
	_sweep(MAPS)
	StoryMaker.forget()
	var laid := stage()
	check(Maps.save("stage", laid) == OK and Maps.ids() == PackedStringArray(["stage"]), "a map to play on is kept in the scratch folder")
	laid.free()
	maker = StoryMaker.new()
	add_child(maker)
	await frames(2)

	# --- a new story --------------------------------------------------------
	check(maker.lines.is_empty() and maker.story_id == "" and not maker.unsaved and maker.mode == StoryMaker.NEW_MODE,
		"a new story has no lines, no name, nothing to save, and plays in the box")
	check(maker.npc_name == StoryMaker.NEW_NAME and maker.sprite == StoryMaker.NEW_SPRITE
			and maker.player_name == StoryMaker.NEW_PLAYER_NAME,
		"with the bench's own character in it, to start from")
	check(maker.map_id == "" and maker.map_to_play() == "stage", "set on whichever map there is (%s)" % maker.map_to_play())
	check(maker.play() == "empty" and not maker.playing, "and with nothing to say it cannot be played, and says why")

	# --- writing it ---------------------------------------------------------
	check(maker.add_line("Ah, a new face.") == 0 and maker.line_count() == 1 and maker.speaker_of(0) == StoryMaker.NPC and maker.unsaved,
		"the first line put in is the character's, and the story has something to save")
	check(maker.add_line("Who are you?") == 1 and maker.speaker_of(1) == StoryMaker.PLAYER,
		"and the next the player's, turn and turn about")
	check(maker.add_line("", StoryMaker.NPC) == 2 and maker.speaker_of(2) == StoryMaker.NPC,
		"unless the line says whose it is")
	check(maker.set_text(2, "I tinker.") and maker.text_of(2) == "I tinker." and not maker.set_text(9, "x"),
		"a line's words are changed where it stands, and nowhere else")
	check(maker.toggle_speaker(1) and maker.speaker_of(1) == StoryMaker.NPC
			and maker.toggle_speaker(1) and maker.speaker_of(1) == StoryMaker.PLAYER,
		"a line is given to the other of the two, and back")
	check(not maker.set_speaker(1, "cat"), "and to nobody else")
	check(maker.add_line("Nothing you break stays broken.", StoryMaker.NPC, 0) == 1
			and maker.text_of(1) == "Nothing you break stays broken." and maker.text_of(2) == "Who are you?",
		"a line is put in after any other")
	check(maker.move_line(3, -1) and maker.text_of(2) == "I tinker." and maker.text_of(3) == "Who are you?",
		"and moved up a place")
	check(not maker.move_line(0, -1) and not maker.move_line(3, 1) and not maker.move_line(1, 0),
		"but not off either end, nor nowhere")
	check(maker.remove_line(1) and maker.line_count() == 3 and maker.text_of(1) == "I tinker." and not maker.remove_line(7),
		"and taken away")
	maker.add_line("   ")
	check(maker.line_count() == 4 and maker.said().size() == 3,
		"a line with nothing in it yet is kept on the desk and never said")
	maker.remove_line(3)

	# --- what the character and the scene are handed ------------------------
	var def := maker.character()
	var nodes: Dictionary = def["nodes"]
	var rules: Dictionary = def["rules"]
	check(String(def["id"]) == StoryMaker.CHARACTER and String(def["name"]) == StoryMaker.NEW_NAME
			and String(def["sprite"]) == StoryMaker.NEW_SPRITE and String(def["player_name"]) == StoryMaker.NEW_PLAYER_NAME
			and String(def["start"]) == "1" and nodes.size() == 3,
		"the character is handed the story as the database hands a conversation: a line each, from the start")
	check(String(nodes["1"]["next"]) == "2" and String(nodes["2"]["next"]) == "3" and not nodes["3"].has("next")
			and String(nodes["3"]["speaker"]) == StoryMaker.PLAYER and String(nodes["3"]["text"]) == "Who are you?",
		"each line leading to the next and the last to nothing, said by whoever says it")
	check(int(nodes["1"]["speed"]) == StoryMaker.LINE_SPEED and String(nodes["1"]["emotion"]) == StoryMaker.LINE_EMOTION
			and String(nodes["1"]["voice"]) == StoryMaker.LINE_VOICE,
		"each saying what a line in the database would where it does not say itself")
	check(String(rules["1"]["listens"]) == FreeTalk.TALK and not rules["2"].has("listens")
			and String(rules["2"]["next"]) == "3" and int(rules["1"]["once"]) == 0,
		"and free, the first answering a press and each leading on, never spent")
	check(Dialogue.problems_in(def).is_empty(), "which the conversations' own checker passes (%s)" % str(Dialogue.problems_in(def)))
	(maker.lines[0] as Dictionary)["emotion"] = "happy"
	check(String(maker.character()["nodes"]["1"]["emotion"]) == "happy", "whatever else a line was given goes with it")
	(maker.lines[0] as Dictionary).erase("emotion")
	var scene := maker.scene_script(Vector2(300, 400), Vector2(200, 400), 414.0)
	check((scene["beats"] as Array).size() == 3 and String(scene["beats"][2]["say"]) == StoryMaker.PLAYER
			and String(scene["beats"][2]["text"]) == "Who are you?" and String(scene["beats"][0]["do"][0]["fade"]) == "in",
		"a novel is a beat a line, coming up out of black")
	check(String(scene["cast"]["npc"]["facing"]) == "left" and String(scene["cast"]["player"]["facing"]) == "right"
			and String(scene["cast"]["player"]["sprite"]) == StoryMaker.PLAYER_SPRITE and CutsceneScript.problems_in(scene).is_empty(),
		"with the two of them cast facing each other, and the scenes' own checker passes it (%s)" % str(CutsceneScript.problems_in(scene)))
	check(maker.problems().is_empty(), "the story reads clean")
	check(StoryMaker.problems_in({"lines": []}).has("no lines")
			and StoryMaker.problems_in({"mode": "opera", "lines": ["Hi."]}).size() == 1
			and StoryMaker.problems_in({"lines": [{"speaker": "cat", "text": "Meow."}]}).size() == 1
			and StoryMaker.problems_in({"lines": [7]}).size() == 2,
		"and the checker catches nothing to say, a way of playing that is none, a line said by nobody, and a line that is not one")

	# --- the ways of playing --------------------------------------------------
	check(maker.set_mode_id("novel") and maker.mode == StoryMaker.Mode.NOVEL and maker.mode_id() == "novel"
			and not maker.set_mode_id("opera") and maker.mode == StoryMaker.Mode.NOVEL,
		"the way it is played is set by its id, and an id that is none is refused")
	maker.set_mode(StoryMaker.Mode.FROZEN)

	# --- keeping it -------------------------------------------------------------
	check(Stories.id_for(" First Meeting! ") == "first_meeting" and Stories.id_for("...") == "",
		"a story's name is filed the way a map's is")
	check(maker.save_as("   ") == "name" and Stories.ids().is_empty(), "a story with no name to file it under is not kept")
	check(maker.save_as("Test Story") == "" and maker.story_id == "test_story" and not maker.unsaved,
		"SAVE keeps it under its name")
	var path := Stories.path_of("test_story")
	check(path == SCRATCH.path_join("test_story.json") and FileAccess.file_exists(path), "as a file of its own (%s)" % path)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(parsed is Dictionary and String(parsed["mode"]) == "frozen" and String(parsed["name"]) == StoryMaker.NEW_NAME
			and (parsed["lines"] as Array).size() == 3 and String(parsed["lines"][0]["speaker"]) == "npc"
			and String(parsed["lines"][0]["text"]) == "Ah, a new face." and not parsed.has("spot"),
		"plain JSON: the map, the way it plays, who is in it, and the lines, each who says it and what")
	check(Stories.ids() == PackedStringArray(["test_story"]) and Stories.exists("test_story") and not Stories.exists("nowhere"),
		"which the list of stories finds")
	maker.set_text(0, "Ah. A new face.")
	maker.set_map("stage")
	maker.set_spot(Vector2i(12, Room.H - 3))
	check(maker.unsaved and maker.save_as("test story") == "", "a story changed and saved again goes over the old one")
	var again := Stories.load_story("test_story")
	check(String(again["lines"][0]["text"]) == "Ah. A new face." and String(again["map"]) == "stage"
			and int(again["spot"][0]) == 12 and int(again["spot"][1]) == Room.H - 3,
		"and what is read back is what was saved last, the map and the character's spot with it")
	maker.new_story()
	check(maker.lines.is_empty() and maker.story_id == "" and not maker.unsaved and maker.spot == Vector2i(-1, -1),
		"NEW clears the desk")
	check(maker.save_as("other") == "" and Stories.ids() == PackedStringArray(["other", "test_story"]),
		"a second story is kept beside the first")
	check(maker.open("test_story") and maker.line_count() == 3 and maker.story_id == "test_story" and maker.map_id == "stage"
			and maker.spot == Vector2i(12, Room.H - 3) and not maker.unsaved,
		"LOAD puts a kept story back on the desk as it was saved")
	check(not maker.open("nowhere") and maker.story_id == "test_story", "and a story that is not there leaves the desk alone")
	check(Stories.remove("other") == OK and Stories.ids() == PackedStringArray(["test_story"]), "a story thrown away is gone from the list")
	var hand := FileAccess.open(SCRATCH.path_join("by_hand.json"), FileAccess.WRITE)
	hand.store_string('{"lines": ["One.", {"speaker": "player", "text": "Two."}, "  "], "mode": "opera"}')
	hand.close()
	check(maker.open("by_hand") and maker.line_count() == 3 and maker.speaker_of(0) == StoryMaker.NPC and maker.text_of(0) == "One."
			and maker.speaker_of(1) == StoryMaker.PLAYER and maker.said().size() == 2 and maker.mode == StoryMaker.NEW_MODE
			and maker.npc_name == StoryMaker.NEW_NAME and maker.map_to_play() == "stage",
		"a file written by hand is squared off: a bare line is the character's, and what it leaves out is the new story's")
	Stories.remove("by_hand")
	maker.open("test_story")

	# --- played in the box ------------------------------------------------------
	var changes: Array = []
	maker.playing_changed.connect(func(on: bool) -> void: changes.append(on))
	check(maker.play() == "" and maker.playing and changes == [true], "PLAY stands the map up")
	await frames(2)
	await physics(6)
	var room := maker.room
	check(room != null and room.cols == Room.W and room.rows == Room.H and room.is_solid(5, Room.H - 2) and not room.is_solid(5, 5),
		"the map laid, cell for cell")
	check(enemies().is_empty() and room.box == null and room.digs.is_empty(),
		"and stood empty: nobody at the post, no box, nothing to dig")
	check(maker.player != null and maker.npc != null and maker.scene == null, "with a body in it and the character on it, and no scene")
	var n := maker.npc
	check(n.mode == Npc.Mode.FREEZE and n.npc_id == StoryMaker.CHARACTER and n.display_name == StoryMaker.NEW_NAME
			and n.nodes.size() == 3 and n.start == "1" and n.is_in_group("npcs") and not n.is_in_group("actors"),
		"the character talks in the box, is called what the story calls them, and is no target")
	var p := maker.player
	check(p.weapons.size() == mini(Player.MAX_WEAPONS, Weapons.ids().size()) and p.runner.board == maker.graphs[p.weapon_id]
			and p.runner.board != GameState.weapon_board(p.weapon_id),
		"the body carries a kit's worth, on copies of the profile's graphs")
	var start := room.spawn_point()
	check(p.global_position.distance_to(start) < 4.0 and n.is_on_floor()
			and n.global_position.is_equal_approx(room.stand_point(Vector2i(12, Room.H - 3), Npc.BODY.y * 0.5)),
		"the body stands at the start and the character in the story's spot, on the floor (%s)" % str(n.global_position))
	check(p.global_position.distance_to(n.global_position) > Npc.TALK_RANGE and not n.in_range,
		"out of talking range of each other")
	# Up close, a press walks the player over and opens the box.
	p.global_position = n.global_position + Vector2(-50.0, 0.0)
	await physics(2)
	check(n.in_range and not n.is_talking(), "walked up, the player is in range and nothing has been said")
	await press()
	var opened := await until(func() -> bool: return n.is_talking())
	check(opened and n.node_id == "1" and p.controls_locked(),
		"a press up close starts the story in the box, and holds the player")
	check(n.current_line() == "Ah. A new face." and n.speaker() == StoryMaker.NPC and n.speaker_name() == StoryMaker.NEW_NAME,
		"on its first line, said by the character")
	await listen(n)
	await press()
	check(n.node_id == "2" and n.current_line() == "I tinker.", "and a press on a line read moves to the next")
	await listen(n)
	await press()
	check(n.node_id == "3" and n.speaker() == StoryMaker.PLAYER and n.speaker_name() == StoryMaker.NEW_PLAYER_NAME,
		"the player's line is the player's, under the name the story gives them")
	await listen(n)
	await press()
	await physics(2)
	check(not n.is_talking() and not p.controls_locked(), "and past the last line the conversation ends and lets the player go")
	maker.stop()
	await frames(2)
	check(not maker.playing and changes == [true, false] and maker.room == null and maker.player == null and maker.npc == null
			and get_tree().get_nodes_in_group("player").is_empty() and get_tree().get_nodes_in_group("npcs").is_empty(),
		"leaving play strikes the map, the body and the character")
	check(maker.line_count() == 3 and maker.text_of(0) == "Ah. A new face.", "and the story is as it was")

	# --- played free --------------------------------------------------------------
	maker.set_mode(StoryMaker.Mode.FREE)
	check(maker.play() == "", "PLAY again, free")
	await frames(2)
	await physics(6)
	n = maker.npc
	p = maker.player
	check(n != null and n.mode == Npc.Mode.FREE and n.free_talk.rules.size() == 3, "the character talks free, with a rule a line")
	p.global_position = n.global_position + Vector2(-50.0, 0.0)
	await physics(2)
	check(n.answers_press(), "and up close a press would get an answer")
	await press()
	check(n.free_talk.is_talking() and n.free_talk.line_id == "1" and not n.is_talking() and not p.controls_locked(),
		"a press starts the story free: in a bubble, with the player's hands their own")
	var went := await until(func() -> bool: return n.free_talk.line_id == "2", 900)
	check(went, "and the next line follows by itself once the first has been read")
	var theirs := await until(func() -> bool: return n.free_talk.line_id == "3", 900)
	check(theirs and n.free_talk.speaker() == StoryMaker.PLAYER and n.free_speaker() == p,
		"the player's line is said over the player")
	var over := await until(func() -> bool: return not n.free_talk.is_talking(), 900)
	check(over, "and the story ends when the last line has been read")
	maker.stop()
	await frames(2)

	# --- played as a novel ----------------------------------------------------------
	maker.set_mode(StoryMaker.Mode.NOVEL)
	check(maker.play() == "", "PLAY again, as a novel")
	await frames(2)
	await physics(6)
	var sc := maker.scene
	check(sc != null and maker.player == null and maker.npc == null and maker.reading(),
		"a novel stands no body and no character to talk to: a scene, being read")
	check(sc.cast.has(StoryMaker.NPC) and sc.cast.has(StoryMaker.PLAYER) and sc.beats.size() == 3 and sc.index == 0
			and sc.speaker_name() == StoryMaker.NEW_NAME and sc.line() == "Ah. A new face.",
		"with the two of them cast, on the first line")
	var who: CutsceneActor = sc.cast[StoryMaker.NPC]
	var you: CutsceneActor = sc.cast[StoryMaker.PLAYER]
	check(not sc.own_floor and sc.get_children().filter(func(c: Node) -> bool: return c is StaticBody2D).is_empty()
			and who.is_on_floor() and you.is_on_floor(),
		"on the map's own floor, with none of the scene's")
	check(who.facing == -1 and you.facing == 1 and who.global_position.x > you.global_position.x,
		"facing each other, the character in the story's spot")
	check(Arena.current() == sc, "the scene is the world while it runs")
	var typed := await until(func() -> bool: return sc.line_finished(), 600)
	check(typed and sc.waiting_for_press(), "a line types itself out and waits to be read")
	sc.press()
	await frames(1)
	check(sc.index == 1 and sc.line() == "I tinker.", "a press a line")
	sc.press()
	sc.press()
	await frames(1)
	check(sc.index == 2 and sc.speaker_name() == StoryMaker.NEW_PLAYER_NAME, "the player's under the player's name")
	sc.press()
	sc.press()
	await frames(3)
	check(not maker.playing and maker.scene == null and Arena.current() == maker and changes.size() == 6,
		"and past the last line the novel is over, the desk is back, and the world is its own again")
	check(maker.play() == "" and maker.reading(), "read again")
	await frames(2)
	maker.scene.skip()
	await frames(3)
	check(not maker.playing and maker.scene == null, "and skipped, it is over at once")
	# A story with a spot the map has no room in puts the character along the
	# floor from the start instead.
	maker.set_spot(Vector2i(3, 3))
	maker.set_mode(StoryMaker.Mode.FROZEN)
	maker.play()
	await frames(2)
	await physics(4)
	var along := maker.room.stand_point(Vector2i(4 + StoryMaker.APART, Room.H - 3), Npc.BODY.y * 0.5)
	check(maker.npc.global_position.is_equal_approx(along),
		"with no room to stand where the story says, the character stands along the floor from the start (%s)" % str(maker.npc.global_position))
	maker.stop()
	await frames(2)
	# And with no map kept anywhere, nothing to play it on.
	Maps.scratch_dir = MAPS + "_none"
	check(maker.map_to_play() == "" and maker.play() == "map" and not maker.playing,
		"with no map kept anywhere there is nothing to play it on, and PLAY says so")
	Maps.scratch_dir = MAPS

	# --- kept between visits -----------------------------------------------------------
	maker.add_line("One more.")
	var left: Array = maker.lines.duplicate(true)
	maker.queue_free()
	await frames(2)
	maker = StoryMaker.new()
	add_child(maker)
	await frames(2)
	check(maker.lines == left and maker.unsaved and maker.story_id == "test_story" and maker.map_id == "stage",
		"the story on the desk is still there when the maker is come back to, unsaved as it was")
	maker.queue_free()
	await frames(2)
	StoryMaker.forget()
	maker = StoryMaker.new()
	add_child(maker)
	await frames(2)
	check(maker.lines.is_empty() and maker.story_id == "", "and forgotten, the next visit starts on a new one")
	maker.queue_free()
	await frames(2)

	# --- the stories the game ships with --------------------------------------------------
	Stories.scratch_dir = ""
	var shipped := Stories.ids()
	check(shipped.has("first_meeting"), "there is a first_meeting to start from (%s)" % str(shipped))
	for id in shipped:
		var found := StoryMaker.problems_in(Stories.load_story(id))
		check(found.is_empty(), "%s.json reads clean%s" % [id, "" if found.is_empty() else " — " + "; ".join(found)])

	_sweep(SCRATCH)
	_sweep(MAPS)
	Maps.scratch_dir = ""
	StoryMaker.forget()
	print("[STORY] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Empties a scratch folder, and takes it away.
func _sweep(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
