class_name StoryDesk
extends Control

## The desk a story is written at, in the story maker (`StoryMaker`): along
## the top the story's name and what is done with it — SAVE, LOAD, NEW, PLAY;
## down the left what the story is set on and how it is played — the map it
## imports, the way it plays, who the character is and what they and the
## player are called; and in the middle the lines, one a row: who says it,
## the words, the row moved up or down, and the row taken away, which asks
## twice. A line is typed where it stands, and the return key goes on to the
## next line, or to a new one after the last.
##
## It makes no change of its own: everything it does is asked of the maker,
## which is what a test asks too.

## How wide the column down the left is, and how tall the line along the
## bottom.
const SIDE_W := 232.0
const FOOT_H := 28.0
## The room a panel of the desk's keeps inside its edge, in either mode.
const PANEL_PAD := 8.0
## How wide a line's number and the name of who says it stand.
const NUMBER_W := 30.0
const WHO_W := 132.0
## How long a button that asks twice stays asked, and a line stays said.
const ARM_TIME := 3.0
const SAY_TIME := 4.0
## Who a story's character may look like: the atlas's people, and the game's
## own player. One the atlas does not have is left out.
const CAST := ["wizzard_m", "wizzard_f", "knight_m", "knight_f", "elf_m", "elf_f",
	"dwarf_m", "dwarf_f", "lizard_m", "lizard_f", "angel", "doc", "player"]
const ICON_UP := [
	".......",
	"...#...",
	"..###..",
	".#####.",
	"#######",
	".......",
	".......",
]
const ICON_DOWN := [
	".......",
	".......",
	"#######",
	".#####.",
	"..###..",
	"...#...",
	".......",
]
const ICON_OUT := [
	"#.....#",
	".#...#.",
	"..#.#..",
	"...#...",
	"..#.#..",
	".#...#.",
	"#.....#",
]

var maker: StoryMaker

var _px := PixelDraw.new(self)
var _bar: PanelContainer
var _side: PanelContainer
var _sheet: PanelContainer
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
## One entry a line: {"who", "edit", "up", "down", "bin"}.
var _rows: Array = []
var _add: Button
var _name: LineEdit
var _map: Button
## Mode -> its button.
var _modes: Dictionary = {}
var _npc_name: LineEdit
var _sprite: Button
var _player_name: LineEdit
## What is up over the desk — the list of kept stories, or the maps — or null.
var _popup: Control = null
## The line the foot is saying, in what colour, and for how much longer.
var _said: String = ""
var _said_tone := UiKit.TEXT
var _said_left: float = 0.0
## What has been asked once and waits to be asked again — "save:<id>" over
## another story's name, "delete:<id>", "remove:<line>" — and for how long.
var _armed: String = ""
var _armed_left: float = 0.0
## The name the field was last given by the maker, to see the story change.
var _shown_id: String = ""
## Whether the chrome was built for a thumb.
var _thumb: bool = false

func _ready() -> void:
	UiKit.fill_screen(self)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build()
	Loc.language_changed.connect(func(_lang: String) -> void: _build())

## --- the chrome -------------------------------------------------------------

## Everything on the desk but the story's own state, built for the language
## and the mode in force: built again when either changes.
func _build() -> void:
	var typed := _name.text if _name != null else maker.story_id
	for old in get_children():
		remove_child(old)
		old.queue_free()
	_popup = null
	_thumb = UiKit.mobile()
	_build_bar(typed)
	_build_side()
	_build_sheet()
	_shown_id = maker.story_id
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
	row.add_child(_word(Loc.t("hud.story.title"), Color(0.9, 0.95, 1.0)))
	_name = _edit(typed, Loc.t("hud.story.name"))
	_name.max_length = Maps.ID_LENGTH
	_name.custom_minimum_size.x = 220.0
	_name.text_submitted.connect(func(_text: String) -> void: _name.release_focus())
	row.add_child(_name)
	_bar_button(row, "hud.story.save", UiKit.GOOD, _save)
	_bar_button(row, "hud.story.load", UiKit.ACCENT, _open_list)
	_bar_button(row, "hud.story.new", UiKit.ACCENT, _new)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var play := _bar_button(row, "hud.story.play", UiKit.GOOD, _play)
	play.custom_minimum_size.x = 96.0

