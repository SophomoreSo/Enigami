class_name NpcView
extends Node2D

## A bystander: their character from the atlas, a prompt over their head while
## the player is close enough to talk, and a speech bubble holding the line they
## are saying — with the answers under it when the line is a question.

## Text wraps inside this.
const BUBBLE_WIDTH := 190.0
const BUBBLE_PAD := Vector2(8.0, 6.0)
## Space between the top of the head and the tip of the bubble's tail.
const BUBBLE_GAP := 6.0
const TAIL := Vector2(6.0, 8.0)
const TEXT_SIZE := 10
const NAME_SIZE := 9
const HINT_SIZE := 8
const CORNER := 5
## How far an answer sits in from the line, to leave room for the marker.
const CHOICE_INDENT := 12.0
## Space between the line and the first answer, and after the last.
const CHOICE_GAP := 5.0

var npc: Npc
var sprite: AnimatedSprite2D
## The bubble sits on its own layer so the player walking in front of the NPC
## never covers what they are saying.
var bubble: Node2D
var _font: Font
var _box: StyleBoxFlat
var _prompt_box: StyleBoxFlat
## Where the top of the head is, relative to the NPC.
var _head_y: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	npc = get_parent() as Npc
	z_index = 45
	_font = ThemeDB.fallback_font
	_box = StyleBoxFlat.new()
	_box.bg_color = Style.SPEECH_FILL
	_box.border_color = Style.SPEECH_EDGE
	_box.set_border_width_all(2)
	_box.set_corner_radius_all(CORNER)
	_prompt_box = StyleBoxFlat.new()
	_prompt_box.bg_color = Style.SPEECH_PROMPT_FILL
	_prompt_box.set_corner_radius_all(CORNER)
	bubble = Node2D.new()
	bubble.z_index = 30
	bubble.draw.connect(_draw_bubble)
	add_child(bubble)

## Built on the first frame rather than in `_ready`, by which time the NPC knows
## who it is.
func _build_sprite() -> void:
	var art := Style.npc_art(npc.npc_id)
	var s := Sprites.PIXEL_SCALE
	var frame := Sprites.frame_size(art)
	var art_rect := Sprites.art_rect(art)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.frames_for(art)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(s, s)
	sprite.position = Vector2(0, npc.body_size.y * 0.5 + (frame.y * 0.5 - art_rect.end.y) * s)
	add_child(sprite)
	sprite.play("idle")
	_head_y = sprite.position.y + (art_rect.position.y - frame.y * 0.5) * s

func _process(delta: float) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	if sprite == null:
		_build_sprite()
	_t += delta
	sprite.flip_h = npc.facing < 0
	bubble.queue_redraw()

func _draw_bubble() -> void:
	if sprite == null:
		return
	var tip_y := _head_y - BUBBLE_GAP
	if npc.is_talking():
		_draw_speech(tip_y)
	elif npc.in_range:
		_draw_prompt(tip_y)

