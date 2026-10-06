class_name MapTable
extends Control

## The table a map is laid on, in the map creator (`MapMaker`): the grid in the
## middle; down the left what there is to lay, a tile each, and the map's own
## numbers under them; and along the top the map's name and what is done with
## it — SAVE, LOAD, NEW, a step back and forward, PLAY.
##
## What is laid is drawn the way the game draws it, out of the game's own
## pieces: rock in its region's tint with a lit top (`RoomView`), a monster as
## the atlas character its kind wears and the player's start as the player
## (`Sprites`), the box and the ground to dig in theirs (`TreasureBoxView`,
## `DigSpotView`). They stand still here; PLAY is where they move.
##
## The sheet is drawn only when something on it changes — a map four screens
## each way is fourteen thousand cells — and what follows the pointer is drawn
## over it on a sheet of its own.
##
## A pointer's screen: the left button lays what is in hand, the right one
## erases, SHIFT held drags a box of either, and the map is moved under the
## pointer by the middle button, the move keys or the MOVE tool, and brought
## nearer or further by the wheel. A thumb has MOVE and ERASE among the tiles
## for what it has no button for. Nothing here takes the keyboard but the
## name, so the keys are the map's whenever the name is not being typed.
##
## It makes no change of its own: everything it does is asked of the maker,
## which is what a test asks too.

## How wide the column down the left is, and how tall the line along the
## bottom.
const SIDE_W := 232.0
const FOOT_H := 28.0
## What there is to lay stands in rows of this many tiles, each no narrower
## than this: they share the column's width between them.
const TILES_ACROSS := 4
const TILE_W := 46.0
## The room a panel of the table's keeps inside its edge, in either mode.
const PANEL_PAD := 8.0
## How much of a room's cell one of the sheet's is, nearest first. A raid's
## room is the screen across, so with the column beside it a whole one is only
## seen at half.
const ZOOMS := [1.0, 0.5]
## Screen pixels a second the move keys carry the map.
const PAN_SPEED := 900.0
## How far past its own edge the map can be moved, in cells.
const PAD_CELLS := 4
## How long a button that asks twice stays asked, and a line stays said.
const ARM_TIME := 3.0
const SAY_TIME := 4.0
## The tool that lays nothing: the left button moves the map instead.
const MOVE := "move"

const GRID := Color(1, 1, 1, 0.05)
const SCREEN_LINE := Color(0.45, 0.85, 1.0, 0.22)
const SEAM := Color(0, 0, 0, 0.22)
const ICON_MOVE := [
	"...#...",
	"..###..",
	".#.#.#.",
	"#######",
	".#.#.#.",
	"..###..",
	"...#...",
]
const ICON_ERASE := [
	"#.....#",
	".#...#.",
	"..#.#..",
	"...#...",
	"..#.#..",
	".#...#.",
	"#.....#",
]

var maker: MapMaker
## What is in hand: a mark (`MadeRoom`), or MOVE.
var brush: String = MadeRoom.ROCK

var _px := PixelDraw.new(self)
var _zoom_at: int = ZOOMS.size() - 1
## Where the map's first cell starts, on the sheet.
var _origin := Vector2.ZERO
var _framed: bool = false
var _hover := Vector2i(-1, -1)
## The mark a stroke under way is laying, or "" between strokes, and the last
## cell it laid.
var _stroke: String = ""
var _last := Vector2i.ZERO
## A box being dragged: the corner it started from and what it will lay.
var _boxing: bool = false
var _box_from := Vector2i.ZERO
var _box_mark: String = ""
## Whether the pointer is carrying the map, and where it last had hold of it.
var _panning: bool = false
var _pan_at := Vector2.ZERO
## The line the foot is saying, in what colour, and for how much longer.
var _said: String = ""
var _said_tone := UiKit.TEXT
var _said_left: float = 0.0
## What has been asked once and waits to be asked again — "save:<id>" over
## another map's name, "delete:<id>" — and for how much longer.
var _armed: String = ""
var _armed_left: float = 0.0
## The name the field was last given by the maker, to see the map change.
var _shown_id: String = ""
## Whether the chrome was built for a thumb.
var _thumb: bool = false

var _sheet: Sheet
var _over: Over
var _bar: PanelContainer
var _side: PanelContainer
var _name: LineEdit
var _undo_button: Button
var _redo_button: Button
## The name of what is in hand, under the tiles.
var _in_hand: Label
var _wide: Label
var _high: Label
var _region: Button
var _weapon: Button
var _zoom: Button
## mark or tool -> its tile.
var _palette: Dictionary = {}
## The tile the pointer is on, or "" for none: the foot says its name.
var _over_tile: String = ""
## The list of kept maps, while LOAD has it up.
var _popup: Control = null

## The map itself, drawn when it changes.
class Sheet extends Control:
	var table: MapTable
	func _draw() -> void:
		table._paint_sheet(self)

## What follows the pointer over it: the cell it is on, a box being dragged.
class Over extends Control:
	var table: MapTable
	func _draw() -> void:
		table._paint_over(self)

