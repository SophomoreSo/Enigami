class_name CutsceneView
extends Node2D

## Everything a directed scene puts on the screen: the camera over the stage,
## the room it plays in, the narration panel, and the fade the script calls for.
##
## The staging directions have already been carried out by the `Cutscene` before
## this hears anything. What arrives here on the `scene_direction` cue is the
## rest — `camera` and `fade` — which move nothing in the rules and so were left
## for the picture to answer. A new one is a case in `_direction` and a key in
## the file, with nothing to change in `feature/`.

## How far above the floor the camera looks. The world is drawn at half the
## screen's resolution (`PixelCamera.SCALE`), so the camera sees 640x360 of it
## at rest: this puts the floor into the lower third, clear of the narration.
const EYE_LINE := 60.0
const STAGE := 2400.0
## Dressing along the back wall: a rack of shelves at this spacing.
const SHELF_STEP := 96.0

const BACK := Color(0.055, 0.062, 0.082)
const WALL := Color(0.085, 0.095, 0.125)
const SHELF := Color(0.13, 0.145, 0.185)
const FLOOR := Color(0.10, 0.105, 0.13)
const FLOOR_LINE := Color(0.20, 0.26, 0.32)

var cut: Cutscene
var camera: Camera2D
var pixels: PixelCamera
var box: CutsceneBox
## 1 is full black. A scene opens black so a `fade: in` has something to lift.
var fade: float = 1.0
var _fade_to: float = 1.0
var _fade_rate: float = 0.0
var _curtain: ColorRect
var _directed: bool = false
## A view is attached as the scene enters the tree, which is before the scene's
## own `_ready` has read its file — so where the floor is, and therefore where
## the camera looks, is not known yet. The scene says when its stage is standing
## and this settles then, which is before the first beat can direct the camera.
var _settled: bool = false
## The middle of everywhere the script names, which is what the camera rests on
## and what the room is drawn around.
var _centre: float = 0.0

func _ready() -> void:
	cut = get_parent() as Cutscene
	z_index = -10
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	Fx.register_camera(camera)
	pixels = PixelCamera.new()
	add_child(pixels)

	var layer := CanvasLayer.new()
	layer.layer = CutsceneBox.LAYER
	add_child(layer)
	box = CutsceneBox.new()
	box.cut = cut
	layer.add_child(box)

	# Over everything, including the panel: a fade takes the whole picture.
	var curtain_layer := CanvasLayer.new()
	curtain_layer.layer = CutsceneBox.LAYER + 1
	add_child(curtain_layer)
	_curtain = ColorRect.new()
	_curtain.color = Color(0, 0, 0, 1)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain_layer.add_child(_curtain)

	Cues.fired.connect(_on_cue)
	cut.finished.connect(_on_finished)

func _exit_tree() -> void:
	# A scene torn down mid-direction gives the camera back, or the screen after
	# it inherits a close-up of a room that no longer exists.
	if _directed:
		Fx.release(0.0)

func _process(delta: float) -> void:
	_settle()
	if _fade_rate > 0.0:
		fade = move_toward(fade, _fade_to, _fade_rate * delta)
	else:
		fade = _fade_to
	_curtain.color = Color(0, 0, 0, clampf(fade, 0.0, 1.0))
	queue_redraw()

func _on_cue(name: StringName, data: Dictionary) -> void:
	if name == &"scene_staged":
		_settle()
		return
	if name != &"scene_direction":
		return
	var d = data.get("direction", {})
	if d is Dictionary:
		_direction(d)

## Frames the stage. A scene that says nothing about the camera is framed on the
## middle of everywhere it names, so it is in shot without the file having to
## think about it; a scene with a top-level `camera` is framed the way it asks.
## Either way this is where the camera rests, and a beat's own `camera`
## direction moves away from here and comes back to it.
func _settle() -> void:
	if _settled:
		return
	_settled = true
	var framing = cut.data.get("camera", {})
	if not framing is Dictionary:
		framing = {}
	_centre = _marks_centre()
	if (framing as Dictionary).has("focus"):
		_centre = cut.point_of(framing["focus"]).x
	camera.position = Vector2(_centre, cut.floor_y - EYE_LINE)
	camera.zoom = Vector2.ONE * maxf(float((framing as Dictionary).get("zoom", 1.0)), 0.1)

func _marks_centre() -> float:
	var low := INF
	var high := -INF
	for name in cut.marks:
		var x := cut.point_of(name).x
		low = minf(low, x)
		high = maxf(high, x)
	if low > high:
		return 0.0
	return (low + high) * 0.5

func _direction(d: Dictionary) -> void:
	if d.has("camera"):
		_camera(d["camera"])
	elif d.has("fade"):
		_fade(d)

## A `camera` direction, in the same words a dialogue line uses: what to centre
## on, how far in, how long to take, and a shake on its own that leaves the
## framing alone.
func _camera(value) -> void:
	if not value is Dictionary:
		if String(value) == "reset":
			Fx.release()
			_directed = false
		return
	var c: Dictionary = value
	if c.has("shake"):
		Fx.shake(float(c["shake"]))
		if not c.has("focus") and not c.has("zoom"):
			return
	var focus := camera.global_position
	if c.has("focus"):
		focus = cut.point_of(c["focus"])
		focus.y -= EYE_LINE
	Fx.direct(focus, float(c.get("zoom", 1.0)), float(c.get("time", 0.4)))
	_directed = true

func _fade(d: Dictionary) -> void:
	# "in" means the picture comes in, so the black goes out.
	_fade_to = 0.0 if String(d.get("fade", "in")) == "in" else 1.0
	var time := float(d.get("time", 0.6))
	_fade_rate = 1.0 / time if time > 0.0 else 0.0
	if _fade_rate <= 0.0:
		fade = _fade_to

## However a scene ends — read through or skipped — it ends on black, so the
## screen after it is never cut to mid-shot.
func _on_finished() -> void:
	_fade_to = 1.0
	if _fade_rate <= 0.0:
		_fade_rate = 1.0 / 0.25

## --- the room ---------------------------------------------------------------

func _draw() -> void:
	var y := cut.floor_y
	# Around the stage, not around the camera: a room that slid with every
	# camera move would be a painted backdrop rather than a place.
	var left := _centre - STAGE * 0.5
	draw_rect(Rect2(left, y - 900.0, STAGE, 900.0), BACK)
	draw_rect(Rect2(left, y - 260.0, STAGE, 260.0), WALL)
	# A rack of shelves along the back, so a walk across the room reads as
	# movement rather than a sprite sliding on a flat colour.
	var x := left - fposmod(left, SHELF_STEP)
	while x < left + STAGE:
		draw_rect(Rect2(x + 10.0, y - 214.0, 46.0, 7.0), SHELF)
		draw_rect(Rect2(x + 22.0, y - 150.0, 30.0, 6.0), SHELF)
		x += SHELF_STEP
	draw_rect(Rect2(left, y, STAGE, 600.0), FLOOR)
	draw_rect(Rect2(left, y, STAGE, 2.0), FLOOR_LINE)
