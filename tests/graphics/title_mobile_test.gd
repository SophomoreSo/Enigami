extends Node
## The title's menu in mobile mode: the same four entries as a row of big square
## tiles a thumb can land on, and the column of lines again the moment mobile
## mode is thrown off.
##
## It is thrown where a player throws it — the switch on the controls page,
## under the settings, over the menu — so what is checked is that the menu under
## them follows it without the title being built again; that the tiles are
## square, big, in one row and in order, apart, centred under the seal, clear
## of the pendant and on the screen; that every name fits its tile in both
## languages; that a click anywhere on a tile presses it, on its mark as much as
## on its name; and that the keyboard walks along the row.
##
## Checked on a window that is not 1:1: at 1:1 a design position and a window
## position are the same number, and a click sent to the wrong one lands anyway.

const GameScript := preload("res://app/game.gd")

var fails := 0
var game: Node

func check(ok: bool, what: String) -> void:
	if ok:
		print("[MOBILE] PASS ", what)
	else:
		fails += 1
		push_error("MOBILE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func title() -> TitleScreen:
	return game.current as TitleScreen

func focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()

## The menu's buttons, left to right or top to bottom.
func entries() -> Array:
	return title()._menu_root.get_children()

## A click where `at` is in the 1280x720 the game is drawn at, pressed and let
## go, sent the way the system sends one.
func click(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = get_window().get_final_transform() * at
	m.global_position = m.position
	Input.parse_input_event(m)
	await frames(2)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = m.position
		e.global_position = e.position
		Input.parse_input_event(e)
		await frames(2)

## The action itself rather than a key, so the test holds whatever the keyboard
## or the pad has it bound to.
func action(name: String) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = name
		e.pressed = pressed
		Input.parse_input_event(e)
		await frames(2)

## Where a tile's mark is: the upper half, well clear of the name the button
## carries. A tile has to answer there too, or it is a big picture round a
## small button.
func on_mark(b: Control) -> Vector2:
	var r := b.get_global_rect()
	return Vector2(r.get_center().x, r.position.y + TitleScreen.MARK_TOP + 20.0)

func _ready() -> void:
	var was_mode := Touch.mode
	var was_size := DisplayServer.window_get_size()
	DisplayServer.window_set_size(Vector2i(1440, 810))
	Touch.set_mode(Touch.OFF)
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(10)
	_the_column()
	await _thrown_on()
	_the_row()
	await _the_names()
	await _the_keys()
	await _pressed()
	await _thrown_off()
	Touch.set_mode(was_mode)
	DisplayServer.window_set_size(was_size)
	print("[MOBILE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Off, the menu is what it always was: four lines, one under another.
func _the_column() -> void:
	var t := title()
	check(t._menu_root is VBoxContainer and t._tiles.is_empty(),
		"with mobile mode off, the menu is a column of lines")
	var e := entries()
	var down := e.size() == 4
	for i in range(1, e.size()):
		down = down and (e[i] as Control).global_position.y > (e[i - 1] as Control).global_position.y
	check(down, "four of them, one under another")

## Thrown on the controls page, the way a player throws it: SETTINGS, CONTROL
## SETTINGS, the switch, and back out twice.
func _thrown_on() -> void:
	var t := title()
	t._settings_button.emit_signal("pressed")
	await frames(4)
	t._toggle_controls()
	await frames(6)
	var switch: UiKit.Switch = null
	for c in t._controls.find_children("*", "", true, false):
		if c is UiKit.Switch:
			switch = c
	check(switch != null and not switch.button_pressed, "the controls page has mobile mode off")
	if switch == null:
		return
	await click(switch.get_global_rect().get_center())
	check(Touch.mode == Touch.ON, "a click on the switch throws it on (mode %d)" % Touch.mode)
	await action("ui_cancel")
	await action("ui_cancel")
	await frames(2)
	check(title() == t, "the title is the same screen, not built again")
	check(t._menu_root.visible and not t._settings.visible and not t._controls.visible,
		"backing out leaves the menu on screen")
	check(focus_owner() == t._settings_button and t._tiles.has(focus_owner()),
		"with the keyboard on the SETTINGS tile it came out of")

func _the_row() -> void:
	var t := title()
	check(t._menu_root is HBoxContainer and t._tiles.size() == 4,
		"with mobile mode on, the menu is a row of four tiles (%d)" % t._tiles.size())
	var e := entries()
	var names: Array = []
	for b: Button in e:
		names.append(b.text)
	var want: Array = Menus.items("title").map(func(i: Dictionary) -> String: return String(i["text"]))
	check(names == want, "in the order the lines were in (%s)" % str(names))

	var rects: Array = e.map(func(b: Control) -> Rect2: return b.get_global_rect())
	var square := true
	var small := 0.0
	for r: Rect2 in rects:
		square = square and is_equal_approx(r.size.x, r.size.y)
		small = r.size.x if small == 0.0 else minf(small, r.size.x)
	check(square, "every tile is square")
	# The lines were a 24-pixel word each. A thumb wants several times that.
	check(small >= 144.0, "and big: %.0f across, where a line was a word 24 high" % small)
	var level := true
	var apart := true
	for i in range(1, rects.size()):
		level = level and is_equal_approx(rects[i].position.y, rects[0].position.y)
		apart = apart and rects[i].position.x - rects[i - 1].end.x >= 16.0
	check(level, "all four on one line")
	check(apart, "left to right, with room between them")
	var span := Rect2(rects[0].position, rects[-1].end - rects[0].position)
	check(absf(span.get_center().x - TitleScreen.SEAL.x) <= 1.0,
		"centred under the seal (%.0f, the seal at %.0f)" % [span.get_center().x, TitleScreen.SEAL.x])
	# The pendant hangs from the seal's rim: a line, a node and a diamond, to
	# 60 below it. The tiles go under it, not over it.
	var pendant := TitleScreen.SEAL.y + TitleScreen.SEAL_R + 60.0
	check(span.position.y > pendant, "clear of the pendant (%.0f, it ends at %.0f)" % [span.position.y, pendant])
	var screen := Rect2(Vector2.ZERO, TitleScreen.DESIGN).grow(-8.0)
	check(screen.encloses(span), "and on the screen with room to spare (%s)" % str(span))

## Every name fits the tile it is written in, in every language: a tile is the
## one width it is, so a longer word has nowhere to go.
func _the_names() -> void:
	var was := Loc.language
	for lang in Loc.languages():
		Loc.set_language(lang)
		await frames(4)
		var t := title()
		var over: Array = []
		for b: Button in entries():
			var box := b.get_theme_stylebox("normal")
			var room := b.size.x - box.content_margin_left - box.content_margin_right
			var wide := b.get_theme_font("font").get_string_size(b.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
			if wide > room:
				over.append("%s %.0f of %.0f" % [b.text, wide, room])
		check(t._tiles.size() == 4 and over.is_empty(),
			"in %s the menu is still tiles, and every name fits its own (%s)" % [lang, str(over)])
	Loc.set_language(was)
	await frames(4)

## Along the row with the keys a menu is walked with, and never off the end.
func _the_keys() -> void:
	var t := title()
	t._start_button.grab_focus()
	await frames(1)
	var e := entries()
	await action("ui_right")
	check(focus_owner() == e[1], "right goes from START to the next tile")
	await action("ui_right")
	await action("ui_right")
	check(focus_owner() == e[3], "and on along the row to the last")
	await action("ui_right")
	check(focus_owner() == e[3], "and no further")
	await action("ui_left")
	check(focus_owner() == e[2], "and left comes back")

## A click on the mark presses the tile, and it does what the line did: START
## asks for a save slot, SETTINGS opens the settings, SANDBOX goes to the bench.
func _pressed() -> void:
	var t := title()
	await click(on_mark(t._start_button))
	check(t._save_slot_root.visible and not t._menu_root.visible,
		"a click on START's mark asks for a save slot")
	await action("ui_cancel")
	check(t._menu_root.visible and focus_owner() == t._start_button,
		"and backing out of that comes back to the START tile")
	await click(on_mark(t._settings_button))
	check(t._settings.visible and not t._menu_root.visible,
		"a click on SETTINGS' mark opens the settings")
	await action("ui_cancel")
	var sandbox: Button = entries()[1]
	await click(on_mark(sandbox))
	await frames(10)
	check(game.current is Sandbox, "and one on SANDBOX's goes to the bench (%s)" % game.current)
	game.goto_title()
	await frames(10)
	check(title() != null and title()._tiles.size() == 4,
		"and the title that comes back is laid out for mobile mode too")

## Thrown off, the tiles go and the column comes back, and nothing is left
## pointing at a tile that is gone.
func _thrown_off() -> void:
	var t := title()
	Touch.set_mode(Touch.OFF)
	await frames(2)
	check(t._menu_root is VBoxContainer and t._tiles.is_empty(),
		"thrown off, the menu is a column of lines again")
	check(t._buttons.all(func(b: Object) -> bool: return is_instance_valid(b) and not b.is_queued_for_deletion()),
		"and every button the screen still counts is one that is on it (%d)" % t._buttons.size())
	check(entries().size() == 4 and (entries()[0] as Button).text == Loc.t("menu.title.start"),
		"the same four, START first")
