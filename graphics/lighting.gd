class_name Lighting
extends Node

## The light the picture is shown in: the passes the world is drawn through
## once it has been drawn, after aarthificial's deferred lights ("Deferred
## Lights - Pixel Renderer Devlog #1",
## https://www.youtube.com/watch?v=R6vQ9VmMz2w). Nothing in the world is lit
## as it is drawn. The world is drawn first, unlit, into a g-buffer of two
## textures — its colours, and the way every pixel of it faces — and the
## light is worked out afterwards, once for the whole picture, a lamp at a
## time:
##
##   colours   the world as it always was drawn: the `PixelCamera`'s own
##             buffer, which this is handed.
##   normals   the same world drawn a second time, for how it faces.
##   shadows   for each lamp that throws them, where its light does not
##             reach.
##   light     the picture that is shown: the colours times the light there
##             is with no lamp lit, and then every lamp added to it — a mesh
##             over what it can reach, reading the first two under each of
##             its pixels and leaving out what the third marks.
##
## A lamp is a `Lamp` and what throws a shadow a `ShadowCaster`, both nodes
## put wherever the thing itself is, and both asked for here every frame the
## way the velocity buffer asks what is moving. All of it is on the pixel
## camera's grid, a pixel of every buffer to a pixel of the picture, so light
## falls in the same pixels the world is drawn in.
##
## Where the video's renderer does what a canvas cannot, the same picture is
## reached another way:
##
##   * It fills both textures of the g-buffer in one pass. A canvas item draws
##     into one target, so the normals are a second viewport over the same
##     world. Most of what is drawn says nothing in it and is flat: lit alike
##     from anywhere. What faces some way says so — a sprite through its
##     shader, which works the normals out from its own edge
##     (`lighting.gdshaderinc`), and anything drawn in code by drawing them:
##     a twin of itself on NORMAL_LAYER, which only that viewport sees,
##     painted in `faces`'s colours (`RoomView` does its rock's this way).
##   * It marks shadows in the stencil buffer. A canvas cannot, so they are
##     marked in pictures of their own, a colour of one to a lamp
##     (`shadow.gdshader`). There are MASKS of those and three colours in
##     each, which is how many lamps can throw shadows at once.
##
## And one thing the video's picture has no place for: what gives its own
## light. A bolt in a dark room is not dark. Whatever wears `glow()` is left
## as it was drawn, by the lamps and by the dark alike.
##
## With no lamp on the screen and the room as light as it ever was there is
## nothing to work out, and nothing is: the camera shows the colours as they
## were drawn, and the world is drawn once. So a screen nobody has lit costs
## what it did before any of this.
##
## And a lit one little more, as long as the back of the picture stays out of
## the normals: a room's tile field is most of what a frame costs to draw, it
## is flat, and the normals start out flat — so what is on BACKDROP_LAYER is
## drawn into the colours and not a second time for nothing.
##
## Float buffers, as the velocity buffer's are, and for its reasons: only the
## compatibility renderer keeps what is drawn into one as it was drawn.

## The world units to a pixel of every buffer: the pixel camera's.
const S := PixelCamera.SCALE
## What is drawn on this render layer is drawn into the normals and nowhere
## else: the twin of something drawn in code, saying how it faces.
const NORMAL_LAYER := 1 << 18
## What is drawn on this render layer, and no other, is the back of the
## picture: flat, behind everything that faces any way or gives any light,
## and a great deal of it — a room's tile field, a look's painted depths. It
## is drawn into the colours and left out of the normals.
const BACKDROP_LAYER := 1 << 17
## How many times over a normal is written, so that a colour drawn into the
## same buffer is nothing beside it. `lighting.gdshaderinc` has the same
## number.
const RELIEF := 256.0
## The pictures shadows are marked in, and the lamps to each: one a colour.
const MASKS := 4
const PER_MASK := 3
## How many lamps can throw shadows at once.
const SHADOWS := MASKS * PER_MASK
## How far past a lamp's own reach an edge's shadow is thrown, in reaches:
## far enough that the strip's far end is never inside the lamp's square.
const THROW := 64.0
## How near a lamp a surface has to be, in world units, before the way it
## faces starts to count for less: right under one, the way to it is any way.
const CLOSE := 12.0

