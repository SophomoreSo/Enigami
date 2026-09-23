extends Node
## The assembly screen is drawn in UiKit's pixel look. On the frame, in all three
## places it opens — the bench, a raid and the workbench — with every part on a
## board, joints and breaks, live pulses, a drag, the hovers and a message on
## screen, and a pair of rings the flow can never leave with the dead-code
## notice up over one of them: every PIXEL×PIXEL block of the picture is one
## colour, so nothing it draws is off the grid. On the layout: the biggest board a Workbench grows and
## the palette both end above the info panel, the palette is one block a part
## category with its name beside it in the gutter, every part's name fits its
## palette row, the header's lines fit, and a preview with more to say than rows
## to say it in is cut short and says so.
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

## How far `p` is from the nearest point of the track the dots run on, over
## every shape the editor has outlined. Zero means the track passes through it.
func _on_track(ed: SkillEditor, p: Vector2) -> float:
	var best := INF
	for arc in ed._flow_arcs:
		var loop: PackedVector2Array = arc["loop"]
		for i in loop.size():
			var a := loop[i]
			var step := loop[(i + 1) % loop.size()] - a
			var span := step.length()
			if span <= 0.0:
				continue
			var t := clampf((p - a).dot(step) / (span * span), 0.0, 1.0)
			best = minf(best, (a + step * t).distance_to(p))
	return best

## Which way the dots travel where they cross `p`, one entry a run passing
## through it — two where the outline doubles back on itself, as it does down a
## seam. Empty if no run reaches it.
func _dot_ways(ed: SkillEditor, p: Vector2) -> Array:
	var out: Array = []
	for arc in ed._flow_arcs:
		var loop: PackedVector2Array = arc["loop"]
		var total := ed._loop_length(loop)
		var walked := 0.0
		for i in loop.size():
			var a := loop[i]
			var step := loop[(i + 1) % loop.size()] - a
			var span := step.length()
			if span <= 0.0:
				continue
			var t := clampf((p - a).dot(step) / (span * span), 0.0, 1.0)
			var s := walked + t * span
			walked += span
			if (a + step * t).distance_to(p) > 0.5:
				continue
			# How far into the run that point is, measured the way the run goes.
			var into := fposmod((s - float(arc["from"])) * float(arc["way"]), total)
			if into <= float(arc["span"]) + 0.01:
				out.append((step / span) * float(arc["way"]))
	return out

## Whether the dots crossing `p` run `way`, and only that way.
func _runs_one_way(ed: SkillEditor, p: Vector2, way: Vector2) -> bool:
	var ways := _dot_ways(ed, p)
	if ways.is_empty():
		return false
	for w in ways:
		if (w as Vector2).distance_to(way) > 0.01:
			return false
	return true

func restore(hidden: Array) -> void:
	for n in hidden:
		if is_instance_valid(n):
			n.visible = true

## Every PIXEL×PIXEL block of the frame is one colour. Shrunk to a pixel a block
## and blown back up, a frame only comes back unchanged if no block held two.
## The frame is saved either way, next to the other shots.
func blocks(name: String) -> void:
	await frames(4)
	# The grid is Silkscreen's. A language written in a finer face is still
	# whole pixels, just smaller ones — 둥근모꼴's Hangul is a 16px body where
	# Silkscreen's Latin is an 8px body drawn at twice the size — so the shot is
	# still saved and looked at, and this grid is not claimed of it.
	# `tests/shared/loc_test` is what holds those languages to whole pixels.
	if Loc.pixel_grid() < UiKit.PIXEL:
		await _save_shot(name)
		print("[PIXED] skip %s block check: %s is written on a %d-pixel grid, not %d"
			% [name, Loc.language, Loc.pixel_grid(), UiKit.PIXEL])
		return
	var im := await _save_shot(name)
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

