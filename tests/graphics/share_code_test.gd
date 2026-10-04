extends Node
## COPY and PASTE, driven the way a player drives them: the two buttons under the
## board, and the clipboard's own keys. COPY puts this board on the clipboard as
## a code; PASTE builds the board out of the code on it, and refuses one that is
## wrong, saying why. What a pasted code costs is checked at the workbench, where
## parts are finite — a code is a blueprint and not the parts, so it spends the
## stash exactly as building the same board by hand would have, and a board that
## cannot be paid for changes nothing at all.
##
## It uses the machine's clipboard, so it puts back whatever was on it when it
## is done. Where there is none, a code goes in through what PASTE hands the
## clipboard's text to (`_paste_code`), and only the clipboard's own checks are
## left out.

const GameScript := preload("res://app/game.gd")

var game: Node
var ed: SkillEditor
var fails := 0
var clipboard := DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)

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
## called, so a key is over before the next line of the test. With `command`,
## the clipboard's modifier held — Command on a Mac, Ctrl elsewhere — which
## both are, since only the one the platform reads is asked.
func key(code: int, command: bool = false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.ctrl_pressed = command
		e.meta_pressed = command
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

## `text` pasted in: put on the clipboard and PASTE pressed — by the button, or
## with `by_key` by the clipboard's own key — or, with no clipboard, handed to
## the editor the way PASTE hands it what the clipboard holds.
func paste_in(text: String, by_key: bool = false) -> void:
	if clipboard:
		DisplayServer.clipboard_set(text)
		if by_key:
			key(KEY_V, true)
		else:
			await click(ed._paste_rect().get_center())
	else:
		ed._paste_code(BoardCode.clean(text).left(BoardCode.max_chars()))
	await frames(2)

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
	var was_on_it := DisplayServer.clipboard_get() if clipboard else ""
	GameState.reset_profile()
	seed(3)
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)

	# --- the bench: parts are free, so this is COPY and PASTE on their own ----
	game.goto_sandbox()
	await frames(12)
	var sb: Sandbox = game.current
	sb.set_editing(true)
	await frames(6)
	ed = Views.of(sb).editor
	var b: SkillBoard = ed.current_board()
	for c in b.cells.keys().duplicate():
		b.erase_at(c)
	# A two-cell part and four facings, so the code carries more than a
	# straight line of defaults — and the weapon's own root, which stays.
	b.place("EXPLODE", Vector2i(1, 1), 0)
	b.place("FIRE", Vector2i(3, 1), 1)
	b.place("ICE", Vector2i(3, 2), 2)
	b.place("DAMAGE", Vector2i(2, 2), 3)
	var want := b.duplicate_board()
	var code := BoardCode.encode(b)
	say("the bench board is " + code)

	# No header: COPY and PASTE under the board, side by side, and the X that
	# closes it in the screen's top-left corner.
	var frame := ed._board_frame()
	check(ed._copy_rect().position.y > frame.end.y
			and ed._paste_rect().position.x > ed._copy_rect().end.x
			and ed._paste_rect().position.y == ed._copy_rect().position.y,
		"COPY and PASTE stand under the board, side by side")
	check(ed._close_rect().position == SkillEditor.CORNER and not ed._close_rect().intersects(frame),
		"and the X stands in the top-left corner, clear of the board")

	if clipboard:
		DisplayServer.clipboard_set("")
		await click(ed._copy_rect().get_center())
		check(DisplayServer.clipboard_get() == code, "COPY puts this board on the clipboard as its code")
		check(ed._message_good and ed._message == Loc.t("editor.share.copied",
				[BoardCode.clean(code).length()]),
			"and says so (%s)" % ed._message)
		check(not code.contains("-"), "a code with no dashes in it (%s)" % code)
		DisplayServer.clipboard_set("")
		key(KEY_C, true)
		await frames(2)
		check(DisplayServer.clipboard_get() == code, "and so does the clipboard's own key")
		check(sb.editing, "which closes nothing on the way")

	# Now wipe the build and put it back out of nothing but the code.
	for c in b.cells.keys().duplicate():
		b.erase_at(c)
	check(b.used_components().is_empty() and b.cells.size() == 1,
		"the build is cleared before the code is pasted, down to the weapon's own part")
	# A stray space in the middle, the way a code comes out of a chat message.
	await paste_in(code.left(10) + " " + code.substr(10))
	check(same_parts(want, b), "PASTE builds the board back out of the code, a stray space and all")
	check(b.cells.size() == want.cells.size(), "every part came back (%d of %d)"
		% [b.cells.size(), want.cells.size()])
	check(ed._message_good and ed._message == Loc.t("editor.share.built", [b.cells.size()]),
		"and says it built it (%s)" % ed._message)

	# A code that is nearly right is refused rather than nearly built.
	var body := BoardCode.clean(code)
	var wrong := body.left(3) + ("W" if body[3] != "W" else "k") + body.substr(4)
	await paste_in(wrong, true)
	check(same_parts(want, b), "a code with one character wrong leaves the board alone")
	check(not ed._message_good and ed._message == SkillEditor.code_error_text(BoardCode.MISTYPED),
		"and says so (%s)" % ed._message)

	# Case is half the alphabet: the same letters in the wrong case is a
	# different code, and must be refused the same way.
	await paste_in(body.to_upper())
	check(same_parts(want, b) or body == body.to_upper(),
		"a code shouted in capitals does not build the board")

	# Nothing on the clipboard a code is made of: PASTE says so and does nothing.
	if clipboard:
		DisplayServer.clipboard_set("— 0 —")
		await click(ed._paste_rect().get_center())
		await frames(2)
		check(same_parts(want, b) and ed._message == Loc.t("editor.share.clipboard_empty"),
			"with nothing a code is made of on the clipboard, PASTE says so (%s)" % ed._message)

	# ESC closes the editor, and so does the X in the corner.
	key(KEY_ESCAPE)
	await frames(3)
	check(not sb.editing, "ESC closes the editor")
	sb.set_editing(true)
	await frames(6)
	ed = Views.of(sb).editor
	await click(ed._close_rect().get_center())
	await frames(2)
	check(not sb.editing, "and so does the X")

	# --- the workbench: a code costs what the board costs --------------------
	game.goto_hideout()
	await frames(10)
	game.hideout_ref.set_weapon("GUN")
	game._edit_weapon_graph()
	await frames(6)
	ed = game.editor
	var lib: SkillBoard = ed.current_board()
	# Something built on the gun, so the swap has a part to give back.
	lib.place("SLASH", Vector2i(1, 2), 0)
	var before := lib.duplicate_board()
	check(int(before.used_components().get("SLASH", 0)) == 1,
		"the board being replaced has a SLASH built into it")

	# A build wanting a part that is not in the stash. Its author's own root is
	# in the code like any other part, and stays behind: this gun has its own.
	var shared := SkillBoard.new(7, 5, "theirs")
	shared.place("PROJECTILE", SkillBoard.ROOT, 0)
	shared.place("DUPLICATE", Vector2i(1, 2), 0)
	shared.place("FIRE", Vector2i(2, 2), 0)
	var shared_code := BoardCode.encode(shared)
	GameState.stash.clear()
	GameState.stash["FIRE"] = 1

	await paste_in(shared_code)
	check(same_parts(before, lib), "a build you cannot afford leaves the board as it was")
	check(int(GameState.stash.get("FIRE", 0)) == 1, "and does not spend the parts it could afford")
	check(ed._message.contains(Components.name_for("DUPLICATE")), "the refusal names what is missing (%s)"
		% ed._message)

	# With the missing part in the stash it goes through, and the swap is paid
	# both ways: the old board's parts come back as the new one's go out.
	GameState.stash["DUPLICATE"] = 1
	await paste_in(shared_code)
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
	await paste_in(BoardCode.encode(huge))
	check(same_parts(shared, lib), "a build off a bigger board leaves this one alone")
	check(ed._message.contains("11x9"), "and says which board it was drawn on (%s)"
		% ed._message)

	if clipboard:
		DisplayServer.clipboard_set(was_on_it)
	say("---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
