class_name SkillEditor
extends Control

## The assembly screen. It is deliberately not a safe menu: in a raid the world
## keeps running behind it, so the panel stays translucent and compact and every
## action is a single click.
##
## Drawn in UiKit's pixel look, like the title and its settings: text is the
## pixel face at PIXEL_TEXT, and every fill, border, arrow and icon is whole
## PIXELs laid on the PIXEL grid, so the board reads as the same pixel art as the
## world under it. All of it goes through `PixelDraw`, which snaps to that grid.
## The pixel face has almost none of the symbols in `Style`'s part glyphs, so
## parts are drawn as their `Style.component_icon` instead.
##
## The parts on the right are grouped by the category the rules give them —
## forms, elements, stats and the rest — each block named down the gutter beside
## it in the category's own colour, which is the colour its parts wear.
##
## CODE, in the header, drops the share sheet (`ShareCodePanel`) over all of it:
## the board on the grid written out as a code, and a field to build somebody
## else's board from theirs. What a pasted code costs is decided here — see
## `_build_from_code`.

signal board_changed(slot: int)
signal closed()

const CELL := 50
const BOARD_ORIGIN := Vector2(48, 104)
## The palette's top-left, the gutter its category names sit in included.
const PAL_ORIGIN := Vector2(626, 104)
## Two wide columns of one-line rows rather than four of two-line tiles: the
## pixel face runs up to twice as wide as the one the palette was laid out for,
## and the longest part name takes 130 of a row.
const PAL_COLS := 2
const PAL_W := 244
## Row pitch. Seventeen rows of parts have to end above the info panel, and at
## the 26 this was they do not: a row lost two PIXELs when the behaviour block
## grew to four rows. A row is PAL_H - 4 tall, which still clears the 14-PIXEL
## icon inside it.
const PAL_H := 24
## A category's name is written down the gutter beside its block rather than on
## a header row above it: there are seven of them, and seven more rows do not
## fit between the header and the info panel. The spine is the rule the name
## and the block hang off, PAL_SPINE short of the first column.
const PAL_GUTTER := 122.0
const PAL_SPINE := 10.0
const PAL_GROUP_GAP := 6.0
## The baseline of a row's text, from the top of the row: capitals stand 10
## tall, so this leaves 6 above them and 4 under.
const PAL_TEXT_Y := 16.0

var boards: Array = []               ## Array[SkillBoard]
var slot: int = 0
var inventory: Dictionary = {}       ## component id -> count (the live pool)
var unlimited: bool = false          ## sandbox
var runners: Array = []              ## Array[SkillRunner] for live flow display
var title_text: String = "SKILL ASSEMBLY"
var weapon_id: String = "SWORD"

var selected: String = ""
var rotation_step: int = 0
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _hover_pal: int = -1
var _hover_tab: int = -1
var _hover_close: bool = false
var _hover_share: bool = false
## Drag state. `_drag_source` is -1 for a part pulled off the palette and 1 for
## one lifted off the board (which remembers where it came from so a bad drop
## can put it back instead of destroying it).
var _drag_id: String = ""
var _drag_source: int = 0
var _drag_from: Vector2i = Vector2i(-1, -1)
var _drag_from_rot: int = 0
var _mouse_pos: Vector2 = Vector2.ZERO
var _sim_cache: Dictionary = {}
var _trace_cache: Dictionary = {}
var _sim_dirty: bool = true
## How far each part sits from the INPUT along the joints that carry flow, and
## the furthest of them. The edge highlight is driven off these — see
## `_rebuild_flow` — and `_flow_time` is what walks it along.
var _flow_depth: Dictionary = {}
## Every boundary that carries flow, as Vector3i(cell.x, cell.y, dir). Both
## cells sharing a boundary are filed under it: flush against each other they
## are the same line on screen, and it is the seam neither of them draws.
var _flow_joint: Dictionary = {}
## The track the dots run on: the silhouette of each wired shape, cut open and
## kept as runs rather than loops. Each is {pts, side}, ordered from the INPUT
## end towards the far end, `side` saying which way round is the shape's inside.
## It is worked out from the same `_fused` test that decides which seams are
## drawn, so what looks like one shape is one outline.
var _flow_arcs: Array = []
var _flow_time: float = 0.0
var _message: String = ""
var _message_time: float = 0.0
## The palette, laid out once: a row per part and a block per category, both
## drawn and hit-tested from the same rects. See `_build_palette`.
var _pal_rows: Array = []
var _pal_blocks: Array = []
var _pal_height: float = 0.0
var _ports: Array = []               ## PORT turned to face each direction
var _arrows: Array = []              ## ARROW likewise, for the drag chip
## The share sheet, built the first time it is asked for and kept after that.
var _share: ShareCodePanel = null
var _px := PixelDraw.new(self)

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for d in 4:
		_ports.append(PixelDraw.turn(PORT, d))
		_arrows.append(PixelDraw.turn(ARROW, d))
	set_process(true)

func configure(b: Array, inv: Dictionary, unlim: bool, rs: Array = []) -> void:
	boards = b
	inventory = inv
	unlimited = unlim
	runners = rs
	slot = clampi(slot, 0, maxi(boards.size() - 1, 0))
	_sim_dirty = true
	# The hosts that keep an editor between openings call this every time they
	# raise it: a share sheet left up would come back over a different board.
	_close_share()

func current_board() -> SkillBoard:
	if slot < 0 or slot >= boards.size():
		return null
	return boards[slot]

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_flow_time += delta
	if _message_time > 0.0:
		_message_time -= delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_pos = event.position
		_update_hover(event.position)
		accept_event()
	elif event is InputEventMouseButton:
		_mouse_pos = event.position
		_update_hover(event.position)
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					_press_left()
				MOUSE_BUTTON_RIGHT:
					_click_right()
				MOUSE_BUTTON_WHEEL_UP:
					_rotate(CCW)
				MOUSE_BUTTON_WHEEL_DOWN:
					_rotate(CW)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_release_left()
		accept_event()

## Keys are handled here rather than in _gui_input so they work whether or not
## the panel holds focus, and are marked handled so the screen that opened the
## editor does not act on the same press and re-open it.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	# The share sheet takes the whole keyboard while it is up, its own ESC
	# included: a key falling through it would turn a part or close the editor
	# behind the sheet, and ESC would leave the sheet standing over nothing.
	if _share_open():
		_share.handle_key(event as InputEventKey)
		get_viewport().set_input_as_handled()
		return
	match (event as InputEventKey).keycode:
		KEY_C:
			_open_share()
		KEY_R:
			_rotate(CCW)
		KEY_1, KEY_2, KEY_3, KEY_4:
			var s: int = (event as InputEventKey).keycode - KEY_1
			if s < boards.size():
				slot = s
				_sim_dirty = true
				Audio.play("ui")
		KEY_ESCAPE, KEY_TAB:
			closed.emit()
		_:
			return
	get_viewport().set_input_as_handled()

## The slot tabs share the header's top row with the title, CODE and CLOSE.
const TAB_ORIGIN := Vector2(420, 14)
const TAB_H := 30.0
const TAB_GAP := 8.0
const TAB_MAX_W := 236.0
const CLOSE_W := 100.0
const SHARE_W := 92.0
const BTN_GAP := 8.0

## Each tab as wide as the room between the title and the buttons allows, up to
## TAB_MAX_W: the sandbox can bring four boards.
func _tab_rect(i: int) -> Rect2:
	var room := _share_rect().position.x - 16.0 - TAB_ORIGIN.x
	var n := maxi(boards.size(), 1)
	var w := minf(TAB_MAX_W, floorf((room + TAB_GAP) / n / PX) * PX - TAB_GAP)
	return Rect2(TAB_ORIGIN + Vector2(i * (w + TAB_GAP), 0), Vector2(w, TAB_H))

func _close_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 16.0 - CLOSE_W, 14.0, CLOSE_W, 30.0)

## Beside CLOSE, because a board is shared from the same place it is left.
func _share_rect() -> Rect2:
	return Rect2(_close_rect().position.x - BTN_GAP - SHARE_W, 14.0, SHARE_W, 30.0)

func _update_hover(pos: Vector2) -> void:
	_hover_cell = Vector2i(-1, -1)
	_hover_pal = -1
	_hover_tab = -1
	_hover_share = _share_rect().has_point(pos)
	_hover_close = _close_rect().has_point(pos)
	if _hover_close or _hover_share:
		return
	for i in boards.size():
		if _tab_rect(i).has_point(pos):
			_hover_tab = i
			return
	var b := current_board()
	if b != null:
		var rel := pos - BOARD_ORIGIN
		if rel.x >= 0 and rel.y >= 0:
			var c := Vector2i(int(rel.x / CELL), int(rel.y / CELL))
			if b.in_bounds(c):
				_hover_cell = c
	if _pal_panel().has_point(pos):
		for i in _pal_list().size():
			if _pal_rect(i).has_point(pos):
				_hover_pal = i
				return