func _ready() -> void:
	UiKit.fill_screen(self)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build()
	Loc.language_changed.connect(func(_lang: String) -> void: _build())

## --- the chrome -------------------------------------------------------------

## Everything on the table but the map's own state, built for the language and
## the mode in force: built again when either changes.
func _build() -> void:
	var typed := _name.text if _name != null else maker.map_id
	for old in get_children():
		remove_child(old)
		old.queue_free()
	_popup = null
	_palette.clear()
	_thumb = UiKit.mobile()
	_sheet = Sheet.new()
	_sheet.table = self
	_sheet.clip_contents = true
	_sheet.gui_input.connect(_on_sheet_input)
	_sheet.mouse_exited.connect(func() -> void: _point_at(Vector2i(-1, -1)))
	add_child(_sheet)
	_over = Over.new()
	_over.table = self
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(_over)
	_build_bar(typed)
	_build_side()
	_shown_id = maker.map_id
	_fit()
	_refresh()

func _build_bar(typed: String) -> void:
	_bar = _panel()
	add_child(_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_bar.add_child(row)
	var back := _button(Loc.t("menu.pause.arrow"), UiKit.ACCENT)
	back.custom_minimum_size.x = 44.0
	back.pressed.connect(func() -> void: maker.leave())
	row.add_child(back)
	row.add_child(_word(Loc.t("hud.maker.title"), Color(0.9, 0.95, 1.0)))
	_name = LineEdit.new()
	_name.text = typed
	_name.placeholder_text = Loc.t("hud.maker.name")
	_name.max_length = Maps.ID_LENGTH
	_name.custom_minimum_size = Vector2(240.0, _plate())
	_name.add_theme_font_override("font", UiKit.PIXEL_FONT)
	_name.add_theme_font_size_override("font_size", UiKit.PIXEL_TEXT)
	_name.add_theme_color_override("font_color", UiKit.TEXT)
	_name.add_theme_color_override("font_placeholder_color", UiKit.DIM)
	_name.add_theme_stylebox_override("normal", UiKit.style(UiKit.BG, UiKit.LINE, 1, 0, true))
	_name.add_theme_stylebox_override("focus", UiKit.style(Color(0, 0, 0, 0), UiKit.ACCENT, 1, 0, true))
	_name.text_submitted.connect(func(_text: String) -> void: _name.release_focus())
	row.add_child(_name)
	_bar_button(row, "hud.maker.save", UiKit.GOOD, _save)
	_bar_button(row, "hud.maker.load", UiKit.ACCENT, _open_list)
	_bar_button(row, "hud.maker.new", UiKit.ACCENT, _new)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	_undo_button = _bar_button(row, "hud.maker.undo", UiKit.ACCENT, _undo)
	_redo_button = _bar_button(row, "hud.maker.redo", UiKit.ACCENT, _redo)
	var play := _bar_button(row, "hud.maker.play", UiKit.GOOD, func() -> void: maker.play())
	play.custom_minimum_size.x = 96.0

func _bar_button(row: HBoxContainer, key: String, tone: Color, press: Callable) -> Button:
	var b := _button(Loc.t(key), tone)
	b.pressed.connect(press)
	row.add_child(b)
	return b

func _build_side() -> void:
	_side = _panel()
	add_child(_side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_side.add_child(column)
	# What there is to lay: the two tools, then every mark a room can hold.
	var tiles := GridContainer.new()
	tiles.columns = TILES_ACROSS
	tiles.add_theme_constant_override("h_separation", 4)
	tiles.add_theme_constant_override("v_separation", 4)
	column.add_child(tiles)
	var entries := PackedStringArray([MOVE, MadeRoom.OPEN])
	entries.append_array(MadeRoom.marks())
	for entry in entries:
		tiles.add_child(_tile(entry))
	_in_hand = _word("", UiKit.ACCENT)
	_in_hand.clip_text = true
	column.add_child(_in_hand)
	column.add_child(UiKit.hline(true))
	# The map's own numbers, under them.
	_wide = _stepper(column, Loc.t("hud.maker.width"), func(by: int) -> void: _resize(Vector2i(by, 0)))
	_high = _stepper(column, Loc.t("hud.maker.height"), func(by: int) -> void: _resize(Vector2i(0, by)))
	_region = _side_button(column, func() -> void:
		maker.set_region((maker.region + 1) % Style.REGION_TINT.size())
		_changed())
	_weapon = _side_button(column, func() -> void:
		maker.cycle_weapon()
		_refresh())
	_zoom = _side_button(column, func() -> void:
		_zoom_to((_zoom_at + 1) % ZOOMS.size(), _sheet.size * 0.5))

## One thing to lay, as a tile with its picture on it. The one in hand is lit
## and cannot be pressed again; its name stands under the tiles, and the foot
## says the name of whichever the pointer is on.
func _tile(entry: String) -> Button:
	var b := _button("", UiKit.ACCENT)
	b.custom_minimum_size = Vector2(TILE_W, maxf(_plate(), 48.0))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chosen := b.get_theme_stylebox("disabled") as StyleBoxFlat
	chosen.bg_color = Color(UiKit.ACCENT, 0.22)
	chosen.border_color = UiKit.ACCENT
	b.pressed.connect(func() -> void: take(entry))
	b.draw.connect(func() -> void: _paint_tile(b, entry))
	b.mouse_entered.connect(func() -> void: _over_tile = entry)
	b.mouse_exited.connect(func() -> void:
		if _over_tile == entry:
			_over_tile = "")
	_palette[entry] = b
	return b

## A number with a way down and a way up either side of it. SHIFT takes ten.
func _stepper(column: VBoxContainer, words: String, step: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	column.add_child(row)
	var caption := _word(words, UiKit.TEXT)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.clip_text = true
	row.add_child(caption)
	var value := _word("", UiKit.ACCENT)
	value.custom_minimum_size.x = 44.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for by: int in [-1, 1]:
		var b := _button("-" if by < 0 else "+", UiKit.ACCENT)
		b.custom_minimum_size.x = 34.0
		b.pressed.connect(func() -> void: step.call(by * (10 if Input.is_key_pressed(KEY_SHIFT) else 1)))
		row.add_child(b)
		if by < 0:
			row.add_child(value)
	return value

func _side_button(column: VBoxContainer, press: Callable) -> Button:
	var b := _button("", UiKit.ACCENT)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.pressed.connect(press)
	column.add_child(b)
	return b

## A word standing beside the buttons, in the middle of the row's height.
func _word(words: String, tone: Color) -> Label:
	var l := UiKit.label(words, UiKit.PIXEL_TEXT, tone, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## A button of the table's: the kit's pixel one, never taking the keyboard, and
## at the table's own size in either mode — a thumb's is taller, but there are
## too many of them on one screen to stand a full thumb each, or to keep a
## thumb's room either side of every word.
func _button(words: String, tone: Color) -> Button:
	var b := UiKit.overlay_button(words, tone, true)
	b.custom_minimum_size = Vector2(0.0, _plate())
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_size_override("font_size", Loc.text_size(words, UiKit.PIXEL_TEXT))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := b.get_theme_stylebox(state) as StyleBoxFlat
		box.content_margin_left = 10.0
		box.content_margin_right = 10.0
	return b

## How tall a thing to press stands on the table.
func _plate() -> float:
	return 56.0 if _thumb else 34.0

## A panel of the table's: the kit's pixel one, keeping the same room inside
## its edge in either mode — the column down the left is one width, and a
## thumb's wider margin would not leave it room for its tiles.
func _panel() -> PanelContainer:
	var p := UiKit.panel(UiKit.PANEL, UiKit.LINE, true)
	var box := p.get_theme_stylebox("panel") as StyleBoxFlat
	box.content_margin_left = PANEL_PAD
	box.content_margin_right = PANEL_PAD
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

## What a mark or a tool is called, in the language being played.
static func name_of(entry: String) -> String:
	match entry:
		MOVE:
			return Loc.t("hud.maker.tool.move")
		MadeRoom.OPEN:
			return Loc.t("hud.maker.tool.erase")
		MadeRoom.ROCK:
			return Loc.t("hud.maker.mark.rock")
		MadeRoom.START:
			return Loc.t("hud.maker.mark.start")
		MadeRoom.BOX:
			return Loc.t("hud.maker.mark.box")
		MadeRoom.DIG:
			return Loc.t("hud.maker.mark.dig")
	var kind := MadeRoom.monster_of(entry)
	return Monsters.name_for(kind).to_upper() if kind != "" else entry

## Takes `entry` in hand: a mark, or MOVE.
func take(entry: String) -> void:
	brush = entry
	_refresh()

## Puts on the chrome whatever the maker has that it shows.
func _refresh() -> void:
	for entry in _palette:
		(_palette[entry] as Button).disabled = entry == brush
		# Its picture is in the map's rock, which may just have changed.
		(_palette[entry] as Button).queue_redraw()
	_in_hand.text = name_of(brush)
	_wide.text = str(maker.cols)
	_high.text = str(maker.rows)
	_region.text = Loc.t("hud.maker.region", [maker.region + 1])
	_weapon.text = Loc.t("hud.maker.weapon", [Weapons.name_for(maker.current_weapon()).to_upper()])
	_zoom.text = Loc.t("hud.maker.zoom", [int(ZOOMS[_zoom_at] * 100.0)])
	if maker.map_id != _shown_id:
		_shown_id = maker.map_id
		_name.text = maker.map_id

## Where everything stands for the screen as it is: the bar across the top, the
## column down the left, and the sheet in what is left over the foot.
func _fit() -> void:
	var bar_h := _bar.get_combined_minimum_size().y
	_bar.position = Vector2.ZERO
	_bar.size = Vector2(size.x, bar_h)
	_side.position = Vector2(0.0, bar_h)
	_side.size = Vector2(SIDE_W, size.y - bar_h)
	var room := Rect2(SIDE_W, bar_h, size.x - SIDE_W, size.y - bar_h - FOOT_H)
	if _sheet.position != room.position or _sheet.size != room.size:
		_sheet.position = room.position
		_sheet.size = room.size
		_over.size = room.size
		if not _framed:
			_framed = true
			_frame_map()
		_keep_in_sight()
		_sheet.queue_redraw()

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	if _thumb != UiKit.mobile():
		_build()
	_fit()
	_undo_button.disabled = not maker.can_undo()
	_redo_button.disabled = not maker.can_redo()
	_said_left = maxf(0.0, _said_left - delta)
	if _armed != "":
		_armed_left -= delta
		if _armed_left <= 0.0:
			_disarm()
	# The move keys carry the map — but not while they are typing a name, nor
	# while one of them is half of a shortcut: SAVE's is a move key too.
	if is_visible_in_tree() and _popup == null and not _name.has_focus() \
			and not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_META):
		var push := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if push != Vector2.ZERO:
			_origin -= push * PAN_SPEED * delta
			_keep_in_sight()
			_sheet.queue_redraw()
	queue_redraw()

## --- the map on the sheet -----------------------------------------------------

## How many screen pixels a cell of the map is across.
func cell_size() -> float:
	return Room.CELL * float(ZOOMS[_zoom_at])

## The cell under a point of the sheet. It may be off the map.
func cell_at(at: Vector2) -> Vector2i:
	return Vector2i(((at - _origin) / cell_size()).floor())

## Where on the sheet the cell `c` is.
func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(c) * cell_size(), Vector2.ONE * cell_size())

## Stands the whole map in the middle of the sheet, where it fits there, and
## otherwise its top-left corner in the sheet's.
func _frame_map() -> void:
	var map := Vector2(maker.cols, maker.rows) * cell_size()
	_origin = ((_sheet.size - map) * 0.5).max(Vector2.ONE * cell_size())

## The map is never moved clean off the sheet: its middle stays within the
## map's own edges and a little. On whole pixels of the look, so nothing on it
## lands between two.
func _keep_in_sight() -> void:
	var cs := cell_size()
	var pad := Vector2.ONE * PAD_CELLS * cs
	var map := Vector2(maker.cols, maker.rows) * cs
	var middle := (_sheet.size * 0.5 - _origin).clamp(-pad, map + pad)
	_origin = ((_sheet.size * 0.5 - middle) / UiKit.PIXEL).round() * UiKit.PIXEL

## Brings the map nearer or further, about the point `about` of the sheet.
func _zoom_to(level: int, about: Vector2) -> void:
	level = clampi(level, 0, ZOOMS.size() - 1)
	if level == _zoom_at:
		return
	var under := (about - _origin) / cell_size()
	_zoom_at = level
	_origin = about - under * cell_size()
	_keep_in_sight()
	_refresh()
	_sheet.queue_redraw()

func _paint_sheet(cv: CanvasItem) -> void:
	var cs := cell_size()
	var k := cs / float(Room.CELL)
	var tint := Style.region_tint(maker.region)
	var view := Rect2(Vector2.ZERO, _sheet.size)
	var across := Vector2i(maker.cols, maker.rows)
	var map := Rect2(_origin, Vector2(across) * cs)
	# Past the map's edge there is rock, which is how the game draws it and how
	# a made room is shut in (`MadeRoom`): darker here, so the edge reads.
	cv.draw_rect(view, tint.darkened(0.4))
	cv.draw_rect(map, Style.ROOM_BG)
	var first := Vector2i(((view.position - _origin) / cs).floor()).clamp(Vector2i.ZERO, across)
	var last := Vector2i(((view.end - _origin) / cs).ceil()).clamp(Vector2i.ZERO, across)
	var plan := maker.plan()
	for y in range(first.y, last.y):
		var row := plan[y]
		for x in range(first.x, last.x):
			if row[x] == MadeRoom.ROCK:
				paint_rock(cv, Rect2(_origin + Vector2(x, y) * cs, Vector2(cs, cs)), tint,
					y > 0 and plan[y - 1][x] != MadeRoom.ROCK)
	# The grid over the rock, a line a cell and a brighter one a screen: a
	# raid's room is one screen, and a camera follows the player past it.
	var line := maxf(1.0, UiKit.PIXEL * k)
	for x in range(first.x, last.x + 1):
		cv.draw_rect(Rect2(_origin.x + x * cs, map.position.y, line, map.size.y),
			SCREEN_LINE if x % Room.W == 0 else GRID)
	for y in range(first.y, last.y + 1):
		cv.draw_rect(Rect2(map.position.x, _origin.y + y * cs, map.size.x, line),
			SCREEN_LINE if y % Room.H == 0 else GRID)
	# Everything else that is laid, after the rock and from the top down: a
	# tall one stands up past its own cell, over whatever is behind it. A few
	# rows more than are in sight, for one whose feet are just under the sheet.
	for y in range(first.y, mini(last.y + 3, across.y)):
		var row := plan[y]
		for x in range(maxi(first.x - 1, 0), mini(last.x + 1, across.x)):
			if row[x] != MadeRoom.ROCK and row[x] != MadeRoom.OPEN:
				paint_mark(cv, row[x], Rect2(_origin + Vector2(x, y) * cs, Vector2(cs, cs)), tint)

func _paint_over(cv: CanvasItem) -> void:
	if _popup != null or (brush == MOVE and not _boxing):
		return
	if _boxing:
		var a := cell_rect(_box_from.clamp(Vector2i.ZERO, Vector2i(maker.cols - 1, maker.rows - 1)))
		var b := cell_rect(_hover.clamp(Vector2i.ZERO, Vector2i(maker.cols - 1, maker.rows - 1)))
		var box := a.merge(b)
		cv.draw_rect(box, Color(UiKit.ACCENT, 0.18))
		_edge(cv, box, UiKit.ACCENT)
	elif maker.holds(_hover):
		_edge(cv, cell_rect(_hover), Color.WHITE)

## A border a PIXEL wide, inside `r`.
func _edge(cv: CanvasItem, r: Rect2, col: Color) -> void:
	var w := float(UiKit.PIXEL)
	cv.draw_rect(Rect2(r.position, Vector2(r.size.x, w)), col)
	cv.draw_rect(Rect2(r.position.x, r.end.y - w, r.size.x, w), col)
	cv.draw_rect(Rect2(r.position.x, r.position.y + w, w, r.size.y - w * 2.0), col)
	cv.draw_rect(Rect2(r.end.x - w, r.position.y + w, w, r.size.y - w * 2.0), col)

## --- what is laid, drawn --------------------------------------------------------

## A cell of rock, as `RoomView` draws one: the region's tint, a lit strip
## along a top with nothing over it, and a dark seam to the next.
static func paint_rock(cv: CanvasItem, r: Rect2, tint: Color, lit: bool) -> void:
	var k := r.size.x / float(Room.CELL)
	cv.draw_rect(r, tint)
	if lit:
		cv.draw_rect(Rect2(r.position, Vector2(r.size.x, 4.0 * k)), tint.lightened(0.35))
	cv.draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0 * k)), SEAM)
	cv.draw_rect(Rect2(r.position, Vector2(2.0 * k, r.size.y)), SEAM)

