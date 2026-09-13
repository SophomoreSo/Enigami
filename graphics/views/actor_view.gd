class_name ActorView
extends Node2D

## The body of an actor: an animated sprite cut from the shared atlas, the
## status colours washed over it, and the numbers that float off it when it is
## hit. Subclasses choose the character and the animation; everything else is
## the same for the player and for every monster.

## Which atlas character this actor wears. Subclasses set it in `_configure`.
var art: String = Style.PLAYER_ART
## A permanent multiply over the sprite — a boss phase, a reskinned monster.
var tint: Color = Color.WHITE

var actor: Actor
var sprite: AnimatedSprite2D
## Blows the silhouette out to white on a hit, then fades.
var flash: float = 0.0

var _mat: ShaderMaterial
var _started: bool = false

func _ready() -> void:
	actor = get_parent() as Actor
	if actor != null:
		actor.damaged.connect(_on_damaged)

## Runs once, on the first frame — by which time the actor has finished its own
## `_ready` and its collider and identity are settled.
func _ensure() -> bool:
	if _started:
		return actor != null and is_instance_valid(actor)
	if actor == null or not is_instance_valid(actor):
		return false
	_started = true
	_configure()
	_build_sprite()
	return true

## Subclass hook: pick `art`, `tint` and `z_index` from the actor.
func _configure() -> void:
	pass

## Subclass hook: called every frame to choose the animation.
func _animate() -> void:
	play("idle")

func _build_sprite() -> void:
	var s := Sprites.PIXEL_SCALE
	var frame := Sprites.frame_size(art)
	var art_rect := Sprites.art_rect(art)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.frames_for(art)
	sprite.animation = "idle"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(s, s)
	# The tile is centred on the node, so back the node off by however much
	# padding sits under the art — usually none, but never assume it.
	sprite.position = Vector2(0, actor.body_size.y * 0.5 + (frame.y * 0.5 - art_rect.end.y) * s)
	_mat = Sprites.status_material()
	sprite.material = _mat
	add_child(sprite)
	sprite.play("idle")

func _process(delta: float) -> void:
	if not _ensure():
		return
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
	sprite.flip_h = actor.facing < 0
	_animate()
	_update_status()
	_burn_sparks(delta)
	queue_redraw()

## Plays `name`, or freezes on `frame` of it when `frame` is not negative — the
## pack has no jump art, so airborne poses are held run frames.
func play(name: String, speed: float = 1.0, frame: int = -1) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(name):
		name = "idle"
	if frame >= 0:
		sprite.animation = name
		sprite.frame = mini(frame, sprite.sprite_frames.get_frame_count(name) - 1)
		sprite.pause()
		return
	sprite.speed_scale = speed
	if sprite.animation != name or not sprite.is_playing():
		sprite.play(name)

## Chill and burn read as a multiply; a hit needs to blow the whole silhouette
## out to white, which a modulate cannot do, so the shader blends instead.
func _update_status() -> void:
	if _mat == null:
		return
	var t := tint
	if actor.chill_time > 0.0:
		t = t.lerp(Color(0.45, 0.8, 1.0), 0.5)
	if actor.burn_time > 0.0:
		t = t.lerp(Color(1.0, 0.45, 0.2), 0.4)
	_mat.set_shader_parameter("tint", t)
	_mat.set_shader_parameter("flash", clampf(status_flash(), 0.0, 1.0))

## What the shader's flash channel should read. Overridden where something else
## has to show through it, like a monster's wind-up.
func status_flash() -> float:
	return flash

var _ember: float = 0.0

func _burn_sparks(delta: float) -> void:
	if actor.burn_time <= 0.0:
		return
	_ember -= delta
	if _ember > 0.0:
		return
	_ember = 0.08
	Fx.burst(actor.global_position + Vector2(randf_range(-6, 6), 0),
		Style.ELEMENT_COLOR["FIRE"], 1, 40.0)

func _on_damaged(a: Actor, amount: float) -> void:
	# Damage over time never reaches here: it is not a connection, so it neither
	# flashes the sprite nor throws a number.
	flash = 1.0
	var col := Color(1, 0.95, 0.6) if a.team != 0 else Color(1, 0.5, 0.5)
	Fx.damage_number(a.global_position + Vector2(0, -a.hurt_radius - 6), amount, col)

## A strip of health over a monster, hidden while it is untouched.
func draw_health_bar(width: float, y: float) -> void:
	if actor.health_ratio() >= 1.0:
		return
	draw_rect(Rect2(-width * 0.5, y, width, 3.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(-width * 0.5, y, width * actor.health_ratio(), 3.0), Style.HEALTH_BAR)
