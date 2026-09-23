class_name RaidView
extends Node2D

## Everything a raid puts on the screen: the camera that follows it, the HUD,
## the assembly overlay and the map window.
##
## It pulls from the raid every frame rather than being pushed at. The raid
## therefore has no HUD to update and no editor to configure — it just runs,
## and this reads it.

var raid: Raid
var camera: Camera2D
var pixels: PixelCamera
var hud: Hud
var editor: SkillEditor
var map_panel: MapPanel

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
	editor.closed.connect(func() -> void: raid.set_editing(false))
	editor.board_changed.connect(func(slot: int) -> void: raid.on_board_changed(slot))
	layer.add_child(editor)

	map_panel = MapPanel.new()
	map_panel.visible = false
	map_panel.closed.connect(func() -> void: raid.set_reading_map(false))
	layer.add_child(map_panel)

	raid.noticed.connect(func(text: String) -> void: hud.show_toast(text))
	raid.editing_changed.connect(_on_editing)
	raid.reading_map_changed.connect(_on_reading_map)

func _process(_delta: float) -> void:
	if raid == null or not is_instance_valid(raid):
		return
	hud.player = raid.player
	hud.prompt = raid.prompt
	hud.extract_ratio = raid.extract_ratio
	map_panel.map = raid.map
	map_panel.room = raid.room

## Event-driven rather than polled: when the editor consumes TAB to close
## itself, this must not see the same press and open it straight back up.
func _unhandled_input(event: InputEvent) -> void:
	if raid == null or raid.ended:
		return
	if event.is_action_pressed("open_editor"):
		raid.set_editing(not raid.editing)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_map"):
		# Only ever opened from here: the window itself consumes the same press
		# to close, so this never sees the one that puts it away.
		raid.set_reading_map(true)
		get_viewport().set_input_as_handled()

func _on_editing(on: bool) -> void:
	if on:
		editor.weapon_id = raid.player.weapon_id
		editor.configure(GameState.raid_boards, GameState.raid_bag, false, raid.player.runners)
		editor.visible = true
		editor.grab_focus()
	else:
		editor.visible = false

func _on_reading_map(on: bool) -> void:
	map_panel.visible = on
