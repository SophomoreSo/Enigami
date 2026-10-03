class_name TreasureBoxView
extends Node2D

## The box a room's loot is kept in: a wooden chest with a gold band, glowing
## while there is something in it, and standing open and dark once it is empty.
## Over it, while the player is in reach of a shut one, the key that opens it.

var box: TreasureBox
var _t: float = 0.0
## How far the lid has swung back, 0 shut to 1 open, so opening it is seen.
var _lid: float = 0.0

## The box sits on a cell's centre, which is half a cell above the floor.
const FLOOR := 16.0
const W := 26.0
const H := 16.0
const LID_H := 7.0

func _ready() -> void:
	box = get_parent() as TreasureBox
	# With the loot, under the kit a death left: a box is found, a kit is
	# looked for.
	z_index = 35
	if box != null and box.is_open:
		_lid = 1.0

func _process(delta: float) -> void:
	_t += delta
	if box != null and is_instance_valid(box):
		_lid = move_toward(_lid, 1.0 if box.is_open else 0.0, delta * 5.0)
	queue_redraw()

func _draw() -> void:
	if box == null or not is_instance_valid(box):
		return
	var top := FLOOR - H
	var body := Rect2(-W * 0.5, top, W, H)
	if not box.is_open:
		var glow := Style.TREASURE_GLOW
		glow.a = 0.20 + 0.10 * sin(_t * 4.0)
		draw_circle(Vector2(0, top + 2.0), 20.0, glow)
	draw_rect(body, Style.TREASURE_WOOD)
	draw_rect(Rect2(-W * 0.5, top + 4.0, W, 3.0), Style.TREASURE_BAND)
	draw_rect(Rect2(-2.0, top + 3.0, 4.0, 5.0), Style.TREASURE_BAND)
	draw_rect(body, Style.TREASURE_EDGE, false, 2.0)
	_draw_lid(top)
	if box.offered():
		var bob := sin(_t * 4.0) * 1.5
		PixelCamera.draw_text(self, Vector2(0, top - 40.0 + bob),
			Loc.t("hud.box.open", [Controls.short_label_for("interact")]),
			Style.TREASURE_PROMPT, Color(0, 0, 0, 0.8))

## Shut, the lid is a slab on top of the box. Open, it has swung back and up:
## what shows is its dark inner face standing over the box, narrowing as it
## leans away, and the black of the inside between the two.
func _draw_lid(top: float) -> void:
	var back := -W * 0.5 - 1.0
	var front := W * 0.5 + 1.0
	var rise := lerpf(LID_H, LID_H + 7.0, _lid)
	var inset := lerpf(0.0, 3.0, _lid)
	var face := Style.TREASURE_WOOD.lerp(Style.TREASURE_INSIDE, 0.45 * _lid)
	var pts := PackedVector2Array([
		Vector2(back, top), Vector2(front, top),
		Vector2(front - inset, top - rise), Vector2(back + inset, top - rise),
	])
	draw_colored_polygon(pts, face)
	# The band runs along the lid's front edge: low on a shut lid, along the top
	# of one that stands open.
	var band_y := lerpf(top - LID_H * 0.5, top - rise + 1.0, _lid)
	draw_rect(Rect2(back + inset, band_y - 1.0, front - back - inset * 2.0, 2.0), Style.TREASURE_BAND)
	pts.append(pts[0])
	draw_polyline(pts, Style.TREASURE_EDGE, 2.0)
	if _lid > 0.5:
		draw_rect(Rect2(-W * 0.5 + 2.0, top, W - 4.0, 3.0), Style.TREASURE_INSIDE)
