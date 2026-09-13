extends Node
## Drives the editor with real mouse events through the viewport, so wheel
## rotation and drag-and-drop are tested the way a player produces them.

const GameScript := preload("res://app/game.gd")
var game: Node
var ed: SkillEditor
var fails := 0

## Same convention as tests/shots.gd: user://shots unless SHOTS_DIR says otherwise.
func shot(name: String) -> void:
	var dir := OS.get_environment("SHOTS_DIR") if OS.has_environment("SHOTS_DIR") else "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))

func say(s: String) -> void:
	print("[EDIT] ", s)

func check(ok: bool, what: String) -> void:
	if ok:
		say("PASS " + what)
	else:
		fails += 1
		push_error("EDITOR FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func move_to(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	get_viewport().push_input(e)
	await get_tree().process_frame
	await get_tree().process_frame

func button(p: Vector2, idx: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = idx
	e.pressed = pressed
	get_viewport().push_input(e)
	await get_tree().process_frame

func cell_pos(c: Vector2i) -> Vector2:
	return SkillEditor.BOARD_ORIGIN + Vector2(c.x * SkillEditor.CELL, c.y * SkillEditor.CELL) + Vector2(25, 25)

func pal_pos(id: String) -> Vector2:
	var ids := ed._palette_ids()
	var i := ids.find(id)
	var col := i % SkillEditor.PAL_COLS
	var row := int(i / SkillEditor.PAL_COLS)
	return SkillEditor.PAL_ORIGIN + Vector2(col * SkillEditor.PAL_W + 40, row * SkillEditor.PAL_H + 20)

func _ready() -> void:
	GameState.reset_profile()
	seed(11)
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_sandbox()   # sandbox: unlimited parts, simplest to reason about
	await frames(12)
	var sb: Sandbox = game.current
	sb.set_editing(true)
	await frames(6)
	ed = Views.of(sb).editor
	var board: SkillBoard = ed.current_board()

	# --- wheel rotation -----------------------------------------------------
	await move_to(cell_pos(Vector2i(3, 0)))
	var before := ed.rotation_step
	await button(cell_pos(Vector2i(3, 0)), MOUSE_BUTTON_WHEEL_UP, true)
	await button(cell_pos(Vector2i(3, 0)), MOUSE_BUTTON_WHEEL_UP, false)
	check(ed.rotation_step == (before + 3) % 4,
		"wheel up turns anticlockwise (%d -> %d)" % [before, ed.rotation_step])
	await button(cell_pos(Vector2i(3, 0)), MOUSE_BUTTON_WHEEL_DOWN, true)
	await button(cell_pos(Vector2i(3, 0)), MOUSE_BUTTON_WHEEL_DOWN, false)
	check(ed.rotation_step == before, "wheel down turns clockwise, back to %d" % ed.rotation_step)

	# --- wheel over a placed part turns that part in place ------------------
	board.place("DAMAGE", Vector2i(5, 1), 0)
	await move_to(cell_pos(Vector2i(5, 1)))
	await button(cell_pos(Vector2i(5, 1)), MOUSE_BUTTON_WHEEL_UP, true)
	await button(cell_pos(Vector2i(5, 1)), MOUSE_BUTTON_WHEEL_UP, false)
	check(int(board.comp_at(Vector2i(5, 1)).get("rot", -1)) == 3,
		"wheel up turns a placed part anticlockwise in place (rot %d)" % int(board.comp_at(Vector2i(5, 1)).get("rot", -1)))
	await button(cell_pos(Vector2i(5, 1)), MOUSE_BUTTON_WHEEL_DOWN, true)
	await button(cell_pos(Vector2i(5, 1)), MOUSE_BUTTON_WHEEL_DOWN, false)
	check(int(board.comp_at(Vector2i(5, 1)).get("rot", -1)) == 0, "wheel down turns it back")
	check(String(board.comp_at(Vector2i(5, 1)).get("id", "")) == "DAMAGE",
		"the part survives being rotated")
	board.erase_at(Vector2i(5, 1))

	# A two-cell part with no room to swing must stay put rather than vanish.
	board.place("AREA", Vector2i(0, 4), 0)
	await move_to(cell_pos(Vector2i(0, 4)))
	await button(cell_pos(Vector2i(0, 4)), MOUSE_BUTTON_WHEEL_UP, true)
	await button(cell_pos(Vector2i(0, 4)), MOUSE_BUTTON_WHEEL_UP, false)
	check(String(board.comp_at(Vector2i(0, 4)).get("id", "")) == "AREA",
		"a blocked rotation leaves the part on the board")
	board.erase_at(Vector2i(0, 4))

	# --- drag from palette onto the board -----------------------------------
	var target := Vector2i(4, 0)
	await move_to(pal_pos("FIRE"))
	await button(pal_pos("FIRE"), MOUSE_BUTTON_LEFT, true)
	check(ed._drag_id == "FIRE", "press on palette picks up FIRE")
	await move_to(cell_pos(target))
	check(ed._hover_cell == target, "drag tracks the hovered cell (got %s want %s, mouse %s)" % [
		str(ed._hover_cell), str(target), str(ed._mouse_pos)])
	await button(cell_pos(target), MOUSE_BUTTON_LEFT, false)
	check(String(board.comp_at(target).get("id", "")) == "FIRE", "release drops FIRE on the board")
	check(ed._drag_id == "", "drag state cleared on release")

	# Capture the drag in flight for a visual check.
	await move_to(pal_pos("DUPLICATE"))
	await button(pal_pos("DUPLICATE"), MOUSE_BUTTON_LEFT, true)
	await move_to(cell_pos(Vector2i(2, 3)) + Vector2(12, 6))
	await frames(2)
	await RenderingServer.frame_post_draw
	shot("10_dragging")
	await button(cell_pos(Vector2i(2, 3)) + Vector2(12, 6), MOUSE_BUTTON_LEFT, false)

	# --- rotate mid-drag, then drop -----------------------------------------
	var bend_cell := Vector2i(4, 1)
	await move_to(pal_pos("BEND"))
	await button(pal_pos("BEND"), MOUSE_BUTTON_LEFT, true)
	await move_to(cell_pos(bend_cell))
	await button(cell_pos(bend_cell), MOUSE_BUTTON_WHEEL_UP, true)
	await button(cell_pos(bend_cell), MOUSE_BUTTON_WHEEL_UP, false)
	var want_rot := ed.rotation_step
	await button(cell_pos(bend_cell), MOUSE_BUTTON_LEFT, false)
	check(int(board.comp_at(bend_cell).get("rot", -1)) == want_rot,
		"part lands with the rotation set mid-drag (rot %d)" % want_rot)

	# --- drag a placed part to a new cell -----------------------------------
	var moved_to := Vector2i(6, 3)
	await move_to(cell_pos(target))
	await button(cell_pos(target), MOUSE_BUTTON_LEFT, true)
	check(board.comp_at(target).is_empty(), "lifting clears the old cell")
	check(ed._drag_id == "FIRE", "lifting carries the part")
	await move_to(cell_pos(moved_to))
	await button(cell_pos(moved_to), MOUSE_BUTTON_LEFT, false)
	check(String(board.comp_at(moved_to).get("id", "")) == "FIRE", "part moved to the new cell")

	# --- a bad drop puts the part back where it was -------------------------
	await move_to(cell_pos(moved_to))
	await button(cell_pos(moved_to), MOUSE_BUTTON_LEFT, true)
	await move_to(Vector2(640, 700))   # dead space below the board
	await button(Vector2(640, 700), MOUSE_BUTTON_LEFT, false)
	check(String(board.comp_at(moved_to).get("id", "")) == "FIRE", "invalid drop restores the part")

	# --- dragging onto the palette discards it ------------------------------
	await move_to(cell_pos(moved_to))
	await button(cell_pos(moved_to), MOUSE_BUTTON_LEFT, true)
	await move_to(pal_pos("ICE"))
	await button(pal_pos("ICE"), MOUSE_BUTTON_LEFT, false)
	check(board.comp_at(moved_to).is_empty(), "dropping on the palette removes the part")

	# --- inventory accounting in a real (limited) pool ----------------------
	sb.set_editing(false)
	game.goto_hideout()
	await frames(8)
	game._edit_library_skill(0)
	await frames(6)
	ed = game.editor
	var lib: SkillBoard = ed.current_board()
	GameState.stash["ICE"] = 1
	var slot_cell := Vector2i(5, 0)
	await move_to(pal_pos("ICE"))
	await button(pal_pos("ICE"), MOUSE_BUTTON_LEFT, true)
	await move_to(cell_pos(slot_cell))
	await button(cell_pos(slot_cell), MOUSE_BUTTON_LEFT, false)
	check(int(GameState.stash.get("ICE", 0)) == 0, "placing spends one from the stash")
	check(String(lib.comp_at(slot_cell).get("id", "")) == "ICE", "ICE placed from the stash")
	# Moving it around must not consume or duplicate stock.
	await move_to(cell_pos(slot_cell))
	await button(cell_pos(slot_cell), MOUSE_BUTTON_LEFT, true)
	await move_to(cell_pos(Vector2i(5, 2)))
	await button(cell_pos(Vector2i(5, 2)), MOUSE_BUTTON_LEFT, false)
	check(int(GameState.stash.get("ICE", 0)) == 0, "moving a placed part costs nothing")
	check(String(lib.comp_at(Vector2i(5, 2)).get("id", "")) == "ICE", "part landed after the move")
	# And removing it returns exactly one.
	await move_to(cell_pos(Vector2i(5, 2)))
	await button(cell_pos(Vector2i(5, 2)), MOUSE_BUTTON_LEFT, true)
	await move_to(pal_pos("ICE"))
	await button(pal_pos("ICE"), MOUSE_BUTTON_LEFT, false)
	check(int(GameState.stash.get("ICE", 0)) == 1, "discarding returns it to the stash")

	# Visual check: arrows only, and no ghost stacked on a placed part.
	lib.place("HOMING", Vector2i(1, 1), 0)
	lib.place("DAMAGE", Vector2i(5, 1), 3)
	ed.selected = "DAMAGE"
	await move_to(cell_pos(Vector2i(5, 1)))
	await frames(2)
	await RenderingServer.frame_post_draw
	shot("11_ports")

	say("---- %d failures ----" % fails)
	get_tree().quit()