## Whatever `mark` stands for, drawn in the cell `r` as the game draws it —
## smaller by as much as `r` is smaller than a room's cell.
static func paint_mark(cv: CanvasItem, mark: String, r: Rect2, tint: Color) -> void:
	var k := r.size.x / float(Room.CELL)
	match mark:
		MadeRoom.ROCK:
			paint_rock(cv, r, tint, true)
		MadeRoom.START:
			_paint_body(cv, Style.PLAYER_ART, Color.WHITE, r, k, false)
		MadeRoom.BOX:
			_paint_box(cv, r, k)
		MadeRoom.DIG:
			_paint_dig(cv, r, k)
		_:
			var kind := MadeRoom.monster_of(mark)
			if kind != "":
				_paint_body(cv, Style.monster_art(kind), Style.monster_tint(kind), r, k, flies(mark))

## Whether `mark` posts a monster that flies: one that holds the middle of its
## cell rather than standing on its floor.
static func flies(mark: String) -> bool:
	var kind := MadeRoom.monster_of(mark)
	return kind != "" and String(Monsters.get_def(kind)["ai"]) == "flyer"

## A character standing in the cell: its first idle frame at the size every
## sprite is drawn (`Sprites.PIXEL_SCALE`), its feet on the cell's floor — or,
## for one that flies, its middle on the cell's.
static func _paint_body(cv: CanvasItem, art: String, tint: Color, r: Rect2, k: float, midair: bool) -> void:
	var frames := Sprites.resolved_frames(art)
	if frames == null or not frames.has_animation("idle") or frames.get_frame_count("idle") == 0:
		return
	var s := Sprites.PIXEL_SCALE * k
	var drawn := Sprites.art_rect(art)
	var at := Vector2(r.get_center().x - drawn.get_center().x * s, r.end.y - drawn.end.y * s)
	if midair:
		at.y = r.get_center().y - drawn.get_center().y * s
	cv.draw_texture_rect(frames.get_frame_texture("idle", 0),
		Rect2(at.round(), Sprites.frame_size(art) * s), false, tint)

