extends Node
## START has to ask for a save slot before it leaves the title. Saving is not
## per-slot yet, so only the question is checked: three slots, the keyboard
## lands on the first, backing out returns to the menu, and it is a pick — not
## START — that moves the game on.

const GameScript := preload("res://app/game.gd")

var game: Node
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SAVE] PASS ", what)
	else:
		fails += 1
		push_error("SAVE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()

## The action itself rather than a key, so the test holds whatever Escape or
## the pad's back button is bound to.
func cancel() -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = "ui_cancel"
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await frames(2)

func _ready() -> void:
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(10)

	var title: TitleScreen = game.current
	title._start_button.emit_signal("pressed")
	await frames(4)
	check(game.state == GameScript.State.TITLE, "START alone does not leave the title")
	check(title._save_slot_root.visible and not title._menu_root.visible,
		"START swaps the menu for the save slots")
	var rows: Array = []
	for c in title._save_slot_root.get_children():
		rows.append((c as Button).text)
	check(rows == ["SLOT 1", "SLOT 2", "SLOT 3", "BACK"],
		"three slots and a way back (%s)" % str(rows))
	check(focus_owner() == title._first_save_slot,
		"the keyboard lands on SLOT 1 (owner=%s)" % str(focus_owner()))

	await cancel()
	check(title._menu_root.visible and not title._save_slot_root.visible,
		"cancel backs out to the menu")
	check(focus_owner() == title._start_button,
		"and gives the keyboard back to START (owner=%s)" % str(focus_owner()))

	title._start_button.emit_signal("pressed")
	await frames(4)
	(title._save_slot_root.get_child(1) as Button).emit_signal("pressed")
	check(title.save_slot == 2, "picking SLOT 2 records slot 2 (got %d)" % title.save_slot)
	await frames(6)
	check(game.state == GameScript.State.HIDEOUT,
		"and the pick is what moves the game on (state=%d)" % game.state)

	print("[SAVE] ---- %d failures ----" % fails)
	get_tree().quit()