## Every part the palette offers, in the order its rows come — the pool's own
## order, gathered into category blocks.
func _palette_ids() -> Array:
	var ids: Array = []
	for row in _pal_list():
		ids.append(String(row["id"]))
	return ids

## The pool the palette is laid out from: the structural parts, always at hand,
## then everything that drops.
func _pool_ids() -> Array:
	var ids: Array = []
	ids.append_array(Components.STRUCTURAL)
	ids.append_array(Components.LOOT_POOL)
	return ids

## Rotation steps advance clockwise on screen (east -> south), so scrolling up
## turns a part anticlockwise.
const CW := 1
const CCW := -1

## The wheel turns whatever the cursor is on: a part already placed gets rotated
## in place, otherwise it sets the facing for the next placement.
func _rotate(dir: int) -> void:
	if _drag_id == "" and _hover_cell.x >= 0:
		var b := current_board()
		if b != null and not b.comp_at(_hover_cell).is_empty():
			_rotate_placed(b, _hover_cell, dir)
			return
	rotation_step = (rotation_step + dir + 4) % 4
	Audio.play("ui")

func _rotate_placed(b: SkillBoard, cell: Vector2i, dir: int) -> void:
	var origin: Vector2i = b.origin_at(cell)
	var entry := b.comp_origin_at(origin)
	var id: String = entry["id"]
	var old_rot: int = entry["rot"]
	var new_rot: int = (old_rot + dir + 4) % 4
	b.erase_at(origin)
	if not b.can_place(id, origin, new_rot):
		# A two-cell part may have nowhere to swing; leave it as it was.
		b.place(id, origin, old_rot)
		_notify("No room to turn %s there." % id)
		Audio.play("deny")
		return
	b.place(id, origin, new_rot)
	rotation_step = new_rot
	_sim_dirty = true
	Audio.play("ui")
	board_changed.emit(slot)

## Press starts either a drag (from the palette, or lifting a placed part) or a
## plain click-to-place on an empty cell.
func _press_left() -> void:
	if _hover_close:
		Audio.play("ui")
		closed.emit()
		return
	if _hover_share:
		_open_share()
		return
	if _hover_tab >= 0:
		slot = _hover_tab
		_sim_dirty = true
		Audio.play("ui")
		return
	if _hover_pal >= 0:
		selected = String(_palette_ids()[_hover_pal])
		_drag_id = selected
		_drag_source = -1
		_drag_from = Vector2i(-1, -1)
		Audio.play("ui")
		return
	if _hover_cell.x < 0:
		return
	var b := current_board()
	if b == null:
		return

	# Lifting a placed part: it leaves the board but not the pool, so it can be
	# dropped back down, returned to its old cell, or thrown at the palette.
	var existing := b.comp_at(_hover_cell)
	if not existing.is_empty():
		var origin = b.origin_at(_hover_cell)
		_drag_id = String(existing["id"])
		_drag_source = 1
		_drag_from = origin
		_drag_from_rot = int(existing["rot"])
		rotation_step = _drag_from_rot
		selected = _drag_id
		b.erase_at(_hover_cell)
		_sim_dirty = true
		Audio.play("erase")
		return

	if selected != "":
		_place_from_palette(_hover_cell)

func _release_left() -> void:
	if _drag_id == "":
		return
	var id := _drag_id
	var src := _drag_source
	_drag_id = ""
	_drag_source = 0

	if _hover_cell.x >= 0 and _drop_on(id, src, _hover_cell):
		return
	if src != 1:
		return  # a palette drag that went nowhere costs nothing

	# Dropping a lifted part on the palette discards it back into the pool;
	# anywhere else invalid, it simply goes back where it was. The whole panel
	# counts, gutter and the gaps between blocks included: a part thrown at the
	# palette was thrown away wherever on it it landed.
	if _hover_pal >= 0 or _pal_panel().has_point(_mouse_pos):
		_give(id)
		Audio.play("erase")
		board_changed.emit(slot)
		return
	var b := current_board()
	if b != null:
		b.place(id, _drag_from, _drag_from_rot)
		rotation_step = _drag_from_rot
	_sim_dirty = true

func _drop_on(id: String, src: int, cell: Vector2i) -> bool:
	var b := current_board()
	if b == null or not b.can_place(id, cell, rotation_step):
		if src == -1:
			_notify("No room for %s there." % id)
			Audio.play("deny")
		return false
	if src == -1 and not _take(id):
		_notify("No %s left in the bag." % id)
		Audio.play("deny")
		return false
	# Dropping onto an occupied cell returns the part underneath to the pool.
	var existing := b.comp_at(cell)
	if not existing.is_empty():
		_give(String(existing["id"]))
	b.place(id, cell, rotation_step)
	_sim_dirty = true
	Audio.play("place")
	board_changed.emit(slot)
	return true

func _place_from_palette(cell: Vector2i) -> void:
	_drop_on(selected, -1, cell)

## Kept for click-driven callers (and the smoke test): press then release.
func _click_left() -> void:
	_press_left()
	_release_left()

func _click_right() -> void:
	if _hover_cell.x < 0:
		return
	var b := current_board()
	if b == null:
		return
	var removed := b.erase_at(_hover_cell)
	if removed != "":
		_give(removed)
		_sim_dirty = true
		Audio.play("erase")
		board_changed.emit(slot)

func _take(id: String) -> bool:
	if unlimited or Components.is_structural(id):
		return true
	return GameState.take_component(id, inventory)

func _give(id: String) -> void:
	if unlimited or Components.is_structural(id):
		return
	GameState.return_component(id, inventory)

func _notify(msg: String) -> void:
	_message = msg
	_message_time = 2.2

## --- sharing ----------------------------------------------------------------
## A board is a circuit, and a circuit is something a player wants to hand to
## another player. `BoardCode` turns this one into a code and back; the sheet
## shows them and collects them, and everything the game has a say in — whether
## the build fits this workbench's grid, and whether the bag can pay for it —
## is decided here, where the board and the pool are.
func _share_open() -> bool:
	return _share != null and is_instance_valid(_share) and _share.visible

func _open_share() -> void:
	# Never with a part in hand: the sheet covers the board it would be dropped
	# on, and the release would land somewhere the player cannot see.
	if _drag_id != "":
		return
	if _share == null or not is_instance_valid(_share):
		_share = ShareCodePanel.new()
		_share.closed.connect(_close_share)
		_share.build_requested.connect(_build_from_code)
		add_child(_share)
	_hover_cell = Vector2i(-1, -1)
	_hover_pal = -1
	_hover_tab = -1
	_hover_close = false
	_hover_share = false
	var b := current_board()
	_share.open_with(BoardCode.encode(b) if b != null else "")
	Audio.play("ui")

func _close_share() -> void:
	if _share != null and is_instance_valid(_share):
		_share.visible = false

func _build_from_code(entry: String) -> void:
	var b := current_board()
	if b == null:
		_share.note("There is no board open to build onto.", UiKit.BAD)
		return
	var read := BoardCode.decode(entry)
	if String(read["error"]) != "":
		_share.note(String(read["error"]), UiKit.BAD)
		Audio.play("deny")
		return
	var want: SkillBoard = read["board"]
	# The grid is this workbench's, not the code's, so a build off a bigger one
	# arrives only if none of it hangs over the edge.
	if not b.fits(want):
		_share.note("That build was laid out on a %dx%d board; this one is %dx%d." % [
			want.width, want.height, b.width, b.height], UiKit.BAD)
		Audio.play("deny")
		return
	# A code is a blueprint and not the parts: it costs exactly what building the
	# same board by hand would have, and nothing moves unless all of it can be
	# paid for. The sandbox, where parts are free, is never asked.
	if not unlimited:
		var missing := GameState.trade_board(b, want, inventory)
		if not missing.is_empty():
			_share.note("Short of %s — nothing has been spent." % _missing_text(missing), UiKit.BAD)
			Audio.play("deny")
			return
	b.adopt(want)
	_sim_dirty = true
	_trace_cache = {}
	# The sheet now shows this board's own code, which is not always the one that
	# was typed: the grid it landed on may not be the grid it was drawn on.
	_share.open_with(BoardCode.encode(b))
	_share.note("Built — %d parts on the board." % b.cells.size(), UiKit.GOOD)
	Audio.play("place")
	board_changed.emit(slot)

## What a refused paste is short of, in the names the palette uses. The count
## goes in front of the name rather than after it, because several parts carry a
## number in their own name and "DUPLICATE x3 x1" reads as neither of them.
func _missing_text(missing: Dictionary) -> String:
	var ids: Array = missing.keys()
	ids.sort()
	var parts: Array[String] = []
	for id in ids:
		parts.append("%d more %s" % [int(missing[id]), String(Components.get_def(id).get("name", id))])
	return ", ".join(parts)

