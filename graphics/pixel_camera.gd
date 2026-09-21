class_name PixelCamera
extends CanvasLayer

## The world, drawn at the art's own resolution and shown at SCALE×.
##
## Actors are 16px art drawn at 2× (`Sprites.PIXEL_SCALE`), but rooms, attacks
## and effects are primitives placed at full resolution, so a slash could land
## between two of a knight's pixels. This puts the whole world on the art's
## grid: a SubViewport shares the screen's World2D and draws it at 1/SCALE, and
## the result is laid over the screen with nearest filtering. The HUD and the
## overlays sit on higher layers and stay sharp.
##
## A grid alone would move the camera in SCALE-pixel steps. So the buffer runs
## BORDER pixels past the screen on every side, its view is snapped to whole
## world pixels, and the image is slid across that border by whatever the real
## camera had left over. This is the smooth pixel-perfect camera from
## https://discussions.unity.com/t/1586409, which does it as a URP render pass
## with a crop shader.
##
## That thread ends on stray vertical lines, put down to float precision. They
## are nearest sampling landing exactly on a texel edge, where rounding picks
## either neighbour. The slide here is rounded to whole screen pixels, so at 2×
## every screen pixel samples a quarter texel in from an edge and never on one.
##
## The real camera is left alone. It still maps the mouse into the world, which
## is why aiming needs nothing from this.
##
## What it asks of everything drawn in the world: a line narrower than SCALE
## world units covers no pixel centre at this resolution and is not drawn at
## all. That is how the room grid and the tile outlines disappeared when this
## went in, at 1.0 wide; they, and every other line that was set thinner, are
## SCALE wide now.

const SCALE := int(Sprites.PIXEL_SCALE)
const BORDER := 1
## Over the world's own canvas, under the screens (5) and the HUD (10).
const LAYER := 1

## Views are drawn on this render layer and no other (see `Views`). While a
## pixel camera is up the screen leaves the layer out, so the world is not drawn
## a second time underneath a picture that covers it.
const WORLD_LAYER := 1 << 19

## The pixel font world text is set in, and its native size in buffer pixels.
const FONT := preload("res://graphics/assets/fonts/Silkscreen-Regular.ttf")
const TEXT_SIZE := 8

## Pixel cameras currently up. A screen swap frees the old one at the end of the
## frame the new one arrived in, and the old one must not hand the world layer
## back to the screen while the new one still needs it left out.
static var _live := 0

var _view: SubViewport
var _image: Sprite2D

## Draws text into the world, centred on `at`, `size` in buffer pixels.
##
## Text drawn at world size is rasterised at that size and then shrunk into the
## buffer through a filter, so it arrives blurred before the picture is ever
## blown back up — the room names went to mush that way. Drawing `size` under a
## SCALE× transform puts each glyph pixel on exactly one buffer pixel instead.
static func draw_text(c: CanvasItem, at: Vector2, text: String, color: Color,
		shadow: Color = Color(0, 0, 0, 0), size: int = TEXT_SIZE, font: Font = FONT) -> void:
	# TEXT_SIZE is Silkscreen's own 8px, one art pixel per glyph pixel. A line
	# in writing Silkscreen does not have is drawn in the language's face, which
	# has its own size — see `Loc.text_size`.
	size = Loc.text_size(text, size)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var o := (at / SCALE - Vector2(w * 0.5, 0.0)).round()
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * SCALE)
	if shadow.a > 0.0:
		c.draw_string(font, o + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, shadow)
	c.draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _enter_tree() -> void:
	_live += 1
	get_viewport().canvas_cull_mask &= ~WORLD_LAYER

func _exit_tree() -> void:
	_live -= 1
	if _live == 0:
		get_viewport().canvas_cull_mask |= WORLD_LAYER
		# Nothing is drawing the world any more, so the grid left for whatever is
		# drawn over it is the screen's own.
		if is_instance_valid(Pointer):
			Pointer.pixel_origin = Vector2.ZERO

func _ready() -> void:
	layer = LAYER
	# After the camera it copies has settled this frame, so the picture is
	# never a frame behind a shake.
	process_priority = 100
	_view = SubViewport.new()
	_view.world_2d = get_viewport().world_2d
	_view.disable_3d = true
	_view.snap_2d_transforms_to_pixel = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_image = Sprite2D.new()
	_image.centered = false
	_image.texture = _view.get_texture()
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_image)
	_follow()

func _process(_delta: float) -> void:
	_follow()

func _follow() -> void:
	var vp := get_viewport()
	var want := Vector2i((vp.get_visible_rect().size / SCALE).ceil()) + Vector2i.ONE * BORDER * 2
	if _view.size != want:
		_view.size = want
	var xf := vp.get_canvas_transform()
	var zoom := xf.get_scale().x
	var corner := xf.affine_inverse() * Vector2.ZERO    # the world at the screen's top-left
	var grid := (corner / SCALE).floor() * SCALE
	var leftover := corner - grid                       # 0..SCALE world units
	_view.canvas_transform = Transform2D(0.0, Vector2.ONE / SCALE, 0.0,
		-grid / SCALE + Vector2.ONE * BORDER)
	_image.scale = Vector2.ONE * zoom * SCALE
	_image.position = -Vector2.ONE * BORDER * SCALE * zoom - (leftover * zoom).round()
	# The crosshair is drawn over this picture, at this picture's scale, by the
	# shell — which has no other way to learn where this grid starts. Handed over
	# rather than fetched: `PixelCamera` is a graphics class and the pointer is
	# not, and the standing check deletes the graphics autoloads this file needs.
	# See `Pointer.on_grid`.
	Pointer.pixel_origin = _image.position
