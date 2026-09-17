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
const PAL_H := 26
## A category's name is written down the gutter beside its block rather than on
## a header row above it: there are seven of them, and seven more rows do not
## fit between the header and the info panel. The spine is the rule the name
## and the block hang off, PAL_SPINE short of the first column.
const PAL_GUTTER := 122.0
const PAL_SPINE := 10.0
const PAL_GROUP_GAP := 6.0
## The baseline of a row's text, from the top of the row: capitals stand 10
## tall, so this leaves 6 above them and 6 under.
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
		_trace_cache = b.trace()
	_draw_wiring()
	for origin in b.cells.keys():
		_draw_component(b, origin)

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
		_px.rect(ghost.grow(-4), Color(0.4, 1.0, 0.6, 0.22) if ok else Color(1.0, 0.4, 0.4, 0.22))
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

## Live joints get a bridge across the seam; joints that touch but do not
## connect get a cross. Without this a board that looks wired can be dead and
## there is no way to see where.
func _draw_wiring() -> void:
	for link in _trace_cache.get("links", []):
		var a: Vector2 = _cell_center(link[0])
		var c: Vector2 = _cell_center(link[1])
		var along := (c - a).normalized().abs()
		var across := Vector2(along.y, along.x)
		# Three PIXELs thick, the width that centres on the line through the
		# middle of the cells.
		_px.rect(Rect2((a + c) * 0.5 - along * 12.0 - across * 3.0, along * 24.0 + across * 6.0),
			Color(0.45, 1.0, 0.75, 0.95))
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
func _part_rect(id: String, origin: Vector2i, rot: int) -> Rect2:
	var r := _cell_rect(origin)
	for c in Components.footprint(id, origin, rot):
		r = r.merge(_cell_rect(c))
	return r.grow(-4)

func _draw_component(b: SkillBoard, origin: Vector2i) -> void:
	var entry: Dictionary = b.cells[origin]
	var id: String = entry["id"]
	var rot: int = entry["rot"]
	var col := Style.component_color(id)
	# A part the flow cannot reach is drawn faint: it is on the board but dead.
	var live: bool = not bool(_trace_cache.get("has_input", false)) \
		or _trace_cache.get("reachable", {}).has(origin)
	var r := _part_rect(id, origin, rot)
	# The part's own ground under its tint, so the grid it covers does not show
	# through the tint and draw a seam across a two-cell part.
	_px.rect(r, CELL_FILL)
	_px.rect(r, Color(col.r, col.g, col.b, 0.28 if live else 0.08))
	_px.frame(r, col if live else Color(col.r, col.g, col.b, 0.35))
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
		var box := _cell_rect(p.cell).grow(-4) if entry.is_empty() \
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
		_trace_cache = b.trace()
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