const LIGHT := preload("res://graphics/assets/shaders/light.gdshader")
const AMBIENT := preload("res://graphics/assets/shaders/ambient.gdshader")
const SHADOW := preload("res://graphics/assets/shaders/shadow.gdshader")
const GLOW := preload("res://graphics/assets/shaders/glow.gdshader")

## The lightings up, newest last. A screen swap brings the new one up before
## the old one goes; the newest is the one the global names.
static var _up: Array[Lighting] = []
static var _glow: ShaderMaterial = null

## The light there is with no lamp lit, the video's global light: every
## colour the world draws is shown times this. White is the room as it was
## always drawn; anything darker, and the lamps are what it is seen by.
var ambient := Color.WHITE
## The world position of every buffer's first pixel, and their size in
## pixels: what the pixel camera is drawing.
var origin := Vector2.ZERO
var size := Vector2i.ZERO
## The world's colours: the pixel camera's own buffer, handed over before
## this is put in the tree.
var colour: SubViewport
## How many lamps reach the screen this frame, and how many of them throw
## shadows.
var lamps_lit := 0
var lamps_shadowed := 0

var _normals: SubViewport
var _masks: Array[SubViewport] = []
var _lit: SubViewport
var _all: ShaderMaterial
var _beams: Array[Beam] = []
var _shades: Array[Shade] = []
var _working := false

## What something that gives its own light wears (`glow.gdshader`): one
## material for all of it. The lamps leave it as it was drawn, and so does
## the dark.
static func glow() -> ShaderMaterial:
	if _glow == null:
		_glow = ShaderMaterial.new()
		_glow.shader = GLOW
	return _glow

## The colour that says a surface faces `way` across the picture — up is
## Vector2.UP — for something drawn in code to paint its twin on NORMAL_LAYER
## in. `counts` is how much the way it faces matters: 1 an edge lit only from
## its own side, 0 a face that takes any light alike.
static func faces(way: Vector2, counts: float = 1.0) -> Color:
	var n := way.normalized() * clampf(counts, 0.0, 1.0) * RELIEF
	return Color(n.x, n.y, 0.0, 1.0)

func _enter_tree() -> void:
	_up.append(self)

func _exit_tree() -> void:
	_up.erase(self)
	if _up.is_empty():
		# Nothing is being lit any more, so no shader is drawing normals.
		RenderingServer.global_shader_parameter_set(&"normals_size", Vector2.ZERO)

func _ready() -> void:
	# In the order they are drawn each frame, after the colours: how the world
	# faces, where each lamp does not reach, and the picture they come to.
	_normals = _viewport(true)
	_normals.world_2d = get_viewport().world_2d
	_normals.snap_2d_transforms_to_pixel = true
	_normals.canvas_cull_mask = 0xFFFFFFFF & ~BACKDROP_LAYER
	for i in MASKS:
		var mask := _viewport(false)
		# Nothing but black where no shadow is, whatever the project clears to.
		mask.transparent_bg = true
		_masks.append(mask)
		for k in PER_MASK:
			var shade := Shade.new()
			shade.clip_contents = true
			shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shade.visible = false
			var m := ShaderMaterial.new()
			m.shader = SHADOW
			m.set_shader_parameter("channel", Vector3(float(k == 0), float(k == 1), float(k == 2)))
			shade.material = m
			mask.add_child(shade)
			_shades.append(shade)
	_lit = _viewport(false)
	# The light there is with no lamp lit, under every lamp: on a layer of its
	# own so it covers the picture wherever the camera is.
	var under := CanvasLayer.new()
	under.layer = -1
	_lit.add_child(under)
	var all := ColorRect.new()
	all.set_anchors_preset(Control.PRESET_FULL_RECT)
	all.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_all = ShaderMaterial.new()
	_all.shader = AMBIENT
	_all.set_shader_parameter("base", colour.get_texture())
	_all.set_shader_parameter("normals", _normals.get_texture())
	all.material = _all
	under.add_child(all)