## --- drawing ----------------------------------------------------------------
const PX := UiKit.PIXEL
const LINE := PixelDraw.LINE
const HEADER_H := 84.0
## Five rows and the controls line under them. The biggest board a Workbench
## grows, and the palette, both end above it.
const INFO_H := 144.0
const INFO_ROWS := 5
## The part being described, up to where the cycle preview starts under the
## palette.
const INFO_LEFT_W := 530.0

## A part's icon is drawn this many PIXELs per bitmap pixel on the board, and
## one PIXEL per bitmap pixel everywhere else.
const ICON_ZOOM := 2
## An empty cell of the board, and what a part sits on.
const CELL_FILL := Color(0.11, 0.13, 0.17)
const CELL_EDGE := Color(0.2, 0.24, 0.3)

## The two halves of the flow display. The silhouette round a wired run is lit
## the whole time — it says what is joined to what, which does not change from
## moment to moment — and the movement is carried by dots running that same
## outline. The outline is the track rather than a path through the middle of
## the parts, so a dot never crosses an icon. Both are measured in cells rather
## than in seconds or PIXELs, so they read at the same pace whatever the board
## is doing: a dot covers FLOW_RATE cells of outline a second, and they sit
## FLOW_DOT_SPAN of it apart, which is two to a cell edge.
const FLOW_EDGE := Color(0.6, 1.0, 0.85)
## The track under the dots, lit the whole way round a wired run. It is the same
## colour held low, so a run reads as live even between two dots, and a dot is
## that same line swelling as it passes rather than the only thing on it.
##
## Flat, not a wash: it takes the part edges it runs along rather than tinting
## them, so a wired run wears one colour the whole way round whatever is on it.
## A part keeps its category colour everywhere else — on its fill, its icon and
## any edge off the run — and being wired is what the outline now says.
const FLOW_TRACK := Color(0.3, 0.5, 0.43)
const FLOW_RATE := 0.8
const FLOW_DOT_SPAN := float(CELL) * 0.5
## A dot is a length of the edge itself rather than a mark sitting on top of
## one: this many PIXELs of it, a PIXEL thick like the edge it replaces, so it
## reads as the outline lighting up under it and never bulges off the shape.
##
## It is a dash rather than a speck because of the corners: a dot of a couple of
## PIXELs turns one on paper and shows nothing, where a dash long enough to have
## two arms visibly bends round it. About half of FLOW_DOT_SPAN, so lit and
## unlit come out the same length and the track still reads as running dashes
## rather than as a line with nicks in it.
const FLOW_DOT := 6

## What the pixel face has no glyph for, as bitmaps: one string per row, `#` for
## a PIXEL. Arrows point east and are turned to face the others.
const PORT := ["#..", "##.", "###", "##.", "#.."]
const ARROW := ["..#..", "...#.", "#####", "...#.", "..#.."]
const CROSS := ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"]
const CHAIN := ["#....", "#....", "#..#.", "#####", "...#."]
const DOT := ["###", "###", "###"]
## Wide enough to read as two loops rather than as two more digits — it sits in
## the same column as counts like "x2", and a tighter one came out as "x00".
const INFINITY := [".##...##.", "#..#.#..#", "#...#...#", "#..#.#..#", ".##...##."]

func _draw() -> void:
	var vp := get_viewport_rect().size
	# Only a light veil: the fight behind this panel has to stay readable.
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.05, 0.07, 0.62))
	_draw_header(vp)
	_draw_board()
	_draw_palette()
	_draw_info(vp)
	_draw_drag()

## Traits matter more than flavour here: the preview below is computed with them.
func _traits_text() -> String:
	var wdef := Weapons.get_def(weapon_id)
	return "%s · melee x%.2f · ranged x%.2f · bolt speed x%.2f" % [
		wdef["name"], float(wdef["melee_mul"]), float(wdef["ranged_mul"]), float(wdef["projectile_speed"])]

func _draw_header(vp: Vector2) -> void:
	_px.rect(Rect2(0, 0, vp.x, HEADER_H), Color(0.07, 0.08, 0.11, 0.9))
	_px.rect(Rect2(0, HEADER_H, vp.x, PX), Color(0.3, 0.5, 0.7, 0.6))
	_px.text(Vector2(48, 34), title_text, Color(0.85, 0.92, 1.0), TAB_ORIGIN.x - 64.0)
	_px.text(Vector2(48, 70), _traits_text(), Color(0.6, 0.7, 0.8), vp.x - 96.0)

	for i in boards.size():
		var b: SkillBoard = boards[i]
		var r := _tab_rect(i)
		var active := i == slot
		var edge := Color(0.45, 0.8, 1.0) if active else Color(0.28, 0.33, 0.4)
		_px.rect(r, Color(0.18, 0.3, 0.42, 0.9) if active else Color(0.11, 0.13, 0.17, 0.9))
		_px.frame(r, edge)
		# The slot's number on a key, since that key is what selects it.
		var key := Rect2(r.position + Vector2(6, 6), Vector2(18, 18))
		_px.rect(key, edge)
		var digit := str(i + 1)
		_px.text(key.position + Vector2((key.size.x - PixelDraw.ink_width(digit)) * 0.5, 14), digit,
			Color(0.07, 0.08, 0.11) if active else Color(0.8, 0.86, 0.94))
		_px.text(r.position + Vector2(32, 20), b.skill_name, Color(0.9, 0.95, 1.0), r.size.x - 40.0)
		if i == _hover_tab and not active:
			_px.frame(r, Color(1, 1, 1, 0.35))
	var sr := _share_rect()
	_px.rect(sr, Color(0.16, 0.3, 0.4, 0.9) if _hover_share else Color(0.11, 0.13, 0.17, 0.9))
	_px.frame(sr, Color(0.55, 0.9, 1.0) if _hover_share else Color(0.32, 0.4, 0.5))
	var share_ink := Color(0.92, 0.98, 1.0) if _hover_share else Color(0.7, 0.8, 0.9)
	_px.text(sr.position + Vector2((sr.size.x - PixelDraw.ink_width("CODE")) * 0.5, 20), "CODE",
		share_ink)
	var cr := _close_rect()
	_px.rect(cr, Color(0.45, 0.18, 0.2, 0.9) if _hover_close else Color(0.14, 0.12, 0.14, 0.9))
	_px.frame(cr, Color(1.0, 0.55, 0.55) if _hover_close else Color(0.45, 0.4, 0.44))
	var ink := Color(1, 0.9, 0.9) if _hover_close else Color(0.8, 0.78, 0.8)
	var mark := CROSS[0].length() * PX + 8.0
	var at := _px.snap(cr.position + Vector2((cr.size.x - mark - PixelDraw.ink_width("CLOSE")) * 0.5, 10))
	_px.icon(at, CROSS, ink)
	_px.text(at + Vector2(mark, 10), "CLOSE", ink)

func _draw_board() -> void:
	var b := current_board()
	if b == null:
		return
	var frame := Rect2(BOARD_ORIGIN - Vector2(10, 10), Vector2(b.width * CELL + 20, b.height * CELL + 20))
	_px.rect(frame, Color(0.08, 0.09, 0.12, 0.92))
	_px.frame(frame, Color(0.3, 0.45, 0.6, 0.7))

	for y in b.height:
		for x in b.width:
			var r := _cell_rect(Vector2i(x, y)).grow(-2)
			_px.rect(r, CELL_EDGE)
			_px.rect(r.grow(-PX), CELL_FILL)

	if _trace_cache.is_empty() or _sim_dirty:
		_refresh_trace(b)
	for origin in b.cells.keys():
		_draw_component(b, origin)
	# The faults go on after the parts rather than before them: the parts now
	# meet with nothing between them, so a cross sits on the seam itself and
	# would be painted over by whichever part is drawn second.
	_draw_faults()
	_draw_flow_dots()

	# Ghost of the part about to be placed. It is suppressed over an occupied
	# cell unless a part is genuinely in hand, so a placed part's own ports are
	# never overlaid by a second set.
	var held := _held_id()
	var occupied := _hover_cell.x >= 0 and not b.comp_at(_hover_cell).is_empty()
	if _hover_cell.x >= 0 and held != "" and (_drag_id != "" or not occupied):
		var ok := b.can_place(held, _hover_cell, rotation_step)
		# One box across the whole footprint, the shape the part would take. A
		# footprint half off the board shows the half that is on it, which is
		# why this grows from the hovered cell rather than from the footprint.
		var ghost := _cell_rect(_hover_cell)
		for c in Components.footprint(held, _hover_cell, rotation_step):
			if b.in_bounds(c):
				ghost = ghost.merge(_cell_rect(c))
		_px.rect(ghost, Color(0.4, 1.0, 0.6, 0.22) if ok else Color(1.0, 0.4, 0.4, 0.22))
		if ok:
			_draw_ports_preview(held, _hover_cell)

	_draw_live_flow(b)

