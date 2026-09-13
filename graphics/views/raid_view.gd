class_name RaidView
extends Node2D

## Everything a raid puts on the screen: the camera that follows it, the HUD,
## and the assembly overlay.
##
## It pulls from the raid every frame rather than being pushed at. The raid
## therefore has no HUD to update and no editor to configure — it just runs,
## and this reads it.

var raid: Raid
var camera: Camera2D
var pixels: PixelCamera
var hud: Hud
var editor: SkillEditor

func _ready() -> void:
	raid = get_parent() as Raid
	camera = Camera2D.new()
	camera.position = Vector2(Room.W * Room.CELL, Room.H * Room.CELL) * 0.5
	camera.zoom = Vector2.ONE
	add_child(camera)
	camera.make_current()
	Fx.register_camera(camera)
	pixels = PixelCamera.new()
	add_child(pixels)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)

	editor = SkillEditor.new()
	editor.visible = false
	editor.title_text = "ASSEMBLY · raid running"
	editor.closed.connect(func() -> void: raid.set_editing(false))
	editor.board_changed.connect(func(slot: int) -> void: raid.on_board_changed(slot))
	layer.add_child(editor)

	raid.noticed.connect(func(text: String) -> void: hud.show_toast(text))
	raid.editing_changed.connect(_on_editing)

func _process(_delta: float) -> void:
	if raid == null or not is_instance_valid(raid):
		return
	hud.player = raid.player
	hud.map = raid.map
	hud.room = raid.room
	hud.prompt = raid.prompt
	hud.extract_ratio = raid.extract_ratio
	hud.tutorial = raid.tutorial_text()

## Event-driven rather than polled: when the editor consumes TAB to close
## itself, this must not see the same press and open it straight back up.
func _unhandled_input(event: InputEvent) -> void:
	if raid == null or raid.ended:
		return
	if event.is_action_pressed("open_editor"):
		raid.set_editing(not raid.editing)
		get_viewport().set_input_as_handled()

func _on_editing(on: bool) -> void:
	if on:
		editor.weapon_id = raid.player.weapon_id
		editor.configure(GameState.raid_boards, GameState.raid_bag, false, raid.player.runners)
		editor.visible = true
		editor.grab_focus()
	else:
		editor.visible = false
