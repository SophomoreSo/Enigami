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
## The size of the body the sprite was last stood on (`_stand_sprite`).
var _stood_on: Vector2 = Vector2.ZERO

func _ready() -> void:
	actor = get_parent() as Actor
	if actor != null:
		actor.damaged.connect(_on_damaged)
		actor.healed.connect(_on_healed)

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
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.frames_for(art)
	sprite.animation = "idle"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(s, s)
	_stand_sprite()
	_mat = Sprites.material_for(art)
	sprite.material = _mat
	add_child(sprite)
	sprite.play("idle")

## Puts the art's feet on the body's: the tile is centred on the node, so the
## node is backed off by half the body and by however much padding sits under
## the art — usually none, but never assume it. Done again whenever the body
## changes size, which a crouching player's does.
func _stand_sprite() -> void:
	var s := Sprites.PIXEL_SCALE
	var frame := Sprites.frame_size(art)
	_stood_on = actor.body_size
	sprite.position = Vector2(0, _stood_on.y * 0.5 + (frame.y * 0.5 - Sprites.art_rect(art).end.y) * s)

func _process(delta: float) -> void:
	if not _ensure():
		return
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
	if actor.body_size != _stood_on:
		_stand_sprite()
	sprite.flip_h = actor.facing < 0
	_animate()
	_update_status()
	_burn_sparks(delta)
	_stun_stars(delta)
	_wet_drips(delta)
	_frost_glints(delta)
	queue_redraw()

## Whether this actor's art has an animation of that name. The atlas characters
## have idle, run and hit; the game's own may have more — see
## `SkinnedCharacter.ANIMS`.
func has_anim(anim: String) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim)

## Plays `name`, or freezes on `frame` of it when `frame` is not negative — how
## an airborne pose is held out of a run cycle for art that has no jump. An
## animation that does not loop stays on its last frame once it has run, until
## something else is asked for.
func play(anim: String, speed: float = 1.0, frame: int = -1) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(anim):
		anim = "idle"
	if frame >= 0:
		sprite.animation = anim
		sprite.frame = mini(frame, sprite.sprite_frames.get_frame_count(anim) - 1)
		sprite.pause()
		return
	sprite.speed_scale = speed
	if sprite.animation != anim:
		sprite.play(anim)
		return
	if sprite.is_playing():
		return
	# Stopped on this animation: paused on a held frame, or a one-shot that has
	# run out. Only the first is started again.
	var last := sprite.sprite_frames.get_frame_count(anim) - 1
	if sprite.sprite_frames.get_animation_loop(anim) or sprite.frame < last:
		sprite.play(anim)

## Chill and burn read as a multiply; a hit needs to blow the whole silhouette
## out to white, which a modulate cannot do, so the shader blends instead.
func _update_status() -> void:
	if _mat == null:
		return
	var t := tint
	if actor.wet_time > 0.0:
		t = t.lerp(Style.ELEMENT_COLOR["WATER"], 0.3)
	if actor.chill_time > 0.0:
		t = t.lerp(Color(0.45, 0.8, 1.0), 0.5)
	if actor.burn_time > 0.0:
		t = t.lerp(Color(1.0, 0.45, 0.2), 0.4)
	# Frozen is ice all over; stunned is dulled: the colour goes out of it
	# while it stands there.
	if actor.frozen():
		t = t.lerp(Style.FROZEN_TINT, 0.75)
	elif actor.stunned():
		t = t.lerp(Color(0.6, 0.6, 0.62), 0.45)
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

var _star: float = 0.0
var _star_turn: float = 0.0

var _drip: float = 0.0

## Drops falling off whatever is wet, now and then.
func _wet_drips(delta: float) -> void:
	if actor.wet_time <= 0.0:
		return
	_drip -= delta
	if _drip > 0.0:
		return
	_drip = 0.22
	Fx.burst(actor.global_position + Vector2(randf_range(-actor.body_size.x, actor.body_size.x) * 0.4,
		actor.body_size.y * 0.3), Style.ELEMENT_COLOR["WATER"], 1, 12.0)

var _glint: float = 0.0

## Frost catching the light on whatever is frozen solid.
func _frost_glints(delta: float) -> void:
	if not actor.frozen():
		return
	_glint -= delta
	if _glint > 0.0:
		return
	_glint = 0.15
	var at := Vector2(randf_range(-0.5, 0.5) * actor.body_size.x, randf_range(-0.5, 0.5) * actor.body_size.y)
	Fx.burst(actor.global_position + at, Style.FROZEN_TINT, 1, 8.0)

## Stars going round over the head of whatever is stunned, one at a time. One
## frozen solid has frost on it instead (`_frost_glints`).
func _stun_stars(delta: float) -> void:
	if not actor.stunned() or actor.frozen():
		return
	_star -= delta
	if _star > 0.0:
		return
	_star = 0.09
	_star_turn += 1.9
	var over := Vector2(cos(_star_turn) * actor.body_size.x * 0.45, -actor.body_size.y * 0.5 - 8.0)
	Fx.burst(actor.global_position + over, Style.STUN_COLOR, 1, 18.0)

## Health given back reads with the damage numbers, green and signed, and a
## line above where they start: what an INVERT gives back lands in the same
## instant as the blow it rides on, and two numbers thrown from one spot are
## one smudge.
func _on_healed(a: Actor, amount: float) -> void:
	var line := float(PixelCamera.TEXT_SIZE * PixelCamera.SCALE)
	Fx.text(a.global_position + Vector2(0, -a.hurt_radius - 6 - line), "+%d" % int(round(amount)), Style.HEAL_COLOR)

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