## What the cursor is currently carrying: a dragged part, else the palette pick.
func _held_id() -> String:
	return _drag_id if _drag_id != "" else selected

func _draw_ports_preview(id: String, origin: Vector2i) -> void:
	var ex := Components.exit_cell(id, origin, rotation_step)
	for d in Components.world_outputs(id, rotation_step):
		_draw_port_arrow(ex, d, Color(0.5, 1.0, 0.7, 0.8))
	var p := Components.world_payload_out(id, rotation_step)
	if p >= 0:
		_draw_port_arrow(ex, p, Color(1.0, 0.6, 0.85, 0.8))

## A chip under the cursor, so a dragged part is visible away from the grid.
func _draw_drag() -> void:
	if _drag_id == "":
		return
	var col := Style.component_color(_drag_id)
	var part_name := String(Components.get_def(_drag_id)["name"])
	# Icon, name, then a rotation readout, since the wheel turns the part while it
	# is in hand.
	var r := Rect2(_px.snap(_mouse_pos + Vector2(14, -16)), Vector2(60.0 + PixelDraw.ink_width(part_name), 30.0))
	# Opaque, unlike the rest of the panel: it is dragged over the palette, and
	# two rows of pixel text through each other are unreadable.
	_px.rect(r, Color(0.07, 0.08, 0.11))
	_px.rect(r, Color(col.r, col.g, col.b, 0.32))
	_px.frame(r, col)
	_px.icon(r.position + Vector2(8, 8), Style.component_icon(_drag_id), col)
	_px.text(r.position + Vector2(30, 20), part_name, Color(0.95, 0.97, 1.0))
	_px.icon(Vector2(r.end.x - 18.0, r.position.y + 10.0), _arrows[rotation_step], Color(0.8, 0.9, 1.0))

func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(BOARD_ORIGIN + Vector2(c.x * CELL, c.y * CELL), Vector2(CELL, CELL))

## CELL is an odd number of PIXELs, so the middle of a cell is the middle of a
## PIXEL, and a bitmap an odd number of PIXELs across centres on it exactly.
func _cell_center(c: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(c.x * CELL + CELL * 0.5, c.y * CELL + CELL * 0.5)

## An arrow out of `cell` across its `dir` edge, the point on the edge itself.
func _draw_port_arrow(cell: Vector2i, dir: int, col: Color) -> void:
	var v := Vector2(Components.dir_to_vec(dir))
	_px.icon_centered(_cell_center(cell) + v * (CELL * 0.5 - 3.0), _ports[dir % 4], col)

## The wiring and the order the flow reaches it in are read off the same walk
## of the board, and both go stale on the same edit, so they are taken together.
func _refresh_trace(b: SkillBoard) -> void:
	_trace_cache = b.trace()
	_rebuild_flow(b)
	# After the joints, never before: the outline is drawn round whatever they
	# fused together.
	_rebuild_outline(b)

## How many joints each part sits from the INPUT. `SkillBoard.trace` walks the
## board breadth-first and emits a link the first time the flow reaches its
## target, so reading the links back in that order settles every part at its
## shortest depth without walking the board a second time.
func _rebuild_flow(b: SkillBoard) -> void:
	_flow_depth = {}
	_flow_joint = {}
	var input = b.find_input()
	if input == null:
		return
	_flow_depth[input] = 0
	for link in _trace_cache.get("links", []):
		# A link leaves by a part's exit cell, which on a two-cell part is not
		# the cell the part is filed under; both ends are resolved to origins.
		var exit_cell: Vector2i = link[0]
		var to: Vector2i = link[1]
		var from = b.origin_at(exit_cell)
		if from == null or not _flow_depth.has(from):
			continue
		# A link that runs back into a part already reached — a ring closing —
		# still fuses its own seam, which is why this is done before the depth
		# is settled below.
		var dir := _step_dir(to - exit_cell)
		if dir >= 0:
			_flow_joint[Vector3i(exit_cell.x, exit_cell.y, dir)] = true
			var back := Components.opposite(dir)
			_flow_joint[Vector3i(to.x, to.y, back)] = true
		if _flow_depth.has(to):
			continue
		_flow_depth[to] = int(_flow_depth[from]) + 1

## The silhouette of every wired shape, as closed loops of points. Only parts
## the flow reaches are outlined: a part it cannot reach is not wired to
## anything, so it gets no track and carries no dots.
##
## The track is drawn round the parts *between* the two ends, with the start and
## the end themselves left out of it. That is what puts its two tips on the side
## of the start the run leaves by and the side of the end it arrives on: with a
## board running left to right, the track leaves the middle of the start's right
## edge and meets the middle of the end's left edge, having gone over and under
## everything in between.
##
## It is the boundary of that middle region rather than the lit silhouette, so
## the sides facing the start and the end count even though they are fused and
## never drawn — those are the two tips. Each cell contributes one directed edge
## per open side, walked with the region on its right, and chaining those end to
## start gives loops that run clockwise on screen. A middle with a hole in it
## yields the hole as a loop of its own, so the dots run that too.
##
## A side is only open onto what it is *joined* to, never onto what merely
## touches it: a run that comes back alongside itself — four parts wired round a
## square, say — has a seam down the middle with no flow across it, and the
## track goes in along one side of that seam and back out along the other. Both
## sides of it are outlined, so the dots follow the run rather than short-
## cutting from one leg of it to the next.
##
## The loops are then cut open, because a loop would send the dots round and
## round: see `_cut_loop`.
func _rebuild_outline(b: SkillBoard) -> void:
	_flow_arcs = []
	var ends := _flow_ends(b)
	if ends.is_empty():
		return
	# The INPUT is always left out: the run starts where it hands the flow over.
	# The far end is left out only when it is an OUTPUT, which is a terminal in
	# the same way — a run that simply stops instead ends on a part like any
	# other, and that part is as wired as the ones behind it, so it is outlined
	# with them.
	var terminal := String(b.comp_origin_at(ends[1]).get("id", "")) == "OUTPUT"
	var mid := {}
	for origin in b.cells.keys():
		if not _flow_depth.has(origin) or origin == ends[0]:
			continue
		if terminal and origin == ends[1]:
			continue
		var entry: Dictionary = b.cells[origin]
		var cells := Components.footprint(String(entry["id"]), origin, int(entry["rot"]))
		for c in cells:
			# The part each cell belongs to, so a side can be asked whether it
			# is joined to what is on the other side of it.
			mid[c] = cells
	var edges := {}
	for c in mid.keys():
		for d in 4:
			# Touching is not joined. Two parts side by side with no flow
			# between them are two shapes however close they sit, so the track
			# runs down the seam and back out rather than straight over it —
			# the dots then go the way the flow goes instead of cutting a
			# corner the flow never cuts. It is the same test the edges are
			# drawn by, so the track keeps to the shape they draw.
			if mid.has(c + Components.dir_to_vec(d)) and _fused(mid[c], c, d):
				continue
			var seg := _outline_edge(c, d)
			var k := _point_key(seg[0])
			if not edges.has(k):
				edges[k] = []
			(edges[k] as Array).append(seg)
	# More than one edge can start at the same point — where four cells meet
	# corner to corner, and at either end of a seam the track runs down — and
	# which is taken decides the shape that comes out. The one turning furthest
	# right is, every time: that is what keeps the region on the right hand all
	# the way round, so the walk turns into a seam rather than carrying on over
	# it, and two parts touching only at a corner stay two shapes.
	for start in edges.keys():
		while not (edges[start] as Array).is_empty():
			var loop := PackedVector2Array()
			var at: Vector2i = start
			var heading := Vector2.ZERO
			while true:
				var here: Array = edges.get(at, [])
				if here.is_empty():
					break
				var pick := _rightmost(here, heading)
				var seg: Array = here[pick]
				here.remove_at(pick)
				loop.append(seg[0])
				heading = ((seg[1] as Vector2) - (seg[0] as Vector2)).normalized()
				at = _point_key(seg[1])
				if at == start:
					break
			if loop.size() >= 4:
				_cut_loop(loop, _flow_head(b, ends[0]), _flow_tail(b, ends[1], terminal))

## Which of the edges starting here to take next, as an index into `here`:
## whichever turns furthest right from the way the walk arrived. Right first,
## then straight on, then left, and back the way it came only when nothing else
## is on offer — that last is the far end of a seam, where the track has run in
## along one side and comes back along the other. With nothing arrived from,
## anything will do and the last is taken, as it always was.
func _rightmost(here: Array, heading: Vector2) -> int:
	if heading == Vector2.ZERO:
		return here.size() - 1
	var best := 0
	var best_rank := 4
	for i in here.size():
		var seg: Array = here[i]
		var way := ((seg[1] as Vector2) - (seg[0] as Vector2)).normalized()
		var turn := heading.cross(way)
		var rank := 0 if turn > 0.0 else (2 if turn < 0.0 else (1 if heading.dot(way) > 0.0 else 3))
		if rank < best_rank:
			best_rank = rank
			best = i
	return best

## Where the dots set off from and where they are heading: the INPUT, and the
## part the flow finishes on — an OUTPUT if the board has one, whatever it
## reaches last if it does not. Empty when there is nothing to run between, as
## on a board that is only an INPUT, and then nothing is drawn at all.
func _flow_ends(b: SkillBoard) -> Array:
	var input = b.find_input()
	if input == null:
		return []
	var best = null
	var best_rank := -1
	for origin in _flow_depth.keys():
		var entry := b.comp_origin_at(origin)
		if entry.is_empty():
			continue
		# An OUTPUT is the end whatever its depth, since that is where the
		# board is actually going; failing that, the furthest part reached.
		var rank := int(_flow_depth[origin])
		if String(entry["id"]) == "OUTPUT":
			rank += 1 << 16
		if rank > best_rank:
			best_rank = rank
			best = origin
	if best == null or best == input:
		return []
	return [input, best]

## Where the far end of a run draws the dots to. A terminal OUTPUT is outside
## the outline, so its own middle serves: the nearest the track comes to it is
## the edge facing it, and that is the tip the dots arrive on.
##
## A last part that is *inside* the outline cannot be found that way — its
## middle is as near one of its sides as another, and the tip would land on
## whichever the arithmetic settled on. The anchor is put a cell beyond the edge
## the flow leaves by instead, so the dots come in on the side the run was
## heading and meet where it stops.
func _flow_tail(b: SkillBoard, origin: Vector2i, terminal: bool) -> Vector2:
	if not terminal:
		return _flow_head(b, origin)
	# An OUTPUT has no side of its own, so the seam is the one the wiring feeds
	# it through — the same side it is drawn coming to a point on.
	var entry := b.comp_origin_at(origin)
	if entry.is_empty():
		return _part_center(b, origin)
	var side := _port_cut(b, String(entry["id"]), origin, int(entry["rot"]))
	if side < 0:
		return _part_center(b, origin)
	return _cell_center(origin) + Vector2(Components.dir_to_vec(side)) * (float(CELL) * 0.5)

## The middle of the seam a part sends its flow across. At either end of a run
## that is a tip of the outline: the INPUT hands the flow over on one, and the
## last part is where it leaves on the other.
##
## The middle of the *part* will not do, a whole cell from the outline as it is.
## It comes out exactly as near some other side of the shape — a run leaving
## west has the cell it leaves into sitting exactly as far above whatever is
## below it — and the tip then lands wherever the arithmetic settles the tie
## rather than where the flow crosses. On the seam itself there is no tie.
func _flow_head(b: SkillBoard, origin: Vector2i) -> Vector2:
	var entry := b.comp_origin_at(origin)
	if entry.is_empty():
		return _part_center(b, origin)
	var id := String(entry["id"])
	var rot := int(entry["rot"])
	var outs := Components.world_outputs(id, rot)
	if outs.is_empty():
		return _part_center(b, origin)
	var v := Vector2(Components.dir_to_vec(int(outs[0])))
	return _cell_center(Components.exit_cell(id, origin, rot)) + v * (float(CELL) * 0.5)

## The middle of the part filed under `origin`, which on a two-cell part is the
## middle of both its cells rather than of either one.
func _part_center(b: SkillBoard, origin: Vector2i) -> Vector2:
	var entry := b.comp_origin_at(origin)
	if entry.is_empty():
		return _cell_center(origin)
	return _part_rect(String(entry["id"]), origin, int(entry["rot"])).get_center()

## A closed outline cut into the two runs between `head` and `tail`, each kept
## from the head end onwards. That is what stops the dots circling: they leave
## the start both ways round the shape, and both runs arrive at the end, so
## every dot on the board is on its way from the one to the other.
##
## Going forward round the loop keeps the shape on the right and going back
## puts it on the left, which is what `side` records — the dots are drawn into
## the edge band, and the band lies on the inside.
func _cut_loop(loop: PackedVector2Array, head: Vector2, tail: Vector2) -> void:
	var total := _loop_length(loop)
	if total <= 0.0:
		return
	var s0 := _cut_at(loop, head)
	var s1 := _cut_at(loop, tail)
	# The two runs share their ends and between them cover the outline exactly
	# once, so every part of it carries dots and none of it carries them twice.
	for way in [1.0, -1.0]:
		var span := fposmod((s1 - s0) * way, total)
		if span <= 0.0:
			continue
		_flow_arcs.append({"loop": loop, "from": s0, "span": span, "way": way})

## How far round `loop` the outline comes closest to `to`. Measured against the
## segments rather than only the corners: a part's middle is nearer the middle
## of its own edge than any corner of it, and going by corners put both cuts on
## the same one whenever the two parts met there — a board whose INPUT and
## OUTPUT sit corner to corner then came out with no runs at all.
func _cut_at(loop: PackedVector2Array, to: Vector2) -> float:
	var best := 0.0
	var best_d := INF
	var walked := 0.0
	for i in loop.size():
		var a := loop[i]
		var step := loop[(i + 1) % loop.size()] - a
		var span := step.length()
		if span <= 0.0:
			continue
		var t := clampf((to - a).dot(step) / (span * span), 0.0, 1.0)
		var d := (a + step * t).distance_squared_to(to)
		if d < best_d:
			best_d = d
			best = walked + t * span
		walked += span
	return best

func _loop_length(loop: PackedVector2Array) -> float:
	var total := 0.0
	for i in loop.size():
		total += (loop[(i + 1) % loop.size()] - loop[i]).length()
	return total

## The point `s` round `loop` from its first corner, the way the outline runs
## there, and how much of that straight run is left past the point, as
## [point, direction, left]. `s` wraps. The third of those is what lets a dot be
## laid down a run at a time: it says where the outline next turns.
func _loop_sample(loop: PackedVector2Array, s: float) -> Array:
	var at := s
	for i in loop.size():
		var a := loop[i]
		var step := loop[(i + 1) % loop.size()] - a
		var span := step.length()
		if span <= 0.0:
			continue
		if at < span:
			return [a + step * (at / span), step / span, span - at]
		at -= span
	return [loop[0], Vector2.RIGHT, 0.0]

## One side of `cell` as a directed segment with the shape on its right, which
## is what makes the loops these chain into come out clockwise.
func _outline_edge(cell: Vector2i, dir: int) -> Array:
	var r := _cell_rect(cell)
	var tr := Vector2(r.end.x, r.position.y)
	var bl := Vector2(r.position.x, r.end.y)
	match dir % 4:
		0: return [tr, r.end]
		1: return [r.end, bl]
		2: return [bl, r.position]
		_: return [r.position, tr]
	return []

## A corner as whole PIXELs, so two edges that meet there chain by an exact
## match rather than by comparing floats that were arrived at two ways.
func _point_key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x), roundi(p.y))