## The box, shut, as `TreasureBoxView` draws it, standing on the cell's floor.
static func _paint_box(cv: CanvasItem, r: Rect2, k: float) -> void:
	var w := TreasureBoxView.W * k
	var h := TreasureBoxView.H * k
	var lid := TreasureBoxView.LID_H * k
	var body := Rect2(r.get_center().x - w * 0.5, r.end.y - h, w, h)
	var glow := Style.TREASURE_GLOW
	glow.a = 0.22
	cv.draw_circle(Vector2(body.get_center().x, body.position.y + 2.0 * k), 20.0 * k, glow)
	var top := Rect2(body.position.x - k, body.position.y - lid, w + 2.0 * k, lid)
	cv.draw_rect(top, Style.TREASURE_WOOD)
	cv.draw_rect(top, Style.TREASURE_EDGE, false, 2.0 * k)
	cv.draw_rect(Rect2(top.position.x, top.get_center().y - k, top.size.x, 2.0 * k), Style.TREASURE_BAND)
	cv.draw_rect(body, Style.TREASURE_WOOD)
	cv.draw_rect(Rect2(body.position.x, body.position.y + 4.0 * k, w, 3.0 * k), Style.TREASURE_BAND)
	cv.draw_rect(Rect2(body.get_center().x - 2.0 * k, body.position.y + 3.0 * k, 4.0 * k, 5.0 * k), Style.TREASURE_BAND)
	cv.draw_rect(body, Style.TREASURE_EDGE, false, 2.0 * k)

