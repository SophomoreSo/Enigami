class_name SandboxView
extends Node2D

## The bench's screen: camera, the readout panel with its spawn buttons, and
## the same assembly overlay the raid uses.

var sandbox: Sandbox
var camera: Camera2D
var pixels: PixelCamera
var editor: SkillEditor
var panel: SandboxPanel

func _ready() -> void:
	sandbox = get_parent() as Sandbox
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
	editor = SkillEditor.new()
	editor.visible = false
	editor.title_text = Loc.t("editor.title.sandbox")
	editor.closed.connect(func() -> void: sandbox.set_editing(false))
	editor.board_changed.connect(func(slot: int) -> void: sandbox.on_board_changed(slot))
	layer.add_child(editor)

	panel = SandboxPanel.new()
	panel.sandbox = sandbox
	layer.add_child(panel)

	sandbox.editing_changed.connect(_on_editing)
	sandbox.loadout_changed.connect(func() -> void: panel.invalidate())

## See RaidView._unhandled_input: the editor consumes its own close key.
func _unhandled_input(event: InputEvent) -> void:
	if sandbox == null or not is_instance_valid(sandbox):
		return
	if event.is_action_pressed("open_editor"):
		sandbox.set_editing(not sandbox.editing)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		sandbox.leave()
		get_viewport().set_input_as_handled()

func _on_editing(on: bool) -> void:
	if on:
		editor.weapon_id = sandbox.player.weapon_id
		editor.configure(sandbox.boards, sandbox.inventory, true, sandbox.player.runners)
		editor.visible = true
		editor.grab_focus()
	# The bench controls share a canvas layer with the editor and would cover
	# the board. Nothing there is usable while assembling anyway.
	else:
		editor.visible = false
	panel.visible = not on
