extends Node

## The mouse pointer: what it looks like, and how fast it moves.
##
## The pointer is drawn here rather than shipped. Every asset in this game that
## is not the sprite atlas or a font is built at boot — the sounds are
## synthesised next door in `audio/`, and the rooms, the effects and the whole
## UI are drawn from primitives — and a cursor is a picture eleven pixels
## across, so it is a table of characters and a handful of lines instead of a
## file to keep in step with the rest.
##
## Sensitivity moves the system pointer the extra distance itself rather than
## keeping a pointer of our own. Every screen in this game is built of Controls,
## and a Control knows where the system pointer is and nothing else: a second,
## private pointer would draw in one place and click in another. Moving the real
## one keeps the cursor, the aim and every button pointing at the same spot.
##
## At 1.0 — what the game ships at — none of the movement code runs at all.

## Where the setting is kept: its own file, beside the language and the key
## bindings and for the same reason. How fast a mouse should move is a property
## of the desk it is sitting on, not of the profile being played on it.
const PATH := "user://enigami_pointer.json"

## What the slider spans. Below the bottom the pointer is slower than the hand
## moving it, which is what a shaky hand or a fine aim wants; above the top it
## crosses the screen faster than the eye follows it back.
const MIN_SENS := 0.4
const MAX_SENS := 2.5
const STEP := 0.1

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

## 1.0 moves the pointer exactly as far as the mouse was moved.
var sensitivity: float = 1.0

## Where our own last warp put the pointer. The window sends that jump back as a
## motion event like any other, and the extra distance has already been added to
## it — so the one event that lands here is let through untouched. Matching on
## the position rather than on a flag matters: a warp that is answered with no
## event at all would leave a flag set and eat the next real move.
var _warped_to: Vector2 = Vector2.INF
## Kept so the picture outlives nothing: handed to the window and held here, it
## goes when this node goes, which is before the renderer that owns it does.
var _tex: ImageTexture = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_saved()
	install()

## --- the picture ------------------------------------------------------------
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

## --- how fast it moves ------------------------------------------------------
func set_sensitivity(v: float) -> void:
	sensitivity = clampf(v, MIN_SENS, MAX_SENS)
	save()

## Where the pointer should end up after a move that landed it at `at`: the
## extra distance sensitivity asks for, and nothing else. It is not held inside
## anything — see `_input`, which declines to take the pointer somewhere it does
## not belong rather than pinning it to the edge. Pure, and the whole of the
## arithmetic, so what the pointer does can be checked without a hand on a
## mouse.
func target_for(at: Vector2, relative: Vector2) -> Vector2:
	return at + relative * (sensitivity - 1.0)

func _input(event: InputEvent) -> void:
	var m := event as InputEventMouseMotion
	if m == null:
		return
	if m.position.distance_squared_to(_warped_to) < 1.0:
		_warped_to = Vector2.INF   # our own jump, already carrying the extra
		return
	if is_equal_approx(sensitivity, 1.0):
		return
	var view := get_viewport()
	if view == null:
		return
	# Already off the window: gone is gone. Below 1.0 the pointer is being held
	# back from where the mouse put it, and without this that pull would reach
	# out and fetch a pointer that had just left — the slower the setting, the
	# harder the window would be to get out of.
	var rect := view.get_visible_rect()
	if not rect.has_point(m.position):
		return
	var want := target_for(m.position, m.relative)
	if want.distance_squared_to(m.position) < 1.0:
		return
	# The pointer belongs to the desk and not to this window. Somebody reaching
	# for a second screen, for another window or for the menu bar has to be able
	# to leave, and a pointer pinned to the border by its own sensitivity could
	# not — so past the edge the extra distance is simply not added, and the
	# last of the way out is the mouse's own.
	if not rect.has_point(want):
		return
	_warped_to = want
	# Into window pixels on the way out: the game is drawn at 1280x720 into
	# whatever size the window happens to be, so an event arrives in the first
	# space and a warp has to be given the second.
	Input.warp_mouse(get_window().get_final_transform() * want)

## --- keeping it -------------------------------------------------------------
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