## Which of the four directions a one-cell step is, or -1 for anything else.
func _step_dir(step: Vector2i) -> int:
	for d in 4:
		if Components.dir_to_vec(d) == step:
			return d
	return -1

## Whether the boundary on `cell`'s `dir` side falls inside the silhouette
## rather than on it — the part's own next cell, or a joint that carries flow.
## Those are the seams nothing draws, which is what fuses a wired run into one
## shape while two parts that merely touch stay two boxes with a cross between.
func _fused(cells: Array, cell: Vector2i, dir: int) -> bool:
	if cells.has(cell + Components.dir_to_vec(dir)):
		return true
	return _flow_joint.has(Vector3i(cell.x, cell.y, dir % 4))

## The flow itself, over the top of the parts: dots running the silhouette of
## each wired shape. The outline under them says what is joined to what; these
## say it is live and carrying.
##
## They are spaced by distance along the run rather than per edge, so a corner
## does not bunch them and a long rail does not stretch them out. Every run
## starts at the INPUT and ends at the far end, so the start sends dots away
## both ways round the shape and the end takes them in from both — nothing goes
## round in a circle, and a dot anywhere on the board is on its way to the end.
func _draw_flow_dots() -> void:
	# The track first and all of it, then the dots over the top: a loop is cut
	# into two runs that between them cover it exactly once, so lighting it off
	# the one going forward lights it the once.
	for arc in _flow_arcs:
		if float(arc["way"]) > 0.0:
			_draw_track(arc["loop"])
	# A cell, not the gap between dots: the rate is cells of outline a second,
	# so sitting them closer together must not also slow them down.
	var travel := _flow_time * FLOW_RATE * float(CELL)
	for arc in _flow_arcs:
		var loop: PackedVector2Array = arc["loop"]
		var total := _loop_length(loop)
		var way: float = arc["way"]
		var span: float = arc["span"]
		# Distance from the head cut, so a dot sets off from the start rather
		# than from wherever the outline happened to be written down first.
		var at := fmod(travel, FLOW_DOT_SPAN)
		while at < span:
			# `way` places the dot and nothing else: a dot is the same mark
			# either way round, being drawn out from its middle.
			_draw_dot(loop, fposmod(float(arc["from"]) + at * way, total), total)
			at += FLOW_DOT_SPAN

