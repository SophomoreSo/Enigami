class_name NpcView
extends Node2D

## A bystander: their character from the atlas, a prompt over their head while
## the player is close enough to talk, and a speech bubble holding the line they
## are saying.

## Text wraps inside this.
const BUBBLE_WIDTH := 170.0
const BUBBLE_PAD := Vector2(8.0, 6.0)
## Space between the top of the head and the tip of the bubble's tail.
const BUBBLE_GAP := 6.0
const TAIL := Vector2(6.0, 8.0)
const TEXT_SIZE := 10
const NAME_SIZE := 9
const CORNER := 5

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
	# Wrapped from the whole line, not the part revealed so far, so a word never
	# jumps to the next row halfway through coming in and the bubble never grows
	# under the reader's eye.
	var rows := _wrap(npc.current_line(), BUBBLE_WIDTH)
	var line_h := _font.get_height(TEXT_SIZE)
	var name_h := _font.get_height(NAME_SIZE)
	var inner := Vector2(_font.get_string_size(npc.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x,
		name_h + line_h * rows.size())
	for row in rows:
		inner.x = maxf(inner.x, _font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x)
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
	bubble.draw_string(_font, pen + Vector2(0, _font.get_ascent(NAME_SIZE)), npc.display_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, Style.SPEECH_NAME)
	pen.y += name_h
	var left := int(npc.revealed)
	for row in rows:
		if left <= 0:
			break
		bubble.draw_string(_font, pen + Vector2(0, _font.get_ascent(TEXT_SIZE)), row.left(left),
			HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, Style.SPEECH_TEXT)
		left -= row.length() + 1   # the space the wrap swallowed
		pen.y += line_h

	# A blinking marker once the line is out, when a press has more to say.
	if npc.line_finished() and npc.has_more() and fmod(_t, 0.8) < 0.5:
		var m := body.end - BUBBLE_PAD
		bubble.draw_colored_polygon(PackedVector2Array([
			m + Vector2(-8, -5), m + Vector2(0, -5), m + Vector2(-4, 0),
		]), Style.SPEECH_NAME)

func _draw_prompt(tip_y: float) -> void:
	var text := "%s  Talk" % Controls.short_label_for("interact")
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
	var bob := sin(_t * 4.0) * 1.5
	var body := Rect2(Vector2(-w * 0.5 - 5.0, tip_y - 16.0 + bob), Vector2(w + 10.0, 15.0))
	bubble.draw_style_box(_prompt_box, body)
	bubble.draw_string(_font, Vector2(body.position.x + 5.0, body.position.y + 3.0 + _font.get_ascent(NAME_SIZE)),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, Style.SPEECH_PROMPT_TEXT)

## Greedy word wrap into rows no wider than `width`. A single word wider than
## the bubble gets a row of its own rather than being split.
func _wrap(text: String, width: float) -> PackedStringArray:
	var rows := PackedStringArray()
	var row := ""
	for word in text.split(" ", false):
		var trial := word if row == "" else row + " " + word
		if row != "" and _font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x > width:
			rows.append(row)
			row = word
		else:
			row = trial
	if row != "":
		rows.append(row)
	return rows