## Ground worth digging, as `DigSpotView` draws it: a lit mound on the floor.
static func _paint_dig(cv: CanvasItem, r: Rect2, k: float) -> void:
	var px := float(PixelCamera.SCALE) * k
	var w := DigSpotView.W * k
	var left := r.get_center().x - w * 0.5
	var ground := r.end.y
	var glow := DigSpotView.GLOW
	glow.a = 0.2
	cv.draw_circle(Vector2(r.get_center().x, ground - px * 2.0), 18.0 * k, glow)
	cv.draw_rect(Rect2(left, ground - px, w, px), DigSpotView.EARTH_DARK)
	cv.draw_rect(Rect2(left + px, ground - px * 2.0, w - px * 2.0, px), DigSpotView.EARTH)
	cv.draw_rect(Rect2(left + px * 3.0, ground - px * 3.0, w - px * 6.0, px), DigSpotView.EARTH)
	cv.draw_rect(Rect2(left + px * 4.0, ground - px * 3.0, px * 3.0, px), DigSpotView.EARTH_LIT)
	cv.draw_rect(Rect2(left + px * 2.0, ground - px * 2.0, px * 2.0, px), DigSpotView.EARTH_LIT)
	cv.draw_rect(Rect2(r.get_center().x, ground - px * 4.0, px, px), Color(1.0, 0.95, 0.7))

