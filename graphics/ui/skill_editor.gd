class_name SkillEditor
extends Control

## The assembly screen. It is deliberately not a safe menu: in a raid the world
## keeps running behind it, so the panel stays translucent and compact and every
## action is a single click.

signal board_changed(slot: int)
signal closed()

const CELL := 50
const BOARD_ORIGIN := Vector2(48, 104)
const PAL_ORIGIN := Vector2(700, 104)
const PAL_COLS := 4
const PAL_W := 132
const PAL_H := 46

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
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_process(true)

func configure(b: Array, inv: Dictionary, unlim: bool, rs: Array = []) -> void:
	boards = b
	inventory = inv
	unlimited = unlim
	runners = rs
	slot = clampi(slot, 0, maxi(boards.size() - 1, 0))
	_sim_dirty = true

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
	match (event as InputEventKey).keycode:
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

const TAB_ORIGIN := Vector2(420, 20)
const TAB_W := 160
const TAB_SIZE := Vector2(150, 46)

func _tab_rect(i: int) -> Rect2:
	return Rect2(TAB_ORIGIN + Vector2(i * TAB_W, 0), TAB_SIZE)

func _close_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 88.0, 14.0, 72.0, 30.0)

func _update_hover(pos: Vector2) -> void:
	_hover_cell = Vector2i(-1, -1)
	_hover_pal = -1
	_hover_tab = -1
	_hover_close = _close_rect().has_point(pos)
	if _hover_close:
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
	var prel := pos - PAL_ORIGIN
	if prel.x >= 0 and prel.y >= 0:
		var col := int(prel.x / PAL_W)
		var row := int(prel.y / PAL_H)
		if col >= 0 and col < PAL_COLS:
			var idx := row * PAL_COLS + col
			if idx >= 0 and idx < _palette_ids().size():
				_hover_pal = idx

func _palette_ids() -> Array:
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
	# anywhere else invalid, it simply goes back where it was.
	if _hover_pal >= 0:
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

func _count(id: String) -> String:
	if unlimited or Components.is_structural(id):
		return "∞"
	return str(int(inventory.get(id, 0)))

## --- drawing ----------------------------------------------------------------
func _draw() -> void:
	var vp := get_viewport_rect().size
	# Only a light veil: the fight behind this panel has to stay readable.
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.05, 0.07, 0.62))
	_draw_header(vp)
	_draw_board()
	_draw_palette()
	_draw_info(vp)
	_draw_drag()