func _viewport(float_buffer: bool) -> SubViewport:
	var v := SubViewport.new()
	v.disable_3d = true
	v.use_hdr_2d = float_buffer
	v.size = Vector2i.ONE
	v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(v)
	return v

## The picture to show: the world lit, or with nothing to light it, the
## world's colours as they were drawn.
func picture() -> Texture2D:
	return _lit.get_texture() if _working else colour.get_texture()

## Whether there is anything to work out this frame: a lamp on the screen, or
## a room darker than it was drawn.
func working() -> bool:
	return _working

## The normals, as a texture, a pixel wider than the picture: see
## `lighting.gdshaderinc` for what a pixel of it holds.
func normals() -> Texture2D:
	return _normals.get_texture()

## The picture `mask` of the shadows, as a texture: a colour of it to a lamp.
func shadows(mask: int = 0) -> Texture2D:
	return _masks[mask].get_texture()

## The world rect the buffers cover.
func area() -> Rect2:
	return Rect2(origin, Vector2(size) * S)

## The buffers cover `texels` pixels from `at`, the world position of the
## first, and `view` is how the world lies across them: what the pixel camera
## is drawing, on its grid. Called by the camera every frame it follows, once
## everything in the world has moved — so the frame's lamps are gathered here,
## and its shadows.
func follow(at: Vector2, texels: Vector2i, view: Transform2D) -> void:
	origin = at
	if texels != size:
		size = texels
		# A pixel wider than the picture, which is how a shader knows it is
		# the normals it is drawing (`lighting.gdshaderinc`). Nothing reads
		# the extra column.
		_normals.size = size + Vector2i(1, 0)
		_lit.size = size
		for mask in _masks:
			mask.size = size
	var lamps := _lamps()
	lamps_lit = lamps.size()
	_working = not lamps.is_empty() or ambient.r < 1.0 or ambient.g < 1.0 or ambient.b < 1.0
	var mode := SubViewport.UPDATE_ALWAYS if _working else SubViewport.UPDATE_DISABLED
	_normals.render_target_update_mode = mode
	_lit.render_target_update_mode = mode
	if not _working:
		lamps_shadowed = 0
		for mask in _masks:
			mask.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_normals.canvas_transform = view
	_lit.canvas_transform = view
	for mask in _masks:
		mask.canvas_transform = view
	if _up.back() == self:
		RenderingServer.global_shader_parameter_set(&"normals_size", Vector2(_normals.size))
	_all.set_shader_parameter("ambient", Vector3(ambient.r, ambient.g, ambient.b))
	_draw_lamps(lamps, _draw_shadows(lamps))

## The lamps that reach the screen this frame.
func _lamps() -> Array[Lamp]:
	var shown := area()
	var lamps: Array[Lamp] = []
	for n in get_tree().get_nodes_in_group(Lamp.GROUP):
		var lamp := n as Lamp
		if lamp != null and lamp.lit() and shown.intersects(_square(lamp)):
			lamps.append(lamp)
	return lamps

