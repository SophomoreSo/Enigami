class_name ShareCodePanel
extends Control

## The assembly screen's share sheet: this board written out as a code, and a
## field to build somebody else's board from theirs.
##
## Drawn in UiKit's pixel look like the editor it sits on — every fill, border
## and letter a whole PIXEL on the PIXEL grid, all of it through `PixelDraw`.
## A sheet rather than a strip in the header: a code is long, and a player
## either wants the whole of it in front of them or does not want to see it.
##
## **The one thing here that is not the face's own:** a code's case matters, and
## Silkscreen has no small letters — it draws them as capitals, so `hBw4k` and
## `HBW4K` come out as the same pixels. Rather than give up half the alphabet,
## or give up the pixel face, the small letters are drawn in a colour of their
## own and the sheet says so. Colour is also the one thing that survives a
## screenshot, which is how most of these get shared.
##
## It knows nothing about boards or parts. It collects characters, shows what
## `BoardCode` makes of them, and hands them up to the editor, which owns the
## board and the bag the parts come out of.

signal build_requested(code: String)
signal closed()

## What the panel is looking at. The editor sets this when it opens the sheet
## and again after a code has been built, so COPY is never a stale board.
var code: String = ""
## What has been typed or pasted in, case and all. Everything outside the
## alphabet is dropped on the way, so a pasted code arrives with any stray space
## or line break gone.
var entry: String = ""

## A line of the boxes, in characters. A code is one unbroken run, so the box is
## the only thing that breaks it up: forty puts an ordinary board's code on one
## line with room to spare, and a longer one breaks every eight words of the
## board rather than somewhere in the middle of one.
const CHARS_PER_LINE := 40
## How many lines each box holds. A code past that is shown cut short, with its
## full length beside COPY, and COPY still takes the whole of it.
const CODE_LINES := 3
const ENTRY_LINES := 3
## Up to two lines for what the sheet has to say about a code.
const NOTE_LINES := 2

const PX := UiKit.PIXEL
const LINE := PixelDraw.LINE
const PAD := 24.0
const GAP := 14.0
const GAP_SMALL := 8.0
const BOX_PAD := 10.0
const BTN_H := 30.0
## A row's baseline, from its top: capitals stand 10 tall, so this centres them.
const BTN_TEXT_Y := 20.0
const BTN_GAP := 10.0

const BG := Color(0.07, 0.08, 0.11, 0.97)
const EDGE := Color(0.35, 0.55, 0.75, 0.85)
const BOX_FILL := Color(0.05, 0.06, 0.08)
const BOX_EDGE := Color(0.24, 0.3, 0.38)
## Capitals and digits cool, small letters warm. Two hues rather than two
## brightnesses: a dim letter reads as a letter that is hard to see, where a
## letter of another colour reads as a letter of another kind.
const CAPITAL_INK := Color(0.86, 0.94, 1.0)
const SMALL_INK := Color(1.0, 0.78, 0.42)

const LEGEND := "orange letters are small ones"
const HINT := "type either case · ENTER builds · ESC closes"

var _hover: String = ""
var _note: String = ""
var _note_col: Color = UiKit.DIM
var _caret: float = 0.0
var _px := PixelDraw.new(self)

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_caret += delta
	queue_redraw()

## Opened fresh every time: a note left over from the last code, and characters
## left in the field, would both be about a board no longer on the grid.
func open_with(board_code: String) -> void:
	code = board_code
	entry = ""
	_note = ""
	_caret = 0.0
	visible = true
	queue_redraw()

## What the editor says back about a code it was handed.
func note(text: String, col: Color) -> void:
	_note = text
	_note_col = col

## --- input ------------------------------------------------------------------

