extends Node
## The story maker's screen, worked the way a person works it: in from the
## title, lines typed at the desk and moved about, who says each pressed into
## the other, a way of playing picked, a map imported, saved under a name,
## found again in the list, played each of the three ways and come back from.
##
## What the maker's rules do is `tests/story/story_maker_test`. This is the
## desk over them — that every press gets to the rule it is for, that the
## whole of it fits the screen in both languages and both modes, and that the
## ways out of it land where they say.
##
## Stories, and the map they are played on, are kept in scratch folders for
## the length of the test, never in the project's own. No pixels are read.

const GameScript := preload("res://app/game.gd")
const SCRATCH := "user://story_desk_test"
const MAPS := "user://story_desk_test_maps"

var fails := 0
var game: Node
var maker: StoryMaker
var view: StoryMakerView
var desk: StoryDesk

func check(ok: bool, what: String) -> void:
	if ok:
		print("[DESK] PASS ", what)
	else:
		fails += 1
		push_error("DESK FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func on_glass(at: Vector2) -> Vector2:
	return get_window().get_final_transform() * at

func move(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = on_glass(at)
	m.global_position = m.position
	Input.parse_input_event(m)
	await frames(2)

func press(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = on_glass(at)
	e.global_position = e.position
	Input.parse_input_event(e)
	await frames(2)

## A press and a let-go on one spot.
func click(at: Vector2) -> void:
	await move(at)
	await press(at, true)
	await press(at, false)

func click_on(c: Control) -> void:
	await click(c.get_global_rect().get_center())

## A key, pressed and let go, with the letter it types.
func key(code: Key, letter: String = "") -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		if letter != "":
			e.unicode = letter.unicode_at(0)
		Input.parse_input_event(e)
		await frames(1)

## Types `text` the way a keyboard does, a letter at a time.
func type_in(text: String) -> void:
	for ch in text:
		var code := KEY_SPACE if ch == " " else (KEY_A + (ch.to_upper().unicode_at(0) - 65) if ch.to_upper() >= "A" and ch.to_upper() <= "Z" else KEY_PERIOD)
		await key(code, ch)

## A key with the platform's own shortcut modifier held.
func shortcut(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		e.command_or_control_autoremap = true
		Input.parse_input_event(e)
		await frames(2)

func action(which: String) -> void:
	var e := InputEventAction.new()
	e.action = which
	e.pressed = true
	Input.parse_input_event(e)
	await frames(3)

func focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()

## The button on the bar that says `words`.
func bar_button(words: String) -> Button:
	return desk._bar.find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return b.text == words).front()

## Every button up over the desk that says `words`.
func popup_buttons(words: String) -> Array:
	if desk._popup == null:
		return []
	return desk._popup.find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return b.text == words)

func row(i: int) -> Dictionary:
	return desk._rows[i]

func screen() -> Vector2:
	return get_viewport().get_visible_rect().size

## A map to play on: the clearing a new map is.
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
	plan[Room.H - 3] = plan[Room.H - 3].left(4) + MadeRoom.START + plan[Room.H - 3].substr(5)
	r.plan = plan
	r.tileset = "grove"
	return r

func _ready() -> void:
	var was_mode := Touch.mode
	var was_language := Loc.language
	Stories.scratch_dir = SCRATCH
	Maps.scratch_dir = MAPS
	_sweep(SCRATCH)
	_sweep(MAPS)
	var laid := stage()
	Maps.save("desk_stage", laid)
	laid.free()
	StoryMaker.forget()
	Touch.set_mode(Touch.OFF)
	Loc.set_language(Loc.DEFAULT)
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	await _the_door()
	await _the_desk()
	await _writing()
	await _settings()
	await _keeping()
	await _playing()
	await _leaving()
	await _both_ways()
	Touch.set_mode(was_mode)
	Loc.set_language(was_language)
	_sweep(SCRATCH)
	_sweep(MAPS)
	Stories.scratch_dir = ""
	Maps.scratch_dir = ""
	StoryMaker.forget()
	print("[DESK] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## STORY MAKER is on the title, under MAP CREATOR, and goes to the desk.
func _the_door() -> void:
	var title := game.current as TitleScreen
	var ids: Array = Menus.items("title").map(func(i: Dictionary) -> String: return String(i["id"]))
	check(ids.find("story_maker") == ids.find("map_maker") + 1, "the title has STORY MAKER, straight under MAP CREATOR (%s)" % str(ids))
	var door: Button = null
	for b in title._menu_root.get_children():
		if (b as Button).text == Loc.t("menu.title.story_maker"):
			door = b
	var foot := title._menu_root.get_global_rect().end.y - title._stage.global_position.y
	check(door != null and title._menu_root.get_child_count() == 6 and foot <= TitleScreen.DESIGN.y,
		"as a line of its own, and the column it makes six of still ends on the design (%.0f of %.0f)" % [foot, TitleScreen.DESIGN.y])
	if door != null:
		door.pressed.emit()
	await frames(8)
	maker = game.current as StoryMaker
	check(game.state == GameScript.State.STORY_MAKER and maker != null, "pressing it goes to the story maker (%s)" % game.current)
	view = Views.of(maker) as StoryMakerView
	desk = view.desk if view != null else null
	check(desk != null and desk.is_visible_in_tree() and not maker.playing, "which opens on its desk, writing")
	check(not view.hud.visible and not view.keys.visible and view.camera == null, "with nothing of a played story's on the screen")

func _the_desk() -> void:
	var s := screen()
	check(desk._bar.position == Vector2.ZERO and is_equal_approx(desk._bar.size.x, s.x),
		"the bar runs across the top of the screen (%s)" % str(desk._bar.get_rect()))
	check(is_equal_approx(desk._side.size.x, StoryDesk.SIDE_W) and is_equal_approx(desk._side.get_rect().end.y, s.y),
		"and the column down the left, under it (%s)" % str(desk._side.get_rect()))
	check(is_equal_approx(desk._sheet.position.x, StoryDesk.SIDE_W) and is_equal_approx(desk._sheet.get_rect().end.y, s.y - StoryDesk.FOOT_H),
		"and the lines have the rest, over the foot (%s)" % str(desk._sheet.get_rect()))
	check(desk._map.text == "DESK_STAGE", "the column says which map the story is set on (%s)" % desk._map.text)
	check(desk._modes.size() == 3 and (desk._modes[StoryMaker.Mode.FROZEN] as Button).disabled
			and not (desk._modes[StoryMaker.Mode.FREE] as Button).disabled,
		"and the three ways of playing it, the box's lit")
	check(desk._npc_name.text == StoryMaker.NEW_NAME and desk._player_name.text == StoryMaker.NEW_PLAYER_NAME
			and desk._sprite.text == StoryMaker.NEW_SPRITE.to_upper(),
		"who the character is, what they look like and what the player is called (%s)" % desk._sprite.text)
	check(desk._rows.is_empty() and desk._add != null and desk._add.is_visible_in_tree(), "no lines yet, and a way to add one")
	check(desk._bar.get_combined_minimum_size().x <= s.x and desk._side.get_combined_minimum_size().x <= StoryDesk.SIDE_W
			and desk._side.get_combined_minimum_size().y <= desk._side.size.y,
		"nothing on it wants more room than it has")

## Lines typed at the desk, and moved about.
func _writing() -> void:
	await click_on(desk._add)
	check(maker.line_count() == 1 and desk._rows.size() == 1 and focus_owner() == row(0)["edit"],
		"ADD puts a line in, and the keyboard on it")
	await type_in("Ah a new face.")
	check(maker.text_of(0) == "Ah a new face." and (row(0)["edit"] as LineEdit).text == maker.text_of(0),
		"what is typed is the line's words, as they are typed (%s)" % maker.text_of(0))
	check((row(0)["who"] as Button).text == StoryMaker.NEW_NAME.to_upper(), "said by the character, by name (%s)" % (row(0)["who"] as Button).text)
	await key(KEY_ENTER)
	await frames(2)
	check(maker.line_count() == 2 and desk._rows.size() == 2 and focus_owner() == row(1)["edit"]
			and maker.speaker_of(1) == StoryMaker.PLAYER and (row(1)["who"] as Button).text == StoryMaker.NEW_PLAYER_NAME.to_upper(),
		"the return key on the last line is a new one after it, the player's, with the keyboard on it")
	await type_in("Who are you.")
	await click_on(row(1)["who"])
	check(maker.speaker_of(1) == StoryMaker.NPC and (row(1)["who"] as Button).text == StoryMaker.NEW_NAME.to_upper(),
		"a press on who says a line gives it to the other")
	await click_on(row(1)["who"])
	check(maker.speaker_of(1) == StoryMaker.PLAYER, "and back")
	await click_on(row(0)["edit"])
	await key(KEY_ENTER)
	await frames(2)
	check(maker.line_count() == 2 and focus_owner() == row(1)["edit"], "the return key on any other line goes on to the next")
	await click_on(row(1)["up"])
	check(maker.text_of(0) == "Who are you." and maker.text_of(1) == "Ah a new face." and focus_owner() == row(0)["edit"],
		"the arrow up moves a line up a place, the keyboard going with it")
	check((row(0)["up"] as Button).disabled and (row(1)["down"] as Button).disabled, "and the first cannot go up, nor the last down")
	await click_on(row(0)["down"])
	check(maker.text_of(0) == "Ah a new face.", "the arrow down moves it back")
	await click_on(row(1)["bin"])
	check(maker.line_count() == 2 and desk._armed == "remove:1" and (row(1)["bin"] as Button).text == Loc.t("hud.story.sure"),
		"the cross on a line only asks, the first time")
	await click_on(row(1)["bin"])
	check(maker.line_count() == 1 and desk._rows.size() == 1 and desk._armed == "", "and takes the line away the second")
	check(maker.unsaved, "and the story has something to save")

## What the story is set on and how it plays, from the column.
func _settings() -> void:
	await click_on(desk._modes[StoryMaker.Mode.NOVEL])
	check(maker.mode == StoryMaker.Mode.NOVEL and (desk._modes[StoryMaker.Mode.NOVEL] as Button).disabled
			and not (desk._modes[StoryMaker.Mode.FROZEN] as Button).disabled,
		"a way of playing is picked with its button, and lit")
	await click_on(desk._modes[StoryMaker.Mode.FROZEN])
	check(maker.mode == StoryMaker.Mode.FROZEN, "and another")
	await click_on(desk._map)
	await frames(2)
	var maps: Array = popup_buttons("DESK_STAGE")
	check(desk._popup != null and maps.size() == 1 and (maps[0] as Button).disabled,
		"MAP puts up the maps the map creator has kept, the one the story is set on lit")
	await action("ui_cancel")
	check(desk._popup == null and not get_tree().paused, "the cancel key puts the list away, and does not pause the desk behind it")
	await click_on(desk._map)
	await frames(2)
	desk._import("desk_stage")
	await frames(2)
	check(maker.map_id == "desk_stage" and desk._popup == null, "a map picked is the story's, and the list goes")
	var was := maker.sprite
	await click_on(desk._sprite)
	check(maker.sprite != was and desk.cast().has(maker.sprite) and desk._sprite.text == maker.sprite.to_upper(),
		"the character's look goes round the cast (%s)" % maker.sprite)
	for i in desk.cast().size() - 1:
		await click_on(desk._sprite)
	check(maker.sprite == was, "and round to where it was")
	desk._npc_name.text = "Tinker"
	desk._npc_name.text_changed.emit("Tinker")
	await frames(1)
	check(maker.npc_name == "Tinker" and (row(0)["who"] as Button).text == "TINKER",
		"the character's name typed in the column is the story's, and the lines say it")
	desk._player_name.text = "You"
	desk._player_name.text_changed.emit("You")
	maker.add_line("And you.")
	desk._fill_rows()
	await frames(1)
	check(maker.player_name == "You" and (row(1)["who"] as Button).text == "YOU", "and so is the player's")

func _keeping() -> void:
	desk._name.text = "   "
	desk._save()
	await frames(2)
	check(maker.unsaved and Stories.ids().is_empty() and desk._said == Loc.t("hud.story.refused.name"),
		"SAVE with no name keeps nothing, and says why (%s)" % desk._said)
	desk._name.text = "Desk Story"
	await shortcut(KEY_S)
	check(not maker.unsaved and Stories.exists("desk_story") and maker.story_id == "desk_story",
		"with a name, the save key keeps the story under it")
	check(desk._name.text == "desk_story" and desk._said.contains(Stories.path_of("desk_story")),
		"the field shows the name it was filed under, and the foot says where (%s)" % desk._said)
	desk._new()
	await frames(2)
	check(maker.line_count() == 0 and maker.story_id == "" and desk._name.text == "" and desk._rows.is_empty()
			and desk._npc_name.text == StoryMaker.NEW_NAME and not maker.unsaved,
		"NEW clears the desk, the name and the character with it")
	desk._name.text = "desk story"
	desk._save()
	await frames(2)
	check((Stories.load_story("desk_story")["lines"] as Array).size() == 2 and desk._armed != "",
		"SAVE under the name of a story kept already only asks, the first time")
	desk._save()
	await frames(2)
	check((Stories.load_story("desk_story")["lines"] as Array).is_empty() and desk._armed == "", "and replaces it the second")
	desk._name.text = "other tale"
	maker.add_line("Once.")
	desk._save()
	await frames(2)
	desk._open_list()
	await frames(3)
	var picks: Array = desk._popup.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	check(desk._popup != null and picks.has("OTHER_TALE") and picks.has("DESK_STORY"),
		"LOAD lists every story that is kept (%s)" % str(picks))
	desk._delete("other_tale")
	await frames(2)
	check(Stories.exists("other_tale") and desk._armed == "delete:other_tale", "DELETE only asks, the first time")
	desk._delete("other_tale")
	await frames(2)
	check(not Stories.exists("other_tale") and Stories.exists("desk_story"), "and throws that story away the second, and no other")
	await action("ui_cancel")
	maker.add_line("Twice.")
	desk._fill_rows()
	desk._name.text = "desk story"
	# Over another story's name: the first press asks, the second replaces.
	desk._save()
	desk._save()
	await frames(2)
	check(maker.story_id == "desk_story" and (Stories.load_story("desk_story")["lines"] as Array).size() == 2,
		"the desk's story saved over the kept one under that name")
	desk._open_list()
	await frames(2)
	desk._load("desk_story")
	await frames(3)
	check(desk._popup == null and maker.story_id == "desk_story" and desk._name.text == "desk_story"
			and maker.line_count() == 2 and desk._rows.size() == 2 and desk._npc_name.text == maker.npc_name,
		"a story picked from the list is put on the desk under its name, and the list goes")

## Each of the three ways, from PLAY, and back from each.
func _playing() -> void:
	maker.set_mode(StoryMaker.Mode.FROZEN)
	bar_button(Loc.t("hud.story.play")).pressed.emit()
	await frames(8)
	check(maker.playing and not desk.is_visible_in_tree() and view.hud.visible and view.keys.visible and view.camera != null,
		"PLAY puts the desk away and a played story's readout up, with a camera")
	check(view.hud.player == maker.player and Pointer.who() == Pointer.Who.HAND,
		"the raid's own HUD over the body in it, and the pointer the player's")
	var who := Views.of(maker.npc) as NpcView
	check(who != null and who.dialogue != null and who.bubble != null and get_tree().get_nodes_in_group("enemies").is_empty(),
		"the character has their view, with the box and the bubble, and nothing else stands in the map")
	var drawn := Views.of(maker.room) as MadeRoomView
	check(drawn != null and drawn.tiles.id() == "grove" and view.pixels.lighting.ambient == MapTiles.of("grove").ambient(),
		"the map drawn in its tileset, in its own light")
	check(game._touch_face() == TouchPad.Face.PLAY, "and the console wears its playing face")
	await action("pause")
	check(not maker.playing and desk.is_visible_in_tree() and not get_tree().paused and not view.hud.visible and view.camera == null,
		"the pause key on a played story goes back to the desk, and strikes the camera")
	check(get_tree().get_nodes_in_group("npcs").is_empty() and get_tree().get_nodes_in_group("player").is_empty(),
		"with nothing left standing from the play")
	maker.set_mode(StoryMaker.Mode.FREE)
	desk._play()
	await frames(8)
	who = Views.of(maker.npc) as NpcView
	check(maker.playing and maker.npc.mode == Npc.Mode.FREE and who != null and who.bubble != null,
		"played free, the character talks in a bubble")
	await action("pause")
	check(not maker.playing and desk.is_visible_in_tree(), "and the pause key comes back from that too")
	maker.set_mode(StoryMaker.Mode.NOVEL)
	desk._play()
	await frames(8)
	var seen := Views.of(maker.scene) as CutsceneView
	check(maker.playing and maker.reading() and seen != null and seen.box != null and view.camera == null
			and not view.hud.visible and not view.keys.visible,
		"played as a novel, the scene brings its own camera and panel, and nothing of a raid's is up")
	check(seen.pixels.lighting.ambient == MapTiles.of("grove").ambient(), "in the map's light")
	check(game._touch_face() == TouchPad.Face.TALK, "and the console wears the face a scene does")
	await action("ui_cancel")
	await frames(3)
	check(not maker.playing and desk.is_visible_in_tree() and not get_tree().paused and maker.scene == null,
		"the cancel key skips the novel, back to the desk")
	maker.set_mode(StoryMaker.Mode.FROZEN)
	desk._new()
	desk._play()
	await frames(2)
	check(not maker.playing and desk._said == Loc.t("hud.story.refused.empty"),
		"PLAY on a story with nothing to say stays at the desk, and says why (%s)" % desk._said)
	desk._load("desk_story")
	await frames(2)

func _leaving() -> void:
	await action("pause")
	check(get_tree().paused and game.pause_menu.visible and game.pause_title.visible and not game.pause_abandon.visible,
		"the pause key on the desk opens PAUSED, with MAIN MENU on it")
	game._pause_to_title()
	await frames(6)
	check(game.state == GameScript.State.TITLE and not get_tree().paused, "MAIN MENU goes to the title")
	game.goto_story_maker()
	await frames(6)
	maker = game.current as StoryMaker
	view = Views.of(maker) as StoryMakerView
	desk = view.desk
	check(maker.story_id == "desk_story" and maker.line_count() == 2 and desk._name.text == "desk_story" and desk._rows.size() == 2,
		"and the story that was on the desk is on it when the maker is come back to")
	(desk._bar.find_children("*", "Button", true, false)[0] as Button).pressed.emit()
	await frames(6)
	check(game.state == GameScript.State.TITLE, "the arrow in the desk's corner goes to the title too")
	game.goto_story_maker()
	await frames(6)
	maker = game.current as StoryMaker
	view = Views.of(maker) as StoryMakerView
	desk = view.desk

## In the other language and in mobile mode the desk is built again, and
## still fits: nothing wider than the bar, the column no wider than it was and
## no taller than the screen, and the lines still on it.
func _both_ways() -> void:
	for lang in Loc.languages():
		for thumb in [false, true]:
			Loc.set_language(lang)
			Touch.set_mode(Touch.ON if thumb else Touch.OFF)
			await frames(6)
			var s := screen()
			var how := "%s, %s" % [lang, "for a thumb" if thumb else "at a desk"]
			check(desk._bar.get_combined_minimum_size().x <= s.x and is_equal_approx(desk._bar.size.x, s.x),
				"the bar fits the screen (%s: %.0f of %.0f)" % [how, desk._bar.get_combined_minimum_size().x, s.x])
			check(is_equal_approx(desk._side.size.x, StoryDesk.SIDE_W) and desk._side.get_combined_minimum_size().y <= s.y - desk._bar.size.y,
				"the column is its own width and no taller than the room under the bar (%s: %s wants %s)"
					% [how, str(desk._side.size), str(desk._side.get_combined_minimum_size())])
			check(is_equal_approx(desk._sheet.position.x, StoryDesk.SIDE_W) and desk._sheet.size.x > 0.0 and desk._sheet.size.y > 0.0,
				"and the lines have the rest (%s: %s)" % [how, str(desk._sheet.get_rect())])
			check(desk._rows.size() == 2 and (desk._rows[0]["edit"] as LineEdit).text == maker.text_of(0)
					and desk._npc_name.text == maker.npc_name,
				"with the lines still on it, and the names (%s)" % how)
	Touch.set_mode(Touch.OFF)
	Loc.set_language(Loc.DEFAULT)
	await frames(4)

## Empties a scratch folder, and takes it away.
func _sweep(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
