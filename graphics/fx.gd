extends Node

## Screen feel: shake, impact sparks and damage numbers. Everything is drawn
## from primitives so the game needs no art assets.
##
## Nothing here changes the simulation — a shake that stops and a spark that
## fades leave the fight exactly as it was. The clock effects that *do* change
## it (hitstop, dilation) are a rule and live in `feature/core/time_control.gd`.

var camera: Camera2D = null

var _shake: float = 0.0
var _shake_decay: float = 7.0

## How deep the bars over the top and the bottom of the screen stand, in
## screen pixels: a conversation in the box brings them in, and says how deep
## they are as they come and go (`Letterbox`). Nothing under them is seen, so
## a camera taken while they are there may go that much further up or down —
## see `direct`.
var bars: float = 0.0

## The camera while something has taken it — see `direct`.
var _directing := false
var _releasing := false
var _home_pos := Vector2.ZERO
var _home_zoom := Vector2.ONE
## What it was asked to centre on, framed afresh every frame (`_framed`).
var _focus := Vector2.ZERO
var _want_zoom := Vector2.ONE
var _move_time: float = 0.4

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(d: float) -> void:
	if camera != null and is_instance_valid(camera):
		if _shake > 0.01:
			_shake = maxf(0.0, _shake - _shake_decay * (1.0 / 60.0))
			camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		elif camera.offset != Vector2.ZERO:
			camera.offset = camera.offset.lerp(Vector2.ZERO, 0.4)
		_steer(d)

func register_camera(c: Camera2D) -> void:
	camera = c
	_directing = false
	_releasing = false

## Nothing asks whether shake is wanted before asking for it: every cue that
## lands one is describing the hit, not the setting. The setting is read here,
## once, so turning it off is one answer rather than a flag threaded through
## `CueVisuals` — and a shake already running settles back to nothing either
## way, which `_process` is what does.
func shake(amount: float) -> void:
	if not Video.screen_shake:
		return
	_shake = maxf(_shake, amount)

## Takes the screen's camera for a while — a conversation framing who is
## talking, say: centres on `focus` (a world point) at `zoom` times the screen's
## own zoom, easing there over `time` seconds, until `release` hands it back.
##
## It never zooms out past the screen's own framing, and never shows anything
## that framing did not: a close-up by a wall slides along rather than reveal the
## dark past the room. What is under the `bars` is not shown, so while there are
## any it goes as much further up or down as they are deep — as deep as they
## are at the moment, coming in or going out.
func direct(focus: Vector2, zoom: float = 1.0, time: float = 0.4) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if not _directing:
		_directing = true
		_home_pos = camera.global_position
		_home_zoom = camera.zoom
	_releasing = false
	_want_zoom = _home_zoom * maxf(zoom, 1.0)
	_focus = focus
	_move_time = maxf(time, 0.0)

## Eases the camera back to where the screen had it, over `time` seconds.
func release(time: float = 0.4) -> void:
	if not _directing:
		return
	_releasing = true
	_focus = _home_pos
	_want_zoom = _home_zoom
	_move_time = maxf(time, 0.0)

## Whether something has the camera. A screen that moves its own camera leaves
## it be until it is handed back.
func directing() -> bool:
	return _directing

func _steer(d: float) -> void:
	if not _directing:
		return
	# Covers 99% of the way in `_move_time`, whatever the frame rate.
	var k := 1.0 if _move_time <= 0.0 else 1.0 - exp(-d * 4.6 / _move_time)
	camera.zoom = camera.zoom.lerp(_want_zoom, k)
	# Where it is going, and where that has brought it, are framed afresh every
	# frame, at the zoom it has come to and as deep as the bars stand now.
	var going := _framed(_focus, _want_zoom)
	camera.global_position = _framed(camera.global_position.lerp(going, k), camera.zoom)
	if _releasing and camera.global_position.distance_to(_home_pos) < 0.5 \
			and camera.zoom.distance_to(_home_zoom) < 0.002:
		camera.global_position = _home_pos
		camera.zoom = _home_zoom
		_directing = false
		_releasing = false

## `at`, moved no further than it must be for a camera there at `zoom` to show
## nothing the screen's own framing did not, but what is under the bars.
func _framed(at: Vector2, zoom: Vector2) -> Vector2:
	var screen := camera.get_viewport_rect().size
	var slack := screen / _home_zoom * 0.5 - screen / zoom * 0.5
	slack.y += bars / zoom.y
	slack = slack.max(Vector2.ZERO)
	return at.clamp(_home_pos - slack, _home_pos + slack)

