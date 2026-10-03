class_name JeanGreyTestView
extends Node2D

## The Jean Grey test's screen: the camera over the whole ground, the HUD, and
## the same assembly overlay the bench uses, for the rock's graph.

var screen: JeanGreyTest
var camera: Camera2D
var pixels: PixelCamera
var editor: SkillEditor
var hud: JeanGreyHud

func _ready() -> void:
	screen = get_parent() as JeanGreyTest
	camera = Camera2D.new()
	camera.position = Vector2(Room.W * Room.CELL, Room.H * Room.CELL) * 0.5
	add_child(camera)
	camera.make_current()
	Fx.register_camera(camera)
	pixels = PixelCamera.new()
	add_child(pixels)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = JeanGreyHud.new()
	hud.screen = screen
	layer.add_child(hud)
	editor = SkillEditor.new()
	editor.visible = false
	editor.closed.connect(func() -> void: screen.set_editing(false))
	editor.board_changed.connect(func() -> void: screen.on_board_changed())
	layer.add_child(editor)

	screen.editing_changed.connect(_on_editing)
	screen.stolen.connect(func(seconds: float) -> void: hud.show_stolen(seconds))
	screen.fell.connect(func() -> void: hud.show_fell())
	screen.floor_reset.connect(func() -> void: hud.again())

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
		editor.weapon_id = JeanGreyTest.WEAPON
		editor.configure(screen.board, screen.inventory, true,
			screen.player.runner if screen.player != null and is_instance_valid(screen.player) else null)
		editor.visible = true
		editor.grab_focus()
	else:
		editor.visible = false
	# The read-outs share a layer with the editor and would sit on its header.
	hud.visible = not on
