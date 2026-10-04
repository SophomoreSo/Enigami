extends Node
## The assembly board in mobile mode, which is laid out for a thumb and worked
## with one (`SkillEditor`, "for a thumb").
##
## On the layout: the X in the corner, the board with COPY and PASTE under it,
## the tabs, the plates and the two under them are all on the screen and none on
## another; everything a thumb presses is
## a thumb's size; every part in the pool is on some tab; a first workbench's
## grid stands at a thumb's width a cell and the biggest one a workbench grows
## still fits, its cells no smaller than a desk's, with the way out's arrow
## clear of the parts beside it; and the frame is on the PIXEL grid like the
## desk's is.
##
## On the working of it, with a thumb sent the way the system sends one: a tab
## brings its category up; a touch on a plate takes the part in hand and a touch
## on an empty cell sets it down; a touch on a part on the board picks it — and
## moves nothing — for TURN to turn and REMOVE to put back in the bag; a part
## dragged is moved, from a plate or across the board, and thrown at the parts
## it is put away; the weapon's own part is picked, turned and moved the same
## way, and REMOVE leaves it on the board. COPY puts the board on the clipboard
## and PASTE builds it back off it, and the X closes the board.
##
## And at a desk it is the board it was: thrown off under an open board, the
## desk's layout comes back, cell for cell.
##
## Needs a real renderer: the block check reads the frame back.

const GameScript := preload("res://app/game.gd")