func _bar_button(row: HBoxContainer, key: String, tone: Color, press: Callable) -> Button:
	var b := _button(Loc.t(key), tone)
	b.pressed.connect(press)
	row.add_child(b)
	return b

## What the story is set on and how it is played, down the left.
func _build_side() -> void:
	_side = _panel()
	add_child(_side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_side.add_child(column)
	column.add_child(_word(Loc.t("hud.story.map"), UiKit.DIM))
	_map = _side_button(column, _open_maps)
	column.add_child(UiKit.hline(true))
	column.add_child(_word(Loc.t("hud.story.mode"), UiKit.DIM))
	_modes.clear()
	for m in StoryMaker.MODE_IDS.size():
		var b := _side_button(column, func() -> void: _set_mode(m))
		b.text = Loc.t("hud.story.modes.%s" % StoryMaker.MODE_IDS[m])
		b.add_theme_font_size_override("font_size", Loc.text_size(b.text, UiKit.PIXEL_TEXT))
		_chosen_look(b)
		_modes[m] = b
	column.add_child(UiKit.hline(true))
	column.add_child(_word(Loc.t("hud.story.character"), UiKit.DIM))
	_npc_name = _edit(maker.npc_name, Loc.t("hud.story.npc"))
	_npc_name.text_changed.connect(func(text: String) -> void:
		maker.set_npc_name(text)
		_refresh_rows())
	column.add_child(_npc_name)
	column.add_child(_word(Loc.t("hud.story.sprite"), UiKit.DIM))
	_sprite = _side_button(column, _cycle_sprite)
	column.add_child(UiKit.hline(true))
	column.add_child(_word(Loc.t("hud.story.player"), UiKit.DIM))
	_player_name = _edit(maker.player_name, Loc.t("hud.story.you"))
	_player_name.text_changed.connect(func(text: String) -> void:
		maker.set_player_name(text)
		_refresh_rows())
	column.add_child(_player_name)

## The lines, one a row, in a list that scrolls, with the way to add one
## pinned under it.
func _build_sheet() -> void:
	_sheet = _panel()
	add_child(_sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_sheet.add_child(v)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiKit.pixel_scroll(_scroll)
	v.add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 4)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows_box)
	_add = _button(Loc.t("hud.story.add"), UiKit.GOOD)
	_add.pressed.connect(_add_line)
	v.add_child(_add)
	_fill_rows()

## A row for every line: its number, who says it, the words, and the row
## moved or taken away. Built again whenever a line comes or goes or moves;
## the words are typed straight into the maker, and never rebuild it.
func _fill_rows() -> void:
	for old in _rows_box.get_children():
		_rows_box.remove_child(old)
		old.queue_free()
	_rows.clear()
	_armed = ""
	for i in maker.line_count():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows_box.add_child(row)
		var n := _word(str(i + 1), UiKit.DIM)
		n.custom_minimum_size.x = NUMBER_W
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(n)
		var who := _button("", UiKit.ACCENT)
		who.custom_minimum_size.x = WHO_W
		who.clip_text = true
		who.pressed.connect(func() -> void:
			if maker.toggle_speaker(i):
				_refresh_rows()
				Audio.play("ui"))
		row.add_child(who)
		var edit := _edit(maker.text_of(i), Loc.t("hud.story.line"))
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_changed.connect(func(text: String) -> void: maker.set_text(i, text))
		edit.text_submitted.connect(func(_text: String) -> void: _next_line(i))
		row.add_child(edit)
		var up := _icon_button(ICON_UP, func() -> void: _move(i, -1))
		row.add_child(up)
		var down := _icon_button(ICON_DOWN, func() -> void: _move(i, 1))
		row.add_child(down)
		var bin := _icon_button(ICON_OUT, func() -> void: _remove(i))
		bin.add_theme_color_override("font_color", UiKit.BAD)
		row.add_child(bin)
		_rows.append({"who": who, "edit": edit, "up": up, "down": down, "bin": bin})
	_refresh_rows()

