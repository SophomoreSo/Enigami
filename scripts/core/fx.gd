extends Node

## Screen feel: shake, hitstop, time dilation, impact sparks and damage numbers.
## Everything is drawn from primitives so the game needs no art assets.

var camera: Camera2D = null
var world: Node = null

var _shake: float = 0.0
var _shake_decay: float = 7.0
var _hitstop_until: float = 0.0
var _dilation_until: float = 0.0
var _dilation_scale: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_d: float) -> void:
	var now := _now()
	var target := 1.0
	if now < _hitstop_until:
		target = 0.02
	elif now < _dilation_until:
		target = _dilation_scale
	Engine.time_scale = lerpf(Engine.time_scale, target, 0.35) if absf(Engine.time_scale - target) > 0.01 else target

	if camera != null and is_instance_valid(camera):
		if _shake > 0.01:
			_shake = maxf(0.0, _shake - _shake_decay * (1.0 / 60.0))
			camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		elif camera.offset != Vector2.ZERO:
			camera.offset = camera.offset.lerp(Vector2.ZERO, 0.4)

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func register_camera(c: Camera2D) -> void:
	camera = c

func register_world(w: Node) -> void:
	world = w

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func hitstop(seconds: float) -> void:
	_hitstop_until = maxf(_hitstop_until, _now() + seconds)

func dilate(seconds: float, scale: float = 0.45) -> void:
	_dilation_until = maxf(_dilation_until, _now() + seconds)
	_dilation_scale = scale

func is_dilated() -> bool:
	return _now() < _dilation_until

func clear_time_effects() -> void:
	_hitstop_until = 0.0
	_dilation_until = 0.0
	Engine.time_scale = 1.0

## --- spawned visuals --------------------------------------------------------
func burst(pos: Vector2, color: Color, count: int = 8, power: float = 180.0) -> void:
	if world == null or not is_instance_valid(world):
		return
	var n := Spark.new()
	n.setup(pos, color, count, power)
	world.add_child(n)

func ring(pos: Vector2, color: Color, radius: float) -> void:
	if world == null or not is_instance_valid(world):
		return
	var n := Ring.new()
	n.setup(pos, color, radius)
	world.add_child(n)

func damage_number(pos: Vector2, amount: float, color: Color = Color(1, 1, 1)) -> void:
	if world == null or not is_instance_valid(world):
		return
	var n := FloatText.new()
	n.setup(pos, "%d" % int(round(amount)), color)
	world.add_child(n)

func text(pos: Vector2, s: String, color: Color = Color(1, 1, 1)) -> void:
	if world == null or not is_instance_valid(world):
		return
	var n := FloatText.new()
	n.setup(pos, s, color)
	world.add_child(n)

## --- primitives -------------------------------------------------------------
class Spark extends Node2D:
	var parts: Array = []
	var life: float = 0.45
	var color: Color = Color.WHITE

	func setup(pos: Vector2, c: Color, count: int, power: float) -> void:
		position = pos
		color = c
		z_index = 60
		for i in count:
			var a := randf() * TAU
			parts.append({
				"p": Vector2.ZERO,
				"v": Vector2(cos(a), sin(a)) * randf_range(0.4, 1.0) * power,
				"s": randf_range(1.5, 3.5),
			})

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
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
	var life: float = 0.3
	var max_life: float = 0.3
	var color: Color = Color.WHITE
	var radius: float = 30.0

	func setup(pos: Vector2, c: Color, r: float) -> void:
		position = pos
		color = c
		radius = r
		z_index = 60

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := 1.0 - life / max_life
		var c := color
		c.a = 1.0 - t
		draw_arc(Vector2.ZERO, radius * (0.3 + t), 0, TAU, 28, c, 2.5 + 3.0 * (1.0 - t))

class FloatText extends Node2D:
	var life: float = 0.8
	var label: String = ""
	var color: Color = Color.WHITE
	var font: Font

	func setup(pos: Vector2, s: String, c: Color) -> void:
		position = pos + Vector2(randf_range(-6, 6), -8)
		label = s
		color = c
		z_index = 70
		font = ThemeDB.fallback_font

	func _process(delta: float) -> void:
		life -= delta
		position.y -= 46.0 * delta
		if life <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var c := color
		c.a = clampf(life / 0.5, 0.0, 1.0)
		var shadow := Color(0, 0, 0, c.a * 0.8)
		draw_string(font, Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, shadow)
		draw_string(font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, c)
