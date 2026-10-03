class_name LooseRockView
extends Node2D

## The rock, lying where it came down (`LooseRock`), drawn so it is found again:
## the rock itself, and over it a small mark in the weapon's own colour that
## bobs and breathes. It is the one weapon that can be left behind in a room,
## and it says where it is from across the room — quietly, since it is not the
## kit a death left (`LostKitView`), which is meant to be seen from the door.
##
## Still coming down it turns over as it bounces, a quarter at a time, the way
## it flew; lying still it lies the right way up.

const TUMBLE := 14.0
## How far over the rock the mark stands, and how far it bobs: whole pixels of
## the world's picture, which is drawn at half the screen's.
const MARK_LIFT := 18.0
const MARK_BOB := 2.0
## The mark, a pixel of the picture a letter.
const MARK := [
	"##...##",
	".##.##.",
	"..###..",
	"...#...",
]

var rock: LooseRock
var _t: float = 0.0
var _spin: float = 0.0

func _ready() -> void:
	rock = get_parent() as LooseRock
	# Over the room and what grows in it, under whoever walks it.
	z_index = 35

func _process(delta: float) -> void:
	if rock == null or not is_instance_valid(rock):
		return
	_t += delta
	if rock.resting:
		_spin = 0.0
	elif absf(rock.velocity.x) > 20.0:
		_spin += delta * TUMBLE * signf(rock.velocity.x)
	queue_redraw()

func _draw() -> void:
	if rock == null or not is_instance_valid(rock):
		return
	var tex := Sprites.texture(Style.weapon_art(rock.weapon))
	if tex != null:
		var turn := roundf(_spin / (PI * 0.5)) * PI * 0.5
		draw_set_transform(Vector2.ZERO, turn, Vector2.ONE * Sprites.PIXEL_SCALE)
		draw_texture(tex, -(tex.get_size() * 0.5).floor())
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if rock.resting:
		_draw_mark()

## A chevron pointing down at the rock, in the weapon's colour, bobbing a pixel
## at a time and breathing.
func _draw_mark() -> void:
	var c := Style.weapon_color(rock.weapon)
	c.a = 0.75 + 0.25 * sin(_t * 3.0)
	var px := Sprites.PIXEL_SCALE
	var bob := roundf(sin(_t * 2.4) * MARK_BOB) * px
	var top := -LooseRock.RADIUS - MARK_LIFT + bob
	var left := -floorf(float(String(MARK[0]).length()) * 0.5) * px
	for y in MARK.size():
		var row := String(MARK[y])
		for x in row.length():
			if row[x] == "#":
				draw_rect(Rect2(left + x * px, top + y * px, px, px), c)
