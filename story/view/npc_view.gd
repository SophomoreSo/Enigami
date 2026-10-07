class_name NpcView
extends Node2D

## A bystander: their character from the atlas, a prompt over their head while
## the player is close enough to talk and a press would get an answer, and —
## once they are talking in the box — the dialogue box at the top of the screen
## (see `DialogueBox`), the screen gone wide around it (`Letterbox`), and the
## camera each line of their dialogue file asks for. What they say free goes in
## a bubble over whoever says it (`SpeechBubble`).

## The prompt is a keycap with the interact key on it, pressing itself, so it
## reads as "press this" rather than as a label (`PixelDraw.key_cap`).
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
## The bars over the top and the bottom of the picture while the box has the
## screen, on a layer of their own under the box's.
var letterbox: Letterbox
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

	var bars_layer := CanvasLayer.new()
	bars_layer.layer = Letterbox.LAYER
	add_child(bars_layer)
	letterbox = Letterbox.new()
	letterbox.npc = npc
	bars_layer.add_child(letterbox)

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
	# Somebody standing in a lamp's light throws a shadow the size of
	# themselves, as every body in a fight does (`ShadowCaster`).
	var caster := ShadowCaster.new()
	caster.box(Rect2(-npc.body_size * 0.5, npc.body_size))
	add_child(caster)
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
## leaves the camera where the last one put it; the conversation ending hands
## it back to the screen, as the bars go back out.
##
## The box opening brings the bars in (`Letterbox`) and leaves less of the
## screen to see — and somebody standing on a room's floor stands where the
## bottom bar comes. So the camera takes the two of them into what the bars
## leave as they come in, at the screen's own zoom; the bars let it go further
## up or down than the screen's own framing would (`Fx.bars`). `"reset"` goes
## back to that.
func _direct_camera() -> void:
	if not npc.is_talking():
		if _directed != "":
			Fx.release(Letterbox.TIME)
			_directed = ""
		return
	if npc.node_id == _directed:
		return
	if _directed == "":
		_frame(Letterbox.TIME)
	_directed = npc.node_id
	var cam = npc.current_node().get("camera", null)
	if cam is String and cam == "reset":
		_frame(0.4)
	elif cam is Dictionary:
		var time := float(cam.get("time", 0.4))
		if cam.has("focus") or cam.has("zoom"):
			Fx.direct(_focus_point(String(cam.get("focus", "both"))), float(cam.get("zoom", 1.0)), time)
		if cam.has("shake"):
			Fx.shake(float(cam["shake"]))

## The two of them, at the screen's own zoom, in what the bars leave.
func _frame(time: float) -> void:
	Fx.direct(_focus_point("both"), 1.0, time)

func _focus_point(focus: String) -> Vector2:
	var me := npc.global_position + FACE_LIFT
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return me
	if player is Player:
		player = (player as Player).vessel()
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
	_px.key_cap(Vector2(0.0, tip_y), Controls.short_label_for("interact"), _t)