## Puts on the rows what the maker has that they show: who says each line,
## which can still move which way, and which is asked about.
func _refresh_rows() -> void:
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var who: Button = row["who"]
		who.text = _who(maker.speaker_of(i))
		who.add_theme_font_size_override("font_size", Loc.text_size(who.text, UiKit.PIXEL_TEXT))
		(row["up"] as Button).disabled = i == 0
		(row["down"] as Button).disabled = i == _rows.size() - 1
		var bin: Button = row["bin"]
		bin.text = Loc.t("hud.story.sure") if _armed == "remove:%d" % i else ""
		bin.add_theme_font_size_override("font_size", Loc.text_size(bin.text, UiKit.PIXEL_TEXT))
		bin.queue_redraw()

## What who says a line is called on the row: the character's name, or the
## player's, as the story has them — or, with nothing typed yet, which it is.
func _who(speaker: String) -> String:
	var called := maker.npc_name if speaker == StoryMaker.NPC else maker.player_name
	if called.strip_edges() == "":
		called = Loc.t("hud.story.npc" if speaker == StoryMaker.NPC else "hud.story.you")
	return called.to_upper()

## A button with a small picture on it rather than a word, until it has a word
## to say.
func _icon_button(icon: Array, press: Callable) -> Button:
	var b := _button("", UiKit.DIM)
	b.custom_minimum_size.x = _plate()
	b.pressed.connect(press)
	b.draw.connect(func() -> void:
		if b.text == "":
			PixelDraw.new(b).icon_centered((b.size * 0.5).floor(), icon,
				Color.WHITE if b.is_hovered() and not b.disabled else (UiKit.DIM if b.disabled else UiKit.TEXT)))
	return b

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

## A button of the desk's: the kit's pixel one, never taking the keyboard —
## that is the lines' to have — and at the desk's own size in either mode, for
## the map table's reason: too many of them on one screen to stand a full
## thumb each.
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

## A button that cannot be pressed because it is what is chosen: lit, not
## greyed.
static func _chosen_look(b: Button) -> void:
	var chosen := b.get_theme_stylebox("disabled") as StyleBoxFlat
	chosen.bg_color = Color(UiKit.ACCENT, 0.22)
	chosen.border_color = UiKit.ACCENT
	b.add_theme_color_override("font_disabled_color", Color.WHITE)

## A field to type in, in the pixel look, saying `placeholder` while empty.
func _edit(text: String, placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0.0, _plate())
	e.add_theme_font_override("font", UiKit.PIXEL_FONT)
	e.add_theme_font_size_override("font_size", UiKit.PIXEL_TEXT)
	e.add_theme_color_override("font_color", UiKit.TEXT)
	e.add_theme_color_override("font_placeholder_color", UiKit.DIM)
	e.add_theme_stylebox_override("normal", UiKit.style(UiKit.BG, UiKit.LINE, 1, 0, true))
	e.add_theme_stylebox_override("focus", UiKit.style(Color(0, 0, 0, 0), UiKit.ACCENT, 1, 0, true))
	return e

## How tall a thing to press stands on the desk.
func _plate() -> float:
	return 56.0 if _thumb else 34.0

## A panel of the desk's: the kit's pixel one, keeping the same room inside
## its edge in either mode.
func _panel() -> PanelContainer:
	var p := UiKit.panel(UiKit.PANEL, UiKit.LINE, true)
	var box := p.get_theme_stylebox("panel") as StyleBoxFlat
	box.content_margin_left = PANEL_PAD
	box.content_margin_right = PANEL_PAD
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

## Who the character may look like, of `CAST`, as the atlas has them.
func cast() -> PackedStringArray:
	var out := PackedStringArray()
	for art in CAST:
		if Style.has_character(art):
			out.append(art)
	if out.is_empty():
		out.append(maker.sprite)
	return out

## Puts on the chrome whatever the maker has that it shows.
func _refresh() -> void:
	var map := maker.map_to_play()
	_map.text = map.to_upper() if map != "" else Loc.t("hud.story.no_map")
	_map.add_theme_font_size_override("font_size", Loc.text_size(_map.text, UiKit.PIXEL_TEXT))
	for m in _modes:
		(_modes[m] as Button).disabled = m == maker.mode
	_sprite.text = maker.sprite.to_upper()
	if maker.story_id != _shown_id:
		_shown_id = maker.story_id
		_name.text = maker.story_id
	_refresh_rows()

## The whole story put on the desk again: after NEW, or a story loaded.
func _took() -> void:
	_npc_name.text = maker.npc_name
	_player_name.text = maker.player_name
	_fill_rows()
	_refresh()