## The whole of one wired shape's outline, lit low: the line the dots run on.
## Drawn corner to corner rather than PIXEL by PIXEL — it does not fade — and a
## corner the outline turns out of the shape on belongs to the side arriving at
## it, exactly as it does for a dot, so no corner is laid down twice and doubled
## up should this ever be drawn in a colour that is not flat.
func _draw_track(loop: PackedVector2Array) -> void:
	for i in loop.size():
		var at := loop[i]
		var seg := loop[(i + 1) % loop.size()] - at
		var span := seg.length()
		if span <= 0.0:
			continue
		var along := seg / span
		var prev := at - loop[(i - 1 + loop.size()) % loop.size()]
		if prev.normalized().cross(along) > 0.0:
			at += along * float(PX)
			span -= float(PX)
		if span > 0.0:
			_draw_band(at, along, span, FLOW_TRACK)

## A dot: FLOW_DOT PIXELs of the edge itself, lit, with `at` their middle. It is
## a length *of the outline* rather than a straight mark laid over it, so a dot
## going round a corner turns with the shape instead of carrying straight on off
## it. That is what the walk below is for: a piece per straight run the dot
## covers, which for a dot on a corner is two of them meeting there.
func _draw_dot(loop: PackedVector2Array, at: float, total: float) -> void:
	var left := float(FLOW_DOT * PX)
	# Started on the PIXEL grid rather than wherever the middle happens to fall:
	# every corner is on it too, so each piece below is whole PIXELs and none of
	# them is rounded away. A dot is then the same length wherever it is, which
	# it was not while a turn could lose one end of it to the snap.
	var s := fposmod(floorf((at - left * 0.5) / float(PX)) * float(PX), total)
	var along := Vector2.ZERO
	var lit := 0
	while left > 0.0:
		var hit := _loop_sample(loop, s)
		var turn: Vector2 = hit[1]
		if along.cross(turn) > 0.0:
			# Where the outline turns out of the shape, both of its sides own
			# the same corner PIXEL. The arm arriving lays it and the arm
			# leaving steps over it: a dot on a corner is then as long as a dot
			# on a straight, and the fade does not double back on itself over
			# the one PIXEL both arms would otherwise put a step of it on.
			along = turn
			s = fposmod(s + float(PX), total)
			continue
		along = turn
		# Up to the next corner, or the rest of the dot if it reaches no corner.
		var run := minf(left, float(hit[2]))
		if run <= 0.0:
			break
		_draw_dot_piece(hit[0], along, run, lit)
		lit += int(run / float(PX))
		s = fposmod(s + run, total)
		left -= run

## One straight piece of a dot: `span` of the outline from `at`, running
## `along`, starting `lit` PIXELs into the dot.
##
## A PIXEL at a time, because a dot is not one flat mark: it comes up out of the
## track it runs on and goes back down into it, brightest in the middle, the way
## the band sliding along a loading bar does. That is also what carries a dot
## round a corner without a seam — the fade is over the whole dot, so the two
## arms meeting there pick up where each other left off.
func _draw_dot_piece(at: Vector2, along: Vector2, span: float, lit: int) -> void:
	var step := along * float(PX)
	for i in int(span / float(PX)):
		# Over the length of the whole dot, ends included: a PIXEL of it is
		# taken at its middle, so neither end comes out at nothing.
		var k := (float(lit + i) + 0.5) / float(FLOW_DOT)
		# Out of the track and back into it, rather than out of nothing: the
		# line is already lit, and a dot is the length of it that is brightest.
		_draw_band(at + step * float(i), along, float(PX),
			FLOW_TRACK.lerp(FLOW_EDGE, sin(PI * k)))

## `span` of the outline from `at`, running `along`, in `col`. The band is a
## PIXEL deep on the shape's side of the boundary — the loop's right, since the
## loops come out clockwise — so whatever is laid in it clips to the edge and
## the shape keeps its silhouette exactly.
func _draw_band(at: Vector2, along: Vector2, span: float, col: Color) -> void:
	var z := at + along * span + Vector2(-along.y, along.x) * float(PX)
	_px.rect(Rect2(Vector2(minf(at.x, z.x), minf(at.y, z.y)), (z - at).abs()), col)

## Only what is *wrong* is marked here: a cross where two parts touch but the
## receiving port faces away, and a dot where the flow runs out into empty
## space. What carries flow is not marked at all — the parts meet edge to edge,
## so the highlight running the chain is what shows a joint is live.
func _draw_faults() -> void:
	for br in _trace_cache.get("breaks", []):
		_px.icon_centered((_cell_center(br["from"]) + _cell_center(br["to"])) * 0.5, CROSS,
			Color(1.0, 0.4, 0.4, 0.95))
	for leak in _trace_cache.get("leaks", []):
		if String(leak.get("why", "")) != "empty":
			continue
		var v := Vector2(Components.dir_to_vec(int(leak["dir"])))
		_px.icon_centered(_cell_center(leak["from"]) + v * (CELL * 0.5 + 5.0), DOT, Color(0.9, 0.6, 0.35, 0.75))

## A two-cell part is one box across both of its cells rather than two boxes
## side by side: the seam between them would otherwise read as two parts, and
## run right through the icon sitting on it.
##
## The box is the cells themselves, with nothing trimmed off: parts that sit
## next to each other meet, and a wired run reads as one unbroken shape rather
## than as a row of tiles needing something drawn between them.
func _part_rect(id: String, origin: Vector2i, rot: int) -> Rect2:
	var r := _cell_rect(origin)
	for c in Components.footprint(id, origin, rot):
		r = r.merge(_cell_rect(c))
	return r

## A part's share of the silhouette, one cell edge at a time. Only the sides
## that are not fused are drawn, so parts the flow runs through come out as a
## single shape with no seams inside it: what is wired reads as one object, and
## two parts that merely touch stay two boxes with a cross between them.
##
## Each part draws only its own stretch, in its own colour, so the colour of
## the outline changes from one edge of the shape to the next. The whole of it
## stays lit: what is wired does not change from moment to moment, and the
## moving part of the picture is the dots over the top of it.
## A port is the one part that is not a box — see `_port_cut` — and its point
## is its edge on the side it points out of. The two sides running into that
## point stop where it starts, and the side is not drawn at all.
func _draw_part_edges(id: String, origin: Vector2i, rot: int, own: Color, cut: int = -1) -> void:
	var cells := Components.footprint(id, origin, rot)
	var r := _part_rect(id, origin, rot)
	var deep := _point_depth(r, cut) if cut >= 0 else 0.0
	for c in cells:
		for d in 4:
			if d == cut or _fused(cells, c, d):
				continue
			_px.rect(_trim_to_point(_edge_rect(cells, c, d), d, cut, deep), own)
	if cut >= 0:
		_draw_port_point(r, cut, own)

## The one-PIXEL band along `cell`'s `dir` side, inside the cell. North and
## south take the corners and east and west stop short of them, so a translucent
## edge is never laid down twice where two sides meet — the same split
## `PixelDraw.frame` makes. Where the silhouette carries on north or south,
## though, there is no corner to yield: the band runs the whole height instead,
## and the rail stays unbroken across the seam it just fused.
func _edge_rect(cells: Array, cell: Vector2i, dir: int) -> Rect2:
	var r := _cell_rect(cell)
	if dir % 2 == 1:
		return Rect2(r.position.x, r.end.y - PX if dir % 4 == 1 else r.position.y,
			r.size.x, PX)
	var top := r.position.y + (0.0 if _fused(cells, cell, 3) else float(PX))
	var bot := r.end.y - (0.0 if _fused(cells, cell, 1) else float(PX))
	return Rect2(r.end.x - PX if dir % 4 == 0 else r.position.x, top, PX, bot - top)

## Which side a part comes to a point on, or -1 for everything that is a box.
## The INPUT points the way it hands the flow over. The OUTPUT has no direction
## of its own — a part takes flow on any side that is not one of its outputs —
## so what points it is the wiring: the side it is actually fed from. One that
## nothing reaches stays a box, nothing having said yet where its port is.
func _port_cut(b: SkillBoard, id: String, origin: Vector2i, rot: int) -> int:
	if id == "INPUT":
		var outs := Components.world_outputs(id, rot)
		return int(outs[0]) if not outs.is_empty() else -1
	if id != "OUTPUT":
		return -1
	var cells := Components.footprint(id, origin, rot)
	for link in _trace_cache.get("links", []):
		var to: Vector2i = link[1]
		if not cells.has(to):
			continue
		var d := _step_dir(to - (link[0] as Vector2i))
		if d >= 0:
			return Components.opposite(d)
	return -1

