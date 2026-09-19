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
## The pause menu's two ways out. Which one is on screen depends on where it was
## opened from; see `_pause`.
var pause_abandon: Button = null
var pause_leave: Button = null
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
	# The pause menu is built once and outlives every screen, so it is the one
	# thing a language switch on the title screen cannot reach by itself.
	Loc.language_changed.connect(_rebuild_pause_menu)
	goto_title()

func _rebuild_pause_menu(_lang: String) -> void:
	var was_open: bool = pause_menu != null and pause_menu.visible
	if pause_menu != null and is_instance_valid(pause_menu):
		overlay_layer.remove_child(pause_menu)
		pause_menu.queue_free()
	_build_pause_menu()
	UiKit.fill_screen(pause_menu)
	pause_menu.visible = was_open

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
	h.title_requested.connect(goto_title)
	h.edit_requested.connect(_edit_library_skill)
	ui_layer.add_child(h)
	current = h
	hideout_ref = h

## The bench is opened from the title and hands back to it. It used to hand back
## to the hideout, which was where it was opened from; with no way into it from
## there any more, that left it emptying into a screen nobody had asked for —
## and one showing whatever profile happened to be loaded, since the bench is
## reached without picking a save slot at all.
func goto_sandbox() -> void:
	_clear()
	state = State.SANDBOX
	var s := Sandbox.new()
	s.exit_requested.connect(goto_title)
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
	editor.title_text = Loc.t("editor.title.workbench")
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

## The menu keeps running while the tree is stopped, which makes it the only
## thing that can still hear the key that would start it again: everything else,
## `Game` included, is paused along with the screen underneath, so the press
## that opens the menu cannot be the press that closes it.
class PauseMenu extends Control:
	var game: Node
	func _unhandled_input(event: InputEvent) -> void:
		if not visible or not event.is_action_pressed("pause"):
			return
		if game != null and is_instance_valid(game):
			game._unpause()
		get_viewport().set_input_as_handled()

## In UiKit's pixel look, like the title's settings — the same rows, the same
## rebinding list — because it is the same menu reached from inside a raid, and
## the raid behind it is pixel art.
##
## On a panel of its own, and an opaque one. The raid goes on drawing behind the
## pause menu: it is stopped, so a toast caught mid-life stays where it was, and
## with nothing behind the rows its words came through them — through the RESUME
## button most of all, whose hover fill is a wash of colour rather than a solid.
func _build_pause_menu() -> void:
	pause_menu = PauseMenu.new()
	(pause_menu as PauseMenu).game = self
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(dim)
	# The pixel face runs up to twice as wide as the one this menu was laid out
	# for, and the rebinding list is two columns of it: 600 holds them, as it
	# does on the title, and the scroll adds its bar.
	var panel := UiKit.panel(UiKit.PANEL, Color(0.22, 0.3, 0.38), true)
	panel.custom_minimum_size = Vector2(600, 0)
	var scroll := UiKit.screen_scroll(panel, Vector2(336, 36), 608.0)
	UiKit.pixel_scroll(scroll)
	pause_menu.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UiKit.title(Loc.t("menu.pause.heading"), 24, true))
	v.add_child(UiKit.hline(true))
	var resume := UiKit.button(Loc.t("menu.pause.resume"), UiKit.GOOD, true)
	resume.custom_minimum_size = Vector2(280, 40)
	resume.pressed.connect(_unpause)
	v.add_child(resume)
	v.add_child(_vol_row(Loc.t("menu.pause.music"), func() -> float: return Audio.music_volume, func(x: float) -> void: Audio.set_music_volume(x)))
	v.add_child(_vol_row(Loc.t("menu.pause.sound"), func() -> float: return Audio.sfx_volume, func(x: float) -> void: Audio.set_sfx_volume(x)))
	v.add_child(UiKit.spacer(6))
	var cp := ControlsPanel.new()
	cp.pixel = true
	v.add_child(cp)
	v.add_child(UiKit.spacer(8))
	# The way out, which is not the same act on every screen: forfeiting a raid
	# costs the kit, and stepping off the bench costs nothing. Two buttons
	# rather than one that changes its words, because they are different
	# colours as well as different sentences — `_pause` shows the right one.
	pause_abandon = UiKit.button(Loc.t("menu.pause.abandon"), UiKit.BAD, true)
	pause_abandon.custom_minimum_size = Vector2(280, 36)
	pause_abandon.pressed.connect(func() -> void:
		_unpause()
		if state == State.RAID:
			var lost := GameState.die()
			_raid_finished("died", lost))
	v.add_child(pause_abandon)
	pause_leave = UiKit.button(Loc.t("menu.pause.leave"), UiKit.ACCENT, true)
	pause_leave.custom_minimum_size = Vector2(280, 36)
	pause_leave.pressed.connect(func() -> void:
		_unpause()
		if current != null and is_instance_valid(current) and current.has_method("leave"):
			current.leave())
	v.add_child(pause_leave)
	overlay_layer.add_child(pause_menu)

func _vol_row(name: String, getter: Callable, setter: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UiKit.label(name, 16, UiKit.TEXT, true)
	l.custom_minimum_size = Vector2(80, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = getter.call()
	s.custom_minimum_size = Vector2(240, 20)
	UiKit.pixel_slider(s)
	s.value_changed.connect(setter)
	h.add_child(s)
	return h

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	# Every screen that is played rather than clicked through: a raid, and the
	# bench. Menus have their own way back and do not want a second one over
	# the top of them.
	if get_tree().paused:
		return      # the menu itself answers this one; see PauseMenu above
	if state == State.RAID or state == State.SANDBOX:
		_pause()
		get_viewport().set_input_as_handled()

func _pause() -> void:
	var in_raid := state == State.RAID
	pause_abandon.visible = in_raid
	pause_leave.visible = not in_raid
	get_tree().paused = true
	pause_menu.visible = true
	Audio.play("ui")

func _unpause() -> void:
	get_tree().paused = false
	pause_menu.visible = false