## Every key while the sheet is open, handled or swallowed: a key that fell
## through would rotate a part or close the editor behind it.
func handle_key(e: InputEventKey) -> bool:
	if (e.ctrl_pressed or e.meta_pressed) and e.keycode == KEY_V:
		_paste()
		return true
	if (e.ctrl_pressed or e.meta_pressed) and e.keycode == KEY_C:
		_copy()
		return true
	match e.keycode:
		KEY_ESCAPE:
			Audio.play("ui")
			closed.emit()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_build()
			return true
		KEY_BACKSPACE:
			if not entry.is_empty():
				_set_entry(entry.left(entry.length() - 1))
				Audio.play("erase")
			return true
		KEY_DELETE:
			if not entry.is_empty():
				_set_entry("")
				Audio.play("erase")
			return true
	# Whatever the key actually produced, shift and layout included — which is
	# the only way to tell an `a` from an `A` without knowing the keyboard.
	var typed := char(e.unicode) if e.unicode > 0 else ""
	if typed == "0":
		note(BoardCode.HAS_ZERO, UiKit.WARN)
		Audio.play("deny")
	elif BoardCode.holds(typed) and entry.length() < BoardCode.max_chars():
		_set_entry(entry + typed)
		Audio.play("ui")
	return true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _at((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_hover = _at((event as InputEventMouseButton).position)
		match _hover:
			"copy": _copy()
			"paste": _paste()
			"build": _build()
			"close":
				Audio.play("ui")
				closed.emit()
	accept_event()

func _at(pos: Vector2) -> String:
	var l := _layout()
	for key in ["copy", "paste", "build", "close"]:
		if (l[key] as Rect2).has_point(pos):
			return key
	return ""

func _set_entry(s: String) -> void:
	entry = BoardCode.clean(s)
	# A note is about the code that was there when it was written.
	_note = ""
	_caret = 0.0

func _copy() -> void:
	if code.is_empty():
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		note("There is no clipboard here — read the code off the sheet.", UiKit.WARN)
		return
	DisplayServer.clipboard_set(code)
	note("Code copied — %d characters." % BoardCode.clean(code).length(), UiKit.GOOD)
	Audio.play("ui")

func _paste() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		note("There is no clipboard here — type the code in.", UiKit.WARN)
		return
	var got := BoardCode.clean(DisplayServer.clipboard_get())
	if got.is_empty():
		note("There is no code on the clipboard.", UiKit.WARN)
		Audio.play("deny")
		return
	_set_entry(got.left(BoardCode.max_chars()))
	Audio.play("ui")

## Handed up to the editor, which owns the board and the parts. Whatever it
## makes of the code comes back through `note`.
func _build() -> void:
	if entry.is_empty():
		note("Nothing to build — type or paste a code first.", UiKit.WARN)
		Audio.play("deny")
		return
	build_requested.emit(entry)

## --- layout -----------------------------------------------------------------

## Every rect on the sheet, worked out from the font rather than from a guess at
## how wide a character is: the boxes are drawn and hit-tested from these same
## numbers, so a button cannot drift away from the box it belongs to.
func _layout() -> Dictionary:
	var box_w := _box_width()
	var w := box_w + PAD * 2.0
	var code_h := CODE_LINES * LINE + BOX_PAD * 2.0
	var entry_h := ENTRY_LINES * LINE + BOX_PAD * 2.0
	var h := PAD + BTN_H + GAP + LINE + code_h + GAP_SMALL + BTN_H + GAP \
		+ LINE + entry_h + GAP_SMALL + BTN_H + GAP + NOTE_LINES * LINE + GAP_SMALL + LINE + PAD
	var vp := get_viewport_rect().size
	var at := _px.snap(Vector2(maxf((vp.x - w) * 0.5, 0.0), maxf((vp.y - h) * 0.5, 0.0)))

	var l := {"panel": Rect2(at, Vector2(w, h))}
	var x := at.x + PAD
	var y := at.y + PAD
	l["title"] = Vector2(x, y + BTN_TEXT_Y)
	l["close"] = Rect2(at.x + w - PAD - _button_width("CLOSE"), y, _button_width("CLOSE"), BTN_H)
	y += BTN_H + GAP
	l["code_label"] = Vector2(x, y + 14.0)
	y += LINE
	l["code_box"] = Rect2(x, y, box_w, code_h)
	y += code_h + GAP_SMALL
	l["copy"] = Rect2(x, y, _button_width("COPY"), BTN_H)
	l["copy_note"] = Vector2((l["copy"] as Rect2).end.x + BTN_GAP, y + BTN_TEXT_Y)
	y += BTN_H + GAP
	l["entry_label"] = Vector2(x, y + 14.0)
	y += LINE
	l["entry_box"] = Rect2(x, y, box_w, entry_h)
	y += entry_h + GAP_SMALL
	l["paste"] = Rect2(x, y, _button_width("PASTE"), BTN_H)
	l["build"] = Rect2((l["paste"] as Rect2).end.x + BTN_GAP, y, _button_width("BUILD"), BTN_H)
	y += BTN_H + GAP
	l["note"] = Vector2(x, y + 14.0)
	# A gap before the controls line, or a note that wraps to its second line
	# runs straight on into it and the two read as one paragraph.
	y += NOTE_LINES * LINE + GAP_SMALL
	l["hint"] = Vector2(x, y + 14.0)
	l["text_width"] = box_w - BOX_PAD * 2.0
	return l

## A box wide enough for a full line of the *widest* characters the alphabet
## has, and the caret after it. The face is proportional — an `i` is six PIXELs
## and a `W` fourteen — so a box sized to an average line would be overrun by a
## code that happened to come out wide, and the line would reflow as it was
## typed.
func _box_width() -> float:
	var widest := 0.0
	for i in BoardCode.ALPHABET.length():
		widest = maxf(widest, PixelDraw.text_width(BoardCode.ALPHABET[i]))
	var w := widest * float(CHARS_PER_LINE + 1)   # the caret is the + 1
	return ceilf((w + BOX_PAD * 2.0) / PX) * PX

func _button_width(label: String) -> float:
	return ceilf((PixelDraw.ink_width(label) + 28.0) / PX) * PX

## --- drawing ----------------------------------------------------------------
func _draw() -> void:
	var vp := get_viewport_rect().size
	# Darker than the editor's own veil: the sheet is a stop, and the board
	# under it would otherwise read as something still being edited.
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.04, 0.05, 0.72))
	var l := _layout()
	var panel: Rect2 = l["panel"]
	_px.rect(panel, BG)
	_px.frame(panel, EDGE)

	_px.text(l["title"], "SHARE CODE", Color(0.85, 0.92, 1.0))
	_draw_button(l["close"], "CLOSE", Color(1.0, 0.6, 0.6), _hover == "close", true)

	var width: float = l["text_width"]
	_px.text(l["code_label"], "THIS BOARD", UiKit.ACCENT, width)
	var c := BoardCode.clean(code)
	if c.is_empty():
		_px.text((l["code_box"] as Rect2).position + Vector2(BOX_PAD, BOX_PAD + 14.0),
			"— this board cannot be put into a code —", UiKit.BAD, width)
		_px.rect(l["code_box"], Color(0, 0, 0, 0))
		_px.frame(l["code_box"], BOX_EDGE)
	else:
		_draw_box(l["code_box"], _lines(c, CODE_LINES, false))
	_draw_button(l["copy"], "COPY", UiKit.GOOD, _hover == "copy", not c.is_empty())
	if not c.is_empty():
		_px.text(l["copy_note"], "%d characters · %s" % [c.length(), LEGEND], UiKit.DIM)

	_px.text(l["entry_label"], "BUILD FROM A CODE", UiKit.ACCENT, width)
	var typed := _lines(entry, ENTRY_LINES, true)
	# A block caret on the end of what has been typed, blinking, so an empty
	# field reads as one waiting for a code rather than as one that is broken.
	if fmod(_caret, 1.0) < 0.6:
		typed[typed.size() - 1] = String(typed[typed.size() - 1]) + "_"
	_draw_box(l["entry_box"], typed)
	_draw_button(l["paste"], "PASTE", UiKit.ACCENT, _hover == "paste",
		DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD))
	_draw_button(l["build"], "BUILD", UiKit.GOOD, _hover == "build", not entry.is_empty())

	var says := _note if _note != "" else _live_note()
	var col := _note_col if _note != "" else UiKit.DIM
	var note_at: Vector2 = l["note"]
	var rows := PixelDraw.wrap(says, width, NOTE_LINES)
	for i in rows.size():
		_px.text(note_at + Vector2(0, i * LINE), rows[i], col)
	_px.text(l["hint"], HINT, Color(0.5, 0.58, 0.68), width)