## How far back a port is cut: the staircase runs at forty-five degrees from the
## middle of the side it points out of, so it reaches in as far as that side is
## wide, halved and landed on the grid.
func _point_depth(r: Rect2, dir: int) -> float:
	var v := Vector2(Components.dir_to_vec(dir))
	var across := absf(r.size.x * -v.y + r.size.y * v.x)
	return float((int(across / float(PX)) - 1) / 2 * PX)

## A port as strips a PIXEL thick, running the way it points: each one is a
## PIXEL shorter than the one before as they go out from the middle, which is
## that forty-five degree cut written on the grid. The middle strip runs the
## whole depth, and is the point itself.
func _port_strips(r: Rect2, dir: int) -> Array:
	var v := Vector2(Components.dir_to_vec(dir))
	var w := Vector2(-v.y, v.x)
	# The corner the strips are counted from: the one both `v` and `w` run away
	# from, so a port reads the same whichever way round it is turned.
	var base := Vector2(r.position.x if v.x + w.x > 0.0 else r.end.x,
		r.position.y if v.y + w.y > 0.0 else r.end.y)
	var deep := absf(r.size.x * v.x + r.size.y * v.y)
	var n := int(absf(r.size.x * w.x + r.size.y * w.y) / float(PX))
	var out := []
	for i in n:
		var lead := deep - float(absi(i - (n - 1) / 2) * PX)
		var a := base + w * (float(i) * float(PX))
		var z := a + w * float(PX) + v * lead
		out.append(Rect2(Vector2(minf(a.x, z.x), minf(a.y, z.y)), (z - a).abs()))
	return out

## The ground and the tint under a part, which for a port is its strips rather
## than its box: the two corners it is cut back to a point from show the board
## behind them, and the cut is the shape of the part rather than a mark on it.
func _draw_part_body(r: Rect2, cut: int, col: Color) -> void:
	if cut < 0:
		_px.rect(r, col)
		return
	for strip in _port_strips(r, cut):
		_px.rect(strip, col)

## The point itself: the PIXEL each strip ends on, which taken together are the
## two runs of the staircase meeting at the tip.
func _draw_port_point(r: Rect2, dir: int, col: Color) -> void:
	var v := Vector2(Components.dir_to_vec(dir))
	for strip in _port_strips(r, dir):
		var tip := strip as Rect2
		if absf(v.x) > 0.0:
			tip.position.x = strip.end.x - float(PX) if v.x > 0.0 else strip.position.x
			tip.size.x = float(PX)
		else:
			tip.position.y = strip.end.y - float(PX) if v.y > 0.0 else strip.position.y
			tip.size.y = float(PX)
		_px.rect(tip, col)

## An edge band stopped where a port's point starts, so the straight sides give
## way to the staircase rather than running on behind it. Only the two sides
## across from the point are cut back: the side it points out of is not drawn,
## and the one behind it runs the full width.
func _trim_to_point(band: Rect2, dir: int, cut: int, deep: float) -> Rect2:
	if cut < 0 or dir % 2 == cut % 2:
		return band
	var v := Vector2(Components.dir_to_vec(cut))
	if v.x > 0.0:
		band.size.x -= deep
	elif v.x < 0.0:
		band.position.x += deep
		band.size.x -= deep
	elif v.y > 0.0:
		band.size.y -= deep
	else:
		band.position.y += deep
		band.size.y -= deep
	return band

func _draw_component(b: SkillBoard, origin: Vector2i) -> void:
	var entry: Dictionary = b.cells[origin]
	var id: String = entry["id"]
	var rot: int = entry["rot"]
	var col := Style.component_color(id)
	# A part the flow cannot reach is drawn faint: it is on the board but dead.
	var live: bool = not bool(_trace_cache.get("has_input", false)) \
		or _trace_cache.get("reachable", {}).has(origin)
	var r := _part_rect(id, origin, rot)
	var cut := _port_cut(b, id, origin, rot)
	# The part's own ground under its tint, so the grid it covers does not show
	# through the tint and draw a seam across a two-cell part.
	_draw_part_body(r, cut, CELL_FILL)
	_draw_part_body(r, cut, Color(col.r, col.g, col.b, 0.28 if live else 0.08))
	# The edge is what carries the wiring now that the parts touch, so it is
	# drawn brighter than the part it bounds, and the run lights it on its way
	# past. A part the flow never reaches never lights: the same reading the
	# bridges gave, moved onto the part itself.
	_draw_part_edges(id, origin, rot,
		col.lightened(0.45) if live else Color(col.r, col.g, col.b, 0.35), cut)
	# No name under the icon: none fits a cell in the pixel face. Hovering the
	# part names it in the panel along the bottom instead. The icon is drawn at
	# ICON_ZOOM here — a cell is wide enough for it, and at palette size it was
	# lost in the middle of one.
	_px.icon_centered(r.get_center(), Style.component_icon(id),
		col.lightened(0.3) if live else Color(col.r, col.g, col.b, 0.4), ICON_ZOOM)

	var ex := Components.exit_cell(id, origin, rot)
	var arrow_col := col.lightened(0.4) if live else Color(col.r, col.g, col.b, 0.35)
	for d in Components.world_outputs(id, rot):
		_draw_port_arrow(ex, d, arrow_col)
	var pd := Components.world_payload_out(id, rot)
	if pd >= 0:
		_draw_port_arrow(ex, pd, Color(1.0, 0.55, 0.8) if live else Color(1.0, 0.55, 0.8, 0.35))

## Live pulses from the running circuit, so the board shows its own timing: a
## diamond that swells as the pulse crosses a part, and the part's border lit
## clockwise from the top as far as the pulse has got.
##
## A pulse is at whichever of a two-cell part's cells the flow entered by, so
## both are resolved back to the part: the wipe goes round the whole of it.
func _draw_live_flow(b: SkillBoard) -> void:
	if slot >= runners.size():
		return
	var r: SkillRunner = runners[slot]
	if r == null or r.board != b:
		return
	for p in r.pulses:
		var origin: Vector2i = b.origin_at(p.cell)
		var entry := b.comp_origin_at(origin)
		var box := _cell_rect(p.cell) if entry.is_empty() \
			else _part_rect(String(entry["id"]), origin, int(entry["rot"]))
		var k := p.progress()
		_px.diamond(box.get_center(), 3 + int(round(2.0 * sin(k * PI))), Color(0.6, 1.0, 0.85, 0.85))
		_px.lap(box, k, Color(0.5, 1.0, 0.8, 0.7))

## The parts, in blocks — one a category, in the order the pool brings them: a
## category's block starts where its first part does, and every later part of
## the same category joins it rather than starting a second block of its own.
func _pal_groups() -> Array:
	var groups: Array = []
	var at := {}
	for id in _pool_ids():
		var cat := String(Components.get_def(id).get("cat", Components.CAT_STRUCT))
		if not at.has(cat):
			at[cat] = groups.size()
			groups.append({"cat": cat, "ids": []})
		(groups[int(at[cat])]["ids"] as Array).append(id)
	return groups

## Every row and every block placed, once. The pool is a constant, so this is
## worked out on first use and kept: the rows the palette draws and the rects
## the cursor is tested against are then the same numbers, and a block that
## grows a part pushes the ones under it down on its own.
func _build_palette() -> void:
	_pal_rows = []
	_pal_blocks = []
	var x := PAL_ORIGIN.x + PAL_GUTTER
	var y := PAL_ORIGIN.y
	for group in _pal_groups():
		var ids: Array = group["ids"]
		var rows := int(ceil(float(ids.size()) / float(PAL_COLS)))
		var cat := String(group["cat"])
		_pal_blocks.append({
			"name": Style.category_name(cat),
			"col": Style.category_color(cat),
			# The name is right-aligned on the spine, on the first row's baseline.
			"baseline": Vector2(x - PAL_SPINE - 8.0, y + PAL_TEXT_Y),
			"spine": Rect2(x - PAL_SPINE, y, PX, rows * PAL_H - 4.0),
		})
		for i in ids.size():
			_pal_rows.append({"id": String(ids[i]), "rect": Rect2(
				Vector2(x + (i % PAL_COLS) * PAL_W, y + int(i / PAL_COLS) * PAL_H),
				Vector2(PAL_W - 4, PAL_H - 4))})
		y += rows * PAL_H + PAL_GROUP_GAP
	_pal_height = y - PAL_GROUP_GAP - PAL_ORIGIN.y

func _pal_list() -> Array:
	if _pal_rows.is_empty():
		_build_palette()
	return _pal_rows

func _pal_rect(i: int) -> Rect2:
	return _pal_list()[i]["rect"]

## The panel the blocks sit on: 10 clear of the rows on every side, the gutter
## included. Anything thrown at it is thrown at the palette.
func _pal_panel() -> Rect2:
	_pal_list()   # for _pal_height, which the layout works out
	return Rect2(PAL_ORIGIN - Vector2(10, 10),
		Vector2(PAL_GUTTER + PAL_COLS * PAL_W - 4 + 20, _pal_height + 20))

