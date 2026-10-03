class_name TreasureBoxView
extends Node2D

## The box a room's loot is kept in: a wooden chest with a gold band, glowing
## while there is something in it, and standing open and dark once it is empty.
## Over it, while the player is in reach of a shut one, the key that opens it.
##
## That prompt is the same keycap an NPC's talk prompt is — the interact key on
## a key that presses itself, and no word — so walking up to a box and walking
## up to someone ask for the same press the same way. It is drawn here because
## the shared `PixelDraw.key_cap` is still on the graphics branch; once it lands,
## `_draw_prompt` is that one call and the KEY_ constants here go.

## The keycap, in PixelDraw.PX blocks, as the talk prompt has it: the face at
## its narrowest, how far it stands over its base, and one press every
## PRESS_EVERY seconds — down, held, back up.
const KEY_W := 11
const KEY_H := 9
const KEY_DEPTH := 2
const PRESS_EVERY := 1.1
const PRESS_DOWN := 0.07
const PRESS_HOLD := 0.12
const PRESS_UP := 0.12
## And its colours: a pale face over a darker side, dark lettering, and an
## opaque dark rim, since the rim goes down as overlapping blocks.
const KEY_FACE := Color(0.86, 0.9, 0.96)
const KEY_SIDE := Color(0.42, 0.47, 0.56)
const KEY_TEXT := Color(0.08, 0.09, 0.12)
const KEY_RIM := Color(0.05, 0.06, 0.08)
## Space between the top of the lid and the bottom of the key.
const PROMPT_GAP := 6.0

var box: TreasureBox
var _t: float = 0.0
## The key sits on its own layer, the way the talk prompt does: drawn at the
## screen's resolution in PixelDraw's blocks, which a layer the pixel camera
## does not copy allows, and never covered by the player walking past.
var _prompt_layer: CanvasLayer
var _prompt: Node2D
var _px: PixelDraw
## How far the lid has swung back, 0 shut to 1 open, so opening it is seen.
var _lid: float = 0.0

## The box sits on a cell's centre, which is half a cell above the floor.
const FLOOR := 16.0
const W := 26.0
const H := 16.0
const LID_H := 7.0

func _ready() -> void:
	box = get_parent() as TreasureBox
	# With the loot, under the kit a death left: a box is found, a kit is
	# looked for.
	z_index = 35
	if box != null and box.is_open:
		_lid = 1.0
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.layer = PixelCamera.LAYER + 1
	_prompt_layer.follow_viewport_enabled = true
	add_child(_prompt_layer)
	_prompt = Node2D.new()
	_prompt.draw.connect(_draw_prompt)
	_prompt_layer.add_child(_prompt)
	_px = PixelDraw.new(_prompt)

func _process(delta: float) -> void:
	_t += delta
	if box != null and is_instance_valid(box):
		_lid = move_toward(_lid, 1.0 if box.is_open else 0.0, delta * 5.0)
		# On whole world pixels, the grid the box is drawn on, so the key's
		# blocks line up with it.
		_prompt.position = (global_position / PixelCamera.SCALE).round() * PixelCamera.SCALE
	queue_redraw()
	_prompt.queue_redraw()

func _draw() -> void:
	if box == null or not is_instance_valid(box):
		return
	var top := FLOOR - H
	var body := Rect2(-W * 0.5, top, W, H)
	if not box.is_open:
		var glow := Style.TREASURE_GLOW
		glow.a = 0.20 + 0.10 * sin(_t * 4.0)
		draw_circle(Vector2(0, top + 2.0), 20.0, glow)
	draw_rect(body, Style.TREASURE_WOOD)
	draw_rect(Rect2(-W * 0.5, top + 4.0, W, 3.0), Style.TREASURE_BAND)
	draw_rect(Rect2(-2.0, top + 3.0, 4.0, 5.0), Style.TREASURE_BAND)
	draw_rect(body, Style.TREASURE_EDGE, false, 2.0)
	_draw_lid(top)

## The interact key over a shut box in reach, pressing itself.
func _draw_prompt() -> void:
	if box == null or not is_instance_valid(box) or not box.offered():
		return
	var label := Controls.short_label_for("interact")
	var px := PixelDraw.PX
	var foot := Vector2(0.0, FLOOR - H - LID_H - PROMPT_GAP)
	# Square for a single key, wider for a word like "LMB".
	var size := Vector2(maxf(PixelDraw.ink_width(label) + 6 * px, KEY_W * px), KEY_H * px)
	var sink := roundi(KEY_DEPTH * _pressed(fmod(_t, PRESS_EVERY))) * px
	# The base stays put; the face rides KEY_DEPTH above it and sinks onto it.
	var base := Rect2(_px.snap(Vector2(foot.x - size.x * 0.5, foot.y - px - size.y)), size)
	var face := Rect2(base.position - Vector2(0.0, KEY_DEPTH * px - sink), size)
	_stepped(face.merge(base).grow(px), 2, KEY_RIM)
	_stepped(base, 1, KEY_SIDE)
	_stepped(face, 1, KEY_FACE)
	# `text` takes a baseline, and capitals stand 5 blocks: 2 clear above them.
	_px.text_centered(face.position + Vector2(0.0, 7 * px), label, KEY_TEXT, size.x)

## `r` filled with its corners cut `cut` blocks deep in steps, the pixel art way
## of rounding one.
func _stepped(r: Rect2, cut: int, col: Color) -> void:
	for i in cut + 1:
		var k := cut - i
		_px.rect(Rect2(r.position + Vector2(k, i) * PixelDraw.PX, r.size - Vector2(k, i) * 2 * PixelDraw.PX), col)

## How far down the key is, 0 up to 1 all the way, `t` seconds into a press.
static func _pressed(t: float) -> float:
	if t < PRESS_DOWN:
		return ease(t / PRESS_DOWN, 0.5)
	t -= PRESS_DOWN
	if t < PRESS_HOLD:
		return 1.0
	t -= PRESS_HOLD
	if t < PRESS_UP:
		return 1.0 - ease(t / PRESS_UP, 2.0)
	return 0.0

## Shut, the lid is a slab on top of the box. Open, it has swung back and up:
## what shows is its dark inner face standing over the box, narrowing as it
## leans away, and the black of the inside between the two.
func _draw_lid(top: float) -> void:
	var back := -W * 0.5 - 1.0
	var front := W * 0.5 + 1.0
	var rise := lerpf(LID_H, LID_H + 7.0, _lid)
	var inset := lerpf(0.0, 3.0, _lid)
	var face := Style.TREASURE_WOOD.lerp(Style.TREASURE_INSIDE, 0.45 * _lid)
	var pts := PackedVector2Array([
		Vector2(back, top), Vector2(front, top),
		Vector2(front - inset, top - rise), Vector2(back + inset, top - rise),
	])
	draw_colored_polygon(pts, face)
	# The band runs along the lid's front edge: low on a shut lid, along the top
	# of one that stands open.
	var band_y := lerpf(top - LID_H * 0.5, top - rise + 1.0, _lid)
	draw_rect(Rect2(back + inset, band_y - 1.0, front - back - inset * 2.0, 2.0), Style.TREASURE_BAND)
	pts.append(pts[0])
	draw_polyline(pts, Style.TREASURE_EDGE, 2.0)
	if _lid > 0.5:
		draw_rect(Rect2(-W * 0.5 + 2.0, top, W - 4.0, 3.0), Style.TREASURE_INSIDE)
