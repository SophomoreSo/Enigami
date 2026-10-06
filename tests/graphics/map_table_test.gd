extends Node
## The map creator's screen, played the way a person plays it: in from the
## title, a map laid with the pointer and taken back with the keys, saved under
## a name, found again in the list, played, and come back to.
##
## What the creator's rules do is `tests/feature/map_maker_test`. This is the
## table over them — that every press gets to the rule it is for, that the
## whole of it fits the screen in both languages and both modes, and that the
## two ways out of it land where they say.
##
## Maps are kept in a scratch folder for the length of the test, never in the
## project's own. No pixels are read: a window is not needed.

const GameScript := preload("res://app/game.gd")
const SCRATCH := "user://map_table_test"

var fails := 0
var game: Node
var maker: MapMaker
var view: MapMakerView
var table: MapTable

func check(ok: bool, what: String) -> void:
	if ok:
		print("[TABLE] PASS ", what)
	else:
		fails += 1
		push_error("TABLE FAIL: " + what)

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

func press(at: Vector2, down: bool, button: MouseButton = MOUSE_BUTTON_LEFT, shift: bool = false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = down
	e.shift_pressed = shift
	e.position = on_glass(at)
	e.global_position = e.position
	Input.parse_input_event(e)
	await frames(2)

## A press and a let-go on one spot.
func click(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await move(at)
	await press(at, true, button)
	await press(at, false, button)

## Pressed at `from`, carried to `to`, let go there.
func drag(from: Vector2, to: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT, shift: bool = false) -> void:
	await move(from)
	await press(from, true, button, shift)
	await move(to)
	await press(to, false, button, shift)

## A key with the platform's own shortcut modifier held: Cmd on a Mac, Ctrl
## anywhere else.
func shortcut(code: Key, shift: bool = false) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		e.shift_pressed = shift
		e.command_or_control_autoremap = true
		Input.parse_input_event(e)
		await frames(2)

func action(which: String) -> void:
	var e := InputEventAction.new()
	e.action = which
	e.pressed = true
	Input.parse_input_event(e)
	await frames(3)

## The middle of a cell of the map, on the screen.
func at_cell(c: Vector2i) -> Vector2:
	return table._sheet.global_position + table.cell_rect(c).get_center()

func tile(entry: String) -> Button:
	return table._palette[entry]

func screen() -> Vector2:
	return get_viewport().get_visible_rect().size

func _ready() -> void:
	var was_mode := Touch.mode
	var was_language := Loc.language
	Maps.scratch_dir = SCRATCH
	_sweep()
	MapMaker.forget()
	Touch.set_mode(Touch.OFF)
	Loc.set_language(Loc.DEFAULT)
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	await _the_door()
	_the_table()
	await _the_pointer()
	await _the_keys()
	await _keeping()
	await _playing()
	await _leaving()
	await _both_ways()
	Touch.set_mode(was_mode)
	Loc.set_language(was_language)
	_sweep()
	Maps.scratch_dir = ""
	MapMaker.forget()
	print("[TABLE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## MAP CREATOR is on the title, under SANDBOX, and goes to the table.
func _the_door() -> void:
	var title := game.current as TitleScreen
	var ids: Array = Menus.items("title").map(func(i: Dictionary) -> String: return String(i["id"]))
	check(ids.find("map_maker") == ids.find("sandbox") + 1, "the title has MAP CREATOR, straight under SANDBOX (%s)" % str(ids))
	var door: Button = null
	for b in title._menu_root.get_children():
		if (b as Button).text == Loc.t("menu.title.map_maker"):
			door = b
	check(door != null and title._menu_root.get_child_count() == 5
			and title._menu_root.get_global_rect().end.y <= title._stage.global_position.y + TitleScreen.DESIGN.y,
		"as a line of its own, and the column it makes five of still ends on the design (%.0f of %.0f)"
			% [title._menu_root.get_global_rect().end.y - title._stage.global_position.y, TitleScreen.DESIGN.y])
	if door != null:
		door.pressed.emit()
	await frames(8)
	maker = game.current as MapMaker
	check(game.state == GameScript.State.MAP_MAKER and maker != null, "pressing it goes to the map creator (%s)" % game.current)
	view = Views.of(maker) as MapMakerView
	table = view.table if view != null else null
	check(table != null and table.is_visible_in_tree() and not maker.playing, "which opens on its table, laying")
	check(not view.hud.visible and not view.keys.visible, "with nothing of a played map's on the screen")

func _the_table() -> void:
	var s := screen()
	check(table._bar.position == Vector2.ZERO and is_equal_approx(table._bar.size.x, s.x),
		"the bar runs across the top of the screen (%s)" % str(table._bar.get_rect()))
	check(is_equal_approx(table._side.size.x, MapTable.SIDE_W) and is_equal_approx(table._side.get_rect().end.y, s.y),
		"and the column down the left, under it (%s)" % str(table._side.get_rect()))
	var want := PackedStringArray([MapTable.MOVE, MadeRoom.OPEN])
	want.append_array(MadeRoom.marks())
	check(PackedStringArray(table._palette.keys()) == want, "there is a tile for the two tools and for every mark a room can hold (%d)" % table._palette.size())
	var inside := true
	var named := true
	var column := Rect2(table._side.global_position, table._side.size)
	for entry: String in table._palette:
		inside = inside and column.encloses(tile(entry).get_global_rect())
		named = named and MapTable.name_of(entry) != "" and MapTable.name_of(entry) != entry
	check(inside, "every one of them in the column, none of them scrolled out of it")
	check(named, "and every one with a name")
	check(table.brush == MadeRoom.ROCK and tile(MadeRoom.ROCK).disabled and not tile("c").disabled
			and table._in_hand.text == MapTable.name_of(MadeRoom.ROCK),
		"it opens with rock in hand, its tile lit and its name under the tiles")
	var sheet := Rect2(Vector2.ZERO, table._sheet.size)
	var whole := Rect2(table._origin, Vector2(maker.cols, maker.rows) * table.cell_size())
	check(sheet.encloses(whole), "and with the whole of a new map in sight (%s in %s)" % [str(whole), str(sheet)])
	check(table._bar.get_combined_minimum_size().x <= s.x and table._side.get_combined_minimum_size().x <= MapTable.SIDE_W
			and table._side.get_combined_minimum_size().y <= table._side.size.y,
		"nothing on it wants more room than it has")

func _the_pointer() -> void:
	# The left button lays what is in hand, a cell at a time along the drag.
	await drag(at_cell(Vector2i(10, 10)), at_cell(Vector2i(18, 10)))
	var laid := true
	for x in range(10, 19):
		laid = laid and maker.mark_at(Vector2i(x, 10)) == MadeRoom.ROCK
	check(laid and maker.mark_at(Vector2i(19, 10)) == MadeRoom.OPEN and maker.mark_at(Vector2i(9, 10)) == MadeRoom.OPEN,
		"a drag with the left button lays rock from where it started to where it ended")
	check(maker.unsaved and maker.can_undo(), "and the map has something to save, and to take back")
	# The right one erases.
	await click(at_cell(Vector2i(14, 10)), MOUSE_BUTTON_RIGHT)
	check(maker.mark_at(Vector2i(14, 10)) == MadeRoom.OPEN and maker.mark_at(Vector2i(13, 10)) == MadeRoom.ROCK,
		"a click with the right button erases the cell under it")
	# SHIFT drags a box.
	await drag(at_cell(Vector2i(22, 6)), at_cell(Vector2i(25, 8)), MOUSE_BUTTON_LEFT, true)
	var boxed := true
	for y in range(6, 9):
		for x in range(22, 26):
			boxed = boxed and maker.mark_at(Vector2i(x, y)) == MadeRoom.ROCK
	check(boxed and maker.mark_at(Vector2i(26, 8)) == MadeRoom.OPEN and maker.mark_at(Vector2i(22, 9)) == MadeRoom.OPEN,
		"SHIFT held, a drag lays a box from corner to corner")
	await drag(at_cell(Vector2i(23, 7)), at_cell(Vector2i(24, 7)), MOUSE_BUTTON_RIGHT, true)
	check(maker.mark_at(Vector2i(23, 7)) == MadeRoom.OPEN and maker.mark_at(Vector2i(24, 7)) == MadeRoom.OPEN
			and maker.mark_at(Vector2i(22, 7)) == MadeRoom.ROCK, "and with the right button, erases one")
	# A tile takes its mark in hand.
	await click(tile("c").get_global_rect().get_center())
	check(table.brush == "c" and tile("c").disabled and not tile(MadeRoom.ROCK).disabled
			and table._in_hand.text == Monsters.name_for("CRAWLER").to_upper(),
		"a click on a tile takes what is on it in hand (%s)" % table._in_hand.text)
	await click(at_cell(Vector2i(30, 19)))
	check(maker.mark_at(Vector2i(30, 19)) == "c", "and the next click on the map lays it")
	# MOVE lays nothing: it carries the map.
	await click(tile(MapTable.MOVE).get_global_rect().get_center())
	var was := table._origin
	var before := maker.plan()
	await drag(at_cell(Vector2i(20, 12)), at_cell(Vector2i(20, 12)) + Vector2(48, 32))
	check(table._origin.is_equal_approx(was + Vector2(48, 32)) and maker.plan() == before,
		"with MOVE in hand a drag carries the map and lays nothing (%s from %s)" % [str(table._origin), str(was)])
	await drag(at_cell(Vector2i(20, 12)), at_cell(Vector2i(20, 12)) - Vector2(48, 32), MOUSE_BUTTON_MIDDLE)
	check(table._origin.is_equal_approx(was), "and so does one with the middle button, whatever is in hand")
	# The wheel brings it nearer, about the cell the pointer is on.
	var under := Vector2i(20, 12)
	var spot := at_cell(under)
	await press(spot, true, MOUSE_BUTTON_WHEEL_UP)
	check(is_equal_approx(table.cell_size(), float(Room.CELL)) and table.cell_at(spot - table._sheet.global_position) == under,
		"the wheel brings the map to a room's own size, about the cell the pointer is on")
	await press(spot, true, MOUSE_BUTTON_WHEEL_DOWN)
	check(is_equal_approx(table.cell_size(), Room.CELL * 0.5), "and takes it back to half")
	await click(tile(MadeRoom.ROCK).get_global_rect().get_center())

func _the_keys() -> void:
	var was := maker.mark_at(Vector2i(30, 19))
	await shortcut(KEY_Z)
	check(was == "c" and maker.mark_at(Vector2i(30, 19)) == MadeRoom.OPEN and maker.can_redo(),
		"the undo key takes the last stroke back")
	await shortcut(KEY_Z, true)
	check(maker.mark_at(Vector2i(30, 19)) == "c" and not maker.can_redo(), "and with SHIFT lays it again")
	# The bar's own buttons do the same, and say when there is nothing to do.
	check(not table._undo_button.disabled and table._redo_button.disabled, "REDO is unlit with nothing to lay again")
	table._undo_button.pressed.emit()
	await frames(2)
	check(maker.mark_at(Vector2i(30, 19)) == MadeRoom.OPEN and not table._redo_button.disabled, "UNDO on the bar is the same step back")
	table._redo_button.pressed.emit()
	await frames(2)
	# A name being typed keeps its keys: they are not the map's.
	table._name.grab_focus()
	await frames(2)
	var origin := table._origin
	Input.action_press("move_right")
	await frames(6)
	Input.action_release("move_right")
	check(table._origin == origin, "while the name has the keyboard the move keys do not carry the map")
	await click(at_cell(Vector2i(5, 5)), MOUSE_BUTTON_MIDDLE)
	check(not table._name.has_focus(), "a press on the map takes the keyboard back from the name")
	Input.action_press("move_right")
	await frames(6)
	Input.action_release("move_right")
	await frames(2)
	check(table._origin.x < origin.x, "and then they do (%.0f from %.0f)" % [table._origin.x, origin.x])

func _keeping() -> void:
	# A size, from the column.
	table._resize(Vector2i(10, 0))
	await frames(2)
	check(maker.cols == Room.W + 10 and table._wide.text == str(Room.W + 10) and table._high.text == str(Room.H),
		"the column's numbers are the map's, and change it (%s x %s)" % [table._wide.text, table._high.text])
	# SAVE wants a name.
	table._name.text = "   "
	table._save()
	await frames(2)
	check(maker.unsaved and Maps.ids().is_empty() and table._said == Loc.t("hud.maker.refused.name"),
		"SAVE with no name keeps nothing, and says why (%s)" % table._said)
	table._name.text = "Table Keep"
	await shortcut(KEY_S)
	check(not maker.unsaved and Maps.exists("table_keep") and maker.map_id == "table_keep",
		"with a name, the save key keeps the map under it")
	check(table._name.text == "table_keep" and table._said.contains(Maps.path_of("table_keep")),
		"the field shows the name it was filed under, and the foot says where (%s)" % table._said)
	# Over another map's name, it asks first.
	table._new()
	await frames(2)
	check(maker.cols == Room.W and maker.map_id == "" and table._name.text == "" and not maker.unsaved,
		"NEW clears the table and the name with it")
	table._name.text = "table keep"
	table._save()
	await frames(2)
	var kept := Maps.load_room("table_keep")
	check(kept != null and kept.cols == Room.W + 10 and table._armed != "",
		"SAVE under the name of a map kept already only asks, the first time")
	if kept != null:
		kept.free()
	table._save()
	await frames(2)
	kept = Maps.load_room("table_keep")
	check(kept != null and kept.cols == Room.W and table._armed == "", "and replaces it the second")
	if kept != null:
		kept.free()
	table._name.text = "other hall"
	maker.begin_stroke()
	maker.lay(Vector2i(8, 8), MadeRoom.ROCK)
	table._save()
	await frames(2)
	# LOAD lists what is kept.
	table._open_list()
	await frames(3)
	var picks: Array = table._popup.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	check(table._popup != null and picks.has("OTHER_HALL") and picks.has("TABLE_KEEP"),
		"LOAD lists every map that is kept (%s)" % str(picks))
	await action("ui_cancel")
	check(table._popup == null and not get_tree().paused, "the cancel key puts the list away, and does not pause the table behind it")
	table._open_list()
	await frames(2)
	table._delete("other_hall")
	await frames(2)
	check(Maps.exists("other_hall") and table._armed == "delete:other_hall", "DELETE only asks, the first time")
	table._delete("other_hall")
	await frames(2)
	check(not Maps.exists("other_hall") and Maps.exists("table_keep"), "and throws that map away the second, and no other")
	table._load("table_keep")
	await frames(3)
	check(table._popup == null and maker.map_id == "table_keep" and table._name.text == "table_keep"
			and maker.mark_at(Vector2i(8, 8)) == MadeRoom.OPEN,
		"a map picked from the list is put on the table under its name, and the list goes")

func _playing() -> void:
	maker.begin_stroke()
	maker.lay(Vector2i(20, 19), "y")
	table._changed()
	table._bar.find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return b.text == Loc.t("hud.maker.play"))[0].pressed.emit()
	await frames(8)
	check(maker.playing and not table.is_visible_in_tree() and view.hud.visible and view.keys.visible,
		"PLAY puts the table away and a played map's readout up")
	check(view.hud.player == maker.player and Pointer.who() == Pointer.Who.HAND,
		"the raid's own HUD over the body in it, and the pointer the player's to aim with")
	check(get_tree().get_nodes_in_group("enemies").size() == 1, "and what was laid is standing in it")
	# The assembly board, on its key.
	await action("open_editor")
	check(maker.editing and view.editor.visible and not view.keys.visible, "the assembly key opens the board over it")
	maker.set_editing(false)
	await frames(2)
	# The pause key goes back to the table rather than into the pause menu.
	await action("pause")
	check(not maker.playing and table.is_visible_in_tree() and not get_tree().paused and not view.hud.visible,
		"the pause key on a played map goes back to the table")
	check(maker.mark_at(Vector2i(20, 19)) == "y" and get_tree().get_nodes_in_group("enemies").is_empty(),
		"with the plan as it was, and nothing left standing from the play")

	# A map wider than the screen: the camera goes along it, and stops at its ends.
	maker.resize(Vector2i(Room.W * 2, Room.H * 2))
	maker.begin_stroke()
	maker.lay_box(Vector2i(0, Room.H * 2 - 2), Vector2i(Room.W * 2 - 1, Room.H * 2 - 1), MadeRoom.ROCK)
	maker.lay(Vector2i(Room.W * 2 - 3, Room.H * 2 - 3), MadeRoom.START)
	maker.play()
	await frames(6)
	var map := Vector2(maker.cols, maker.rows) * Room.CELL
	var half := screen() * 0.5
	check(view.camera.position.is_equal_approx(map - half),
		"on a map bigger than the screen the camera is on the player, and stops at the map's edge (%s, the corner %s)"
			% [str(view.camera.position), str(map - half)])
	maker.stop()
	await frames(3)
	# The floor and the start, then the size: two steps back to the map as it was.
	maker.undo()
	maker.undo()
	table._changed()
	check(maker.cols == Room.W and maker.rows == Room.H and maker.mark_at(Vector2i(20, 19)) == "y",
		"and the map is the size it was again")

func _leaving() -> void:
	# The pause key on the table is the pause menu, and its MAIN MENU the way out.
	await action("pause")
	check(get_tree().paused and game.pause_menu.visible and game.pause_title.visible and not game.pause_abandon.visible,
		"the pause key on the table opens PAUSED, with MAIN MENU on it")
	var left := maker.plan()
	game._pause_to_title()
	await frames(6)
	check(game.state == GameScript.State.TITLE and not get_tree().paused, "MAIN MENU goes to the title")
	game.goto_map_maker()
	await frames(6)
	maker = game.current as MapMaker
	view = Views.of(maker) as MapMakerView
	table = view.table
	check(maker.plan() == left and maker.map_id == "table_keep" and table._name.text == "table_keep",
		"and the map that was on the table is on it when the creator is come back to")
	# The arrow in the corner is the other way out.
	(table._bar.find_children("*", "Button", true, false)[0] as Button).pressed.emit()
	await frames(6)
	check(game.state == GameScript.State.TITLE, "the arrow in the table's corner goes to the title too")
	game.goto_map_maker()
	await frames(6)
	maker = game.current as MapMaker
	view = Views.of(maker) as MapMakerView
	table = view.table

## In the other language and in mobile mode the table is built again, and still
## fits: nothing wider than the bar, the column no wider than it was and no
## taller than the screen, and what is in hand still in hand.
func _both_ways() -> void:
	table.take("w")
	for lang in Loc.languages():
		for thumb in [false, true]:
			Loc.set_language(lang)
			Touch.set_mode(Touch.ON if thumb else Touch.OFF)
			await frames(6)
			var s := screen()
			var how := "%s, %s" % [lang, "for a thumb" if thumb else "at a desk"]
			check(table._bar.get_combined_minimum_size().x <= s.x and is_equal_approx(table._bar.size.x, s.x),
				"the bar fits the screen (%s: %.0f of %.0f)" % [how, table._bar.get_combined_minimum_size().x, s.x])
			check(is_equal_approx(table._side.size.x, MapTable.SIDE_W) and table._side.get_combined_minimum_size().y <= s.y - table._bar.size.y,
				"the column is its own width and no taller than the room under the bar (%s: %s wants %s)"
					% [how, str(table._side.size), str(table._side.get_combined_minimum_size())])
			check(is_equal_approx(table._sheet.position.x, MapTable.SIDE_W) and table._sheet.size.x > 0.0 and table._sheet.size.y > 0.0,
				"and the sheet has the rest (%s: %s)" % [how, str(table._sheet.get_rect())])
			check(table.brush == "w" and tile("w").disabled and table._palette.size() == MadeRoom.marks().size() + 2,
				"with what was in hand still in hand (%s)" % how)
	Touch.set_mode(Touch.OFF)
	Loc.set_language(Loc.DEFAULT)
	await frames(4)

## Empties the scratch folder, and takes it away.
func _sweep() -> void:
	if not DirAccess.dir_exists_absolute(SCRATCH):
		return
	for file in DirAccess.get_files_at(SCRATCH):
		DirAccess.remove_absolute(SCRATCH.path_join(file))
	DirAccess.remove_absolute(SCRATCH)