func _draw_header(vp: Vector2) -> void:
	draw_rect(Rect2(0, 0, vp.x, 84), Color(0.07, 0.08, 0.11, 0.9))
	draw_line(Vector2(0, 84), Vector2(vp.x, 84), Color(0.3, 0.5, 0.7, 0.6), 1.5)
	var text_width := TAB_ORIGIN.x - 64.0
	draw_string(_font, Vector2(48, 34), title_text, HORIZONTAL_ALIGNMENT_LEFT, text_width, 18, Color(0.85, 0.92, 1.0))
	var wdef := Weapons.get_def(weapon_id)
	# Traits matter more than flavour here: the preview below is computed with them.
	draw_string(_font, Vector2(48, 58), "%s · melee x%.2f · ranged x%.2f · bolt speed x%.2f" % [
		wdef["name"], float(wdef["melee_mul"]), float(wdef["ranged_mul"]), float(wdef["projectile_speed"])],
		HORIZONTAL_ALIGNMENT_LEFT, text_width, 11, Color(0.6, 0.7, 0.8))

	for i in boards.size():
		var b: SkillBoard = boards[i]
		var r := _tab_rect(i)
		var active := i == slot
		draw_rect(r, Color(0.18, 0.3, 0.42, 0.9) if active else Color(0.11, 0.13, 0.17, 0.9))
		draw_rect(r, Color(0.45, 0.8, 1.0) if active else Color(0.28, 0.33, 0.4), false, 1.5)
		draw_string(_font, r.position + Vector2(10, 20), "SLOT %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.85, 1.0))
		draw_string(_font, r.position + Vector2(10, 37), b.skill_name, HORIZONTAL_ALIGNMENT_LEFT, 136, 12, Color(0.9, 0.95, 1.0))
		if i == _hover_tab and not active:
			draw_rect(r, Color(1, 1, 1, 0.35), false, 1.2)
	var cr := _close_rect()
	draw_rect(cr, Color(0.45, 0.18, 0.2, 0.9) if _hover_close else Color(0.14, 0.12, 0.14, 0.9))
	draw_rect(cr, Color(1.0, 0.55, 0.55) if _hover_close else Color(0.45, 0.4, 0.44), false, 1.4)
	draw_string(_font, cr.position + Vector2(0, 20), "✕ CLOSE", HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 11,
		Color(1, 0.9, 0.9) if _hover_close else Color(0.8, 0.78, 0.8))

func _draw_board() -> void:
	var b := current_board()
	if b == null:
		return
	var size := Vector2(b.width * CELL, b.height * CELL)
	draw_rect(Rect2(BOARD_ORIGIN - Vector2(10, 10), size + Vector2(20, 20)), Color(0.08, 0.09, 0.12, 0.92))
	draw_rect(Rect2(BOARD_ORIGIN - Vector2(10, 10), size + Vector2(20, 20)), Color(0.3, 0.45, 0.6, 0.7), false, 1.5)

	for y in b.height:
		for x in b.width:
			var r := Rect2(BOARD_ORIGIN + Vector2(x * CELL, y * CELL), Vector2(CELL, CELL))
			draw_rect(r.grow(-1), Color(0.11, 0.13, 0.17))
			draw_rect(r.grow(-1), Color(0.2, 0.24, 0.3), false, 1.0)

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
		for c in Components.footprint(held, _hover_cell, rotation_step):
			if not b.in_bounds(c):
				continue
			var r := Rect2(BOARD_ORIGIN + Vector2(c.x * CELL, c.y * CELL), Vector2(CELL, CELL))
			draw_rect(r.grow(-3), Color(0.4, 1.0, 0.6, 0.22) if ok else Color(1.0, 0.4, 0.4, 0.22))
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
	var def := Components.get_def(_drag_id)
	var col := Style.component_color(_drag_id)
	var w := 108.0 if int(def.get("cells", 1)) == 1 else 150.0
	var r := Rect2(_mouse_pos + Vector2(14, -16), Vector2(w, 34))
	draw_rect(r, Color(col.r, col.g, col.b, 0.32))
	draw_rect(r, col, false, 1.6)
	draw_string(_font, r.position + Vector2(8, 23), Style.component_glyph(_drag_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
	draw_string(_font, r.position + Vector2(30, 22), String(def["name"]), HORIZONTAL_ALIGNMENT_LEFT, w - 36, 11, Color(0.95, 0.97, 1.0))
	# Rotation readout, since the wheel turns the part while it is in hand.
	var arrow: String = ["→", "↓", "←", "↑"][rotation_step]
	draw_string(_font, r.position + Vector2(w - 20, 23), arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.9, 1.0))

func _cell_center(c: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(c.x * CELL + CELL * 0.5, c.y * CELL + CELL * 0.5)

func _draw_port_arrow(cell: Vector2i, dir: int, col: Color) -> void:
	var v := Vector2(Components.dir_to_vec(dir))
	var c := _cell_center(cell) + v * (CELL * 0.5 - 8.0)
	var perp := v.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		c + v * 7.0, c - v * 3.0 + perp * 5.0, c - v * 3.0 - perp * 5.0,
	]), col)

## Live joints get a bridge across the seam; joints that touch but do not
## connect get a cross. Without this a board that looks wired can be dead and
## there is no way to see where.
func _draw_wiring() -> void:
	for link in _trace_cache.get("links", []):
		var a: Vector2 = _cell_center(link[0])
		var c: Vector2 = _cell_center(link[1])
		var mid := (a + c) * 0.5
		var v := (c - a).normalized()
		draw_line(mid - v * 11.0, mid + v * 11.0, Color(0.45, 1.0, 0.75, 0.95), 3.5)
	for br in _trace_cache.get("breaks", []):
		var a2: Vector2 = _cell_center(br["from"])
		var c2: Vector2 = _cell_center(br["to"])
		var mid2 := (a2 + c2) * 0.5
		var v2 := (c2 - a2).normalized()
		var p := v2.orthogonal() * 6.0
		var q := v2 * 6.0
		draw_line(mid2 - q - p, mid2 + q + p, Color(1.0, 0.4, 0.4, 0.95), 2.5)
		draw_line(mid2 - q + p, mid2 + q - p, Color(1.0, 0.4, 0.4, 0.95), 2.5)
	for leak in _trace_cache.get("leaks", []):
		if String(leak.get("why", "")) != "empty":
			continue
		var a3: Vector2 = _cell_center(leak["from"])
		var v3 := Vector2(Components.dir_to_vec(int(leak["dir"])))
		draw_circle(a3 + v3 * (CELL * 0.5 + 6.0), 3.0, Color(0.9, 0.6, 0.35, 0.75))

