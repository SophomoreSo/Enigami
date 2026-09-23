class_name SandboxView
extends Node2D

## The bench's screen: camera, the raid's own HUD, the drawer of bench tools,
## and the same assembly overlay the raid uses.

var sandbox: Sandbox
var camera: Camera2D
var pixels: PixelCamera
var hud: Hud
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
	# The raid's readout, the same as in a raid: a skill tried here should read
	# the way it will once it is carried.
	hud = Hud.new()
	layer.add_child(hud)
	editor = SkillEditor.new()
	editor.visible = false
	editor.closed.connect(func() -> void: sandbox.set_editing(false))
	editor.board_changed.connect(func(slot: int) -> void: sandbox.on_board_changed(slot))
	layer.add_child(editor)

	panel = SandboxPanel.new()
	panel.sandbox = sandbox
	layer.add_child(panel)

	sandbox.editing_changed.connect(_on_editing)

func _process(_delta: float) -> void:
	if sandbox == null or not is_instance_valid(sandbox):
		return
	hud.player = sandbox.player
	# No map here and nothing to extract from: the line along the bottom names
	# the keys the room answers to, which are the hideout's.
	hud.footer = Loc.t("hud.footer_lobby")

## See RaidView._unhandled_input: the editor consumes its own close key.
func _unhandled_input(event: InputEvent) -> void:
	if sandbox == null or not is_instance_valid(sandbox):
		return
	if event.is_action_pressed("open_editor"):
		sandbox.set_editing(not sandbox.editing)
		get_viewport().set_input_as_handled()
	# Pause is deliberately not taken here. It used to walk straight out of the
	# bench, which meant a press people expect to stop the game for a moment
	# instead threw the screen away and left them in the hideout. `app/game.gd`
	# has it now, and puts the pause menu up the way it does in a raid.

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
