extends Node
## The assembly screen is drawn in UiKit's pixel look. On the frame, in all three
## places it opens — the bench, a raid and the workbench — with every part on a
## board, joints and breaks, live pulses, a drag, the hovers and a message on
## screen: every PIXEL×PIXEL block of the picture is one colour, so nothing it
## draws is off the grid. On the layout: the biggest board a Workbench grows and
## the palette both end above the info panel, every part's name fits its palette
## row, the header's lines fit, and a preview with more to say than rows to say
## it in is cut short and says so.
##
## Needs a real renderer: the block check reads the frame back.

const GameScript := preload("res://app/game.gd")

var game: Node
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[PIXED] PASS ", what)
	else:
		fails += 1
		push_error("PIXED FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Hides everything drawn behind `ed`, so the frame is the editor alone: the
## screen under it is not in the pixel look, and the world under it is slid by
## what the camera had left over, a pixel off the grid on purpose.
func isolate(ed: SkillEditor) -> Array:
	var hidden: Array = []
	var own := ed.get_parent()
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var layer := n as CanvasLayer
		if layer != own and layer.visible:
			layer.visible = false
			hidden.append(layer)
	for c in own.get_children():
		if c != ed and c is CanvasItem and (c as CanvasItem).visible:
			(c as CanvasItem).visible = false
			hidden.append(c)
	return hidden

func restore(hidden: Array) -> void:
	for n in hidden:
		if is_instance_valid(n):
			n.visible = true

## Every PIXEL×PIXEL block of the frame is one colour. Shrunk to a pixel a block
## and blown back up, a frame only comes back unchanged if no block held two.
## The frame is saved either way, next to the other shots.
func blocks(name: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	var dir := OS.get_environment("SHOTS_DIR") if OS.has_environment("SHOTS_DIR") else "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	im.save_png(dir.path_join("pixel_editor_%s.png" % name))
	var screen := Vector2i(get_viewport().get_visible_rect().size)
	if im.get_size() != screen:
		print("[PIXED] skip %s block check: the frame is %s, not %s" % [name, im.get_size(), screen])
		return
	var s := UiKit.PIXEL
	var round_trip := im.duplicate() as Image
	round_trip.resize(screen.x / s, screen.y / s, Image.INTERPOLATE_NEAREST)
	round_trip.resize(screen.x, screen.y, Image.INTERPOLATE_NEAREST)
	var same := round_trip.get_data() == im.get_data()
	var split := 0
	var first := Vector2i(-1, -1)
	if not same:
		for y in range(0, screen.y - s + 1, s):
			for x in range(0, screen.x - s + 1, s):
				var c := im.get_pixel(x, y)
				var whole := true
				for dy in s:
					for dx in s:
						if im.get_pixel(x + dx, y + dy) != c:
							whole = false
				if not whole:
					split += 1
					if first.x < 0:
						first = Vector2i(x, y)
	check(same, "%s: every %d×%d block on screen is one colour (%d split, the first at %s)"
		% [name, s, s, split, first])

func _ready() -> void:
	GameState.reset_profile()
	# A new profile keeps whatever facility levels the last one had — resetting
	# does not touch them — so this puts back the Workbench it maxes below, or
	# every run after it starts on the biggest board there is.
	var facilities_before: Dictionary = GameState.facilities.duplicate()
	seed(5)
	# A fourth skill, so the bench brings the most boards it can and the header
	# has the most tabs to fit.
	GameState.new_skill()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(8)

	# --- the bench: every part at once, pulses, a drag and a message ------------
	game.goto_sandbox()
	await frames(12)
	var sb: Sandbox = game.current
	sb.set_editing(true)
	await frames(4)
	var ed: SkillEditor = Views.of(sb).editor
	check(ed.boards.size() == 4, "the bench brings four boards (%d)" % ed.boards.size())
	check(ed._tab_rect(ed.boards.size() - 1).end.x <= ed._close_rect().position.x,
		"four tabs fit before CLOSE (%.0f of %.0f)" % [ed._tab_rect(3).end.x, ed._close_rect().position.x])
	check(ed._text_width(ed.title_text) <= SkillEditor.TAB_ORIGIN.x - 64.0, "the bench's title fits before the tabs")
	var b := ed.current_board()
	for c in b.cells.keys().duplicate():
		b.erase_at(c)
	# Row by row in palette order, so every icon is on the board at once and the
	# parts meet in joints, breaks and dead ends.
	var at := Vector2i.ZERO
	for id in ed._palette_ids():
		var w := int(Components.get_def(id).get("cells", 1))
		if at.x + w > b.width:
			at = Vector2i(0, at.y + 1)
		b.place(id, at, 0)
		at.x += w
	check(at.y < b.height and at.x < b.width, "every part fits on the bench's board, a cell to spare")
	ed._sim_dirty = true
	# Pulses at three points of crossing a part. A long timer holds them there.
	var runner: SkillRunner = ed.runners[ed.slot]
	runner.pulses.clear()
	for spot in [[Vector2i(0, 0), 0.8], [Vector2i(2, 0), 0.35], [Vector2i(3, 2), 0.1]]:
		var pulse := SkillRunner.Pulse.new(spot[0], 1000, Payload.new(), 50)
		pulse.timer = int(1000.0 * (1.0 - float(spot[1])))
		runner.pulses.append(pulse)
	ed.selected = "FIRE"
	ed._update_hover(ed._cell_center(Vector2i(at.x + 1, at.y)))
	ed._drag_id = "DASHSLASH"
	ed._mouse_pos = Vector2(611, 333)
	ed._notify("No room for DASHSLASH there.")
	var hidden := isolate(ed)
	await blocks("bench")
	restore(hidden)
	ed._drag_id = ""
	sb.set_editing(false)
	await frames(2)

	# --- a raid: every hover at once -----------------------------------------
	game._deploy("SWORD", [0, 1, 2])
	await frames(20)
	var raid: Raid = game.current
	raid.set_editing(true)
	await frames(4)
	var red: SkillEditor = Views.of(raid).editor
	check(red._text_width(red.title_text) <= SkillEditor.TAB_ORIGIN.x - 64.0, "the raid's title fits before the tabs")
	red.selected = "SLASH"
	red._hover_pal = 5
	red._hover_tab = 1
	red._hover_close = true
	hidden = isolate(red)
	await blocks("raid")
	restore(hidden)
	raid.set_editing(false)
	await frames(2)

	# --- the workbench: the biggest board, on a weapon that refuses it ---------
	GameState.facilities["workbench"] = int(GameState.FACILITY_INFO["workbench"]["max"])
	var most := GameState.board_size()
	game.goto_hideout()
	await frames(8)
	var big := GameState.new_skill()
	big.place("PROJECTILE", Vector2i(1, int(most.y / 2)), 0)
	game._edit_library_skill(GameState.skill_library.size() - 1)
	await frames(4)
	var wb: SkillEditor = game.editor
	check(wb._text_width(wb.title_text) <= SkillEditor.TAB_ORIGIN.x - 64.0, "the workbench's title fits before the tabs")
	wb.weapon_id = "SWORD"
	wb._sim_dirty = true
	wb._update_hover(wb._cell_center(Vector2i(most.x - 1, most.y - 1)))
	hidden = isolate(wb)
	await blocks("workbench")
	restore(hidden)

	# --- layout -------------------------------------------------------------
	var vp := get_viewport().get_visible_rect().size
	var info_top := vp.y - SkillEditor.INFO_H
	var board_end := SkillEditor.BOARD_ORIGIN + Vector2(most) * SkillEditor.CELL + Vector2(10, 10)
	check(board_end.y <= info_top, "the biggest board (%dx%d) ends above the info panel (%.0f of %.0f)"
		% [most.x, most.y, board_end.y, info_top])
	check(board_end.x <= SkillEditor.PAL_ORIGIN.x - 10.0, "and short of the palette (%.0f of %.0f)"
		% [board_end.x, SkillEditor.PAL_ORIGIN.x - 10.0])
	# The palette's panel runs 10 past its rows on every side.
	var ids := wb._palette_ids()
	check(wb._pal_rect(ids.size() - 1).end.y + 10.0 <= info_top, "the palette ends above the info panel")
	check(wb._pal_rect(SkillEditor.PAL_COLS - 1).end.x + 10.0 <= vp.x, "and inside the screen")
	var tight: Array = []
	for i in ids.size():
		var id: String = ids[i]
		# The widest count a row can show.
		wb.inventory[id] = 99
		var part_name := String(Components.get_def(id)["name"])
		if wb._text_width(part_name) > wb._pal_name_width(i):
			tight.append("%s (%.0f of %.0f)" % [part_name, wb._text_width(part_name), wb._pal_name_width(i)])
	check(tight.is_empty(), "every part's name fits its palette row beside a count of 99 (too tight: %s)" % str(tight))
	var long_traits: Array = []
	for w in Weapons.ids():
		wb.weapon_id = w
		if wb._text_width(wb._traits_text()) > vp.x - 96.0:
			long_traits.append(w)
	check(long_traits.is_empty(), "every weapon's traits fit the header (too long: %s)" % str(long_traits))
	check(wb._text_width(SkillEditor.HINT) <= vp.x - 96.0, "the controls line fits the screen")

	# A preview with more rows than the panel has: the refusal, three outputs,
	# an overclock and the life.
	wb.weapon_id = "SWORD"
	var p := Payload.new()
	p.form = "SLASH"
	var long := {"outputs": [p, p, p], "cycle_seconds": 0.5, "heat": 1.0, "overclock": 2,
		"speed_mul": 1.5, "penalty_seconds": 0.1, "ttl": 6, "triggers": {}}
	var rows := wb._preview_rows(big, long, vp.x - 48.0 - SkillEditor.PAL_ORIGIN.x)
	check(rows.size() == SkillEditor.INFO_ROWS, "a long preview is cut to %d rows (%d)" % [SkillEditor.INFO_ROWS, rows.size()])
	check(String(rows[-1]["text"]).begins_with("…"), "and its last row says what was left out ('%s')" % rows[-1]["text"])

	GameState.facilities = facilities_before
	GameState.save_game()
	print("[PIXED] ---- %d failures ----" % fails)
	get_tree().quit()