## What the sheet says about the code so far, with no action behind it: a code
## still being typed is not a mistake, so nothing is called wrong until it is
## the length of a whole one.
func _live_note() -> String:
	if entry.is_empty():
		return "Type a code in, or PASTE one from the clipboard."
	if entry.length() < BoardCode.WORD_CHARS + 1 or entry.length() % BoardCode.WORD_CHARS != 1:
		return "%d characters so far…" % entry.length()
	var read := BoardCode.decode(entry)
	if String(read["error"]) != "":
		return String(read["error"])
	var board: SkillBoard = read["board"]
	var tags := board.compute_tags()
	return "%dx%d · %d parts · %s" % [board.width, board.height, board.cells.size(),
		", ".join(tags) if tags.size() > 0 else "utility"]

func _draw_box(r: Rect2, rows: PackedStringArray) -> void:
	_px.rect(r, BOX_FILL)
	_px.frame(r, BOX_EDGE)
	for i in rows.size():
		_draw_code(r.position + Vector2(BOX_PAD, BOX_PAD + 14.0 + i * LINE), rows[i])

## A line of a code, a character at a time, so the small letters can be coloured
## apart from the capitals the face draws them as. Advances add up exactly in
## this face — there is no kerning — and every one of them is a whole number of
## PIXELs, so stepping along by them keeps the line on the grid.
func _draw_code(at: Vector2, line: String) -> void:
	var x := 0.0
	for i in line.length():
		var ch := line[i]
		_px.text(at + Vector2(x, 0), ch, SMALL_INK if BoardCode.is_small(ch) else CAPITAL_INK)
		x += PixelDraw.text_width(ch)