## The shadows of the lamps that throw them — the widest and brightest first,
## as far as the masks go round — each given a colour of a mask and the edges
## near it to draw there. Which colour each lamp got, by lamp: its number
## among all the masks' colours.
func _draw_shadows(lamps: Array[Lamp]) -> Dictionary:
	var throwing: Array[Lamp] = []
	for lamp in lamps:
		if lamp.shadows:
			throwing.append(lamp)
	if throwing.size() > SHADOWS:
		throwing.sort_custom(func(a: Lamp, b: Lamp) -> bool:
			return a.radius * a.energy > b.radius * b.energy)
		throwing.resize(SHADOWS)
	lamps_shadowed = throwing.size()
	var casters: Array[ShadowCaster] = []
	if not throwing.is_empty():
		for n in get_tree().get_nodes_in_group(ShadowCaster.GROUP):
			var caster := n as ShadowCaster
			if caster != null and caster.mesh != null and caster.is_visible_in_tree():
				casters.append(caster)
	var given := {}
	for i in _shades.size():
		var shade := _shades[i]
		if i >= throwing.size():
			shade.visible = false
			continue
		var lamp := throwing[i]
		given[lamp] = i
		var at := lamp.global_position
		var reach := _square(lamp)
		shade.visible = true
		shade.position = reach.position
		shade.size = reach.size
		var m := shade.material as ShaderMaterial
		m.set_shader_parameter("light", at)
		m.set_shader_parameter("reach", lamp.radius * THROW)
		shade.thrown.clear()
		for caster in casters:
			if caster.covers().intersects(reach) and not caster.holds(at):
				shade.thrown.append([caster.mesh, caster.global_transform])
		shade.queue_redraw()
	for i in MASKS:
		_masks[i].render_target_update_mode = SubViewport.UPDATE_ALWAYS \
			if i * PER_MASK < throwing.size() else SubViewport.UPDATE_DISABLED
	return given

## Every lamp's mesh in the picture, told what its lamp is like and which
## colour of which mask its shadows are in.
func _draw_lamps(lamps: Array[Lamp], given: Dictionary) -> void:
	while _beams.size() < lamps.size():
		_beams.append(_beam())
	for i in _beams.size():
		var beam := _beams[i]
		if i >= lamps.size():
			beam.visible = false
			continue
		var lamp := lamps[i]
		beam.visible = true
		beam.position = lamp.global_position
		beam.scale = Vector2.ONE * lamp.radius
		var m := beam.material as ShaderMaterial
		var slot := int(given.get(lamp, -1))
		var k := slot % PER_MASK if slot >= 0 else -1
		@warning_ignore("integer_division")
		m.set_shader_parameter("shade", _masks[maxi(slot, 0) / PER_MASK].get_texture())
		m.set_shader_parameter("channel", Vector3(float(k == 0), float(k == 1), float(k == 2)))
		m.set_shader_parameter("tint", Vector3(lamp.color.r, lamp.color.g, lamp.color.b))
		m.set_shader_parameter("energy", lamp.energy * lamp.color.a)
		m.set_shader_parameter("inner", clampf(lamp.inner, 0.0, 0.999))
		m.set_shader_parameter("falloff", lamp.falloff)
		m.set_shader_parameter("aim", lamp.aim())
		m.set_shader_parameter("spread", lamp.spread)
		m.set_shader_parameter("soft", clampf(lamp.soft, 0.001, 1.0))
		m.set_shader_parameter("volume", lamp.volume)
		m.set_shader_parameter("close", CLOSE / lamp.radius)

## The square round a lamp's reach, in the world: what its mesh covers.
func _square(lamp: Lamp) -> Rect2:
	var r := Vector2.ONE * lamp.radius
	return Rect2(lamp.global_position - r, r * 2.0)

func _beam() -> Beam:
	var beam := Beam.new()
	var m := ShaderMaterial.new()
	m.shader = LIGHT
	m.set_shader_parameter("base", colour.get_texture())
	m.set_shader_parameter("normals", _normals.get_texture())
	beam.material = m
	_lit.add_child(beam)
	return beam

## A lamp's mesh: the square round its reach, 1 from its middle to its edge,
## which is what `light.gdshader` measures in.
class Beam extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color.WHITE)

## What one lamp's shadows are drawn by: a box the size of its reach, which
## nothing is drawn outside of, and inside it every caster's edges, each
## where the caster is in the world. Its material is the lamp's own
## `shadow.gdshader`, told where the lamp is.
class Shade extends Control:
	## What throws a shadow in this lamp's light: [mesh, where in the world].
	var thrown: Array = []

	func _draw() -> void:
		var back := Transform2D(0.0, -position)
		for t in thrown:
			draw_mesh(t[0], null, back * (t[1] as Transform2D))
