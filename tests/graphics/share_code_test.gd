extends Node
## The share sheet, driven the way a player drives it: the key that opens it,
## the code typed in a character at a time, ENTER to build. What a pasted code costs is
## checked at the workbench, where parts are finite — a code is a blueprint and
## not the parts, so it spends the stash exactly as building the same board by
## hand would have, and a board that cannot be paid for changes nothing at all.

const GameScript := preload("res://app/game.gd")

var game: Node
var ed: SkillEditor
var fails := 0

func say(s: String) -> void:
	print("[SHARE] ", s)

func check(ok: bool, what: String) -> void:
	if ok:
		say("PASS " + what)
	else:
		fails += 1
		push_error("SHARE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Pressed and released on the spot: `push_input` runs the handlers as it is
## called, so a key is over before the next line of the test.
func key(code: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		get_viewport().push_input(e)

func click(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	get_viewport().push_input(m)
	await get_tree().process_frame
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		get_viewport().push_input(e)
		await get_tree().process_frame

## One character of a code, case and all. The sheet reads `unicode`, which is
## the only thing on the event that tells an `a` from an `A`.
func type_char(c: String) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = c.to_upper().unicode_at(0)
		e.unicode = c.unicode_at(0)
		e.pressed = pressed
		get_viewport().push_input(e)

## A code typed a character at a time — anything outside the alphabet included,
## which the sheet is supposed to drop on the way in.
func type_code(code: String) -> void:
	for i in code.length():
		type_char(code[i])
	await get_tree().process_frame

func same_parts(a: SkillBoard, b: SkillBoard) -> bool:
	if a.cells.size() != b.cells.size():
		return false
	for origin in a.cells:
		var there: Dictionary = b.cells.get(origin, {})
		if there.is_empty() or String(there["id"]) != String(a.cells[origin]["id"]) \
				or int(there["rot"]) != int(a.cells[origin]["rot"]):
			return false
	return true

func _ready() -> void:
	GameState.reset_profile()
	seed(3)
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)

	# --- the bench: parts are free, so this is the sheet on its own ----------
	game.goto_sandbox()
	await frames(12)
	var sb: Sandbox = game.current
	sb.set_editing(true)
	await frames(6)
	ed = Views.of(sb).editor
	var b: SkillBoard = ed.current_board()
	for c in b.cells.keys().duplicate():
		b.erase_at(c)
	# A two-cell part and three facings, so the code carries more than a
	# straight line of defaults.
	b.place("INPUT", Vector2i(0, 1), 0)
	b.place("AREA", Vector2i(1, 1), 0)
	b.place("BEND", Vector2i(3, 1), 1)
	b.place("ICE", Vector2i(3, 2), 2)
	b.place("OUTPUT", Vector2i(2, 2), 0)
	var want := b.duplicate_board()
	var code := BoardCode.encode(b)
	say("the bench board is " + code)

	key(KEY_C)
	await frames(2)
	check(ed._share_open(), "C opens the share sheet")
	check(ed._share.code == code, "and it is showing this board's code")

	# The sheet takes the whole keyboard: a key reaching the editor behind it
	# would turn a part on a board nobody can see.
	var rot_before := ed.rotation_step
	key(KEY_R)
	await frames(2)
	check(ed.rotation_step == rot_before, "R does not reach the editor under the sheet")
	check(ed._share_open(), "and the sheet is still up")

	# Now wipe the board and build it back out of nothing but the code.
	for c in b.cells.keys().duplicate():
		b.erase_at(c)
	check(b.cells.is_empty(), "the board is cleared before the code is typed")
	check(not code.contains("-"), "the sheet's code has no dashes in it (%s)" % code)
	# A stray space in the middle, the way a code gets retyped off a screenshot.
	await type_code(code.left(10) + " " + code.substr(10))
	check(ed._share.entry == code,
		"a stray space is dropped on the way in, case kept (%d characters)"
			% ed._share.entry.length())
	key(KEY_ENTER)
	await frames(2)
	check(same_parts(want, b), "ENTER builds the board back out of the code")
	check(b.cells.size() == want.cells.size(), "every part came back (%d of %d)"
		% [b.cells.size(), want.cells.size()])
	check(ed._share.code == BoardCode.encode(b), "and the sheet now shows the board it built")
	check(ed._share.entry.is_empty(), "the field is emptied once its code has been used")

	# A code that is nearly right is refused rather than nearly built.
	var body := BoardCode.clean(code)
	var wrong := body.left(3) + ("W" if body[3] != "W" else "k") + body.substr(4)
	await type_code(wrong)
	key(KEY_ENTER)
	await frames(2)
	check(same_parts(want, b), "a code with one character wrong leaves the board alone")
	check(ed._share._note.contains("check out"), "and says so (%s)" % ed._share._note)

	# Case is half the alphabet: the same letters in the wrong case is a
	# different code, and must be refused the same way.
	key(KEY_DELETE)
	await type_code(body.to_upper())
	key(KEY_ENTER)
	await frames(2)
	check(same_parts(want, b) or body == body.to_upper(),
		"a code shouted in capitals does not build the board")

	# A 0 is not in the alphabet at all, and the sheet says which character was
	# meant rather than swallowing the key.
	key(KEY_DELETE)
	type_char("0")
	await frames(2)
	check(ed._share.entry.is_empty(), "a 0 never lands in the field")
	check(ed._share._note.contains("zero"), "and the sheet says why (%s)" % ed._share._note)

	# ESC closes the sheet, and only the sheet.
	key(KEY_ESCAPE)
	await frames(2)
	check(not ed._share_open(), "ESC closes the sheet")
	check(sb.editing, "and leaves the editor open behind it")
	key(KEY_ESCAPE)
	await frames(3)
	check(not sb.editing, "the next ESC closes the editor")

	# The header button opens it too, and the slot tabs still fit in front of it.
	sb.set_editing(true)
	await frames(6)
	ed = Views.of(sb).editor
	check(not ed._share_open(), "reopening the editor does not bring the sheet back with it")
	var last := ed.boards.size() - 1
	check(ed._tab_rect(last).end.x <= ed._share_rect().position.x,
		"the tabs fit before the CODE button (%.0f of %.0f)" % [
			ed._tab_rect(last).end.x, ed._share_rect().position.x])
	check(ed._share_rect().end.x <= ed._close_rect().position.x, "which sits clear of CLOSE")
	await click(ed._share_rect().get_center())
	await frames(2)
	check(ed._share_open(), "the CODE button opens the sheet")
	await click((ed._share._layout()["close"] as Rect2).get_center())
	await frames(2)
	check(not ed._share_open(), "and the sheet's own CLOSE shuts it")
	sb.set_editing(false)
	await frames(4)

	# --- the workbench: a code costs what the board costs --------------------
	game.goto_hideout()
	await frames(10)
	game._edit_library_skill(0)
	await frames(6)
	ed = game.editor
	var lib: SkillBoard = ed.current_board()
	var before := lib.duplicate_board()
	check(int(before.used_components().get("SLASH", 0)) == 1,
		"the board being replaced has a SLASH built into it")

	# A build wanting a part that is not in the stash.
	var shared := SkillBoard.new(7, 5, "theirs")
	shared.place("INPUT", Vector2i(0, 2), 0)
	shared.place("DUPLICATE", Vector2i(1, 2), 0)
	shared.place("FIRE", Vector2i(2, 2), 0)
	shared.place("OUTPUT", Vector2i(3, 2), 0)
	var shared_code := BoardCode.encode(shared)
	GameState.stash.clear()
	GameState.stash["FIRE"] = 1

	key(KEY_C)
	await frames(2)
	check(ed._share_open(), "the sheet opens at the workbench too")
	await type_code(shared_code)
	key(KEY_ENTER)
	await frames(2)
	check(same_parts(before, lib), "a build you cannot afford leaves the board as it was")
	check(int(GameState.stash.get("FIRE", 0)) == 1, "and does not spend the parts it could afford")
	check(ed._share._note.contains("DUPLICATE"), "the refusal names what is missing (%s)"
		% ed._share._note)

	# With the missing part in the stash it goes through, and the swap is paid
	# both ways: the old board's parts come back as the new one's go out.
	GameState.stash["DUPLICATE"] = 1
	key(KEY_ENTER)
	await frames(2)
	check(same_parts(shared, lib), "with the part in the stash, the code builds")
	check(int(GameState.stash.get("DUPLICATE", 0)) == 0 and int(GameState.stash.get("FIRE", 0)) == 0,
		"and the parts came out of the stash")
	check(int(GameState.stash.get("SLASH", 0)) == 1,
		"while the board it replaced went back into it (SLASH x%d)"
			% int(GameState.stash.get("SLASH", 0)))
	check(lib.width == before.width and lib.height == before.height,
		"the board keeps its own grid")
	check(lib.skill_name == before.skill_name, "and its own name (%s)" % lib.skill_name)

	# A build laid out on a bigger workbench than this one is turned away whole.
	var huge := SkillBoard.new(11, 9, "big")
	huge.place("SLASH", Vector2i(9, 8), 0)
	await type_code(BoardCode.encode(huge))
	key(KEY_ENTER)
	await frames(2)
	check(same_parts(shared, lib), "a build off a bigger board leaves this one alone")
	check(ed._share._note.contains("11x9"), "and says which board it was drawn on (%s)"
		% ed._share._note)

	say("---- %d failures ----" % fails)
	get_tree().quit()
