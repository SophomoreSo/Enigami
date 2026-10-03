class_name NpcView
extends Node2D

## A bystander: their character from the atlas, a prompt over their head while
## the player is close enough to talk and a press would get an answer, and —
## once they are talking in the box — the dialogue box at the top of the screen
## (see `DialogueBox`) and the camera each line of their dialogue file asks for.
## What they say free goes in a bubble over whoever says it (`SpeechBubble`).

## The prompt is a keycap with the interact key on it, pressed now and then so
## it reads as "press this" rather than as a label. It is pixel art on the same
## grid as the NPC under it, so every size here is in PixelDraw.PX blocks.
##
## The cap's face, at its narrowest: room for one capital with a margin.
const KEY_W := 11
const KEY_H := 9
## How far the face stands above its base, and so how far a press sinks it.
const KEY_DEPTH := 2
## One press every PRESS_EVERY seconds: down over PRESS_DOWN, held, then back up
## over PRESS_UP.
const PRESS_EVERY := 1.1
const PRESS_DOWN := 0.07
const PRESS_HOLD := 0.12
const PRESS_UP := 0.12
## Space between the top of the head and the bottom of the prompt.
const PROMPT_GAP := 6.0
## A focus on someone frames their face rather than their feet.
const FACE_LIFT := Vector2(0, -18)

var npc: Npc
var sprite: AnimatedSprite2D
## The prompt sits on its own layer so the player walking in front of the NPC
## never covers it — and so its key is sharp, drawn at the screen's resolution
## in PixelDraw's blocks, the way the hideout's signs are (`HideoutWorldView`):
## a canvas layer is not part of the world the pixel camera copies. It follows
## the camera, just over the pixel picture.
var prompt_layer: CanvasLayer
var prompt: Node2D
var dialogue: DialogueBox
## On the prompt's layer, for the prompt's reasons: free talk is reading text.
var bubble: SpeechBubble
var _px: PixelDraw
## Where the top of the head is, relative to the NPC.
var _head_y: float = 0.0
var _t: float = 0.0
## The line whose camera directions have been carried out, or "" when this NPC
## does not have the camera.
var _directed: String = ""

func _ready() -> void:
	npc = get_parent() as Npc
	z_index = 45
	prompt_layer = CanvasLayer.new()
	prompt_layer.layer = PixelCamera.LAYER + 1
	prompt_layer.follow_viewport_enabled = true
	add_child(prompt_layer)
	prompt = Node2D.new()
	prompt.draw.connect(_draw_prompt)
	prompt_layer.add_child(prompt)
	_px = PixelDraw.new(prompt)
	bubble = SpeechBubble.new()
	bubble.npc = npc
	prompt_layer.add_child(bubble)

	var dialogue_layer := CanvasLayer.new()
	dialogue_layer.layer = DialogueBox.LAYER
	add_child(dialogue_layer)
	dialogue = DialogueBox.new()
	dialogue.npc = npc
	dialogue_layer.add_child(dialogue)

## Built on the first frame rather than in `_ready`, by which time the NPC knows
## who it is.
func _build_sprite() -> void:
	var art := Style.npc_art(String(npc.data.get("sprite", "")))
	var s := Sprites.PIXEL_SCALE
	var frame := Sprites.frame_size(art)
	var art_rect := Sprites.art_rect(art)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.frames_for(art)
	# A character drawn the map way needs its material to show colours at all.
	sprite.material = Sprites.material_for(art)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(s, s)
	sprite.position = Vector2(0, npc.body_size.y * 0.5 + (frame.y * 0.5 - art_rect.end.y) * s)
	add_child(sprite)
	sprite.play("idle")
	_head_y = sprite.position.y + (art_rect.position.y - frame.y * 0.5) * s
	bubble.npc_head = _head_y

func _process(delta: float) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	if sprite == null:
		_build_sprite()
	_t += delta
	sprite.flip_h = npc.facing < 0
	# On whole world pixels, the grid the NPC is drawn on, so the cap's blocks
	# line up with theirs.
	prompt.position = (global_position / PixelCamera.SCALE).round() * PixelCamera.SCALE
	prompt.queue_redraw()
	_direct_camera()

## An NPC taken away mid-conversation gives the camera back.
func _exit_tree() -> void:
	if _directed != "":
		Fx.release()

## Carries out a line's `camera` once, as the line starts. A line with none
## leaves the camera where the last one put it; the conversation ending, or
## `"reset"`, hands it back to the screen.
func _direct_camera() -> void:
	if not npc.is_talking():
		if _directed != "":
			Fx.release()
			_directed = ""
		return
	if npc.node_id == _directed:
		return
	_directed = npc.node_id
	var cam = npc.current_node().get("camera", null)
	if cam is String and cam == "reset":
		Fx.release()
	elif cam is Dictionary:
		var time := float(cam.get("time", 0.4))
		if cam.has("focus") or cam.has("zoom"):
			Fx.direct(_focus_point(String(cam.get("focus", "both"))), float(cam.get("zoom", 1.0)), time)
		if cam.has("shake"):
			Fx.shake(float(cam["shake"]))

func _focus_point(focus: String) -> Vector2:
	var me := npc.global_position + FACE_LIFT
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return me
	var them := player.global_position + FACE_LIFT
	match focus:
		"npc":
			return me
		"player":
			return them
		_:
			return (me + them) * 0.5

## Only while nobody is talking: once they are, the box or the bubble says it
## all. And only when a press would get an answer — a free talker with nothing
## left to say has no prompt over their head — and has not already had one: the
## player walking over to talk has pressed it.
func _draw_prompt() -> void:
	if sprite == null or npc.is_talking() or npc.free_talk.is_talking() or not npc.answers_press() \
			or npc.approaching():
		return
	var tip_y := _head_y - PROMPT_GAP
	var text := Controls.short_label_for("interact")
	var px := PixelDraw.PX
	# Square for a single key, wider for a word like "LMB".
	var size := Vector2(maxf(PixelDraw.ink_width(text) + 6 * px, KEY_W * px), KEY_H * px)
	var sink := roundi(KEY_DEPTH * _pressed(fmod(_t, PRESS_EVERY))) * px
	# The base stays put; the face rides KEY_DEPTH above it and sinks onto it.
	var base := Rect2(_px.snap(Vector2(-size.x * 0.5, tip_y - size.y)), size)
	var face := Rect2(base.position - Vector2(0.0, KEY_DEPTH * px - sink), size)
	# A dark rim round the whole cap, so it reads on a pale wall as well as a dark one.
	_cap(face.merge(base).grow(px), 2, Style.KEY_CAP_RIM)
	_cap(base, 1, Style.KEY_CAP_SIDE)
	_cap(face, 1, Style.KEY_CAP_FACE)
	# `text` takes a baseline, and capitals stand 5 blocks: 2 clear above them.
	_px.text_centered(face.position + Vector2(0.0, 7 * px), text, Style.KEY_CAP_TEXT, size.x)

## `r` filled with its corners cut `cut` blocks deep in steps, the pixel art way
## of rounding one.
func _cap(r: Rect2, cut: int, col: Color) -> void:
	var px := PixelDraw.PX
	for i in cut + 1:
		var k := cut - i
		_px.rect(Rect2(r.position + Vector2(k, i) * px, r.size - Vector2(k, i) * 2 * px), col)

## How far down the cap is, 0 up to 1 all the way, `t` seconds into a press.
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