func _draw_component(b: SkillBoard, origin: Vector2i) -> void:
	var entry: Dictionary = b.cells[origin]
	var id: String = entry["id"]
	var rot: int = entry["rot"]
	var def := Components.get_def(id)
	var cells := Components.footprint(id, origin, rot)
	var col := Style.component_color(id)
	# A part the flow cannot reach is drawn faint: it is on the board but dead.
	var live: bool = not bool(_trace_cache.get("has_input", false)) \
		or _trace_cache.get("reachable", {}).has(origin)
	var fill_a := 0.28 if live else 0.08
	var line_col := col if live else Color(col.r, col.g, col.b, 0.35)
	for c in cells:
		var r := Rect2(BOARD_ORIGIN + Vector2(c.x * CELL, c.y * CELL), Vector2(CELL, CELL))
		draw_rect(r.grow(-3), Color(col.r, col.g, col.b, fill_a))
		draw_rect(r.grow(-3), line_col, false, 1.8)
	var center := _cell_center(origin)
	if cells.size() > 1:
		center = (_cell_center(cells[0]) + _cell_center(cells[1])) * 0.5
	var glyph_col := col.lightened(0.3) if live else Color(col.r, col.g, col.b, 0.4)
	var name_col := Color(0.75, 0.8, 0.88) if live else Color(0.5, 0.52, 0.56)
	draw_string(_font, center + Vector2(-CELL * 0.5, 4), Style.component_glyph(id), HORIZONTAL_ALIGNMENT_CENTER, CELL, 16, glyph_col)
	draw_string(_font, center + Vector2(-CELL * 0.8, CELL * 0.42), String(def["name"]), HORIZONTAL_ALIGNMENT_CENTER, CELL * 1.6, 8, name_col)

	var ex := Components.exit_cell(id, origin, rot)
	var arrow_col := col.lightened(0.4) if live else Color(col.r, col.g, col.b, 0.35)
	for d in Components.world_outputs(id, rot):
		_draw_port_arrow(ex, d, arrow_col)
	var pd := Components.world_payload_out(id, rot)
	if pd >= 0:
		_draw_port_arrow(ex, pd, Color(1.0, 0.55, 0.8) if live else Color(1.0, 0.55, 0.8, 0.35))

## Live pulses from the running circuit, so the board shows its own timing.
func _draw_live_flow(b: SkillBoard) -> void:
	if slot >= runners.size():
		return
	var r: SkillRunner = runners[slot]
	if r == null or r.board != b:
		return
	for p in r.pulses:
		var c := _cell_center(p.cell)
		var glow := Color(0.6, 1.0, 0.85, 0.85)
		draw_circle(c, 7.0 + 4.0 * sin(p.progress() * PI), glow)
		draw_arc(c, CELL * 0.42, -PI * 0.5, -PI * 0.5 + TAU * p.progress(), 20, Color(0.5, 1.0, 0.8, 0.7), 2.0)

