extends Node

## The mouse pointer the game draws for itself.
##
## The pointer is drawn here rather than shipped. Every asset in this game that
## is not the sprite atlas or a font is built at boot — the sounds are
## synthesised next door in `audio/`, and the rooms, the effects and the whole
## UI are drawn from primitives — and a cursor is a picture eleven pixels
## across, so it is a table of characters and a handful of lines instead of a
## file to keep in step with the rest.
##
## How fast it moves is the game's, and only while the game is doing the
## pointing. That distinction is the whole of the design, and it was learned the
## hard way: the game used to move the *system* pointer to serve the setting,
## and on macOS that cannot be made to behave.
##
##   * Moving the pointer works — a move lands where it is sent, to the pixel,
##     on a 2x screen, and seven hundred moves in a row land there too.
##   * But the call that does it unhooks the pointer from the mouse underneath
##     and swallows what the hand does for a moment afterwards. The hand keeps
##     going, the two drift apart, and when the system puts them back together
##     the pointer arrives wherever the mouse had got to. On a fast zigzag that
##     is somewhere across the screen.
##   * Keeping the pointer on the window, which is the other way to stop them
##     drifting apart, unhooks it outright: the pointer stops following the
##     mouse at all and only moves when something moves it.
##
## So the system pointer is never moved, never held, and never argued with.
## While the player has the controls the game takes the mouse instead — Godot
## hands over raw movement and nothing else — and keeps a pointer of its own,
## `point`, which it moves at whatever speed the setting asks for and draws the
## crosshair at. Let go of the controls for a menu, a map or a conversation, and
## the system pointer comes straight back, at its own speed, for the buttons.
##
## Which means the setting is aim speed. Menus are the system's and stay 1:1.

## The pointer, one character per art pixel: `#` is the bright body, `.` is
## nothing. The dark edge around it is not drawn here — it is worked out from
## the body, so the shape is the only thing there is to keep right.
##
## A crosshair rather than an arrow: the mouse's whole job in a raid is to say
## where an attack goes, and the gap in the middle leaves what is being aimed at
## visible instead of sitting an arrowhead on top of it.
const ART := [
	".....#.....",
	".....#.....",
	".....#.....",
	"...........",
	"...........",
	"###..#..###",
	"...........",
	"...........",
	".....#.....",
	".....#.....",
	".....#.....",
]
## Screen pixels to an art pixel. The UI is drawn at two, and a pointer at one
## would be the only thing on screen at a finer grain than everything else.
const SCALE := 2
const INK := Color(0.96, 0.99, 1.0)
const EDGE := Color(0.05, 0.07, 0.1)

## Where the setting is kept: its own file, beside the language and the key
## bindings and for the same reason. How fast a mouse should move is a property
## of the desk it is sitting on, not of the profile being played on it.
const PATH := "user://enigami_pointer.json"

## What the slider spans. Below the bottom the pointer is slower than the hand
## moving it, which is what a fine aim wants; above the top it crosses the
## screen faster than the eye follows it back.
const MIN_SENS := 0.4
const MAX_SENS := 2.5
const STEP := 0.1

## 1.0 carries the pointer exactly as far as the mouse was moved.
var sensitivity: float = 1.0

## Where the game is pointing, in the 1280x720 it is drawn at. While the system
## pointer is doing the pointing this is simply where that is; while the game is
## doing it, this is what the mouse has been moving.
var point: Vector2 = Vector2.ZERO

## Kept so the picture outlives nothing: handed to the window and held here, it
## goes when this node goes, which is before the renderer that owns it does.
var _tex: ImageTexture = null
var _taken: bool = false
var _crosshair: TextureRect = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_saved()
	install()
	_build_crosshair()

## Hands the built pointer to the window. Every Control in the game uses the
## arrow shape — nothing here asks for a hand or a beam — so one picture is the
## whole cursor.
func install() -> void:
	_tex = texture()
	if _tex == null:
		return
	Input.set_custom_mouse_cursor(_tex, Input.CURSOR_ARROW, hotspot())

## Give the pointer back on the way out. A texture still held by the window
## when the renderer shuts down is reported as a leak, which is a real one: the
## game is quitting, but nothing should be left holding the door.
func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	_tex = null

