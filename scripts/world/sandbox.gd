class_name Sandbox
extends Node2D

## A room where nothing is at stake. Parts are unlimited, boards are copies of
## the library, and the same skill can be tried on each weapon back to back so
## the differences between weapons are something you see rather than read.

signal exit_requested()

var room: Room
var player: Player
var camera: Camera2D
var editor: SkillEditor
var panel: Control
var boards: Array = []
var weapon_index: int = 0
var inventory: Dictionary = {}
var _dps_window: Array = []   ## [time, damage] pairs over the last few seconds
var _dps: float = 0.0
var _font: Font
var editing: bool = false

func _ready() -> void:
	_font = ThemeDB.fallback_font
	Fx.register_world(self)
	Audio.play_music()

	camera = Camera2D.new()
	camera.position = Vector2(Room.W * Room.CELL, Room.H * Room.CELL) * 0.5
	add_child(camera)
	camera.make_current()
	Fx.register_camera(camera)

	room = Room.new()
	add_child(room)
	var record := {"kind": "entry", "danger": 1, "region": 0, "variant": 7, "enemies": [], "loot": []}
	room.build(Vector2i.ZERO, record, {}, 12345)

	# Copies only: nothing here touches the hideout.
	boards.clear()
	for b in GameState.skill_library:
		boards.append(b.duplicate_board())
	if boards.is_empty():
		boards.append(Weapons.make_innate_board("SWORD"))
	boards = boards.slice(0, 4)

	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	player.room = room
	player.global_position = room.spawn_point()
	_apply_weapon()

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	editor = SkillEditor.new()
	editor.visible = false
	editor.title_text = "SANDBOX · parts are free"
	editor.closed.connect(_close_editor)
	editor.board_changed.connect(func(slot: int) -> void:
		player.rebuild_runner(slot)
		panel.invalidate())
	layer.add_child(editor)
	panel = SandboxPanel.new()
	panel.sandbox = self
	layer.add_child(panel)

	spawn_dummy()

func _apply_weapon() -> void:
	var ids := Weapons.ids()
	weapon_index = weapon_index % ids.size()
	player.setup(String(ids[weapon_index]), boards)
	player.max_health = 9999.0
	player.health = 9999.0

func cycle_weapon() -> void:
	weapon_index += 1
	_apply_weapon()
	if panel != null:
		panel.invalidate()
	Audio.play("ui")

func current_weapon() -> String:
	return player.weapon_id

func spawn_dummy() -> void:
	var e := Enemy.new()
	e.setup("DUMMY", 1, "")
	e.position = room.cell_center(28, 16)
	e.room = room
	e.collision_layer = 4
	e.collision_mask = 1
	e.damaged.connect(_on_damage)
	add_child(e)

func spawn_monster(kind: String) -> void:
	var e := Enemy.new()
	e.setup(kind, 2, "")
	e.position = room.cell_center(24 + randi() % 8, 10)
	e.room = room
	e.collision_layer = 4
	e.collision_mask = 1
	e.damaged.connect(_on_damage)
	add_child(e)

func clear_monsters() -> void:
	for c in get_children():
		if c is Enemy:
			c.queue_free()

func _on_damage(_a: Actor, amount: float) -> void:
	_dps_window.append([float(Time.get_ticks_msec()) / 1000.0, amount])

func _process(_delta: float) -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	_dps_window = _dps_window.filter(func(e: Array) -> bool: return now - float(e[0]) <= 3.0)
	var total := 0.0
	for e in _dps_window:
		total += float(e[1])
	_dps = total / 3.0


## See Raid._unhandled_input: the editor consumes its own close key.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_editor"):
		if editing:
			_close_editor()
		else:
			_open_editor()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		exit_requested.emit()
		get_viewport().set_input_as_handled()

func dps() -> float:
	return _dps

func _open_editor() -> void:
	editing = true
	editor.weapon_id = player.weapon_id
	editor.configure(boards, inventory, true, player.runners)
	editor.visible = true
	editor.grab_focus()
	player.input_locked = true
	# The bench controls share a canvas layer with the editor and would cover
	# the board. Nothing here is usable while assembling anyway.
	panel.visible = false

func _close_editor() -> void:
	editing = false
	editor.visible = false
	player.input_locked = false
	panel.visible = true

