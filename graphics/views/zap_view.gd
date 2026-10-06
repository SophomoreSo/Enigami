class_name ZapView
extends Node2D

## A beam: a white-hot core inside a glow in the payload's colour, and a flare
## where it landed. It has already struck by the time it is first drawn, so
## this is the afterimage of a strike, thinning out over a few frames, and not
## a thing travelling.
##
## Where it landed is lit for as long: a lamp at the flare, going out with it.

## How far the flare's light reaches in world units, how bright it is as it
## lands, and how much of it hangs in the air.
const FLARE_REACH := 140.0
const FLARE := 2.2
const FLARE_AIR := 0.12

var beam: Zap
var lamp: Lamp

func _ready() -> void:
	beam = get_parent() as Zap
	z_index = 47
	material = Lighting.glow()
	lamp = Lamp.of(Style.NEUTRAL_ATTACK, FLARE_REACH, 0.0)
	lamp.volume = FLARE_AIR
	add_child(lamp)

func _process(_delta: float) -> void:
	if beam != null and is_instance_valid(beam):
		lamp.position = beam.to
		lamp.color = Style.element_color(beam.payload)
		lamp.energy = FLARE * clampf(beam.life / beam.max_life, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	if beam == null or not is_instance_valid(beam):
		return
	var t := clampf(beam.life / beam.max_life, 0.0, 1.0)
	var c := Style.element_color(beam.payload)
	var width := beam.half_width * 2.0
	# The glow fades and the core thins inside it, so the beam reads as going
	# out rather than being switched off.
	var glow := c
	glow.a = 0.55 * t
	draw_line(beam.from, beam.to, glow, width * (0.6 + 0.4 * t))
	draw_line(beam.from, beam.to, Color(1, 1, 1, 0.95 * t), maxf(width * 0.35 * t, 1.0))
	# Where it landed: a wall, the cursor, or the last thing it struck.
	var flare := c
	flare.a = 0.8 * t
	draw_circle(beam.to, width * (0.5 + 0.5 * t), flare)
	draw_circle(beam.to, width * 0.35 * t, Color(1, 1, 1, 0.9 * t))