## --- whose pointer it is ----------------------------------------------------
## The game is pointing whenever somebody has the controls: a raid, the bench,
## the hideout floor. Every screen that takes the keys away — the assembly
## overlay, the map, a conversation, the pause menu — hands the pointer back on
## the same frame, because the same thing decides both.
func game_is_pointing() -> bool:
	if get_tree() == null or get_tree().paused:
		return false
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("controls_locked") and not p.controls_locked():
			return true
	return false

func _process(_delta: float) -> void:
	var take := game_is_pointing()
	if take != _taken:
		_taken = take
		# Taken, not confined and not warped: Godot hands over raw movement and
		# leaves the system pointer where it was. Handed back, the system puts
		# it back itself. Nothing here ever tells it where to be.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if take else Input.MOUSE_MODE_VISIBLE
	if not _taken:
		var vp := get_viewport()
		if vp != null:
			point = vp.get_mouse_position()
	if _crosshair != null:
		_crosshair.visible = _taken
		# Snapped to the grid the rest of the picture is on. The art is drawn at
		# SCALE, so an odd screen pixel puts every art pixel of it across two
		# screen ones — the crosshair was the only thing on screen doing that,
		# and `pixel_camera_test` counts exactly that and nothing else.
		_crosshair.position = ((point - hotspot()) / float(SCALE)).floor() * SCALE

func _input(event: InputEvent) -> void:
	if not _taken:
		return
	var m := event as InputEventMouseMotion
	if m == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	point = carry(point, m.relative, vp.get_visible_rect().size)

## Where the pointer lands after the mouse has been moved `by`: the distance the
## setting asks for, kept on the screen. Pure, so what the pointer does can be
## checked without a hand on a mouse.
func carry(from: Vector2, by: Vector2, bounds: Vector2) -> Vector2:
	var to: Vector2 = from + by * sensitivity
	return Vector2(clampf(to.x, 0.0, maxf(bounds.x - 1.0, 0.0)),
		clampf(to.y, 0.0, maxf(bounds.y - 1.0, 0.0)))

## Where the game is pointing, in the world `node` stands in — what
## `get_global_mouse_position` answers, asked of the game's pointer instead of
## the system's. The two are the same thing whenever the system is pointing.
func world_point(node: CanvasItem) -> Vector2:
	var vp := node.get_viewport()
	if vp == null:
		return point
	return vp.get_canvas_transform().affine_inverse() * point

func set_sensitivity(v: float) -> void:
	sensitivity = clampf(v, MIN_SENS, MAX_SENS)
	save()

## --- the crosshair ----------------------------------------------------------
## Drawn by the shell rather than by a screen: every screen the player has the
## controls on wants it, and none of them should have to know that.
func _build_crosshair() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_crosshair = TextureRect.new()
	_crosshair.texture = _tex
	_crosshair.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.visible = false
	layer.add_child(_crosshair)

## --- keeping the setting ----------------------------------------------------
func load_saved() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	sensitivity = clampf(float((parsed as Dictionary).get("sensitivity", 1.0)), MIN_SENS, MAX_SENS)

func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"sensitivity": sensitivity}))
	f.close()

## The pointer, drawn. One art pixel of padding all round, so the dark edge has
## somewhere to go on the arms that reach the border of the table.
func texture() -> ImageTexture:
	var w: int = ART[0].length() + 2
	var h: int = ART.size() + 2
	var img := Image.create(w * SCALE, h * SCALE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var col := _cell(x - 1, y - 1)
			if col.a > 0.0:
				_block(img, x, y, col)
	return ImageTexture.create_from_image(img)

## Dead centre, which is where a crosshair points from.
func hotspot() -> Vector2:
	return Vector2(float(ART[0].length() + 2), float(ART.size() + 2)) * SCALE * 0.5

## The colour of one art cell: the body where the table says so, the dark edge
## where it does not but a neighbour does, and nothing anywhere else.
func _cell(x: int, y: int) -> Color:
	if _body(x, y):
		return INK
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if _body(x + dx, y + dy):
				return EDGE
	return Color(0, 0, 0, 0)

func _body(x: int, y: int) -> bool:
	if y < 0 or y >= ART.size() or x < 0 or x >= ART[y].length():
		return false
	return ART[y][x] == "#"

func _block(img: Image, x: int, y: int, col: Color) -> void:
	for j in SCALE:
		for i in SCALE:
			img.set_pixel(x * SCALE + i, y * SCALE + j, col)