## --- spawned visuals --------------------------------------------------------
## Loose visuals are lent to whatever screen is running rather than made for
## it and thrown away. Every moment of a fight asks for some — a hit, a jump, a
## landing, a slide down a wall asks every frame — so each kind is drawn from a
## pool of its own (`Pool`): borrowed, set going and let go of in one breath,
## it plays itself out and goes back to wait for the next. A screen that goes
## away takes back at once whatever it still had out, so none outlives the
## fight it belonged to.
var sparks := Pool.new(Spark, 64)
var rings := Pool.new(Ring, 16)
var words := Pool.new(FloatText, 24)

func _world() -> Node:
	return Arena.current()

func burst(pos: Vector2, color: Color, count: int = 8, power: float = 180.0) -> void:
	var world := _world()
	if world == null:
		return
	var n := sparks.borrow(world) as Spark
	n.setup(pos, color, count, power)
	sparks.dispose(n)

func ring(pos: Vector2, color: Color, radius: float) -> void:
	var world := _world()
	if world == null:
		return
	var n := rings.borrow(world) as Ring
	n.setup(pos, color, radius)
	rings.dispose(n)

func damage_number(pos: Vector2, amount: float, color: Color = Color(1, 1, 1)) -> void:
	text(pos, "%d" % int(round(amount)), color)

func text(pos: Vector2, s: String, color: Color = Color(1, 1, 1)) -> void:
	var world := _world()
	if world == null:
		return
	var n := words.borrow(world) as FloatText
	n.setup(pos, s, color)
	words.dispose(n)

## --- primitives -------------------------------------------------------------
## Each is set up afresh every time it is lent, and let go of the moment it is:
## `_disposed` is a primitive saying it has a little left to play, and it hands
## itself back to its pool once it has played it.
##
## All three are their own light (`Lighting.glow`): a spark is as bright in a
## dark room, and no lamp makes a number brighter.
class Spark extends Node2D:
	var pool: Pool = null
	var parts: Array = []
	var life: float = 0.45
	var color: Color = Color.WHITE

	func _init() -> void:
		material = Lighting.glow()

	func setup(pos: Vector2, c: Color, count: int, power: float) -> void:
		position = pos
		color = c
		z_index = 60
		life = 0.45
		parts.clear()
		for i in count:
			var a := randf() * TAU
			parts.append({
				"p": Vector2.ZERO,
				"v": Vector2(cos(a), sin(a)) * randf_range(0.4, 1.0) * power,
				"s": randf_range(1.5, 3.5),
			})
		queue_redraw()

	func _disposed() -> void:
		pass

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			pool.give_back(self)
			return
		for part in parts:
			part["p"] += part["v"] * delta
			part["v"] *= 0.90
			part["v"].y += 260.0 * delta
		queue_redraw()

	func _draw() -> void:
		var a := clampf(life / 0.45, 0.0, 1.0)
		for part in parts:
			var c := color
			c.a = a
			draw_circle(part["p"], part["s"] * a, c)

class Ring extends Node2D:
	var pool: Pool = null
	var life: float = 0.3
	var max_life: float = 0.3
	var color: Color = Color.WHITE
	var radius: float = 30.0

	func _init() -> void:
		material = Lighting.glow()

	func setup(pos: Vector2, c: Color, r: float) -> void:
		position = pos
		color = c
		radius = r
		z_index = 60
		life = max_life
		queue_redraw()

	func _disposed() -> void:
		pass

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			pool.give_back(self)
			return
		queue_redraw()

	func _draw() -> void:
		var t := 1.0 - life / max_life
		var c := color
		c.a = 1.0 - t
		draw_arc(Vector2.ZERO, radius * (0.3 + t), 0, TAU, 28, c, 2.5 + 3.0 * (1.0 - t))

class FloatText extends Node2D:
	var pool: Pool = null
	var life: float = 0.8
	var label: String = ""
	var color: Color = Color.WHITE

	func _init() -> void:
		material = Lighting.glow()

	func setup(pos: Vector2, s: String, c: Color) -> void:
		position = pos + Vector2(randf_range(-6, 6), -8)
		label = s
		color = c
		z_index = 70
		life = 0.8
		queue_redraw()

	func _disposed() -> void:
		pass

	func _process(delta: float) -> void:
		life -= delta
		position.y -= 46.0 * delta
		if life <= 0.0:
			pool.give_back(self)
			return
		queue_redraw()

	func _draw() -> void:
		var c := color
		c.a = clampf(life / 0.5, 0.0, 1.0)
		PixelCamera.draw_text(self, Vector2.ZERO, label, c, Color(0, 0, 0, c.a * 0.8))