func _save_shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	var dir := OS.get_environment("SHOTS_DIR") if OS.has_environment("SHOTS_DIR") else "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	im.save_png(dir.path_join("pixel_editor_%s.png" % name))
	return im

## One line as another language spells it, read straight off disk: a fit check
## is about the words, and switching the game into a language to read one would
## rebuild every screen listening, including the one being measured.
func _in(lang: String, key: String) -> String:
	var domain := key.get_slice(".", 0)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(
		Loc.DIR.path_join(lang).path_join(domain + ".json")))
	var at = parsed
	for part in key.split(".").slice(1):
		if not (at is Dictionary) or not (at as Dictionary).has(part):
			return ""
		at = (at as Dictionary)[part]
	return String(at)

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
	check(ed._tab_rect(ed.boards.size() - 1).end.x <= ed._share_rect().position.x,
		"four tabs fit before CODE (%.0f of %.0f)" % [ed._tab_rect(3).end.x, ed._share_rect().position.x])
	check(ed._share_rect().end.x <= ed._close_rect().position.x, "and CODE before CLOSE")
	check(PixelDraw.text_width(ed.title_text) <= SkillEditor.TAB_ORIGIN.x - 64.0, "the bench's title fits before the tabs")
	var b := ed.current_board()
	for c in b.cells.keys().duplicate():
		b.erase_at(c)
	# Every part at once no longer fits the 7x5 a starting Workbench grows — the
	# parts fill it to the last cell, leaving none for the hovered ghost below —
	# so the shot is taken on a bigger one. It is still a board the editor draws
	# exactly as it draws any other. It grows a row whenever the palette does;
	# the check below is what says when.
	b.resize_grid(9, 7)
	# Row by row in palette order, so every icon is on the board at once and the
	# parts meet in joints, breaks and dead ends.
	var at := Vector2i.ZERO
	for id in ed._palette_ids():
		var w := int(Components.get_def(id).get("cells", 1))
		if at.x + w > b.width:
			at = Vector2i(0, at.y + 1)
		b.place(id, at, 0)
		at.x += w
	# Where the next part would land is where the hovered ghost is drawn, so what
	# has to be free is that cell — not the rest of the row the last part happens
	# to have filled.
	var ghost := at if at.x < b.width else Vector2i(0, at.y + 1)
	check(ghost.y < b.height,
		"every part fits on the bench's board with a cell to spare for the ghost (%s of %dx%d)"
			% [str(ghost), b.width, b.height])
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
	check(PixelDraw.text_width(red.title_text) <= SkillEditor.TAB_ORIGIN.x - 64.0, "the raid's title fits before the tabs")
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
	check(PixelDraw.text_width(wb.title_text) <= SkillEditor.TAB_ORIGIN.x - 64.0, "the workbench's title fits before the tabs")
	wb.weapon_id = "SWORD"
	wb._sim_dirty = true
	wb._update_hover(wb._cell_center(Vector2i(most.x - 1, most.y - 1)))
	hidden = isolate(wb)
	await blocks("workbench")
	restore(hidden)

	# --- the share sheet, over the same board ---------------------------------
	# Both boxes full, a button under the cursor and something to say, so every
	# piece of it is on screen at once.
	wb._open_share()
	wb._share.entry = BoardCode.clean(BoardCode.encode(big))
	wb._share.note("Short of 2 more FIRE, 1 more DUPLICATE x3 — nothing has been spent.", UiKit.BAD)
	wb._share._hover = "build"
	wb._share._caret = 0.0
	hidden = isolate(wb)
	await blocks("share")
	restore(hidden)
	var sheet := wb._share._layout()
	var panel_rect: Rect2 = sheet["panel"]
	var screen := get_viewport().get_visible_rect().size
	check(panel_rect.position.x >= 0.0 and panel_rect.end.x <= screen.x
		and panel_rect.position.y >= 0.0 and panel_rect.end.y <= screen.y,
		"the share sheet fits on screen (%s in %s)" % [str(panel_rect.size), str(screen)])
	for pair in [["copy", "paste"], ["paste", "build"]]:
		check(not (sheet[pair[0]] as Rect2).intersects(sheet[pair[1]] as Rect2),
			"the sheet's %s and %s buttons do not overlap" % pair)
	# The widest line the alphabet can spell, which is what the box is sized for.
	var widest := "W".repeat(ShareCodePanel.CHARS_PER_LINE) + "_"
	check((sheet["code_box"] as Rect2).size.x - ShareCodePanel.BOX_PAD * 2.0
		>= PixelDraw.text_width(widest),
		"the widest line the alphabet can spell, caret and all, fits the code box")
	# In every language: a translation is free to reword the line, not to run it
	# off the sheet, and the widest face is not always the one being played in.
	for lang in Loc.languages():
		check(PixelDraw.text_width(_in(lang, "editor.share.hint")) <= float(sheet["text_width"]),
			"and the sheet's own controls line fits it in %s" % lang)
	wb._close_share()

	# --- rings the flow can never leave ---------------------------------------
	# Two of them: the board from the report, fed by its INPUT, and an unfed one
	# beside it. Both are drawn switched off, both come out as one shape rather
	# than as a box a part, and the notice is up over the one under the cursor.
	for dc in big.cells.keys().duplicate():
		big.erase_at(dc)
	big.place("INPUT", Vector2i(0, 2), 0)
	big.place("DUPLICATE", Vector2i(1, 2), 3)   # in from the west, out north
	big.place("FIRE", Vector2i(1, 1), 0)
	big.place("DAMAGE", Vector2i(2, 1), 1)
	big.place("FIRE", Vector2i(2, 2), 2)        # closing the ring
	big.place("OUTPUT", Vector2i(3, 2), 0)      # stranded, and drawn faint
	big.place("DELAY", Vector2i(5, 1), 0)
	big.place("DELAY", Vector2i(6, 1), 1)
	big.place("DELAY", Vector2i(6, 2), 2)
	big.place("DELAY", Vector2i(5, 2), 3)       # a ring with nothing feeding it
	wb._sim_dirty = true
	wb._update_hover(wb._cell_center(Vector2i(2, 1)))
	wb._mouse_pos = wb._cell_center(Vector2i(2, 1))
	await frames(2)
	var caught: Dictionary = wb._trace_cache["dead"]
	check(caught.size() == 8, "both rings are marked as dead code (%d parts)" % caught.size())
	# The notice is hung off the whole ring, so it never covers what it names —
	# measured at the tallest the box can be, which is the worst case for it.
	var ring := wb._dead_group_rect(big, Vector2i(2, 1))
	var note := wb._dead_hint_box(get_viewport().get_visible_rect().size, ring,
		SkillEditor.DEAD_BOX_ROWS)
	check(not note.intersects(ring), "and the notice sits clear of the ring it names")
	hidden = isolate(wb)
	await blocks("dead")
	restore(hidden)

	# --- the track round a branch --------------------------------------------
	# A trigger's side branch running back the way the main line came: the two
	# rows touch the whole way along, and the flow crosses between them at one
	# end only. The seam is the one place they are not joined, so the track has
	# to run its whole length rather than stopping partway and leaving the rest
	# of it drawn as a part edge. Twice over: with the branch ending in a leak,
	# where the seam is a slot open at the west, and with it feeding back into
	# the form, where it is a crack with the shape closed round both ends.
	for last_rot in [2, 3]:                          # the last part west, then north
		for bc in big.cells.keys().duplicate():
			big.erase_at(bc)
		big.place("INPUT", Vector2i(0, 1), 0)
		big.place("DASHSLASH", Vector2i(1, 1), 0)    # two cells, out east
		big.place("ON_HIT", Vector2i(3, 1), 0)       # out east, branch south
		big.place("OUTPUT", Vector2i(4, 1), 0)
		big.place("OVERCLOCK", Vector2i(3, 2), 2)    # the branch, running west
		big.place("OVERCLOCK", Vector2i(2, 2), 2)
		big.place("OVERCLOCK", Vector2i(1, 2), last_rot)
		wb._sim_dirty = true
		wb._update_hover(Vector2(-1, -1))
		await frames(2)
		var how := "leaking" if last_rot == 2 else "fed back"
		# Every cell of the seam the flow does not cross, which is every one the
		# editor has left an edge on rather than fusing away.
		for sx in [1, 2]:
			var seam := wb._cell_center(Vector2i(sx, 1)) + Vector2(0, SkillEditor.CELL * 0.5)
			if wb._fused_seam.has(Vector3i(sx, 1, Components.S)):
				continue
			check(_on_track(wb, seam) <= 0.5,
				"%s: the track runs the seam under cell %d (%.1f off it)"
					% [how, sx, _on_track(wb, seam)])
		# And runs it once: a shape's two runs share their ends and cover its
		# outline exactly, so no stretch of it carries dots twice and none none.
		var runs: Dictionary = {}
		for arc in wb._flow_arcs:
			var key := str(arc["loop"])
			runs[key] = float(runs.get(key, 0.0)) + float(arc["span"])
		check(not runs.is_empty(), "%s: the board has a track at all" % how)
		for arc2 in wb._flow_arcs:
			var round_trip := wb._loop_length(arc2["loop"])
			var covered := float(runs[str(arc2["loop"])])
			if not is_equal_approx(covered, round_trip):
				check(false, "%s: a shape is covered exactly once (%.0f of %.0f)"
					% [how, covered, round_trip])
				break
		check(true, "%s: every shape's runs cover its outline exactly once" % how)
		# And every stretch of it runs the way the flow runs under it: east over
		# the parts the main line crosses east, west under the branch running
		# home, and both at once down the seam between them, which is one side of
		# each. The seam is the pair: the two lips are the same line on screen.
		var half := SkillEditor.CELL * 0.5
		check(_runs_one_way(wb, wb._cell_center(Vector2i(2, 1)) - Vector2(0, half), Vector2.RIGHT),
			"%s: the dots run east over the main line" % how)
		check(_runs_one_way(wb, wb._cell_center(Vector2i(2, 2)) + Vector2(0, half), Vector2.LEFT),
			"%s: and west under the branch running home" % how)
		var seam_ways := _dot_ways(wb, wb._cell_center(Vector2i(2, 1)) + Vector2(0, half))
		check(seam_ways.has(Vector2.RIGHT) and seam_ways.has(Vector2.LEFT),
			"%s: and both ways down the seam between them (%s)" % [how, str(seam_ways)])
		# The branch only runs when the trigger fires, so it is drawn drained of
		# the flow's colour: the parts it reaches and nothing else.
		var drained: Array = []
		var coloured: Array = []
		for cx in [1, 2, 3]:
			if wb._conditional.has(Vector2i(cx, 2)):
				drained.append(cx)
			if not wb._conditional.has(Vector2i(cx, 1)):
				coloured.append(cx)
		check(drained == [1, 2, 3] and coloured == [1, 2, 3],
			"%s: the branch is drawn conditional and the main line is not (%s, %s)"
				% [how, str(drained), str(coloured)])
		if last_rot == 3:
			# The branch hands the flow back up into the form at the west end.
			check(_runs_one_way(wb, wb._cell_center(Vector2i(1, 2)) - Vector2(half, 0), Vector2.UP),
				"%s: and north up the side the branch feeds back on" % how)

	# A line of parts with two ends is not a circle and must not be drawn as one:
	# the dots leave where the INPUT hands over, go both ways round the shape and
	# meet again where the flow leaves it, so both sides of it run with the flow.
	for lc in big.cells.keys().duplicate():
		big.erase_at(lc)
	big.place("INPUT", Vector2i(0, 1), 0)
	big.place("FIRE", Vector2i(1, 1), 0)
	big.place("DAMAGE", Vector2i(2, 1), 0)
	big.place("SLASH", Vector2i(3, 1), 0)
	big.place("OUTPUT", Vector2i(4, 1), 0)
	wb._sim_dirty = true
	await frames(2)
	for side in [-1.0, 1.0]:
		var edge := wb._cell_center(Vector2i(2, 1)) + Vector2(0, side * SkillEditor.CELL * 0.5)
		check(_runs_one_way(wb, edge, Vector2.RIGHT),
			"a straight run carries its dots east %s it too (%s)"
				% ["over" if side < 0.0 else "under", str(_dot_ways(wb, edge))])

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
	var panel := wb._pal_panel()
	check(panel.end.y <= info_top, "the palette ends above the info panel (%.0f of %.0f)"
		% [panel.end.y, info_top])
	check(panel.end.x <= vp.x, "and inside the screen (%.0f of %.0f)" % [panel.end.x, vp.x])
	check(panel.position.x >= SkillEditor.PAL_ORIGIN.x - 10.0, "the palette's panel starts at its gutter")
	# One block a category, every part of a category inside its own block, and
	# every block's name written in the gutter beside it rather than over it.
	var blocks := wb._pal_blocks
	var cats: Array = []
	for id in ids:
		var cat := String(Components.get_def(id).get("cat", Components.CAT_STRUCT))
		if not cats.has(cat):
			cats.append(cat)
	check(blocks.size() == cats.size(), "the palette is %d blocks, one a category (%d)"
		% [cats.size(), blocks.size()])
	var split: Array = []
	for cat in cats:
		var rows: Array = []
		for i in ids.size():
			if String(Components.get_def(ids[i]).get("cat", Components.CAT_STRUCT)) == cat:
				rows.append(i)
		if int(rows[-1]) - int(rows[0]) != rows.size() - 1:
			split.append(cat)
	check(split.is_empty(), "every category's parts are one run of rows (split: %s)" % str(split))
	var wide: Array = []
	var room := SkillEditor.PAL_GUTTER - SkillEditor.PAL_SPINE - 8.0
	for block in blocks:
		if PixelDraw.text_width(String(block["name"])) > room:
			wide.append("%s (%.0f of %.0f)" % [block["name"], PixelDraw.text_width(String(block["name"])), room])
	check(wide.is_empty(), "every category name fits the gutter (too wide: %s)" % str(wide))
	var overlap: Array = []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if wb._pal_rect(i).intersects(wb._pal_rect(j)):
				overlap.append("%s/%s" % [ids[i], ids[j]])
	check(overlap.is_empty(), "no two palette rows overlap (%s)" % str(overlap))
	var tight: Array = []
	for i in ids.size():
		var id: String = ids[i]
		# The widest count a row can show.
		wb.inventory[id] = 99
		var part_name := Components.name_for(id)
		if PixelDraw.text_width(part_name) > wb._pal_name_width(i):
			tight.append("%s (%.0f of %.0f)" % [part_name, PixelDraw.text_width(part_name), wb._pal_name_width(i)])
	check(tight.is_empty(), "every part's name fits its palette row beside a count of 99 (too tight: %s)" % str(tight))
	var long_traits: Array = []
	for w in Weapons.ids():
		wb.weapon_id = w
		if PixelDraw.text_width(wb._traits_text()) > vp.x - 96.0:
			long_traits.append(w)
	check(long_traits.is_empty(), "every weapon's traits fit the header (too long: %s)" % str(long_traits))
	for lang in Loc.languages():
		check(PixelDraw.text_width(_in(lang, "editor.hint")) <= vp.x - 96.0,
			"the controls line fits the screen in %s" % lang)

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
	get_tree().quit(1 if fails > 0 else 0)