## Where everything stands for the screen as it is: the bar across the top,
## the column down the left, and the lines in what is left over the foot.
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

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	if _thumb != UiKit.mobile():
		_build()
	_fit()
	_said_left = maxf(0.0, _said_left - delta)
	if _armed != "":
		_armed_left -= delta
		if _armed_left <= 0.0:
			_disarm()
	queue_redraw()

## --- the lines --------------------------------------------------------------

## The keyboard onto line `i`, at the end of its words, with the list
## scrolled to show it.
func _focus(i: int) -> void:
	if i < 0 or i >= _rows.size():
		return
	var edit: LineEdit = _rows[i]["edit"]
	edit.grab_focus()
	edit.caret_column = edit.text.length()
	_scroll.ensure_control_visible.call_deferred(edit)

## The return key on line `i`: on to the next line, or to a new one after the last.
func _next_line(i: int) -> void:
	if i + 1 < maker.line_count():
		_focus(i + 1)
	else:
		_add_line()

func _add_line() -> void:
	var i := maker.add_line()
	_fill_rows()
	_focus(i)
	Audio.play("ui")

func _move(i: int, by: int) -> void:
	if maker.move_line(i, by):
		_fill_rows()
		_focus(i + by)
		Audio.play("ui")

## Taking a line away cannot be undone, so the first press only asks.
func _remove(i: int) -> void:
	if _armed != "remove:%d" % i:
		_arm("remove:%d" % i)
		_refresh_rows()
		Audio.play("ui")
		return
	_armed = ""
	maker.remove_line(i)
	_fill_rows()
	Audio.play("deny")

func _set_mode(m: int) -> void:
	maker.set_mode(m)
	_refresh()
	Audio.play("ui")

func _cycle_sprite() -> void:
	var who := cast()
	maker.set_sprite(who[(who.find(maker.sprite) + 1) % who.size()])
	_refresh()
	Audio.play("ui")

## --- the keys ---------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _popup != null or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key == null or not key.is_command_or_control_pressed() or key.keycode != KEY_S:
		return
	_save()
	get_viewport().set_input_as_handled()

## The cancel key puts away what is up over the desk, before it would pause
## the desk behind it.
func _unhandled_input(event: InputEvent) -> void:
	if _popup != null and is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		_close_popup()
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
	var was := _armed
	_armed = ""
	if _popup != null and was.begins_with("delete:"):
		_fill_list()
	elif was.begins_with("remove:"):
		_refresh_rows()

## SAVE: the story is kept under the name in the field. Under the name of
## another story that is kept already, the first press only asks.
func _save() -> void:
	var id := Stories.id_for(_name.text)
	if id != "" and id != maker.story_id and Stories.exists(id) and _armed != "save:" + id:
		_arm("save:" + id)
		_tell(Loc.t("hud.story.replace", [id.to_upper()]), UiKit.WARN)
		Audio.play("ui")
		return
	_armed = ""
	var refused := maker.save_as(_name.text)
	if refused != "":
		_tell(Loc.t("hud.story.refused.%s" % refused), UiKit.BAD)
		Audio.play("deny")
		return
	_tell(Loc.t("hud.story.saved", [Stories.path_of(id)]), UiKit.GOOD)
	Audio.play("ui")
	_refresh()

func _new() -> void:
	maker.new_story()
	_took()
	Audio.play("ui")

## PLAY: the story set going on its map. One with nothing to say, or no map to
## say it on, stays on the desk, and the foot says why.
func _play() -> void:
	get_viewport().gui_release_focus()
	var refused := maker.play()
	if refused != "":
		_tell(Loc.t("hud.story.refused.%s" % refused), UiKit.BAD)
		Audio.play("deny")

## --- what is put up over the desk --------------------------------------------

func _open_popup() -> bool:
	if _popup != null:
		return false
	get_viewport().gui_release_focus()
	_popup = Control.new()
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_popup)
	Audio.play("ui")
	return true

func _close_popup() -> void:
	if _popup == null:
		return
	remove_child(_popup)
	_popup.queue_free()
	_popup = null
	_armed = ""
	Audio.play("ui")