func _draw_palette() -> void:
	var panel := _pal_panel()
	_px.rect(panel, Color(0.08, 0.09, 0.12, 0.92))
	_px.frame(panel, Color(0.3, 0.45, 0.6, 0.7))

	for block in _pal_blocks:
		var col: Color = block["col"]
		_px.rect(block["spine"], Color(col.r, col.g, col.b, 0.7))
		var label := PixelDraw.clip(String(block["name"]), PAL_GUTTER - PAL_SPINE - 8.0)
		var at: Vector2 = block["baseline"] - Vector2(PixelDraw.ink_width(label), 0.0)
		_px.text(at, label, col)

	var ids := _palette_ids()
	for i in ids.size():
		var id: String = ids[i]
		var r := _pal_rect(i)
		var have := unlimited or Components.is_structural(id) or int(inventory.get(id, 0)) > 0
		var c := Style.component_color(id)
		var bg := Color(c.r, c.g, c.b, 0.18 if have else 0.05)
		if id == selected:
			bg = Color(c.r, c.g, c.b, 0.42)
		_px.rect(r, bg)
		_px.frame(r, c if have else Color(0.3, 0.32, 0.36))
		_px.icon(r.position + Vector2(8, 4), Style.component_icon(id), c)
		_draw_count(r.end - Vector2(8, 6), id)
		_px.text(r.position + Vector2(30, PAL_TEXT_Y), String(Components.get_def(id)["name"]),
			Color(0.92, 0.95, 1.0) if have else Color(0.45, 0.48, 0.52), _pal_name_width(i))
		if i == _hover_pal:
			_px.frame(r, Color(1, 1, 1, 0.5))

## The room a palette row leaves its part's name: after the icon, and short of
## the count.
func _pal_name_width(i: int) -> float:
	return _pal_rect(i).size.x - 46.0 - _count_width(String(_pal_list()[i]["id"]))

## A part there is no end of shows an infinity sign instead of a count, drawn
## because the pixel face has none. On its own, without the "x" a count has: the
## two together read as one more number.
func _endless(id: String) -> bool:
	return unlimited or Components.is_structural(id)

func _count_width(id: String) -> float:
	if _endless(id):
		return INFINITY[0].length() * PX
	return PixelDraw.ink_width("x%d" % int(inventory.get(id, 0)))

## "x2", or the infinity, right-aligned on `right`.
func _draw_count(right: Vector2, id: String) -> void:
	var col := Color(0.6, 0.7, 0.8)
	var at := _px.snap(right - Vector2(_count_width(id), 0))
	if _endless(id):
		_px.icon(at + Vector2(0, -5 * PX), INFINITY, col)
	else:
		_px.text(at, "x%d" % int(inventory.get(id, 0)), col)

func _draw_info(vp: Vector2) -> void:
	var y := vp.y - INFO_H
	_px.rect(Rect2(0, y, vp.x, INFO_H), Color(0.07, 0.08, 0.11, 0.94))
	_px.rect(Rect2(0, y, vp.x, PX), Color(0.3, 0.5, 0.7, 0.6))

	var b := current_board()
	# The part under the cursor, on the palette or the board, else the one in
	# hand. The board names nothing itself, since no name fits in a cell.
	var describe := selected
	if _hover_pal >= 0:
		describe = String(_palette_ids()[_hover_pal])
	elif b != null and _hover_cell.x >= 0 and not b.comp_at(_hover_cell).is_empty():
		describe = String(b.comp_at(_hover_cell)["id"])
	if describe != "":
		var def := Components.get_def(describe)
		_px.text(Vector2(48, y + 26), String(def["name"]), Style.component_color(describe), INFO_LEFT_W)
		var desc := PixelDraw.wrap(String(def["desc"]), INFO_LEFT_W, 2)
		for i in desc.size():
			_px.text(Vector2(48, y + 46 + i * LINE), desc[i], Color(0.72, 0.78, 0.86))
		_px.text(Vector2(48, y + 86), "cells %d   cost %d ticks, one per cell   heat %.1f" % [
			int(def["cells"]), Components.tick_cost(describe), float(def["heat"])],
			Color(0.55, 0.65, 0.75), INFO_LEFT_W)

	if b == null:
		return
	# The board walk is only redone when something actually changed.
	if _sim_dirty or _sim_cache.is_empty():
		var sim := SkillRunner.new(b)
		sim.base_payload_provider = func() -> Payload: return Weapons.base_payload(weapon_id)
		_sim_cache = sim.simulate()
		_refresh_trace(b)
		_sim_dirty = false
	var rx := PAL_ORIGIN.x
	var right := vp.x - 48.0
	var notes := _preview_rows(b, _sim_cache, right - rx)
	for i in notes.size():
		var note: Dictionary = notes[i]
		var at := Vector2(rx, y + 26 + i * LINE)
		if note.has("icon"):
			_px.icon(at - Vector2(0, 5 * PX), note["icon"], note["col"])
			at.x += 18.0
		_px.text(at, note["text"], note["col"], right - at.x)

	if _message_time > 0.0:
		_px.text(Vector2(48, y + 106), _message, Color(1.0, 0.65, 0.55), INFO_LEFT_W)
	# Controls live along the bottom, clear of the slot tabs at the top.
	_px.text(Vector2(48, vp.y - 8), HINT, Color(0.5, 0.58, 0.68), vp.x - 96.0)

const HINT := "drag to place · wheel turns the part under the cursor · RMB removes · C shares a code · TAB or ESC closes"

## What the cycle preview says, a row each, as {text, col} and an `icon` to put
## before a row. There is room for INFO_ROWS of them: a preview that runs longer
## says how much it left out rather than running off the bottom of the screen.
func _preview_rows(b: SkillBoard, result: Dictionary, width: float) -> Array:
	var rows: Array = []
	if String(result.get("error", "")) != "":
		_add_rows(rows, String(result["error"]), Color(1.0, 0.55, 0.5), width, INFO_ROWS)
		return rows
	var outs: Array = result["outputs"]
	rows.append({"text": "CYCLE %.2fs   outputs %d   heat %.1f" % [
		float(result["cycle_seconds"]), outs.size(), float(result["heat"])],
		"col": Color(0.7, 0.95, 0.85)})
	# A weapon that will not carry the board matters more than anything under it,
	# so it goes straight under the cycle rather than wherever rows are left.
	if not Weapons.accepts_board(weapon_id, b):
		_add_rows(rows, Weapons.rejection_reason(weapon_id, b), Color(1.0, 0.5, 0.5), width, 2)
	if outs.is_empty():
		# A flow that simply ran out of life is not a wiring fault, and
		# `first_problem` would go looking for one that is not there.
		var why := b.first_problem()
		if bool(result.get("expired", false)):
			why = "The flow runs out of life (%d) before it reaches an OUTPUT. Shorten it, or hold the cast button to charge it further." % int(result.get("ttl", 0))
		_add_rows(rows, why, Color(1.0, 0.62, 0.45), width, 3)
	for i in mini(outs.size(), 3):
		var p: Payload = Weapons.finalize(weapon_id, (outs[i] as Payload).clone())
		rows.append({"text": "• %s" % p.summary(), "col": Color(0.82, 0.88, 0.95)})
	# Overclocking is a trade, so show both halves of it.
	if int(result.get("overclock", 0)) > 0:
		rows.append({"text": "OVERCLOCK x%d · clock x%.2f · +%.2fs settle" % [
			int(result["overclock"]), float(result["speed_mul"]), float(result["penalty_seconds"])],
			"col": Style.flow_color()})
	# What holding the cast button buys this board, in the board's own terms. The
	# binding is named so the row fits, and stays true after a rebind.
	rows.append({"text": "LIFE %d · hold %s for more, release to fire" % [
		int(result.get("ttl", 0)), Controls.short_label_for("cast_skill")],
		"col": Color(0.78, 0.68, 1.0)})
	var trig: Dictionary = result.get("triggers", {})
	for k in trig:
		# A loop can queue several follow-ups on one trigger, each landing
		# after the one before. List the whole chain, so four laps read as
		# four attacks rather than as a single very large one.
		var q = trig[k]
		var n := 0
		while q != null:
			var label: String = String(Components.get_def(k).get("name", k)) if n == 0 else "then"
			rows.append({"text": "%s: %s" % [label, (q as Payload).summary()],
				"col": Color(1.0, 0.7, 0.85), "icon": CHAIN})
			n += 1
			q = q.on_hit
	if rows.size() > INFO_ROWS:
		var cut := rows.size() - INFO_ROWS + 1
		rows.resize(INFO_ROWS - 1)
		rows.append({"text": "… %d more" % cut, "col": Color(0.55, 0.65, 0.75)})
	return rows

func _add_rows(rows: Array, text: String, col: Color, width: float, most: int) -> void:
	for line in PixelDraw.wrap(text, width, most):
		rows.append({"text": line, "col": col})
