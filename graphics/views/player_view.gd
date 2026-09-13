class_name PlayerView
extends ActorView

## The player: the knight, the weapon they are pointing, the ghost a dash
## leaves behind, the charge bar over their head, and the rings that report
## guard and dash recovery.

## The weapon is a separate tile so it can swing to the aim direction while the
## body keeps running. Every weapon tile in the atlas points up.
const WEAPON_GRIP := 0.82  ## share of the tile that hangs past the hand
const WEAPON_HAND := 10.0  ## how far out of the body the hand holds it

const TRAIL_LIFE := 0.22
const CHARGE_COLOR := Color(0.78, 0.68, 1.0)
const PARRY_COLOR := Color(1, 0.95, 0.6)
const DASH_COLOR := Color(0.7, 0.9, 1.0)

## The charge read-out rides above the head: clear of the ring at its widest,
## and high enough that the body never grows into it.
const CHARGE_BAR := Vector2(40.0, 5.0)
const CHARGE_BAR_Y := -46.0

var player: Player
var weapon_sprite: Sprite2D
var _weapon_art: String = ""
var _trail: Array = []
var _spark: float = 0.0

func _configure() -> void:
	player = actor as Player
	art = Style.PLAYER_ART
	z_index = 50

func _build_sprite() -> void:
	super._build_sprite()
	weapon_sprite = Sprite2D.new()
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.centered = false
	weapon_sprite.scale = Vector2.ONE * Sprites.PIXEL_SCALE
	weapon_sprite.z_index = 1
	add_child(weapon_sprite)

func _animate() -> void:
	if flash > 0.55:
		# The knight ships a recoil pose; hold it for the front of the flash.
		play("hit", 1.0, 0)
	elif player.is_dashing():
		play("run", 2.2)
	elif not player.is_on_floor():
		# The pack has no jump art: hold the stride that reads as rising or
		# falling instead of cycling a run cycle in mid-air.
		play("run", 1.0, 2 if player.velocity.y < 0.0 else 0)
	elif absf(player.velocity.x) > 12.0:
		play("run", clampf(absf(player.velocity.x) / Player.RUN_SPEED, 0.65, 1.6))
	else:
		play("idle")
	_update_weapon()

func _update_weapon() -> void:
	if weapon_sprite == null:
		return
	if _weapon_art != Style.weapon_art(player.weapon_id):
		_weapon_art = Style.weapon_art(player.weapon_id)
		var tex := Sprites.texture(_weapon_art)
		weapon_sprite.texture = tex
		if tex != null:
			# Pivot at the grip, so aiming rotates the blade around the hand.
			weapon_sprite.offset = Vector2(-tex.region.size.x * 0.5, -tex.region.size.y * WEAPON_GRIP)
	# I-frames blink the whole rig, weapon included.
	var lit := player.invuln <= 0.0 or int(player.invuln * 24.0) % 2 == 0
	sprite.self_modulate.a = 1.0 if lit else 0.35
	weapon_sprite.self_modulate.a = sprite.self_modulate.a
	weapon_sprite.position = player.aim * WEAPON_HAND
	weapon_sprite.rotation = player.aim.angle() + PI * 0.5

func _process(delta: float) -> void:
	super._process(delta)
	if not _started:
		return
	_update_trail(delta)
	_charge_sparks(delta)

func _update_trail(delta: float) -> void:
	if player.is_dashing():
		_trail.append({"p": player.global_position, "t": TRAIL_LIFE})
	for t in _trail:
		t["t"] -= delta
	_trail = _trail.filter(func(t: Dictionary) -> bool: return t["t"] > 0.0)

## Charging is a thing happening to the character, not just a bar moving in the
## corner: it draws a tightening ring and pulls sparks inward, so holding the
## button reads as doing something even with the HUD out of view.
func _charge_sparks(delta: float) -> void:
	if not player.charging:
		_spark = 0.0
		return
	_spark -= delta
	if _spark > 0.0:
		return
	_spark = 0.09
	var a := randf() * TAU
	var r := 34.0 + randf() * 16.0
	Fx.burst(player.global_position + Vector2(cos(a), sin(a)) * r, CHARGE_COLOR, 1, 28.0)

func _draw() -> void:
	if not _started:
		return
	for t in _trail:
		var a: float = clampf(t["t"] / TRAIL_LIFE, 0.0, 1.0)
		draw_circle(to_local(t["p"]), 10.0 * a, Color(0.6, 0.85, 1.0, a * 0.35))

	# The sprite is the body; these are the state read-outs drawn over it.
	if player.charge > 0.0:
		var ct := player.charge_ratio()
		draw_arc(Vector2.ZERO, 34.0 - 10.0 * ct, 0, TAU, 28,
			Color(CHARGE_COLOR.r, CHARGE_COLOR.g, CHARGE_COLOR.b, 0.30 + 0.55 * ct), 2.0 + 2.0 * ct)
		_draw_charge_bar(ct)
	if player.parry_time > 0.0:
		draw_arc(Vector2.ZERO, 24.0, 0, TAU, 24, Color(PARRY_COLOR.r, PARRY_COLOR.g, PARRY_COLOR.b, 0.9), 2.5)
	var recovery := player.dash_recovery()
	if recovery < 1.0:
		draw_arc(Vector2(0, 22), 6.0, -PI * 0.5, -PI * 0.5 + TAU * recovery, 16,
			Color(DASH_COLOR.r, DASH_COLOR.g, DASH_COLOR.b, 0.7), 2.0)

## How much of a charge there is, over the head of whoever is paying for it.
## Holding the cast button is a decision taken in the middle of a fight, with
## the eye on the character and something usually walking towards them — so
## the progress is drawn where the eye already is rather than in the corner of
## the screen. The ring says a charge is happening; this says how far it has
## got.
func _draw_charge_bar(ct: float) -> void:
	var bar := Rect2(-CHARGE_BAR.x * 0.5, CHARGE_BAR_Y, CHARGE_BAR.x, CHARGE_BAR.y)
	draw_rect(bar, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ct, bar.size.y)), CHARGE_COLOR)
	draw_rect(bar, Color(0.5, 0.6, 0.7, 0.8), false, 1.0)