## A tile's picture: the thing itself in the middle of the tile, at the size
## the game draws it where that fits the tile and at half that where it does
## not — the Warden and the Arbiter are too big for one. A tool has a mark of
## its own.
func _paint_tile(b: Button, entry: String) -> void:
	var ink := Color.WHITE if b.disabled or b.is_hovered() else UiKit.TEXT
	var room := Rect2(Vector2.ZERO, b.size).grow(-4.0)
	match entry:
		MOVE:
			PixelDraw.new(b).icon_centered(room.get_center(), ICON_MOVE, ink, 2)
		MadeRoom.OPEN:
			PixelDraw.new(b).icon_centered(room.get_center(), ICON_ERASE, ink, 2)
		_:
			var k := 1.0 if stands_in(entry).size.x <= room.size.x and stands_in(entry).size.y <= room.size.y else 0.5
			var cs := Room.CELL * k
			var tall := stands_in(entry).size.y * k
			# In the middle of the tile, whatever its own shape: `stands_in` is
			# measured from the middle of the cell's floor.
			var foot := Vector2(room.get_center().x - stands_in(entry).get_center().x * k,
				room.get_center().y + tall * 0.5 - stands_in(entry).end.y * k)
			paint_mark(b, entry, Rect2(foot.x - cs * 0.5, foot.y - cs, cs, cs), Style.region_tint(maker.region))

## The room what `mark` stands for takes up at the game's own size, measured
## from the middle of its cell's floor: across from there, and up from it.
static func stands_in(mark: String) -> Rect2:
	var c := float(Room.CELL)
	match mark:
		MadeRoom.ROCK:
			return Rect2(-c * 0.5, -c, c, c)
		MadeRoom.BOX:
			var high := TreasureBoxView.H + TreasureBoxView.LID_H
			return Rect2(-TreasureBoxView.W * 0.5 - 1.0, -high, TreasureBoxView.W + 2.0, high)
		MadeRoom.DIG:
			return Rect2(-DigSpotView.W * 0.5, -PixelCamera.SCALE * 4.0, DigSpotView.W, PixelCamera.SCALE * 4.0)
	var art := Style.PLAYER_ART if mark == MadeRoom.START else Style.monster_art(MadeRoom.monster_of(mark))
	var drawn := Sprites.art_rect(art).size * Sprites.PIXEL_SCALE
	if flies(mark):
		return Rect2(-drawn.x * 0.5, -c * 0.5 - drawn.y * 0.5, drawn.x, drawn.y)
	return Rect2(-drawn.x * 0.5, -drawn.y, drawn.x, drawn.y)