var fails := 0
var game: Node
var bench: Sandbox
var ed: SkillEditor
var changes := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[EDTOUCH] PASS ", what)
	else:
		fails += 1
		push_error("EDTOUCH FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)

func screen() -> Vector2:
	return get_viewport().get_visible_rect().size

func on_glass(at: Vector2) -> Vector2:
	return get_window().get_final_transform() * at

## A finger landing, moving or lifting, sent the way the system sends one — so
## it reaches the board as the click the system makes of it.
func touch(at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = on_glass(at)
	e.pressed = pressed
	Input.parse_input_event(e)

func drag(at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = on_glass(at)
	Input.parse_input_event(e)

func tap(at: Vector2) -> void:
	touch(at, true)
	await frames(2)
	touch(at, false)
	await frames(3)

## A thumb that takes whatever is at `from` and carries it to `to`, in steps.
func carry(from: Vector2, to: Vector2) -> void:
	touch(from, true)
	await frames(2)
	for i in range(1, 5):
		drag(from.lerp(to, float(i) / 4.0))
		await frames(2)
	touch(to, false)
	await frames(3)

func layout() -> Dictionary:
	return ed._thumb_layout()

func cell(c: Vector2i) -> Vector2:
	return ed._cell_center(c)

## The middle of the tab for the category `id` is in, and of its plate once that
## tab is up.
func tab_of(id: String) -> Vector2:
	return (layout()["tabs"][ed._tab_of(id)] as Rect2).get_center()

func plate_of(id: String) -> Vector2:
	var i := ed._palette_ids().find(id)
	return ed._pal_rect(i).get_center() if i >= 0 else Vector2(-1, -1)

## The first part in the pool that covers one cell and is in the category of
## index `tab`, so the test names no part the content may rename.
func part_on(tab: int) -> String:
	for id: String in ed._pal_groups()[tab]["ids"]:
		if Components.footprint(id, Vector2i.ZERO, 0).size() == 1:
			return id
	return ""

func at(c: Vector2i) -> String:
	return String(ed.current_board().comp_at(c).get("id", ""))

func rot_at(c: Vector2i) -> int:
	return int(ed.current_board().comp_at(c).get("rot", -1))

func _ready() -> void:
	var was_mode := Touch.mode
	var was_size := DisplayServer.window_get_size()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Touch.set_mode(Touch.ON)
	TouchPad.set_layout({}, false)
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(8)
	game.goto_sandbox()
	await frames(12)
	bench = game.current as Sandbox
	bench.set_editing(true)
	await frames(6)
	ed = Views.of(bench).editor
	ed.board_changed.connect(func() -> void: changes += 1)
	_the_layout()
	await _the_grid()
	await _on_the_grid()
	# Not 1:1 from here: a press sent at a design position proves nothing on the
	# one window where a design position and a window position are the same.
	DisplayServer.window_set_size(Vector2i(1440, 810))
	await frames(6)
	await _the_parts()
	await _a_part_picked()
	await _a_part_dragged()
	await _copy_and_paste()
	await _at_a_desk()
	await _closing()
	Touch.set_mode(was_mode)
	DisplayServer.window_set_size(was_size)
	print("[EDTOUCH] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- where everything stands ------------------------------------------------------

func _the_layout() -> void:
	check(ed.thumb() and bench.editing, "in mobile mode the board is laid out for a thumb")
	var l := layout()
	var vp := Rect2(Vector2.ZERO, screen())
	var named := {"X": l["close"], "the message": l["message"], "COPY": l["copy"], "PASTE": l["paste"],
		"the board": l["frame"],
		"the plates": l["plates"], "TURN": l["turn"], "REMOVE": l["remove"]}
	var tabs: Array = l["tabs"]
	for i in tabs.size():
		named["tab %d" % i] = tabs[i]
	var off: Array = []
	var over: Array = []
	var keys := named.keys()
	for i in keys.size():
		var a: Rect2 = named[keys[i]]
		if not vp.encloses(a):
			off.append(keys[i])
		for j in range(i + 1, keys.size()):
			if a.intersects(named[keys[j]]):
				over.append("%s/%s" % [keys[i], keys[j]])
	check(off.is_empty(), "everything on it is on the screen (%s)" % str(off))
	check(over.is_empty(), "and nothing stands on anything else (%s)" % str(over))
	var small: Array = []
	for k in ["COPY", "PASTE", "TURN", "REMOVE"]:
		var r: Rect2 = named[k]
		if r.size.y < SkillEditor.THUMB_BTN or r.size.x < 120.0:
			small.append("%s %s" % [k, str(r.size)])
	var x: Rect2 = named["X"]
	if x.size.x < SkillEditor.THUMB_BTN or x.size.y < SkillEditor.THUMB_BTN:
		small.append("X %s" % str(x.size))
	check(x.position == Vector2(SkillEditor.THUMB_EDGE, SkillEditor.THUMB_EDGE),
		"the X is in the screen's top-left corner (%s)" % str(x.position))
	for i in tabs.size():
		var r: Rect2 = tabs[i]
		if r.size.y < 60.0 or r.size.x < 120.0:
			small.append("tab %d %s" % [i, str(r.size)])
	check(small.is_empty(), "the buttons and the tabs are a thumb's size (%s)" % str(small))
	check(tabs.size() == ed._pal_groups().size(), "there is a tab a category (%d)" % tabs.size())
	# The way out is on the board's frame, its head outside it: on the screen,
	# and in the room between the board and the parts rather than on them.
	var arrow := ed._way_out_rect(ed.current_board())
	check(vp.encloses(arrow) and arrow.intersects(l["frame"]) and arrow.end.x > (l["frame"] as Rect2).end.x
			and not arrow.intersects(l["column"]),
		"the way out's arrow stands on the board's right edge, clear of the parts (%s)" % str(arrow))
	check((l["column"] as Rect2).encloses(l["plates"]) and (l["column"] as Rect2).encloses(l["turn"])
			and (l["column"] as Rect2).encloses(l["remove"]),
		"the plates, TURN and REMOVE are one column, which is where a part is thrown away")

	# Every part is on some tab, on a plate a thumb can land on, with its name
	# whole on it at a thumb's size.
	var seen := {}
	var cramped: Array = []
	var clipped: Array = []
	for i in tabs.size():
		ed._tab = i
		var ids := ed._palette_ids()
		for k in ids.size():
			var id: String = ids[k]
			seen[id] = true
			var r := ed._pal_rect(k)
			if r.size.y < 56.0 or not (l["plates"] as Rect2).grow(0.5).encloses(r):
				cramped.append("%s %s" % [id, str(r)])
			var part := Components.name_for(id)
			var size := Loc.text_size(part, UiKit.THUMB_TEXT)
			if PixelDraw.text_width(part, size) > r.size.x - 56.0 - 14.0 - 60.0 - 12.0:
				clipped.append(part)
	ed._tab = 0
	check(seen.size() == ed._pool_ids().size(), "every part in the pool is on a tab (%d of %d)"
		% [seen.size(), ed._pool_ids().size()])
	check(cramped.is_empty(), "each on a plate a thumb's size, in the column's room (%s)" % str(cramped))
	check(clipped.is_empty(), "with its name whole on it, written big (%s)" % str(clipped))

## --- the grid ----------------------------------------------------------------------

## A cell is as big as the room beside the parts lets it be: a thumb's width on
## a first workbench's grid, and never under a desk's on the biggest.
func _the_grid() -> void:
	var b := ed.current_board()
	check(b.width == 7 and b.height == 5 and ed.cell_size() >= 80.0,
		"a first workbench's grid stands at a thumb's width a cell (%.0f, a desk's is %d)"
			% [ed.cell_size(), SkillEditor.CELL])
	check(int(ed.cell_size() / UiKit.PIXEL) % 2 == 1,
		"an odd number of PIXELs, so an icon lands in the middle of one")
	check(ed.board_origin() == ed._px.snap(ed.board_origin()), "and the board stands on the PIXEL grid")
	# Every grid a workbench grows, on a board of its own.
	var layer := CanvasLayer.new()
	add_child(layer)
	var probe := SkillEditor.new()
	layer.add_child(probe)
	var tight: Array = []
	for level in range(1, int(GameState.FACILITY_INFO["workbench"]["max"]) + 1):
		probe.configure(SkillBoard.new(6 + level, 4 + level, "probe"), {}, true)
		await frames(2)
		var l := probe._thumb_layout()
		var frame: Rect2 = l["frame"]
		var side := float(l["cell"])
		if side < float(SkillEditor.CELL) or int(side / UiKit.PIXEL) % 2 != 1 \
				or not Rect2(Vector2.ZERO, screen()).encloses(frame) \
				or frame.intersects(l["column"]) or frame.intersects(l["close"]) \
				or not Rect2(Vector2.ZERO, screen()).encloses(l["paste"]) \
				or (l["paste"] as Rect2).intersects(l["column"]) \
				or probe._way_out_rect(probe.current_board()).intersects(l["column"]):
			tight.append("level %d: cell %.0f, board %s" % [level, side, str(frame)])
	check(tight.is_empty(),
		"every grid a workbench grows fits beside the parts, way out, COPY and PASTE and all, at no less than a desk's cell (%s)" % str(tight))
	layer.queue_free()
	await frames(2)

## Every PIXEL×PIXEL block of the frame is one colour, with the board dressed:
## parts on it, one picked, a tab of plates up and a refusal beside the X.
func _on_the_grid() -> void:
	var form := part_on(0)
	await tap(tab_of(form))
	await tap(plate_of(form))
	await tap(cell(Vector2i(3, 0)))
	# The weapon's own part picked, and REMOVE pressed on it: a refusal, beside
	# the X. Then the part just set down picked in its place.
	await tap(cell(ed.current_board().root))
	await tap((layout()["remove"] as Rect2).get_center())
	await tap(cell(Vector2i(3, 0)))
	var hidden: Array = []
	var own := ed.get_parent()
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var canvas := n as CanvasLayer
		if canvas != own and canvas.visible:
			canvas.visible = false
			hidden.append(canvas)
	for c in own.get_children():
		if c != ed and c is CanvasItem and (c as CanvasItem).visible:
			(c as CanvasItem).visible = false
			hidden.append(c)
	await frames(4)
	if UiKit.pixel_grid() < UiKit.PIXEL:
		print("[EDTOUCH] skip the block check: %s is not written on this grid" % Loc.language)
	else:
		var drawn := [false]
		RenderingServer.frame_post_draw.connect(func() -> void: drawn[0] = true, CONNECT_ONE_SHOT)
		for i in 240:
			await frames(1)
			if drawn[0]:
				break
		var im := get_viewport().get_texture().get_image()
		var size := Vector2i(screen())
		if im.get_size() != size:
			print("[EDTOUCH] skip the block check: the frame is %s, not %s" % [im.get_size(), size])
		else:
			var s := UiKit.PIXEL
			var round_trip := im.duplicate() as Image
			round_trip.resize(size.x / s, size.y / s, Image.INTERPOLATE_NEAREST)
			round_trip.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
			var split := 0
			var first := Vector2i(-1, -1)
			if round_trip.get_data() != im.get_data():
				for y in range(0, size.y - s + 1, s):
					for x in range(0, size.x - s + 1, s):
						var c := im.get_pixel(x, y)
						if im.get_pixel(x + 1, y) != c or im.get_pixel(x, y + 1) != c or im.get_pixel(x + 1, y + 1) != c:
							split += 1
							if first.x < 0:
								first = Vector2i(x, y)
			check(split == 0, "every %d×%d block of the thumb's board is one colour (%d split, the first at %s)"
				% [s, s, split, str(first)])
	for n in hidden:
		if is_instance_valid(n):
			n.visible = true
	# And the board as it was, for what follows: the part is picked still.
	await tap((layout()["remove"] as Rect2).get_center())
	check(at(Vector2i(3, 0)) == "", "the part set down for the picture is taken off again")

## --- the parts ------------------------------------------------------------------------

func _the_parts() -> void:
	var form := part_on(0)
	var flow := part_on(ed._pal_groups().size() - 2)
	await tap(tab_of(flow))
	check(ed._tab == ed._tab_of(flow) and ed._palette_ids().has(flow) and not ed._palette_ids().has(form),
		"a tab brings its own category's parts up, and no other's")
	await tap(tab_of(form))
	check(ed._palette_ids().has(form), "and another tab, its own")
	var before := changes
	await tap(plate_of(form))
	check(ed.selected == form and changes == before and at(Vector2i(4, 0)) == "",
		"a touch on a plate takes the part in hand, and sets nothing down")
	check(ed._hover_pal < 0 and ed._hover_cell.x < 0, "and a thumb that has lifted is hovering over nothing")
	await tap(cell(Vector2i(4, 0)))
	check(at(Vector2i(4, 0)) == form and changes == before + 1,
		"a touch on an empty cell sets it down there (%s)" % at(Vector2i(4, 0)))
	await tap(cell(Vector2i(5, 0)))
	check(at(Vector2i(5, 0)) == form, "and the next touch sets down another, the part still in hand")

## --- a part on the board, picked --------------------------------------------------------

func _a_part_picked() -> void:
	var spot := Vector2i(4, 0)
	var id := at(spot)
	var faced := rot_at(spot)
	var before := changes
	# Some other category's tab up, so the part's own has to come up for it.
	ed._tab = ed._pal_groups().size() - 1
	await tap(cell(spot))
	check(ed._picked == spot, "a touch on a part on the board picks it")
	check(at(spot) == id and rot_at(spot) == faced and changes == before,
		"and moves nothing: it is where it was, facing the way it faced")
	check(ed._tab == ed._tab_of(id) and ed.selected == id,
		"its category's tab comes up with its plate lit, which is what names it")
	var turn := (layout()["turn"] as Rect2).get_center()
	var remove := (layout()["remove"] as Rect2).get_center()
	await tap(turn)
	check(rot_at(spot) == (faced + 1) % 4 and ed._picked == spot and changes == before + 1,
		"TURN turns it where it stands, and it is picked still (%d to %d)" % [faced, rot_at(spot)])
	await tap(turn)
	check(rot_at(spot) == (faced + 2) % 4, "and again")
	await tap(cell(spot))
	check(ed._picked == SkillEditor.NOWHERE, "a second touch lets it go")
	var facing := ed.rotation_step
	await tap(turn)
	check(ed.rotation_step == (facing + 1) % 4 and rot_at(spot) == (faced + 2) % 4,
		"with nothing picked TURN turns the part in hand, for the next one set down")
	before = changes
	await tap(remove)
	check(at(spot) == id and changes == before, "and REMOVE has nothing to take off")
	await tap(cell(spot))
	await tap(remove)
	check(at(spot) == "" and ed._picked == SkillEditor.NOWHERE and changes == before + 1,
		"picked, REMOVE puts it back in the bag")

	# The weapon's own part is where the graph starts, and the hand has it like
	# any other: picked, turned, dragged. REMOVE leaves it on the board.
	var b := ed.current_board()
	var root: Vector2i = b.root
	var root_id := at(root)
	var root_rot := rot_at(root)
	await tap(cell(root))
	check(ed._picked == root and ed.selected == root_id,
		"the weapon's own part is picked like any other")
	await tap(turn)
	check(b.root == root and rot_at(root) == (root_rot + 1) % 4,
		"TURN turns it where it stands (%d to %d)" % [root_rot, rot_at(root)])
	for i in 3:
		await tap(turn)
	check(rot_at(root) == root_rot, "and round again to the way it faced")
	ed._message_time = 0.0
	before = changes
	await tap(remove)
	check(at(root) == root_id and b.root == root and changes == before and ed._message_time > 0.0,
		"REMOVE leaves it on the board, and the plate beside the X says why")
	await tap(cell(root))
	check(ed._picked == SkillEditor.NOWHERE, "a second touch lets it go")
	var over := root + Vector2i(-2, 0)
	await carry(cell(root), cell(over))
	check(b.root == over and at(over) == root_id and at(root) == "" and changes == before + 1,
		"dragged, it moves, and the flow starts where it is now (%s)" % str(b.root))
	await carry(cell(over), cell(root))
	check(b.root == root and rot_at(root) == root_rot, "and dragged back, it is where it was")

## --- a part dragged ---------------------------------------------------------------------

func _a_part_dragged() -> void:
	var from := Vector2i(5, 0)
	var to := Vector2i(5, 3)
	var id := at(from)
	await carry(cell(from), cell(to))
	check(at(from) == "" and at(to) == id, "a part dragged across the board is moved (%s)" % at(to))
	check(ed._picked == SkillEditor.NOWHERE, "and a drag picks nothing")
	var stat := part_on(2)
	await tap(tab_of(stat))
	await carry(plate_of(stat), cell(Vector2i(6, 4)))
	check(at(Vector2i(6, 4)) == stat, "one dragged off its plate is set down where the thumb lifts")
	await carry(cell(Vector2i(6, 4)), (layout()["plates"] as Rect2).get_center())
	check(at(Vector2i(6, 4)) == "", "and one dragged back onto the parts is put away")
	await carry(cell(to), Vector2(cell(to).x, screen().y - 4.0))
	check(at(to) == id, "one let go nowhere goes back where it was")

## --- COPY and PASTE ------------------------------------------------------------------------

## A thumb on COPY puts the board on the clipboard, and one on PASTE builds the
## board back off it — the same board, here. The machine's clipboard is put back
## as it was; with none, there is nothing here to try.
func _copy_and_paste() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		return
	var was := DisplayServer.clipboard_get()
	var b := ed.current_board()
	var code := BoardCode.encode(b)
	DisplayServer.clipboard_set("")
	ed._message_time = 0.0
	await tap(ed._copy_rect().get_center())
	check(DisplayServer.clipboard_get() == code, "a thumb on COPY puts the board on the clipboard")
	check(ed._message_time > 0.0 and ed._message_good, "and the plate beside the X says so")
	var before := b.duplicate_board()
	await tap(ed._paste_rect().get_center())
	check(BoardCode.encode(b) == BoardCode.encode(before) and ed._message_good and bench.editing,
		"a thumb on PASTE builds the board off it — the same one again")
	DisplayServer.clipboard_set(was)

## --- a desk ----------------------------------------------------------------------------------

## Thrown off with the board open — the pause menu comes up over it, and its
## controls page is where the mode is thrown — the desk's board comes back.
func _at_a_desk() -> void:
	Touch.set_mode(Touch.OFF)
	await frames(4)
	check(not ed.thumb() and ed.cell_size() == float(SkillEditor.CELL)
			and ed.board_origin() == SkillEditor.BOARD_ORIGIN + ed._inset(),
		"at a desk the board is a desk's: the same cell, in the same place")
	check(ed._palette_ids().size() == ed._pool_ids().size(), "with every part in its rows at once")
	check(ed._close_rect() == Rect2(SkillEditor.CORNER, Vector2.ONE * SkillEditor.CLOSE_SIDE),
		"and the X a desk's, in its corner")
	Touch.set_mode(Touch.ON)
	await frames(4)
	check(ed.thumb() and ed.cell_size() > float(SkillEditor.CELL), "and thrown back, a thumb's again")

func _closing() -> void:
	await tap(ed._close_rect().get_center())
	check(not bench.editing, "a thumb on the X closes the board")
