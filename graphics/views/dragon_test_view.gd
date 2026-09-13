class_name DragonTestView
extends Node2D

## The dragon test's screen: the camera, the tape over the picture, the HUD and
## the same assembly overlay the bench uses.
##
## Katana ZERO plays its levels back as tape, so this one does too: scanlines
## and a vignette over the world, a blue wash while a charge is held, blood left
## where a guard fell, and tracking noise as the tape rewinds for the next go.

var screen: DragonTest
var camera: Camera2D
var pixels: PixelCamera
var editor: SkillEditor
var hud: DragonTestHud
var tape: Tape
var stains: Stains

func _ready() -> void:
	screen = get_parent() as DragonTest
	camera = Camera2D.new()
	camera.position = Vector2(Room.W * Room.CELL, Room.H * Room.CELL) * 0.5
	add_child(camera)
	camera.make_current()
	Fx.register_camera(camera)
	pixels = PixelCamera.new()
	add_child(pixels)

	stains = Stains.new()
	# Over the building, under everyone standing in it, and on the world's own
	# layer — a child of a view is not given it, and anything left on the default
	# layer is drawn a second time under the pixel picture.
	stains.z_index = 5
	stains.visibility_layer = PixelCamera.WORLD_LAYER
	add_child(stains)

	# Over the world's picture, under the HUD.
	var glass := CanvasLayer.new()
	glass.layer = PixelCamera.LAYER + 1
	add_child(glass)
	tape = Tape.new()
	tape.screen = screen
	glass.add_child(tape)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = DragonTestHud.new()
	hud.screen = screen
	layer.add_child(hud)
	editor = SkillEditor.new()
	editor.visible = false
	editor.title_text = "DRAGON TEST · parts are free"
	editor.closed.connect(func() -> void: screen.set_editing(false))
	editor.board_changed.connect(func(slot: int) -> void: screen.on_board_changed(slot))
	layer.add_child(editor)

	screen.editing_changed.connect(_on_editing)
	screen.cleared.connect(func(one_cast: bool) -> void: hud.show_clear(one_cast))
	screen.floor_reset.connect(_on_floor_reset)
	Cues.fired.connect(_on_cue)

## See RaidView._unhandled_input: the editor consumes its own keys, R included.
func _unhandled_input(event: InputEvent) -> void:
	if screen == null or not is_instance_valid(screen):
		return
	if event.is_action_pressed("open_editor"):
		screen.set_editing(not screen.editing)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		screen.leave()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo() \
			and (event as InputEventKey).physical_keycode == KEY_R and not screen.editing:
		screen.reset_floor()
		get_viewport().set_input_as_handled()

func _on_editing(on: bool) -> void:
	if on:
		editor.weapon_id = screen.player.weapon_id
		editor.configure(screen.boards, screen.inventory, true, screen.player.runners)
		editor.visible = true
		editor.grab_focus()
	else:
		editor.visible = false
	# The read-outs share a layer with the editor and would sit on its header.
	hud.visible = not on

func _on_floor_reset() -> void:
	stains.clear()
	tape.rewind = Tape.REWIND
	hud.rewind()

## A guard's blood sprays away from the cut: the player has not been carried
## through yet when the death lands, so the lunge runs from them to the guard.
func _on_cue(name: StringName, d: Dictionary) -> void:
	if name != &"death" or screen == null or not is_instance_valid(screen):
		return
	if not (d.get("actor") is Enemy):
		return
	var pos: Vector2 = d.get("pos", Vector2.ZERO)
	var from := screen.player.global_position
	stains.add(pos, (pos - from).normalized() if pos.distance_to(from) > 1.0 else Vector2.RIGHT)

## Where the guards fell. Redrawn only when a splash is added or wiped.
class Stains extends Node2D:
	const DARK := Color(0.32, 0.02, 0.07)
	const WET := Color(0.62, 0.04, 0.12)
	const FRESH := Color(0.86, 0.1, 0.2)

	var splats: Array = []

	func add(pos: Vector2, dir: Vector2) -> void:
		splats.append({"p": pos, "d": dir, "seed": randi()})
		queue_redraw()

	func clear() -> void:
		splats.clear()
		queue_redraw()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		for s in splats:
			rng.seed = int(s["seed"])
			var p: Vector2 = s["p"]
			var d: Vector2 = s["d"]
			draw_circle(p, 9.0, DARK)
			for i in 18:
				var t := rng.randf()
				var q: Vector2 = p + d.rotated(rng.randf_range(-0.55, 0.55)) * (8.0 + t * 58.0) \
					+ Vector2(0.0, rng.randf_range(-4.0, 8.0))
				draw_circle(q, lerpf(6.0, 2.0, t), WET if i % 3 else FRESH)
			# A few runs down the wall under the splash.
			for i in 3:
				var x := p.x + d.x * rng.randf_range(10.0, 40.0)
				draw_rect(Rect2(x, p.y, 2.0, rng.randf_range(8.0, 22.0)), DARK)

## The glass the tape is watched through.
class Tape extends Control:
	const REWIND := 0.7
	const WASH := Color(0.2, 0.42, 1.0)

	var screen: DragonTest
	## Counts down while the tape rewinds.
	var rewind: float = 0.0

	func _ready() -> void:
		UiKit.fill_screen(self)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		UiKit.sync_screen(self)
		rewind = maxf(0.0, rewind - delta)
		queue_redraw()

	func _draw() -> void:
		var vp := size
		if screen != null and is_instance_valid(screen) and screen.player != null \
				and screen.player.charge > 0.0:
			var k := screen.player.charge_ratio()
			draw_rect(Rect2(Vector2.ZERO, vp), Color(WASH.r, WASH.g, WASH.b, 0.04 + 0.12 * k))
		if rewind > 0.0:
			var k := rewind / REWIND
			draw_rect(Rect2(Vector2.ZERO, vp), Color(0.12, 0.05, 0.22, 0.3 * k))
			for i in 7:
				draw_rect(Rect2(0.0, randf() * vp.y, vp.x, 2.0 + randf() * 8.0),
					Color(0.85, 0.85, 1.0, 0.22 * k))
		for y in range(0, int(vp.y), 4):
			draw_rect(Rect2(0.0, float(y), vp.x, 1.0), Color(0, 0, 0, 0.09))
		for i in 30:
			var k := float(i) / 30.0
			draw_rect(Rect2(Vector2(i, i) * 2.0, vp - Vector2(i, i) * 4.0),
				Color(0.02, 0.0, 0.05, 0.07 * (1.0 - k)), false, 2.0)