## --- the pointer on the sheet -------------------------------------------------

func _on_sheet_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		var cell := cell_at(click.position)
		if click.pressed:
			# The name lets go of the keyboard: the keys are the map's again.
			get_viewport().gui_release_focus()
			match click.button_index:
				MOUSE_BUTTON_LEFT:
					if brush == MOVE:
						_begin_pan(click.position)
					elif click.shift_pressed:
						_begin_box(cell, brush)
					else:
						_begin_stroke(cell, brush)
				MOUSE_BUTTON_RIGHT:
					if click.shift_pressed:
						_begin_box(cell, MadeRoom.OPEN)
					else:
						_begin_stroke(cell, MadeRoom.OPEN)
				MOUSE_BUTTON_MIDDLE:
					_begin_pan(click.position)
				MOUSE_BUTTON_WHEEL_UP:
					_zoom_to(_zoom_at - 1, click.position)
				MOUSE_BUTTON_WHEEL_DOWN:
					_zoom_to(_zoom_at + 1, click.position)
		elif click.button_index == MOUSE_BUTTON_LEFT or click.button_index == MOUSE_BUTTON_RIGHT:
			if _boxing:
				_boxing = false
				maker.begin_stroke()
				if maker.lay_box(_box_from, cell, _box_mark):
					_changed()
			_stroke = ""
			if click.button_index == MOUSE_BUTTON_LEFT:
				_panning = false
		elif click.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = false
		_point_at(cell)
		_sheet.accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var cell := cell_at(motion.position)
		if _panning:
			# By how far the pointer has got, not by what the event says it moved:
			# a thumb's drag, handed over as a mouse's, says nothing of that.
			_origin += motion.position - _pan_at
			_pan_at = motion.position
			_keep_in_sight()
			_sheet.queue_redraw()
		elif _stroke != "":
			if maker.lay_line(_last, cell, _stroke):
				_changed()
			_last = cell
		_point_at(cell)
	elif event is InputEventPanGesture:
		# Two fingers on a trackpad move the map, as they move any page. Taken
		# here, so that nothing further up the tree is handed the same gesture.
		_origin -= (event as InputEventPanGesture).delta * 12.0
		_keep_in_sight()
		_sheet.queue_redraw()
		_sheet.accept_event()
	elif event is InputEventMagnifyGesture:
		var pinch := event as InputEventMagnifyGesture
		if absf(pinch.factor - 1.0) > 0.02:
			_zoom_to(_zoom_at - 1 if pinch.factor > 1.0 else _zoom_at + 1, pinch.position)
		_sheet.accept_event()

func _begin_stroke(cell: Vector2i, mark: String) -> void:
	maker.begin_stroke()
	_stroke = mark
	_last = cell
	if maker.lay(cell, mark):
		_changed()

func _begin_box(cell: Vector2i, mark: String) -> void:
	_boxing = true
	_box_from = cell
	_box_mark = mark

func _begin_pan(at: Vector2) -> void:
	_panning = true
	_pan_at = at

func _point_at(cell: Vector2i) -> void:
	if cell != _hover or _boxing:
		_hover = cell
		_over.queue_redraw()

## The plan changed: the sheet is drawn again, and the chrome says what it is.
func _changed() -> void:
	_refresh()
	_sheet.queue_redraw()
	_over.queue_redraw()

## The keys that are the table's own: a step back and forward, and SAVE, the
## way they are everywhere. The name, while it is being typed, keeps its keys
## to itself, and none of these reaches here.
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _popup != null or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key == null or not key.is_command_or_control_pressed():
		return
	match key.keycode:
		KEY_Z:
			if key.shift_pressed:
				_redo()
			else:
				_undo()
		KEY_Y:
			_redo()
		KEY_S:
			_save()
		_:
			return
	get_viewport().set_input_as_handled()

## The cancel key puts the list of maps away, the way it closes every other
## window here, before it would pause the table behind it.
func _unhandled_input(event: InputEvent) -> void:
	if _popup != null and is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		_close_list()
		get_viewport().set_input_as_handled()

## --- what the bar does --------------------------------------------------------

## Says a line along the foot for a while.
func _tell(line: String, tone: Color = UiKit.TEXT) -> void:
	_said = line
	_said_tone = tone
	_said_left = SAY_TIME

func _arm(what: String) -> void:
	_armed = what
	_armed_left = ARM_TIME

func _disarm() -> void:
	_armed = ""
	if _popup != null:
		_fill_list()

## SAVE: the map is kept under the name in the field. Under the name of another
## map that is kept already, the first press only asks.
func _save() -> void:
	var id := Maps.id_for(_name.text)
	if id != "" and id != maker.map_id and Maps.exists(id) and _armed != "save:" + id:
		_arm("save:" + id)
		_tell(Loc.t("hud.maker.replace", [id.to_upper()]), UiKit.WARN)
		Audio.play("ui")
		return
	_armed = ""
	var refused := maker.save_as(_name.text)
	if refused != "":
		_tell(Loc.t("hud.maker.refused.%s" % refused), UiKit.BAD)
		Audio.play("deny")
		return
	_tell(Loc.t("hud.maker.saved", [Maps.path_of(id)]), UiKit.GOOD)
	Audio.play("ui")
	_refresh()

