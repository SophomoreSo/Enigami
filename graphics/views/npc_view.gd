class_name NpcView
extends Node2D

## A bystander: their character from the atlas, a prompt over their head while
## the player is close enough to talk, and — once they are talking — the dialogue
## box at the top of the screen (see `DialogueBox`) and the camera each line of
## their dialogue file asks for.

const NAME_SIZE := 9
const CORNER := 5
## Space between the top of the head and the bottom of the prompt.
const PROMPT_GAP := 6.0
## A focus on someone frames their face rather than their feet.
const FACE_LIFT := Vector2(0, -18)

var npc: Npc
var sprite: AnimatedSprite2D
## The prompt sits on its own layer so the player walking in front of the NPC
## never covers it — and so it is reading text, drawn at the screen's
## resolution: a canvas layer is not part of the world the pixel camera copies.
## It follows the camera, just over the pixel picture.
var prompt_layer: CanvasLayer
var prompt: Node2D
var dialogue: DialogueBox
var _font: Font
var _prompt_box: StyleBoxFlat
## Where the top of the head is, relative to the NPC.
var _head_y: float = 0.0
var _t: float = 0.0
## The line whose camera directions have been carried out, or "" when this NPC
## does not have the camera.
var _directed: String = ""

func _ready() -> void:
	npc = get_parent() as Npc
	z_index = 45
	_font = ThemeDB.fallback_font
	_prompt_box = StyleBoxFlat.new()
	_prompt_box.bg_color = Style.SPEECH_PROMPT_FILL
	_prompt_box.set_corner_radius_all(CORNER)
	prompt_layer = CanvasLayer.new()
	prompt_layer.layer = PixelCamera.LAYER + 1
	prompt_layer.follow_viewport_enabled = true
	add_child(prompt_layer)
	prompt = Node2D.new()
	prompt.draw.connect(_draw_prompt)
	prompt_layer.add_child(prompt)

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
	prompt.position = global_position
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

## Only while nobody is talking: once they are, the box says it all.
func _draw_prompt() -> void:
	if sprite == null or npc.is_talking() or not npc.in_range:
		return
	var tip_y := _head_y - PROMPT_GAP
	var text := "%s  Talk" % Controls.short_label_for("interact")
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
	var bob := sin(_t * 4.0) * 1.5
	var body := Rect2(Vector2(-w * 0.5 - 5.0, tip_y - 16.0 + bob), Vector2(w + 10.0, 15.0))
	prompt.draw_style_box(_prompt_box, body)
	prompt.draw_string(_font, body.position + Vector2(5.0, 3.0 + _font.get_ascent(NAME_SIZE)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, Style.SPEECH_PROMPT_TEXT)
