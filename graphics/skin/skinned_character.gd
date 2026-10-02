class_name SkinnedCharacter
extends RefCounted

## A character drawn the map way — see `PixelMap` for the idea. It is a folder
## under `graphics/assets/sprites/<base>/`:
##
##   <base>.skin.png    what the pixels look like: the character, once, in one
##                      frame. Reskinning is editing this file and nothing else.
##   <base>.map.png     a colour of its own for every skin pixel. Made once by
##                      `pixel_map_tool.gd` and then kept: the frames are
##                      painted in it.
##   <base>.<anim>.png  one strip per animation, frames the map's size side by
##                      side, each pixel painted in the map colour of the skin
##                      pixel it stands for.
##
## The strips are encoded as they load (`PixelMap.encode`) into what
## `skin_sprite.gdshader` reads, so `frames` only draw right on a sprite wearing
## `material()`; `resolved()` is the same frames in real colours, for anything
## that draws without one. `Sprites` loads one of these per character, once.

const SHADER_PATH := "res://graphics/assets/shaders/skin_sprite.gdshader"
const SPRITES_DIR := "res://graphics/assets/sprites/"

## How each animation plays. A strip the folder does not have is simply not an
## animation of this character; `ActorView.play` falls back to idle.
const ANIMS := {
	"idle": {"fps": 5.0, "loop": true},
	"run": {"fps": 12.0, "loop": true},
	"crouch": {"fps": 3.0, "loop": true},
	"hit": {"fps": 8.0, "loop": false},
	"rise": {"fps": 10.0, "loop": false},
	"fall": {"fps": 6.0, "loop": true},
	"wall_slide": {"fps": 6.0, "loop": true},
	"dash": {"fps": 20.0, "loop": false},
}

var base: String
var dir: String
var map: PixelMap
var frame_size: Vector2i
## The skin as drawn, and as every material samples it. `reskin` writes into
## this one texture, so a sprite already wearing it changes with it.
var skin: ImageTexture
var skin_image: Image
## Lookup frames: red and green name a skin pixel. Drawn through `material()`.
var frames: SpriteFrames
## Where the drawn pixels sit in the first idle frame — what `Sprites.art_rect`
## reports, so the feet are put on the floor and a portrait is cropped to the
## body.
var art_rect: Rect2
## Painted pixels that matched no map colour, per animation. Anything but zero
## is a strip painted off-palette; the pixels were dropped.
var strays: Dictionary = {}

var _lookup: Dictionary = {}   ## anim -> Array of lookup Images
var _resolved: SpriteFrames

static func folder_of(base_name: String) -> String:
	return SPRITES_DIR.path_join(base_name) + "/"

static func exists(base_name: String) -> bool:
	return base_name != "" and ResourceLoader.exists(folder_of(base_name) + "%s.map.png" % base_name, "Texture2D")

static func load_character(base_name: String) -> SkinnedCharacter:
	var c := SkinnedCharacter.new()
	c.base = base_name
	c.dir = folder_of(base_name)
	c.skin_image = _image(c.dir + "%s.skin.png" % base_name)
	var map_image := _image(c.dir + "%s.map.png" % base_name)
	if c.skin_image == null or map_image == null:
		push_error("SkinnedCharacter: '%s' needs a skin and a map in %s" % [base_name, c.dir])
		return null
	if map_image.get_size() != c.skin_image.get_size():
		push_error("SkinnedCharacter: '%s': the map is %s but the skin is %s"
			% [base_name, map_image.get_size(), c.skin_image.get_size()])
		return null
	c.map = PixelMap.from_image(map_image)
	c.frame_size = c.map.size
	c.skin = ImageTexture.create_from_image(c.skin_image)
	c.frames = SpriteFrames.new()
	c.frames.remove_animation("default")
	for anim: String in ANIMS:
		c._load_strip(anim)
	if not c.frames.has_animation("idle"):
		push_error("SkinnedCharacter: '%s' has no idle strip" % base_name)
		return null
	var used: Rect2i = (c._lookup["idle"][0] as Image).get_used_rect()
	c.art_rect = Rect2(used) if used.size.x > 0 and used.size.y > 0 else Rect2(Vector2.ZERO, Vector2(c.frame_size))
	return c

## An imported texture's pixels, RGBA8. Null if there is no such file.
static func _image(path: String) -> Image:
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img

func _load_strip(anim: String) -> void:
	var strip := _image(dir + "%s.%s.png" % [base, anim])
	if strip == null:
		return
	if strip.get_height() != frame_size.y or strip.get_width() % frame_size.x != 0:
		push_error("SkinnedCharacter: '%s.%s' is %s, not a row of %s frames"
			% [base, anim, strip.get_size(), frame_size])
		return
	var count := strip.get_width() / frame_size.x
	var looks: Array = []
	var dropped := 0
	frames.add_animation(anim)
	frames.set_animation_speed(anim, float(ANIMS[anim]["fps"]))
	frames.set_animation_loop(anim, bool(ANIMS[anim]["loop"]))
	for i in count:
		var painted := strip.get_region(Rect2i(i * frame_size.x, 0, frame_size.x, frame_size.y))
		var look := map.encode(painted)
		dropped += map.strays
		looks.append(look)
		frames.add_frame(anim, ImageTexture.create_from_image(look))
	_lookup[anim] = looks
	strays[anim] = dropped
	if dropped > 0:
		push_warning("SkinnedCharacter: '%s.%s' has %d pixels painted in no map colour" % [base, anim, dropped])

## A material for a sprite showing `frames`: the skin shader, sampling this
## character's skin. One per sprite, since the status uniforms are per actor.
func material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_PATH)
	m.set_shader_parameter("skin", skin)
	return m

## The same animations in real colours, resolved on the CPU: for a portrait or
## anything else drawn without the material. Built on first use, and again
## after a reskin.
func resolved() -> SpriteFrames:
	if _resolved != null:
		return _resolved
	_resolved = SpriteFrames.new()
	_resolved.remove_animation("default")
	for anim: String in _lookup:
		_resolved.add_animation(anim)
		_resolved.set_animation_speed(anim, frames.get_animation_speed(anim))
		_resolved.set_animation_loop(anim, frames.get_animation_loop(anim))
		for look: Image in _lookup[anim]:
			_resolved.add_frame(anim, ImageTexture.create_from_image(PixelMap.resolve(look, skin_image)))
	return _resolved

## Swaps the skin under every frame at once — every sprite already wearing a
## material of this character changes on its next draw. The new skin has to be
## the old one's size, since the frames name its pixels by position.
func reskin(image: Image) -> bool:
	if image == null or image.get_size() != skin_image.get_size():
		push_error("SkinnedCharacter: a skin for '%s' is %s, not %s" % [base, image.get_size() if image else "nothing", skin_image.get_size()])
		return false
	skin_image = image.duplicate()
	skin_image.convert(Image.FORMAT_RGBA8)
	skin.update(skin_image)
	_resolved = null
	return true

## The lookup images of an animation, for tests that want to see what was encoded.
func lookup_frames(anim: String) -> Array:
	return _lookup.get(anim, [])
