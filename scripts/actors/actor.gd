class_name Actor
extends CharacterBody2D

## Shared body for the player and every monster: health, elemental status,
## knockback, and an animated sprite cut from the shared atlas.

signal died(actor: Actor)
signal damaged(actor: Actor, amount: float)

@export var max_health: float = 40.0
var health: float = 40.0
var hurt_radius: float = 14.0
var body_color: Color = Color(0.9, 0.9, 0.95)
var team: int = 1  ## 0 = player, 1 = monsters

var burn_time: float = 0.0
var burn_dps: float = 0.0
var chill_time: float = 0.0
var invuln: float = 0.0
var flash: float = 0.0
var dead: bool = false

func _ready() -> void:
	health = max_health
	add_to_group("actors")

func speed_scale() -> float:
	return 0.45 if chill_time > 0.0 else 1.0

func _process_status(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
	_update_sprite_status()
	if invuln > 0.0:
		invuln -= delta
	if chill_time > 0.0:
		chill_time -= delta
	if burn_time > 0.0:
		burn_time -= delta
		apply_damage(burn_dps * delta, [], null, false)
		if randf() < delta * 12.0:
			Fx.burst(global_position + Vector2(randf_range(-6, 6), 0), Color(1.0, 0.5, 0.2), 1, 40.0)

## Returns the damage actually dealt (0 when blocked or already dead).
func apply_damage(amount: float, elements: Array = [], _source: Node = null, show_number: bool = true) -> float:
	if dead or amount <= 0.0:
		return 0.0
	if invuln > 0.0 and show_number:
		return 0.0
	health -= amount
	if show_number:
		# Damage over time ticks every frame; flashing on it would pin the
		# sprite white and hold the recoil pose for as long as the burn lasts.
		flash = 1.0
		damaged.emit(self, amount)
		var col := Color(1, 0.95, 0.6) if team != 0 else Color(1, 0.5, 0.5)
		Fx.damage_number(global_position + Vector2(0, -hurt_radius - 6), amount, col)
	for e in elements:
		if e == "FIRE":
			burn_time = maxf(burn_time, 2.5)
			burn_dps = maxf(burn_dps, amount * 0.22)
		elif e == "ICE":
			chill_time = maxf(chill_time, 2.0)
	if health <= 0.0:
		_kill()
	return amount

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)

func knockback(dir: Vector2, force: float) -> void:
	velocity += dir.normalized() * force

func _kill() -> void:
	if dead:
		return
	dead = true
	died.emit(self)
	Fx.burst(global_position, body_color, 14, 230.0)
	Audio.play("death", 1.0 + randf_range(-0.1, 0.1))
	queue_free()

func health_ratio() -> float:
	return clampf(health / maxf(max_health, 1.0), 0.0, 1.0)

## Adds a rectangular collider sized to the silhouette.
func _make_body(w: float, h: float) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	add_child(shape)

func draw_health_bar(width: float, y: float) -> void:
	if health_ratio() >= 1.0:
		return
	var w := width
	draw_rect(Rect2(-w * 0.5, y, w, 3.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(-w * 0.5, y, w * health_ratio(), 3.0), Color(0.95, 0.35, 0.35))

## --- sprite rig -------------------------------------------------------------
var sprite: AnimatedSprite2D
var sprite_tint: Color = Color.WHITE  ## permanent tint, e.g. a boss phase
var facing: int = 1

var _sprite_mat: ShaderMaterial

## Builds the sprite for atlas character `base`, standing its drawn pixels on
## the floor of a collider `collider_h` tall.
func _make_sprite(base: String, collider_h: float) -> void:
	var s := Sprites.PIXEL_SCALE
	var frame := Sprites.frame_size(base)
	var art := Sprites.art_rect(base)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.frames_for(base)
	sprite.animation = "idle"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(s, s)
	# The tile is centred on the node, so back the node off by however much
	# padding sits under the art — usually none, but never assume it.
	sprite.position = Vector2(0, collider_h * 0.5 + (frame.y * 0.5 - art.end.y) * s)
	_sprite_mat = Sprites.status_material()
	sprite.material = _sprite_mat
	add_child(sprite)
	sprite.play("idle")

func face(dir: int) -> void:
	if dir != 0:
		facing = signi(dir)
	if sprite != null:
		sprite.flip_h = facing < 0

## Plays `name`, or freezes on `frame` of it when `frame` is not negative —
## the pack has no jump art, so airborne poses are held run frames.
func play_anim(name: String, speed: float = 1.0, frame: int = -1) -> void:
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
func _update_sprite_status() -> void:
	if _sprite_mat == null:
		return
	var t := sprite_tint
	if chill_time > 0.0:
		t = t.lerp(Color(0.45, 0.8, 1.0), 0.5)
	if burn_time > 0.0:
		t = t.lerp(Color(1.0, 0.45, 0.2), 0.4)
	_sprite_mat.set_shader_parameter("tint", t)
	_sprite_mat.set_shader_parameter("flash", clampf(flash, 0.0, 1.0))