func _draw_palette() -> void:
	var ids := _palette_ids()
	var rows := int(ceil(float(ids.size()) / float(PAL_COLS)))
	var panel := Rect2(PAL_ORIGIN - Vector2(10, 10), Vector2(PAL_COLS * PAL_W + 20, rows * PAL_H + 20))
	draw_rect(panel, Color(0.08, 0.09, 0.12, 0.92))
	draw_rect(panel, Color(0.3, 0.45, 0.6, 0.7), false, 1.5)

	for i in ids.size():
		var id: String = ids[i]
		var def := Components.get_def(id)
		var col := int(i % PAL_COLS)
		var row := int(i / PAL_COLS)
		var r := Rect2(PAL_ORIGIN + Vector2(col * PAL_W, row * PAL_H), Vector2(PAL_W - 4, PAL_H - 4))
		var have := unlimited or Components.is_structural(id) or int(inventory.get(id, 0)) > 0
		var c := Style.component_color(id)
		var bg := Color(c.r, c.g, c.b, 0.18 if have else 0.05)
		if id == selected:
			bg = Color(c.r, c.g, c.b, 0.42)
		draw_rect(r, bg)
		draw_rect(r, c if have else Color(0.3, 0.32, 0.36), false, 1.5 if id == selected else 1.0)
		var text_col := Color(0.92, 0.95, 1.0) if have else Color(0.45, 0.48, 0.52)
		draw_string(_font, r.position + Vector2(8, 18), Style.component_glyph(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)
		draw_string(_font, r.position + Vector2(30, 18), String(def["name"]), HORIZONTAL_ALIGNMENT_LEFT, PAL_W - 40, 10, text_col)
		draw_string(_font, r.position + Vector2(30, 34), "x%s" % _count(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.7, 0.8))
		if i == _hover_pal:
			draw_rect(r, Color(1, 1, 1, 0.5), false, 1.5)

func _draw_info(vp: Vector2) -> void:
	var y := vp.y - 132.0
	draw_rect(Rect2(0, y, vp.x, 132), Color(0.07, 0.08, 0.11, 0.94))
	draw_line(Vector2(0, y), Vector2(vp.x, y), Color(0.3, 0.5, 0.7, 0.6), 1.5)

	var describe: String = selected if _hover_pal < 0 else String(_palette_ids()[_hover_pal])
	if describe != "":
		var def := Components.get_def(describe)
		draw_string(_font, Vector2(48, y + 26), String(def["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Style.component_color(describe))
		draw_string(_font, Vector2(48, y + 46), String(def["desc"]), HORIZONTAL_ALIGNMENT_LEFT, 620, 11, Color(0.72, 0.78, 0.86))
		draw_string(_font, Vector2(48, y + 66), "cells %d   cost %d ticks, one per cell   heat %.1f" % [
			int(def["cells"]), Components.tick_cost(describe), float(def["heat"])],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.65, 0.75))

	var b := current_board()
	if b == null:
		return
	# The board walk is only redone when something actually changed.
	if _sim_dirty or _sim_cache.is_empty():
		var sim := SkillRunner.new(b)
		sim.base_payload_provider = func() -> Payload: return Weapons.base_payload(weapon_id)
		_sim_cache = sim.simulate()
		_trace_cache = b.trace()
		_sim_dirty = false
	var result := _sim_cache
	var rx := 700.0
	if String(result.get("error", "")) != "":
		draw_string(_font, Vector2(rx, y + 26), String(result["error"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.55, 0.5))
	else:
		var outs: Array = result["outputs"]
		draw_string(_font, Vector2(rx, y + 26), "CYCLE %.2fs   outputs %d   heat %.1f" % [
			float(result["cycle_seconds"]), outs.size(), float(result["heat"])],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.95, 0.85))
		var line := y + 46.0
		if outs.is_empty():
			# A flow that simply ran out of life is not a wiring fault, and
			# `first_problem` would go looking for one that is not there.
			var why := b.first_problem()
			if bool(result.get("expired", false)):
				why = "The flow runs out of life (%d) before it reaches an OUTPUT. Shorten it, or hold the cast button to charge it further." % int(result.get("ttl", 0))
			draw_string(_font, Vector2(rx, line), why,
				HORIZONTAL_ALIGNMENT_LEFT, 560, 12, Color(1.0, 0.62, 0.45))
			line += 18.0
		for i in mini(outs.size(), 3):
			var p: Payload = Weapons.finalize(weapon_id, (outs[i] as Payload).clone())
			draw_string(_font, Vector2(rx, line), "• %s" % p.summary(), HORIZONTAL_ALIGNMENT_LEFT, 520, 11, Color(0.82, 0.88, 0.95))
			line += 17.0
		# Overclocking is a trade, so show both halves of it.
		if int(result.get("overclock", 0)) > 0:
			draw_string(_font, Vector2(rx, line), "OVERCLOCK x%d · clock x%.2f · +%.2fs settle" % [
				int(result["overclock"]), float(result["speed_mul"]), float(result["penalty_seconds"])],
				HORIZONTAL_ALIGNMENT_LEFT, 520, 10, Style.flow_color())
			line += 16.0
		# What holding the cast button buys this board, in the board's own terms.
		draw_string(_font, Vector2(rx, line),
			"LIFE %d · hold the cast button to buy more, release to fire"
				% int(result.get("ttl", 0)),
			HORIZONTAL_ALIGNMENT_LEFT, 520, 10, Color(0.78, 0.68, 1.0))
		line += 16.0
		var trig: Dictionary = result.get("triggers", {})
		for k in trig:
			# A loop can queue several follow-ups on one trigger, each landing
			# after the one before. List the whole chain, so four laps read as
			# four attacks rather than as a single very large one.
			var q = trig[k]
			var n := 0
			while q != null:
				var label: String = String(Components.get_def(k).get("name", k)) if n == 0 else "then"
				draw_string(_font, Vector2(rx, line), "↳ %s: %s" % [label, (q as Payload).summary()],
					HORIZONTAL_ALIGNMENT_LEFT, 520, 10, Color(1.0, 0.7, 0.85))
				line += 15.0
				n += 1
				q = q.on_hit
		if not Weapons.accepts_board(weapon_id, b):
			draw_string(_font, Vector2(rx, line), Weapons.rejection_reason(weapon_id, b),
				HORIZONTAL_ALIGNMENT_LEFT, 520, 11, Color(1.0, 0.5, 0.5))

	if _message_time > 0.0:
		draw_string(_font, Vector2(48, y + 96), _message, HORIZONTAL_ALIGNMENT_LEFT, 600, 12, Color(1.0, 0.65, 0.55))
	# Controls live along the bottom, clear of the slot tabs at the top.
	draw_string(_font, Vector2(48, vp.y - 10),
		"drag to place · wheel turns the part under the cursor · RMB removes · TAB or ESC closes",
		HORIZONTAL_ALIGNMENT_LEFT, vp.x - 96, 11, Color(0.5, 0.58, 0.68))
