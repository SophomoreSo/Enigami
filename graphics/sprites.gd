extends Node

## Slices the CC0 "16x16 DungeonTileset II" atlas by 0x72 into per-character
## `SpriteFrames`. The pack ships one 512x512 PNG plus a list of tile rects
## (`DungeonAtlasFrames`), so the whole sprite set costs two files and no build
## step: every frame is an `AtlasTexture` window onto the same texture.
##
## See `graphics/assets/sprites/CREDITS.md`. Tile names follow
## `<base>_<idle|run|hit>_anim_f<n>`, except for a handful of monsters that
## ship a single unnamed loop as `<base>_anim_f<n>`.

const ATLAS_PATH := "res://graphics/assets/sprites/dungeon_atlas.png"
const SHADER_PATH := "res://graphics/assets/shaders/actor_sprite.gdshader"

const IDLE_FPS := 6.0
const RUN_FPS := 11.0
const MAX_FRAMES := 16  ## no animation in the pack is longer than this

## Every sprite is drawn at the same whole-number magnification. The room grid
## is 32px and the viewport is 1:1, so 16px art has to be blown up to read at
## all; keeping one integer factor for every character means one apparent pixel
## size across the cast and no shimmer from half-pixels. It also preserves the
## pack's own size relationships, which already track this game's hitboxes:
## the Warden's ogre towers over the Lobber's shaman, and the Arbiter over both.
const PIXEL_SCALE := 2.0

## Which atlas character stands for the player, each monster and each weapon is
## a look rather than a fact about the atlas, so it lives in `Style`.

var _atlas: Texture2D
var _atlas_image: Image
var _shader: Shader
var _rects: Dictionary = {}      ## tile name -> Rect2
var _textures: Dictionary = {}   ## tile name -> AtlasTexture
var _frames: Dictionary = {}     ## base -> SpriteFrames
var _art: Dictionary = {}        ## base -> opaque Rect2 within its tile

func _ready() -> void:
	_atlas = load(ATLAS_PATH)
	_atlas_image = _atlas.get_image()
	_shader = load(SHADER_PATH)
	for line in DungeonAtlasFrames.TILE_LIST.split("\n", false):
		var parts := line.strip_edges().split(" ", false)
		if parts.size() < 5:
			continue
		_rects[parts[0]] = Rect2(
			float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4]))

func has_tile(tile: String) -> bool:
	return _rects.has(tile)

func texture(tile: String) -> AtlasTexture:
	if _textures.has(tile):
		return _textures[tile]
	if not _rects.has(tile):
		return null
	var t := AtlasTexture.new()
	t.atlas = _atlas
	t.region = _rects[tile]
	# Without this a scaled AtlasTexture bleeds in its neighbours on the sheet.
	t.filter_clip = true
	_textures[tile] = t
	return t

## Size of a character's tiles, including the pack's padding.
func frame_size(base: String) -> Vector2:
	for tile in ["%s_idle_anim_f0" % base, "%s_anim_f0" % base, base]:
		if _rects.has(tile):
			return _rects[tile].size
	return Vector2(16, 16)

## Where the drawn pixels actually sit inside the tile. Every character is
## padded with headroom above it — up to eight rows of a twenty-eight row tile —
## so a sprite placed by its tile would hang above its own feet.
func art_rect(base: String) -> Rect2:
	if _art.has(base):
		return _art[base]
	var frame := Vector2.ZERO
	for tile in ["%s_idle_anim_f0" % base, "%s_anim_f0" % base, base]:
		if _rects.has(tile):
			frame = _rects[tile].size
			var used := _atlas_image.get_region(Rect2i(_rects[tile])).get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				_art[base] = Rect2(used)
				return _art[base]
			break
	_art[base] = Rect2(Vector2.ZERO, frame if frame.x > 0.0 else Vector2(16, 16))
	return _art[base]

func _collect(prefix: String) -> Array:
	var out: Array = []
	for i in MAX_FRAMES:
		var t := texture("%s_f%d" % [prefix, i])
		if t == null:
			break
		out.append(t)
	return out

func _add_anim(sf: SpriteFrames, name: String, textures: Array, fps: float, loop: bool) -> void:
	if textures.is_empty():
		return
	sf.add_animation(name)
	sf.set_animation_speed(name, fps)
	sf.set_animation_loop(name, loop)
	for t in textures:
		sf.add_frame(name, t)

## Every character resolves to the same three animation names, so callers never
## have to know which of the pack's two naming schemes a monster uses.
func frames_for(base: String) -> SpriteFrames:
	if _frames.has(base):
		return _frames[base]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var idle := _collect("%s_idle_anim" % base)
	var run := _collect("%s_run_anim" % base)
	if idle.is_empty():
		idle = _collect("%s_anim" % base)
	if run.is_empty():
		run = idle
	if idle.is_empty():
		push_error("Sprites: no frames for '%s'" % base)
		idle = [texture("knight_m_idle_anim_f0")]
		run = idle
	_add_anim(sf, "idle", idle, IDLE_FPS, true)
	_add_anim(sf, "run", run, RUN_FPS, true)
	_add_anim(sf, "hit", _collect("%s_hit_anim" % base), 8.0, false)
	_frames[base] = sf
	return sf

func status_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader
	return m
