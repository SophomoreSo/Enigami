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
## Whether this is one closed shape that a lamp can be inside — a body, not a
## room's rock. A lamp inside one is in front of it, and takes no shadow from
## it: a body on fire lights the room round it.
var body := false

var _shape := PackedVector2Array()

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
	var ends := PackedVector2Array()
	var facings := PackedVector2Array()
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var along := (b - a).normalized()
		ends.append(a)
		ends.append(b)
		facings.append(Vector2(along.y, -along.x))
	_build(ends, facings)
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

func _build(ends: PackedVector2Array, facings: PackedVector2Array) -> void:
	@warning_ignore("integer_division")
	var count := ends.size() / 2
	if count == 0:
		mesh = null
		bounds = Rect2()
		return
	var points := PackedVector2Array()
	var faces := PackedVector2Array()
	var goes := PackedColorArray()
	var order := PackedInt32Array()
	bounds = Rect2(ends[0], Vector2.ZERO)
	for i in count:
		var a := ends[i * 2]
		var b := ends[i * 2 + 1]
		var facing := facings[i]
		var first := points.size()
		points.append_array([a, b, b, a])
		faces.append_array([facing, facing, facing, facing])
		goes.append_array([Color(0, 0, 0), Color(0, 0, 0), Color(1, 0, 0), Color(1, 0, 0)])
		order.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
		bounds = bounds.expand(a).expand(b)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = faces
	arrays[Mesh.ARRAY_COLOR] = goes
	arrays[Mesh.ARRAY_INDEX] = order
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