func _draw_button(r: Rect2, label: String, accent: Color, hot: bool, on: bool) -> void:
	var edge := accent if on else Color(0.32, 0.34, 0.38)
	_px.rect(r, Color(accent.r, accent.g, accent.b, 0.3) if (hot and on) else Color(0.11, 0.13, 0.17))
	_px.frame(r, Color(1, 1, 1, 0.75) if (hot and on) else edge)
	var ink := Color(0.95, 0.98, 1.0) if on else Color(0.45, 0.48, 0.52)
	_px.text(r.position + Vector2((r.size.x - PixelDraw.ink_width(label)) * 0.5, BTN_TEXT_Y),
		label, ink)

## A code broken into lines of CHARS_PER_LINE. One too long for its box keeps
## the end when a caret is sitting in it and the start when one is not, and the
## side that was cut is marked, so neither box can quietly show half a code as
## if it were the whole one.
static func _lines(code: String, most: int, tail: bool) -> PackedStringArray:
	var c := BoardCode.clean(code)
	var total := maxi(1, int(ceil(float(c.length()) / float(CHARS_PER_LINE))))
	var first := 0
	var cut := false
	if total > most:
		cut = true
		first = (total - most) * CHARS_PER_LINE if tail else 0
		total = most
	var out := PackedStringArray()
	for i in total:
		var line := c.substr(first + i * CHARS_PER_LINE, CHARS_PER_LINE)
		if cut and tail and i == 0:
			line = "…" + line
		elif cut and not tail and i == total - 1:
			line += "…"
		out.append(line)
	return out