func _new() -> void:
	maker.new_map()
	_frame_map()
	_changed()
	Audio.play("ui")

func _undo() -> void:
	if maker.undo():
		_keep_in_sight()
		_changed()

func _redo() -> void:
	if maker.redo():
		_keep_in_sight()
		_changed()

func _resize(by: Vector2i) -> void:
	if maker.resize(Vector2i(maker.cols, maker.rows) + by):
		_keep_in_sight()
		_changed()

## --- the list of kept maps ------------------------------------------------------

## LOAD: every map that is kept, each a button that puts it on the table, with
## a way to throw it away beside it that asks twice.
func _open_list() -> void:
	if _popup != null:
		return
	_stroke = ""
	_boxing = false
	_popup = Control.new()
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_popup)
	_fill_list()
	_over.queue_redraw()
	Audio.play("ui")

func _close_list() -> void:
	if _popup == null:
		return
	remove_child(_popup)
	_popup.queue_free()
	_popup = null
	_armed = ""
	_over.queue_redraw()
	Audio.play("ui")

func _fill_list() -> void:
	for old in _popup.get_children():
		_popup.remove_child(old)
		old.queue_free()
	_popup.add_child(UiKit.shade())
	var frame := UiKit.screen_frame(560.0, 56.0, 28.0, true)
	_popup.add_child(frame)
	frame.head.add_child(UiKit.title(Loc.t("hud.maker.load_heading"), UiKit.text(24), true))
	frame.head.add_child(UiKit.hline(true))
	var ids := Maps.ids()
	if ids.is_empty():
		frame.rows.add_child(UiKit.label(Loc.t("hud.maker.none"), UiKit.text(16), UiKit.DIM, true))
	for id in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		frame.rows.add_child(row)
		var pick := UiKit.overlay_button(id.to_upper(), UiKit.ACCENT, true)
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.pressed.connect(func() -> void: _load(id))
		row.add_child(pick)
		var armed := _armed == "delete:" + id
		var bin := UiKit.overlay_button(Loc.t("hud.maker.sure" if armed else "hud.maker.delete"),
			UiKit.BAD if armed else UiKit.DIM, true)
		bin.pressed.connect(func() -> void: _delete(id))
		row.add_child(bin)
	frame.foot.add_child(UiKit.spacer(8))
	var back := UiKit.overlay_button(Loc.t("hud.maker.back"), UiKit.ACCENT, true)
	back.pressed.connect(_close_list)
	frame.foot.add_child(back)

func _load(id: String) -> void:
	if not maker.open(id):
		_tell(Loc.t("hud.maker.refused.read"), UiKit.BAD)
		Audio.play("deny")
		return
	_close_list()
	_frame_map()
	_keep_in_sight()
	_changed()
	_tell(Loc.t("hud.maker.loaded", [id.to_upper()]), UiKit.GOOD)

## Throwing a map away cannot be undone, so the first press only asks.
func _delete(id: String) -> void:
	if _armed != "delete:" + id:
		_arm("delete:" + id)
		_fill_list()
		Audio.play("ui")
		return
	_armed = ""
	Maps.remove(id)
	_fill_list()
	_tell(Loc.t("hud.maker.deleted", [id.to_upper()]), UiKit.WARN)
	Audio.play("deny")

## --- the table itself -----------------------------------------------------------

## The ground under everything, and the line along the foot: what the table
## last said, or the name of the tile the pointer is on, or else what the
## pointer does here; and on the right the cell under the pointer, the map's
## size, and whether it has changed since it was kept.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.BG)
	var foot := Rect2(SIDE_W, size.y - FOOT_H, size.x - SIDE_W, FOOT_H)
	_px.rect(foot, UiKit.PANEL)
	var base := foot.position + Vector2(12.0, 20.0)
	var where := "%dx%d" % [maker.cols, maker.rows]
	if maker.holds(_hover):
		where = "%d,%d   %s" % [_hover.x, _hover.y, where]
	var right := foot.end.x - 12.0 - PixelDraw.text_width(where)
	_px.text(Vector2(right, base.y), where, UiKit.DIM)
	if maker.unsaved:
		var unsaved := Loc.t("hud.maker.unsaved")
		right -= PixelDraw.text_width(unsaved) + 16.0
		_px.text(Vector2(right, base.y), unsaved, UiKit.WARN)
	var room := right - base.x - 16.0
	if _said_left > 0.0:
		_px.text(base, _said, _said_tone, room)
	elif _over_tile != "":
		_px.text(base, name_of(_over_tile), UiKit.TEXT, room)
	else:
		_px.text(base, Loc.t("hud.maker.hint_touch" if _thumb else "hud.maker.hint"), UiKit.DIM, room)
