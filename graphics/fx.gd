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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_d: float) -> void:
	if camera != null and is_instance_valid(camera):
		if _shake > 0.01:
			_shake = maxf(0.0, _shake - _shake_decay * (1.0 / 60.0))
			camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		elif camera.offset != Vector2.ZERO:
			camera.offset = camera.offset.lerp(Vector2.ZERO, 0.4)

func register_camera(c: Camera2D) -> void:
	camera = c

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

## --- spawned visuals --------------------------------------------------------
## Loose visuals hang off whatever screen is running, so they are cleared with
## it and never outlive the fight they belong to.
func _world() -> Node:
	return Arena.current()
func burst(pos: Vector2, color: Color, count: int = 8, power: float = 180.0) -> void:
	var world := _world()
	if world == null:
		return
	var n := Spark.new()
	n.setup(pos, color, count, power)
	world.add_child(n)

func ring(pos: Vector2, color: Color, radius: float) -> void:
	var world := _world()
	if world == null:
		return
	var n := Ring.new()
	n.setup(pos, color, radius)
	world.add_child(n)

func damage_number(pos: Vector2, amount: float, color: Color = Color(1, 1, 1)) -> void:
	var world := _world()
	if world == null:
		return
	var n := FloatText.new()
	n.setup(pos, "%d" % int(round(amount)), color)
	world.add_child(n)

func text(pos: Vector2, s: String, color: Color = Color(1, 1, 1)) -> void:
	var world := _world()
	if world == null:
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

	func setup(pos: Vector2, s: String, c: Color) -> void:
		position = pos + Vector2(randf_range(-6, 6), -8)
		label = s
		color = c
		z_index = 70

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
		PixelCamera.draw_text(self, Vector2.ZERO, label, c, Color(0, 0, 0, c.a * 0.8))