## Side panel with the controls a test bench needs.
class SandboxPanel extends Control:
	var sandbox: Sandbox
	var _font: Font
	var _sim: Array = []

	func invalidate() -> void:
		_sim.clear()

	func _ready() -> void:
		_font = ThemeDB.fallback_font
		UiKit.fill_screen(self)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := VBoxContainer.new()
		v.position = Vector2(20, 90)
		v.add_theme_constant_override("separation", 4)
		add_child(v)
		var wb := UiKit.overlay_button("SWAP WEAPON", UiKit.ACCENT)
		wb.pressed.connect(func() -> void: sandbox.cycle_weapon())
		v.add_child(wb)
		for kind in ["CRAWLER", "SENTRY", "LOBBER", "HOPPER", "DRIFTER", "WARDEN", "ARBITER"]:
			var b := UiKit.overlay_button("spawn %s" % Monsters.get_def(kind)["name"], UiKit.WARN)
			b.pressed.connect(func() -> void: sandbox.spawn_monster(kind))
			v.add_child(b)
		var db := UiKit.overlay_button("spawn dummy", UiKit.GOOD)
		db.pressed.connect(func() -> void: sandbox.spawn_dummy())
		v.add_child(db)
		var cb := UiKit.overlay_button("clear", UiKit.BAD)
		cb.pressed.connect(func() -> void: sandbox.clear_monsters())
		v.add_child(cb)
		var xb := UiKit.overlay_button("leave (ESC)")
		xb.pressed.connect(func() -> void: sandbox.exit_requested.emit())
		v.add_child(xb)

	func _process(_d: float) -> void:
		UiKit.sync_screen(self)
		queue_redraw()

	func _draw() -> void:
		if sandbox == null or sandbox.player == null:
			return
		var vp := get_viewport_rect().size
		draw_rect(Rect2(12, 16, 300, 62), Color(0.07, 0.08, 0.11, 0.85))
		draw_rect(Rect2(12, 16, 300, 62), Color(0.35, 0.5, 0.65, 0.6), false, 1.2)
		var wdef := Weapons.get_def(sandbox.current_weapon())
		draw_string(_font, Vector2(24, 38), "SANDBOX · %s" % String(wdef["name"]).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(wdef["color"]))
		draw_string(_font, Vector2(24, 58), "damage/sec (3s avg): %.1f" % sandbox.dps(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.GOOD)
		draw_string(_font, Vector2(24, 72), "TAB assemble · %s attacks · 1-3 arm · %s casts" % [
				Controls.short_label_for("attack"), Controls.short_label_for("cast_skill")],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.DIM)

		var x := 24.0
		var y := vp.y - 80.0
		for i in sandbox.player.runners.size():
			var r: SkillRunner = sandbox.player.runners[i]
			var armed := i == sandbox.player.selected_slot
			var card := Rect2(x, y, 150, 52)
			draw_rect(card, Color(0.10, 0.13, 0.17, 0.9) if armed else Color(0.07, 0.08, 0.11, 0.85))
			draw_string(_font, Vector2(x + 8, y + 18),
				"%s%d · %s" % ["▸ " if armed else "", i + 1, r.board.skill_name],
				HORIZONTAL_ALIGNMENT_LEFT, 138, 10, Color(1, 1, 1) if armed else UiKit.TEXT)
			while _sim.size() <= i:
				_sim.append({})
			if _sim[i].is_empty():
				var sim := SkillRunner.new(r.board)
				sim.base_payload_provider = func() -> Payload: return Weapons.base_payload(sandbox.current_weapon())
				_sim[i] = sim.simulate()
			var res: Dictionary = _sim[i]
			draw_string(_font, Vector2(x + 8, y + 34), "cycle %.2fs · out %d" % [
				float(res["cycle_seconds"]), (res["outputs"] as Array).size()],
				HORIZONTAL_ALIGNMENT_LEFT, 138, 10, UiKit.DIM)
			var border := Color(0.3, 0.35, 0.42)
			if r.active:
				border = Color(0.5, 0.9, 1.0)
			elif armed:
				border = Color(0.45, 0.95, 0.8)
			UiKit.draw_cooldown(self, card, r.ready_ratio(), r.ready_flash, border)
			x += 158.0
