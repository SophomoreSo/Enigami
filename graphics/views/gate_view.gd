class_name GateView
extends Node2D

## A gate (`Gate`), drawn: a doorway standing on the floor, framed in the
## room's own stone and edged in the doorways' light blue, dark inside, and in
## the dark a pair of chevrons pointing the way it leads — up or down — that bob
## that way. Lit from inside while the player is at it, with the interact key
## over it: the same `PixelDraw.key_cap` a treasure box and someone to talk to
## show.

## The gate stands on a cell's centre, which is half a cell above the floor.
const FLOOR := 16.0
## The dark it opens on, and the stone round it.
const OPEN_W := 40.0
const OPEN_H := 76.0
const PILLAR := 6.0
const LINTEL := 8.0
## How far a chevron's arms reach out and back from its point.
const ARM := 10.0
## Space between the top of the gate and the bottom of the key.
const PROMPT_GAP := 6.0
const INSIDE := Color(0.03, 0.04, 0.06)

var gate: Gate
var _t: float = 0.0
## How lit it is: 0 with nobody at it, 1 with the player at it.
var _lit: float = 0.0
## The key sits on its own layer, the way the treasure box's does: drawn at the
## screen's resolution in PixelDraw's blocks, never covered by whoever stands
## at the gate.
var _prompt_layer: CanvasLayer
var _prompt: Node2D
var _px: PixelDraw

func _ready() -> void:
	gate = get_parent() as Gate
	# Part of the room, behind everything that stands in it or walks past it.
	z_index = 20
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.layer = PixelCamera.LAYER + 1
	_prompt_layer.follow_viewport_enabled = true
	add_child(_prompt_layer)
	_prompt = Node2D.new()
	_prompt.draw.connect(_draw_prompt)
	_prompt_layer.add_child(_prompt)
	_px = PixelDraw.new(_prompt)

func _process(delta: float) -> void:
	_t += delta
	if gate != null and is_instance_valid(gate):
		_lit = move_toward(_lit, 1.0 if gate.offered() else 0.0, delta * 6.0)
		# On whole world pixels, the grid the gate is drawn on, so the key's
		# blocks line up with it.
		_prompt.position = (global_position / PixelCamera.SCALE).round() * PixelCamera.SCALE
	queue_redraw()
	_prompt.queue_redraw()

func _draw() -> void:
	if gate == null or not is_instance_valid(gate):
		return
	var px := float(PixelCamera.SCALE)
	var room := gate.get_parent() as Room
	var stone := Style.region_tint(int(room.data.get("region", 0))) if room != null \
		else Color(0.3, 0.32, 0.38)
	var top := FLOOR - OPEN_H
	var opening := Rect2(-OPEN_W * 0.5, top, OPEN_W, OPEN_H)
	# The dark inside, lit from deep in it while the player is at it.
	draw_rect(opening, INSIDE)
	var glow := Style.DOOR_FILL
	glow.a = 0.16 + 0.22 * _lit + 0.05 * sin(_t * 3.0)
	draw_rect(opening, glow)
	# The way it leads, two chevrons one over the other, bobbing that way.
	var way := -1.0 if gate.dir == Components.N else 1.0
	var bob := roundf(absf(sin(_t * 3.5)) * 3.0 / px) * px * way
	var mid := Vector2(0.0, top + OPEN_H * 0.45 + bob)
	var ink := Style.DOOR_EDGE.lerp(Color.WHITE, 0.4 * _lit)
	ink.a = 1.0
	for k in 2:
		var point := mid + Vector2(0.0, way * (6.0 - 10.0 * float(k)))
		draw_polyline(PackedVector2Array([point + Vector2(-ARM, -way * ARM), point,
			point + Vector2(ARM, -way * ARM)]), ink, px * 2.0)
	# The stone round it: a pillar either side and a lintel over them.
	var pillar_h := OPEN_H + LINTEL
	for x in [-OPEN_W * 0.5 - PILLAR, OPEN_W * 0.5]:
		draw_rect(Rect2(x, FLOOR - pillar_h, PILLAR, pillar_h), stone)
	draw_rect(Rect2(-OPEN_W * 0.5 - PILLAR - px, FLOOR - pillar_h - px,
		OPEN_W + PILLAR * 2.0 + px * 2.0, LINTEL + px), stone.lightened(0.25))
	# Edged like a doorway, so it reads as a way through.
	var edge := Style.DOOR_EDGE
	edge.a = lerpf(edge.a, 1.0, _lit)
	draw_rect(opening, edge, false, px)

## The interact key over the gate while the player is at it, pressing itself.
func _draw_prompt() -> void:
	if gate == null or not is_instance_valid(gate) or not gate.offered():
		return
	var foot := FLOOR - OPEN_H - LINTEL - float(PixelCamera.SCALE) - PROMPT_GAP
	_px.key_cap(Vector2(0.0, foot), Controls.short_label_for("interact"), _t)