## A frame over a shade, under `heading`, with the way back pinned at its foot.
func _frame(heading: String) -> UiKit.ScreenFrame:
	for old in _popup.get_children():
		_popup.remove_child(old)
		old.queue_free()
	_popup.add_child(UiKit.shade())
	var frame := UiKit.screen_frame(560.0, 56.0, 28.0, true)
	_popup.add_child(frame)
	frame.head.add_child(UiKit.title(heading, UiKit.text(24), true))
	frame.head.add_child(UiKit.hline(true))
	frame.foot.add_child(UiKit.spacer(8))
	var back := UiKit.overlay_button(Loc.t("hud.story.back"), UiKit.ACCENT, true)
	back.pressed.connect(_close_popup)
	frame.foot.add_child(back)
	return frame

## LOAD: every story that is kept, each a button that puts it on the desk,
## with a way to throw it away beside it that asks twice.
func _open_list() -> void:
	if _open_popup():
		_fill_list()

func _fill_list() -> void:
	var frame := _frame(Loc.t("hud.story.load_heading"))
	var ids := Stories.ids()
	if ids.is_empty():
		frame.rows.add_child(UiKit.label(Loc.t("hud.story.none"), UiKit.text(16), UiKit.DIM, true))
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
		var bin := UiKit.overlay_button(Loc.t("hud.story.sure" if armed else "hud.story.delete"),
			UiKit.BAD if armed else UiKit.DIM, true)
		bin.pressed.connect(func() -> void: _delete(id))
		row.add_child(bin)

func _load(id: String) -> void:
	if not maker.open(id):
		_tell(Loc.t("hud.story.refused.read"), UiKit.BAD)
		Audio.play("deny")
		return
	_close_popup()
	_took()
	_tell(Loc.t("hud.story.loaded", [id.to_upper()]), UiKit.GOOD)

## Throwing a story away cannot be undone, so the first press only asks.
func _delete(id: String) -> void:
	if _armed != "delete:" + id:
		_arm("delete:" + id)
		_fill_list()
		Audio.play("ui")
		return
	_armed = ""
	Stories.remove(id)
	_fill_list()
	_tell(Loc.t("hud.story.deleted", [id.to_upper()]), UiKit.WARN)
	Audio.play("deny")

## MAP: every map the map creator has kept, each a button that sets the story
## on it.
func _open_maps() -> void:
	if _open_popup():
		_fill_maps()

func _fill_maps() -> void:
	var frame := _frame(Loc.t("hud.story.map_heading"))
	var ids := Maps.ids()
	if ids.is_empty():
		frame.rows.add_child(UiKit.label(Loc.t("hud.story.no_maps"), UiKit.text(16), UiKit.DIM, true))
	for id in ids:
		var pick := UiKit.overlay_button(id.to_upper(), UiKit.ACCENT, true)
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if id == maker.map_to_play():
			UiKit.mark_chosen(pick)
		pick.pressed.connect(func() -> void: _import(id))
		frame.rows.add_child(pick)

func _import(id: String) -> void:
	maker.set_map(id)
	_close_popup()
	_refresh()

## --- the desk itself -----------------------------------------------------------

## The ground under everything, and the line along the foot: what the desk
## last said, or else what the way the story is played means; and on the
## right how many lines there are, and whether it has changed since it was
## kept.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.BG)
	var foot := Rect2(SIDE_W, size.y - FOOT_H, size.x - SIDE_W, FOOT_H)
	_px.rect(foot, UiKit.PANEL)
	var base := foot.position + Vector2(12.0, 20.0)
	var n := maker.line_count()
	var count := Loc.t("hud.story.count_one" if n == 1 else "hud.story.count_many", [n])
	var right := foot.end.x - 12.0 - PixelDraw.text_width(count)
	_px.text(Vector2(right, base.y), count, UiKit.DIM)
	if maker.unsaved:
		var unsaved := Loc.t("hud.story.unsaved")
		right -= PixelDraw.text_width(unsaved) + 16.0
		_px.text(Vector2(right, base.y), unsaved, UiKit.WARN)
	var room := right - base.x - 16.0
	if _said_left > 0.0:
		_px.text(base, _said, _said_tone, room)
	else:
		_px.text(base, Loc.t("hud.story.modes_hint.%s" % maker.mode_id()), UiKit.DIM, room)
