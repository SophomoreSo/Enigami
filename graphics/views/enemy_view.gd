class_name EnemyView
extends ActorView

## A monster: the atlas character its kind wears, plus the read-outs layered
## over it — a ring for a modifier, a second for an elite, a health strip, and
## the dot that says it has seen you.

## AI kinds that leave the ground, and so need an airborne pose.
const AIRBORNE_AI := ["runner", "jumper", "boss"]

var enemy: Enemy
var _phase: int = 1

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
		draw_arc(Vector2.ZERO, s + 10.0, 0, TAU, 28, Style.ELITE_RING, 1.5)

	draw_health_bar(s * 2.4, -s - 12.0)
	if enemy.aggro:
		draw_circle(Vector2(0, -s - 20.0), 2.5, Style.AGGRO_DOT)
