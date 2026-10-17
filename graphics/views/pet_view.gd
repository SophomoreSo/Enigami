class_name PetView
extends Node2D

## A pet (`Pet`): a small round thing with two eyes and a pair of ears, in the
## summon colour, glowing a little, facing the way its summoner does. It blinks.
## An OFFENSIVE one wears a scowl, and reddens as it goes for an enemy.

const BODY := Color(0.62, 0.86, 0.42)
const DARK := Color(0.10, 0.12, 0.10)
const BLINK_EVERY := 3.0
const BLINK_FOR := 0.12

var pet: Pet
var _t := 0.0

func _ready() -> void:
	pet = get_parent() as Pet
	z_index = 40
	material = Lighting.glow()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if pet == null or not is_instance_valid(pet):
		return
	var f := float(pet.facing)
	# Ears, then the body over them.
	draw_rect(Rect2(Vector2(-8, -12), Vector2(4, 6)), BODY.darkened(0.15))
	draw_rect(Rect2(Vector2(4, -12), Vector2(4, 6)), BODY.darkened(0.15))
	draw_circle(Vector2.ZERO, 10.0, BODY)
	draw_circle(Vector2(-3.0 * f, 4.0), 6.0, BODY.lightened(0.15))
	# Eyes, toward the way it faces; shut for a moment every few seconds.
	var shut := fmod(_t, BLINK_EVERY) < BLINK_FOR
	for x: float in [1.0, 5.0]:
		var at := Vector2(x * f - 2.0 * f, -2.0)
		if shut:
			draw_rect(Rect2(at - Vector2(2, 0), Vector2(4, 2)), DARK)
		else:
			draw_rect(Rect2(at - Vector2(1, 2), Vector2(2, 4)), DARK)
		# The scowl: a brow over each eye, slanting in.
		if pet.offensive > 0:
			var inward := 1.0 if x > 3.0 else -1.0
			draw_line(at + Vector2(-2.0, -5.0 - inward), at + Vector2(2.0, -5.0 + inward), DARK, 2.0)
	if pet.target != null:
		draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.35, 0.3, 0.25))
