class_name EnemyView
extends ActorView

## A monster: the atlas character its kind wears, plus the read-outs layered
## over it — a ring for a modifier, a second for an elite, a health strip, and
## the dot that says it has seen you. One the player is in wears a ring of its
## own with the time left on it, and — once it has taken it — their weapon.

## AI kinds that leave the ground, and so need an airborne pose.
const AIRBORNE_AI := ["runner", "jumper", "boss"]

var enemy: Enemy
var _phase: int = 1
## The player's weapon in a possessed monster's hands, held the way the player
## holds it (`PlayerView`): built the first time it is taken.
var _held: Sprite2D = null
var _held_art: String = ""

func _configure() -> void:
	enemy = actor as Enemy
	art = Style.monster_art(enemy.kind)
	tint = Style.monster_tint(enemy.kind)
	z_index = 45

func _animate() -> void:
	if enemy.phase != _phase:
		_phase = enemy.phase
		tint = Style.BOSS_PHASE2_TINT
	var ai := enemy.ai()
	if AIRBORNE_AI.has(ai) and not enemy.is_on_floor():
		# No jump art in the pack: hold a stride instead of running on air.
		play("run", 1.0, 2 if enemy.velocity.y < 0.0 else 0)
	elif absf(enemy.velocity.x) > 12.0 or (ai == "flyer" and enemy.velocity.length() > 24.0):
		play("run", clampf(absf(enemy.velocity.x) / 110.0, 0.7, 1.8))
	else:
		play("idle")
	_update_held()

## The player's weapon, while the player in this monster has taken it — or the
## rock, once it has picked it up.
func _update_held() -> void:
	var armed := enemy.piloted() and enemy.pilot.weapon_hands() == enemy
	if not armed:
		if _held != null:
			_held.visible = false
		return
	if _held == null:
		_held = Sprite2D.new()
		_held.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_held.centered = false
		_held.scale = Vector2.ONE * Sprites.PIXEL_SCALE
		_held.z_index = 1
		add_child(_held)
	var weapon := enemy.pilot.weapon_id
	var art_id := Style.weapon_art(weapon)
	if _held_art != art_id:
		_held_art = art_id
		var tex := Sprites.texture(art_id)
		_held.texture = tex
		if tex != null:
			var grip := Style.weapon_grip(weapon, PlayerView.WEAPON_GRIP)
			_held.offset = Vector2(-tex.region.size.x * 0.5, -tex.region.size.y * grip)
	var aim: Vector2 = enemy.pilot.aim
	_held.visible = true
	_held.position = aim * (enemy.size * 0.6 + PlayerView.WEAPON_HAND * 0.5)
	_held.rotation = 0.0 if Style.weapon_upright(weapon) else aim.angle() + PI * 0.5

## The wind-up before a leap has to read before the leap lands.
func status_flash() -> float:
	if enemy.telegraph <= 0.0:
		return flash
	return maxf(flash, clampf(enemy.telegraph / 0.2, 0.0, 1.0) * 0.75)

func _draw() -> void:
	if not _started:
		return
	var s := enemy.size
	if enemy.modifier != "":
		draw_arc(Vector2.ZERO, s + 6.0, 0, TAU, 24, Style.modifier_color(enemy.modifier), 2.0)
	if enemy.def.get("elite", false) or enemy.def.get("boss", false):
		draw_arc(Vector2.ZERO, s + 10.0, 0, TAU, 28, Style.ELITE_RING, 2.0)

	draw_health_bar(s * 2.4, -s - 12.0)
	if enemy.piloted():
		# The player is in it: a ring, and round it the time left, running out
		# the way a dash's recovery fills.
		var p := enemy.pilot
		draw_arc(Vector2.ZERO, s + 8.0, 0, TAU, 28, Color(Style.POSSESS_COLOR, 0.35), 2.0)
		var left := clampf(p.possess_left / maxf(p.possess_for, 0.01), 0.0, 1.0)
		draw_arc(Vector2.ZERO, s + 8.0, -PI * 0.5, -PI * 0.5 + TAU * left, 28, Style.POSSESS_COLOR, 2.0)
	elif enemy.aggro:
		draw_circle(Vector2(0, -s - 20.0), 2.5, Style.AGGRO_DOT)
