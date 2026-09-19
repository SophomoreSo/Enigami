class_name CutsceneBox
extends Control

## The narration under a directed scene: what is being said now, typed a letter
## at a time, with the name of whoever is saying it when anyone is. It reads the
## `Cutscene` every frame and never writes to it.
##
## Deliberately its own panel rather than the `DialogueBox`: a conversation is
## framed around two portraits facing each other, and a prologue is a voice over
## a room. It sits at the bottom so the stage above it is never covered.

const LAYER := 32

const SIDE_CLEAR := 140.0
const MAX_WIDTH := 760.0
const MIN_WIDTH := 420.0
const BOTTOM := 74.0
const PAD := 18.0
## Silkscreen, like the rest of the game's own text, at the one size that every
## face the game carries divides: twice Silkscreen's native 8px, and once
## 둥근모꼴's 16px. A face has exactly one correct shape per pixel, so a size
## either of them did not draw comes back with some strokes a pixel wider than
## others — see `Loc.pixel_size`, and `tests/shared/loc_test`, which checks
## these three against every language.
const TEXT_SIZE := UiKit.PIXEL_TEXT
const NAME_SIZE := UiKit.PIXEL_TEXT
const HINT_SIZE := UiKit.PIXEL_TEXT
## Baseline to baseline, on the PIXEL grid. The face's own height is 20.48px at
## this size, and a row placed on a fraction of a pixel is a row drawn between
## two of them. `PixelDraw.LINE` is the same spacing the assembly screen uses.
const LINE_H := PixelDraw.LINE
const TAB_HEIGHT := 24.0
const ROWS_SHOWN := 3       ## the panel is this tall whatever the line, so it never jumps
const OPEN_TIME := 0.18
const MARK_INSET := Vector2(16.0, 16.0)

var cut: Cutscene
var _font: Font
var _open: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = UiKit.PIXEL_FONT

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_t += delta
	# Open while there is a line to read, and gone the moment there is not: a
	# beat that only walks somebody across the room shows no panel at all.
	var showing := cut != null and is_instance_valid(cut) and not cut.done and cut.line() != ""
	_open = minf(_open + delta / OPEN_TIME, 1.0) if showing else 0.0
	queue_redraw()

func _draw() -> void:
	if _open <= 0.0:
		return
	var w := clampf(size.x - SIDE_CLEAR * 2.0, MIN_WIDTH, MAX_WIDTH)
	var text_w := w - PAD * 2.0
	var line_h := LINE_H
	var h := PAD * 2.0 + line_h * float(ROWS_SHOWN)
	var box := Rect2(Vector2((size.x - w) * 0.5, size.y - BOTTOM - h), Vector2(w, h))
	# Rises the last few pixels as it opens, which reads as the scene handing
	# the line over rather than the panel being switched on.
	box.position.y += (1.0 - _open) * 8.0

	var fill := Color(UiKit.PANEL.r, UiKit.PANEL.g, UiKit.PANEL.b, 0.93 * _open)
	draw_rect(box, fill)
	draw_rect(box, Color(UiKit.LINE.r, UiKit.LINE.g, UiKit.LINE.b, _open), false, 2.0)

	var name := cut.speaker_name()
	if name != "":
		_draw_name_tab(box, name)

	# Wrapped from the whole line rather than the part typed so far, so a word
	# never jumps down a row halfway through arriving.
	var rows := _wrap(cut.line(), text_w, TEXT_SIZE)
	var shown := int(cut.revealed)
	var pen := box.position + Vector2(PAD, PAD)
	var used := 0
	var ink := Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, _open)
	for row in rows:
		var left := shown - used
		if left <= 0:
			break
		_text(pen, row.left(left), TEXT_SIZE, ink)
		used += row.length() + 1   # the space the wrap ate
		pen.y += line_h

	if cut.waiting_for_press() and cut.line_finished():
		_draw_mark(box)
	_draw_hint(box)

## The speaker's name on a tab over the top-left corner. Narration has no
## speaker and so gets no tab — which is how the two read apart.
func _draw_name_tab(box: Rect2, name: String) -> void:
	var w := _width(name, NAME_SIZE) + PAD * 1.6
	var tab := Rect2(box.position + Vector2(PAD, -TAB_HEIGHT), Vector2(w, TAB_HEIGHT))
	draw_rect(tab, Color(UiKit.PANEL.r, UiKit.PANEL.g, UiKit.PANEL.b, 0.97 * _open))
	draw_rect(tab, Color(UiKit.LINE.r, UiKit.LINE.g, UiKit.LINE.b, _open), false, 2.0)
	var c := Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, _open)
	_text(tab.position + Vector2(PAD * 0.8, (TAB_HEIGHT - LINE_H) * 0.5), name, NAME_SIZE, c)

## The blinking wedge that says the line is read and a press moves it on.
func _draw_mark(box: Rect2) -> void:
	var a := 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 6.0))
	var at := box.end - MARK_INSET
	var c := Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, a * _open)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-7, -5), at + Vector2(3, -5), at + Vector2(-2, 3)]), c)

func _draw_hint(box: Rect2) -> void:
	var hint := Loc.t("hud.cutscene.hint", [
		Controls.short_label_for("ui_accept"), Controls.short_label_for("ui_cancel")])
	var c := Color(UiKit.DIM.r, UiKit.DIM.g, UiKit.DIM.b, 0.8 * _open)
	_text(Vector2(box.position.x, box.end.y + 7.0), hint, HINT_SIZE, c)

## --- text -------------------------------------------------------------------

func _text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	# Rounded onto whole pixels: the face's ascent is 16.48px, and a baseline
	# half a pixel down draws the whole row between two rows of them.
	draw_string(_font, (pos + Vector2(0, _font.get_ascent(font_size))).round(), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

## Greedy word wrap into rows no wider than `width`. A word wider than the box
## gets a row of its own rather than being split.
func _wrap(text: String, width: float, font_size: int) -> PackedStringArray:
	var rows := PackedStringArray()
	var row := ""
	for word in text.split(" ", false):
		var trial := word if row == "" else row + " " + word
		if row != "" and _width(trial, font_size) > width:
			rows.append(row)
			row = word
		else:
			row = trial
	if row != "":
		rows.append(row)
	return rows
