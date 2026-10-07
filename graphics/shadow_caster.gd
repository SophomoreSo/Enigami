class_name ShadowCaster
extends Node2D

## Something that stands in a lamp's light and throws a shadow: the edges of
## it, each knowing which way it faces. It draws nothing itself. Whatever is
## lighting the picture (`Lighting`) asks which casters there are every frame,
## and has each lamp that throws shadows draw the edges near it its own way
## (`shadow.gdshader`): an edge turned from the lamp is drawn out away from it,
## and that is the edge's shadow.
##
## The edges are kept as a mesh, made once and drawn for every lamp — the
## video's shadow caster, and Unity's `ShadowUtility` it comes from: an edge is
## four corners, two that stay on it and two that go, with the way it faces
## kept where a picture's corner would keep its place in the texture. Nothing
## here is worked out again when a lamp moves, or when the caster does: where
## it is is the node's own transform.
##
## A caster is put wherever the thing that throws the shadow is, by its view:
## a room's rock is one (`RoomView`), and a body another (`ActorView`).

## The group every caster in the tree is in, which is how it is found.
const GROUP := &"shadow_casters"

## The edges, as `shadow.gdshader` draws them, or null with none.
var mesh: ArrayMesh = null
## What they cover, in the caster's own space.
var bounds := Rect2()
## Whether this is one closed shape that a light can be inside — a body, not
## a room's rock. A light inside one that is the body's own takes no shadow
## from it: a body on fire lights the room round it. Any other light inside
## one still has the body throw a shadow (`beyond`).
var body := false

var _shape := PackedVector2Array()

## How far past a light inside a body what of the body throws its shadow
## begins, in world units: off the light, so no edge of it runs through it.
const HAIR := 0.5

func _enter_tree() -> void:
	add_to_group(GROUP)

## Loose edges: `ends` two points to an edge, and `facings` the way each
## faces — out of the thing it is an edge of.
func edges(ends: PackedVector2Array, facings: PackedVector2Array) -> void:
	body = false
	_shape = PackedVector2Array()
	_build(ends, facings)

## One closed shape with no dents in it, its corners in the order a clock's
## hand passes them as it is drawn: a body.
func outline(points: PackedVector2Array) -> void:
	var edged := _outlined(points)
	_build(edged[0], edged[1])
	body = true
	_shape = points

## A box.
func box(rect: Rect2) -> void:
	outline(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)]))

## What it covers, in the world.
func covers() -> Rect2:
	return global_transform * bounds

## Whether the world point `at` is inside it, for a body.
func holds(at: Vector2) -> bool:
	return body and Geometry2D.is_point_in_polygon(to_local(at), _shape)

## What of a body throws its shadow in a light at `at`, inside it, as edges in
## the world: the light is taken to stand at the body's edge nearest to it,
## so the body goes on throwing the shadow it threw as the light came in over
## that edge — all of it from the light on, away from that edge. As the light
## passes the body's middle it goes over to the far edge, and the shadow over
## to the other side, as it does going past anything thin. Null for a light
## that is not inside it.
func beyond(at: Vector2) -> ArrayMesh:
	if not holds(at):
		return null
	var shape: PackedVector2Array = global_transform * _shape
	var middle := Vector2.ZERO
	for p in shape:
		middle += p
	middle /= shape.size()
	var nearest := 0
	var least := INF
	for i in shape.size():
		var off := at.distance_to(Geometry2D.get_closest_point_to_segment(at, shape[i], shape[(i + 1) % shape.size()]))
		if off < least:
			least = off
			nearest = i
	var a := shape[nearest]
	var b := shape[(nearest + 1) % shape.size()]
	# The way out of the body over that edge.
	var out := (b - a).orthogonal().normalized()
	if out.dot((a + b) * 0.5 - middle) < 0.0:
		out = -out
	# The body behind a line through the light along that edge, a hair the far
	# side of the light.
	var cut := at - out * HAIR
	var kept := PackedVector2Array()
	for i in shape.size():
		var p := shape[i]
		var q := shape[(i + 1) % shape.size()]
		var dp := (p - cut).dot(out)
		var dq := (q - cut).dot(out)
		if dp <= 0.0:
			_add_corner(kept, p)
		if (dp <= 0.0) != (dq <= 0.0):
			_add_corner(kept, p.lerp(q, dp / (dp - dq)))
	if kept.size() > 1 and kept[0].distance_to(kept[kept.size() - 1]) < 0.001:
		kept.remove_at(kept.size() - 1)
	if kept.size() < 3:
		return null
	# In the order a clock's hand goes, whichever way the body was turned.
	var turning := 0.0
	for i in kept.size():
		turning += kept[i].cross(kept[(i + 1) % kept.size()])
	if turning < 0.0:
		kept.reverse()
	var edged := _outlined(kept)
	return _strips(edged[0], edged[1])

## `corner`, after the last of `corners`, unless it is the same corner again.
static func _add_corner(corners: PackedVector2Array, corner: Vector2) -> void:
	if corners.is_empty() or corners[corners.size() - 1].distance_to(corner) >= 0.001:
		corners.append(corner)

## One closed shape's edges, its corners in the order a clock's hand passes
## them: the two ends of each, and the way each faces, out of the shape.
static func _outlined(points: PackedVector2Array) -> Array:
	var ends := PackedVector2Array()
	var facings := PackedVector2Array()
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var along := (b - a).normalized()
		ends.append(a)
		ends.append(b)
		facings.append(Vector2(along.y, -along.x))
	return [ends, facings]

func _build(ends: PackedVector2Array, facings: PackedVector2Array) -> void:
	mesh = _strips(ends, facings)
	bounds = Rect2(ends[0], Vector2.ZERO) if not ends.is_empty() else Rect2()
	for end in ends:
		bounds = bounds.expand(end)

## The edges as `shadow.gdshader` draws them, or null with none: each four
## corners, two that stay on it and two that go.
static func _strips(ends: PackedVector2Array, facings: PackedVector2Array) -> ArrayMesh:
	@warning_ignore("integer_division")
	var count := ends.size() / 2
	if count == 0:
		return null
	var points := PackedVector2Array()
	var faces := PackedVector2Array()
	var goes := PackedColorArray()
	var order := PackedInt32Array()
	for i in count:
		var a := ends[i * 2]
		var b := ends[i * 2 + 1]
		var facing := facings[i]
		var first := points.size()
		points.append_array([a, b, b, a])
		faces.append_array([facing, facing, facing, facing])
		goes.append_array([Color(0, 0, 0), Color(0, 0, 0), Color(1, 0, 0), Color(1, 0, 0)])
		order.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = faces
	arrays[Mesh.ARRAY_COLOR] = goes
	arrays[Mesh.ARRAY_INDEX] = order
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return made
