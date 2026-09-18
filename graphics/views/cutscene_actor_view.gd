class_name CutsceneActorView
extends Node2D

## One member of a cutscene's cast: their character from the atlas, walking or
## standing according to how fast they are actually moving — unless the beat
## running now asked for something in particular, in which case that wins.
##
## Reads `cast["sprite"]` straight off the node, the same way `NpcView` reads an
## NPC's. The rules never look at that key; they only carry it.

## Below this an actor is standing still as far as the picture is concerned.
const WALK_THRESHOLD := 4.0

var who: CutsceneActor
var sprite: AnimatedSprite2D

func _ready() -> void:
	who = get_parent() as CutsceneActor
	z_index = 40

## Built on the first frame rather than in `_ready`, by which time the cast
## member has been told who they are.
func _build_sprite() -> void:
	var art := Style.npc_art(String(who.cast.get("sprite", "")))
	var s := Sprites.PIXEL_SCALE
	var frame := Sprites.frame_size(art)
	var art_rect := Sprites.art_rect(art)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.frames_for(art)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(s, s)
	sprite.position = Vector2(0, who.body_size.y * 0.5 + (frame.y * 0.5 - art_rect.end.y) * s)
	add_child(sprite)
	sprite.play("idle")

func _process(_delta: float) -> void:
	if who == null or not is_instance_valid(who):
		return
	if sprite == null:
		_build_sprite()
	visible = who.on_stage
	if not visible:
		return
	sprite.flip_h = who.facing < 0
	_play(_wanted())

## What should be playing: whatever an `anim` direction last asked for, or else
## the truth about whether they are walking.
func _wanted() -> String:
	if who.forced_anim != "":
		return who.forced_anim
	return "run" if absf(who.velocity.x) > WALK_THRESHOLD else "idle"

func _play(name: String) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(name):
		name = "idle"
	if sprite.animation != name or not sprite.is_playing():
		sprite.play(name)