func _draw_speech(tip_y: float) -> void:
	var line_h := _font.get_height(TEXT_SIZE)
	var name_h := _font.get_height(NAME_SIZE)
	var hint_h := _font.get_height(HINT_SIZE)
	# Wrapped from the whole line, not the part revealed so far, so a word never
	# jumps to the next row halfway through coming in.
	var rows := _wrap(npc.current_line(), BUBBLE_WIDTH, TEXT_SIZE)
	var options: Array = []
	for c in npc.choices():
		options.append(_wrap(String(c.get("text", "")), BUBBLE_WIDTH - CHOICE_INDENT, TEXT_SIZE))
	var hint := _choice_hint()

	# Sized for the answers from the first letter, even though they only appear
	# once the question is out, so the bubble never grows under the reader's eye.
	var inner := Vector2(_width(npc.display_name, NAME_SIZE), name_h + line_h * rows.size())
	for row in rows:
		inner.x = maxf(inner.x, _width(row, TEXT_SIZE))
	if not options.is_empty():
		inner.y += CHOICE_GAP * 2.0 + hint_h
		inner.x = maxf(inner.x, _width(hint, HINT_SIZE))
		for opt in options:
			inner.y += line_h * opt.size()
			for row in opt:
				inner.x = maxf(inner.x, CHOICE_INDENT + _width(row, TEXT_SIZE))
	var size := inner + BUBBLE_PAD * 2.0
	var body := Rect2(Vector2(-size.x * 0.5, tip_y - TAIL.y - size.y), size)

	bubble.draw_style_box(_box, body)
	# The tail's fill runs up over the box's border so the two read as one shape.
	var base := body.end.y
	bubble.draw_colored_polygon(PackedVector2Array([
		Vector2(-TAIL.x, base - 2.0), Vector2(TAIL.x, base - 2.0), Vector2(0, tip_y),
	]), Style.SPEECH_FILL)
	bubble.draw_polyline(PackedVector2Array([
		Vector2(-TAIL.x, base - 1.0), Vector2(0, tip_y), Vector2(TAIL.x, base - 1.0),
	]), Style.SPEECH_EDGE, 2.0)

	var pen := body.position + BUBBLE_PAD
	_text(pen, npc.display_name, NAME_SIZE, Style.SPEECH_NAME)
	pen.y += name_h
	var left := int(npc.revealed)
	for row in rows:
		if left > 0:
			_text(pen, row.left(left), TEXT_SIZE, Style.SPEECH_TEXT)
		left -= row.length() + 1   # the space the wrap swallowed
		pen.y += line_h

	if npc.is_choosing():
		pen.y += CHOICE_GAP
		for i in options.size():
			var opt: PackedStringArray = options[i]
			var chosen := i == npc.selected
			if chosen:
				bubble.draw_rect(Rect2(pen.x - 3.0, pen.y, inner.x + 6.0, line_h * opt.size()),
					Style.SPEECH_CHOICE_FILL)
				var mid := pen.y + line_h * 0.5
				bubble.draw_colored_polygon(PackedVector2Array([
					Vector2(pen.x + 1.0, mid - 4.0), Vector2(pen.x + 7.0, mid), Vector2(pen.x + 1.0, mid + 4.0),
				]), Style.SPEECH_NAME)
			for row in opt:
				_text(pen + Vector2(CHOICE_INDENT, 0), row, TEXT_SIZE,
					Style.SPEECH_TEXT if chosen else Style.SPEECH_CHOICE)
				pen.y += line_h
		pen.y += CHOICE_GAP
		_text(pen, hint, HINT_SIZE, Style.SPEECH_HINT)
	elif npc.line_finished() and npc.has_more() and fmod(_t, 0.8) < 0.5:
		# A blinking marker once the line is out, when a press has more to say.
		var m := body.end - BUBBLE_PAD
		bubble.draw_colored_polygon(PackedVector2Array([
			m + Vector2(-8, -5), m + Vector2(0, -5), m + Vector2(-4, 0),
		]), Style.SPEECH_NAME)

func _draw_prompt(tip_y: float) -> void:
	var text := "%s  Talk" % Controls.short_label_for("interact")
	var w := _width(text, NAME_SIZE)
	var bob := sin(_t * 4.0) * 1.5
	var body := Rect2(Vector2(-w * 0.5 - 5.0, tip_y - 16.0 + bob), Vector2(w + 10.0, 15.0))
	bubble.draw_style_box(_prompt_box, body)
	_text(body.position + Vector2(5.0, 3.0), text, NAME_SIZE, Style.SPEECH_PROMPT_TEXT)

## How to answer, in whatever the player has the keys bound to.
func _choice_hint() -> String:
	return "%s/%s choose  ·  %s answer" % [Controls.short_label_for("move_up"),
		Controls.short_label_for("move_down"), Controls.short_label_for("interact")]

## Draws `text` with its top-left corner at `pos`.
func _text(pos: Vector2, text: String, size: int, color: Color) -> void:
	bubble.draw_string(_font, pos + Vector2(0, _font.get_ascent(size)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _width(text: String, size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## Greedy word wrap into rows no wider than `width`. A single word wider than
## the bubble gets a row of its own rather than being split.
func _wrap(text: String, width: float, size: int) -> PackedStringArray:
	var rows := PackedStringArray()
	var row := ""
	for word in text.split(" ", false):
		var trial := word if row == "" else row + " " + word
		if row != "" and _width(trial, size) > width:
			rows.append(row)
			row = word
		else:
			row = trial
	if row != "":
		rows.append(row)
	return rows
