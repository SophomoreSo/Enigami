extends Node

## Top-level state machine: title → hideout → raid → results, with the opening
## scene in front of a new profile's first hideout, the sandbox (and the dragon
## test off it), and the hideout's skill editor hanging off the side.
##
## The composition root, and the only script allowed to know both modules: it
## builds screens out of `graphics/` and drives them with `feature/`. Neither
## module reaches the other except through here and through `Cues`.

enum State { TITLE, HIDEOUT, RAID, SANDBOX, RESULTS, DRAGON_TEST, INTRO }

var state: int = State.TITLE
var current: Node = null
var ui_layer: CanvasLayer
var overlay_layer: CanvasLayer
var editor: SkillEditor = null
var pause_menu: Control = null
var hideout_ref: Hideout = null

func _ready() -> void:
	randomize()
	Controls.load_saved()
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 20
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)
	_build_pause_menu()
	UiKit.fill_screen(pause_menu)
	goto_title()

func _clear() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = null
	_close_editor()
	TimeCtl.clear()

## --- screens ----------------------------------------------------------------
func goto_title() -> void:
	_clear()
	state = State.TITLE
	var t := TitleScreen.new()
	t.start_requested.connect(_start_game)
	t.sandbox_requested.connect(goto_sandbox)
	ui_layer.add_child(t)
	current = t

## START, once a save slot has been picked. A profile that has never been
## played gets the prologue first; every start after that goes straight in.
func _start_game() -> void:
	if GameState.intro_seen:
		goto_hideout()
	else:
		goto_intro()

## The opening scene, read out of `data/scenes/intro.json`. It is a world node
## rather than a Control: it has a floor, a cast that walks on it and a camera
## over the top, and only its narration panel is a screen.
func goto_intro() -> void:
	_clear()
	state = State.INTRO
	var c := Cutscene.new()
	c.scene_id = "intro"
	c.finished.connect(_intro_finished)
	# Set before the node enters the tree: a scene whose file is missing is over
	# inside `_ready`, and the handler below must find the screen it built.
	current = c
	add_child(c)

func _intro_finished() -> void:
	GameState.mark_intro_seen()
	goto_hideout()

func goto_hideout() -> void:
	_clear()
	state = State.HIDEOUT
	var h := Hideout.new()
	h.deploy_requested.connect(_deploy)
	h.sandbox_requested.connect(goto_sandbox)
	h.title_requested.connect(goto_title)
	h.edit_requested.connect(_edit_library_skill)
	ui_layer.add_child(h)
	current = h
	hideout_ref = h

func goto_sandbox() -> void:
	_clear()
	state = State.SANDBOX
	var s := Sandbox.new()
	s.exit_requested.connect(goto_hideout)
	s.dragon_test_requested.connect(goto_dragon_test)
	add_child(s)
	current = s

## Leaving the dragon test goes back to the sandbox it was opened from.
func goto_dragon_test() -> void:
	_clear()
	state = State.DRAGON_TEST
	var d := DragonTest.new()
	d.exit_requested.connect(goto_sandbox)
	add_child(d)
	current = d

func _deploy(weapon: String, slots: Array) -> void:
	GameState.deploy(weapon, slots)
	_clear()
	state = State.RAID
	var r := Raid.new()
	r.finished.connect(_raid_finished)
	add_child(r)
	current = r

func _raid_finished(result: String, payload: Dictionary) -> void:
	_clear()
	state = State.RESULTS
	var rs := ResultsScreen.new()
	rs.outcome = result
	rs.payload = payload
	rs.continued.connect(goto_hideout)
	ui_layer.add_child(rs)
	current = rs

## --- hideout skill editing --------------------------------------------------
func _edit_library_skill(index: int) -> void:
	if index < 0 or index >= GameState.skill_library.size():
		return
	_close_editor()
	editor = SkillEditor.new()
	editor.title_text = "WORKBENCH · parts from stash"
	editor.weapon_id = hideout_ref.weapon_id if hideout_ref != null else "SWORD"
	editor.configure([GameState.skill_library[index]], GameState.stash, false, [])
	editor.closed.connect(_close_editor)
	editor.board_changed.connect(func(_s: int) -> void: GameState.save_game())
	overlay_layer.add_child(editor)
	editor.grab_focus()

func _close_editor() -> void:
	if editor != null and is_instance_valid(editor):
		editor.queue_free()
		GameState.save_game()
		if state == State.HIDEOUT and hideout_ref != null and is_instance_valid(hideout_ref):
			hideout_ref.rebuild()
	editor = null

## --- pause ------------------------------------------------------------------
func _build_pause_menu() -> void:
	pause_menu = Control.new()
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(dim)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pause_menu.add_child(UiKit.screen_scroll(v, Vector2(430, 36), 470.0))
	v.add_child(UiKit.title("PAUSED"))
	v.add_child(UiKit.spacer(6))
	var resume := UiKit.button("RESUME", UiKit.GOOD)
	resume.custom_minimum_size = Vector2(280, 40)
	resume.pressed.connect(_unpause)
	v.add_child(resume)
	v.add_child(_vol_row("Music", func() -> float: return Audio.music_volume, func(x: float) -> void: Audio.set_music_volume(x)))
	v.add_child(_vol_row("Sound", func() -> float: return Audio.sfx_volume, func(x: float) -> void: Audio.set_sfx_volume(x)))
	v.add_child(UiKit.spacer(6))
	var cp := ControlsPanel.new()
	cp.custom_minimum_size = Vector2(420, 0)
	v.add_child(cp)
	v.add_child(UiKit.spacer(8))
	var abandon := UiKit.button("ABANDON RAID — forfeits the kit", UiKit.BAD)
	abandon.custom_minimum_size = Vector2(280, 36)
	abandon.pressed.connect(func() -> void:
		_unpause()
		if state == State.RAID:
			var lost := GameState.die()
			_raid_finished("died", lost))
	v.add_child(abandon)
	overlay_layer.add_child(pause_menu)

func _vol_row(name: String, getter: Callable, setter: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UiKit.label(name, 12)
	l.custom_minimum_size = Vector2(70, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = getter.call()
	s.custom_minimum_size = Vector2(200, 18)
	s.value_changed.connect(setter)
	h.add_child(s)
	return h

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if state == State.RAID:
		if get_tree().paused:
			_unpause()
		else:
			_pause()
		get_viewport().set_input_as_handled()

func _pause() -> void:
	get_tree().paused = true
	pause_menu.visible = true
	Audio.play("ui")

func _unpause() -> void:
	get_tree().paused = false
	pause_menu.visible = false
