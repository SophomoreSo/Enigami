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
## The console on the glass, and the layer it is drawn on: over the game and
## every window the game opens, under the pause menu, which replaces it.
var touch_layer: CanvasLayer
var touch_pad: TouchPad = null
var editor: SkillEditor = null
var pause_menu: Control = null
## The pause menu's two pages: PAUSED, and the rebinding list behind its
## CONTROL SETTINGS button. Exactly one of them is on screen; see
## `_pause_controls`.
var pause_main: Control = null
var pause_general: Control = null
var pause_controls: Control = null
## The pause menu's three ways out. Exactly one is on screen, and which one
## depends on where the menu was opened from; see `_pause`.
var pause_abandon: Button = null
## MAIN MENU. It goes to the title from wherever it is pressed, so it is one
## button rather than a word-swap per screen — see `_pause` for which screens
## offer it. In a raid it is `pause_park` instead, which says what it costs
## (nothing) and is a different act (the run is written down, not ended).
var pause_title: Button = null
var pause_park: Button = null
var hideout_ref: HideoutWorld = null

func _ready() -> void:
	randomize()
	Controls.load_saved()
	Touch.load_saved()
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 20
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)
	_build_touch_pad()
	_build_pause_menu()
	UiKit.fill_screen(pause_menu)
	# The pause menu is built once and outlives every screen, so it is the one
	# thing a language switch on the title screen cannot reach by itself.
	Loc.language_changed.connect(_rebuild_pause_menu)
	goto_title()

func _rebuild_pause_menu(_lang: String) -> void:
	var was_open: bool = pause_menu != null and pause_menu.visible
	# Which page was up, not just whether the menu was. The language switch is
	# on the general page, so a rebuild that always landed on PAUSED would throw
	# the player out of the page they were standing in to press it.
	var was_general: bool = pause_general != null and pause_general.visible
	var was_controls: bool = pause_controls != null and pause_controls.visible
	if pause_menu != null and is_instance_valid(pause_menu):
		overlay_layer.remove_child(pause_menu)
		pause_menu.queue_free()
	_build_pause_menu()
	UiKit.fill_screen(pause_menu)
	pause_menu.visible = was_open
	if was_open and (was_general or was_controls):
		pause_main.visible = false
		pause_general.visible = was_general
		pause_controls.visible = was_controls
	_pause_exits()

## --- the console on the glass ------------------------------------------------

## Built once and outliving every screen, like the pause menu: a phone has the
## same controls in a raid, on the hideout floor and at the bench, and no screen
## should have to know that. Whether it is on the screen at all is the setting's
## answer and the pad asks it itself; what is on it is the question below.
func _build_touch_pad() -> void:
	touch_layer = CanvasLayer.new()
	touch_layer.layer = 15
	touch_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(touch_layer)
	touch_pad = TouchPad.new()
	touch_layer.add_child(touch_pad)

func _process(_delta: float) -> void:
	if touch_pad != null and is_instance_valid(touch_pad):
		touch_pad.face = _touch_face()

## Which keys the pad shows. The shell answers because the shell is the one
## thing that knows both what screen is up and who has the controls.
##
## A scene has no player to ask — the prologue is a cast and a camera — and it
## turns its own pages on `interact`, so it wears the same face a conversation
## does. A screen that has taken the controls keeps only the keys that close it
## again: the map is opened and shut with the same key, and on a phone that key
## is on the pad or it is nowhere.
func _touch_face() -> int:
	if state == State.INTRO:
		return TouchPad.Face.TALK
	for p in get_tree().get_nodes_in_group("player"):
		if not p.controls_locked():
			return TouchPad.Face.PLAY
		return TouchPad.Face.TALK if p.talk_locked else TouchPad.Face.SCREEN
	return TouchPad.Face.NONE

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

## START, once a save slot has been picked. A slot put down mid-raid walks
## straight back into that raid — before the prologue check, since a profile
## deep enough in to be carrying a kit has long since seen it. A profile that
## has never been played gets the prologue; every start after that goes to the
## hideout.
func _start_game() -> void:
	if GameState.has_parked_raid():
		_resume_raid()
	elif GameState.intro_seen:
		# A raid the app was closed on rather than parked cannot be walked back
		# into. The kit went with it, as it always has.
		GameState.drop_unparked_raid()
		goto_hideout()
	else:
		goto_intro()

## The raid the slot was put down in. `Raid` reads the parked run out of
## `GameState` itself, the same way it reads the kit — deploying and resuming
## differ in what is already there, not in how the raid is built.
func _resume_raid() -> void:
	_clear()
	state = State.RAID
	var r := Raid.new()
	r.finished.connect(_raid_finished)
	add_child(r)
	current = r

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

## Between raids, as a room you stand in: the weapon rack, the workbench, the
## counter and the gate are places you walk to. The panels behind them are the
## columns the old screen showed all at once — `graphics/ui/hideout.gd` still
## owns what is in them — and the view opens them.
##
## It is a world node rather than a Control, like the bench and the raid, so it
## is added to the tree rather than to `ui_layer` and gets its view from `Views`.
func goto_hideout() -> void:
	_clear()
	state = State.HIDEOUT
	var h := HideoutWorld.new()
	h.deploy_requested.connect(_deploy)
	h.title_requested.connect(goto_title)
	h.edit_requested.connect(_edit_library_skill)
	h.assembly_requested.connect(_edit_kit)
	add_child(h)
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
## One board, picked off the bench's library list by its EDIT button.
func _edit_library_skill(index: int) -> void:
	if index < 0 or index >= GameState.skill_library.size():
		return
	_open_boards([GameState.skill_library[index]])

## The armed kit, opened with the key a raid opens assembly with. Tabs, one per
## slot, the same way the raid shows the boards it carries — and the same boards
## the bench edits one at a time, so this is that reached without the walk.
func _edit_kit() -> void:
	if hideout_ref == null or not is_instance_valid(hideout_ref):
		return
	var boards: Array = hideout_ref.armed_boards()
	if boards.is_empty():
		return
	_open_boards(boards)

## The workbench editor over whatever boards it is given, spending the stash.
func _open_boards(boards: Array) -> void:
	_close_editor()
	editor = SkillEditor.new()
	editor.title_text = Loc.t("editor.title.workbench")
	editor.weapon_id = hideout_ref.weapon_id if hideout_ref != null else "SWORD"
	editor.configure(boards, GameState.stash, false, [])
	editor.closed.connect(_close_editor)
	editor.board_changed.connect(func(_s: int) -> void: GameState.save_game())
	overlay_layer.add_child(editor)
	editor.grab_focus()

func _close_editor() -> void:
	if editor != null and is_instance_valid(editor):
		editor.queue_free()
		GameState.save_game()
		# The board that came back may have a different name and different tags
		# on it, and the bench's panel is showing the old ones.
		if state == State.HIDEOUT and hideout_ref != null and is_instance_valid(hideout_ref):
			# And the player in the room is carrying it, so the HUD is showing
			# the board as it was before it went in.
			hideout_ref.refresh_kit()
			hideout_ref.refresh_panel()
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
			# One level at a time: from a page behind PAUSED the key goes back
			# to PAUSED, the way that page's BACK button does, rather than
			# dropping straight into a raid the player cannot see behind it.
			if game.pause_general != null and game.pause_general.visible:
				game._pause_general(false)
			elif game.pause_controls != null and game.pause_controls.visible:
				game._pause_controls(false)
			else:
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
##
## Three pages, not one. The rebinding list is fifteen rows of two columns,
## which is longer than everything else on the menu put together: inline, it
## pushed the way out so far down that the menu was a scrollbar with a RESUME
## button at the top. It sits behind CONTROL SETTINGS instead, on a page of its
## own, and the volumes sit behind GENERAL SETTINGS on another — the same two
## pages the title's settings keep, reached the same way, so the menu the player
## pauses into is the menu they already know.
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
	# does on the title, and the frame adds its bar.
	var frame := UiKit.screen_frame(608.0, 36.0, 28.0, true)
	pause_menu.add_child(frame)
	pause_main = frame
	frame.head.add_child(_pause_heading(Loc.t("menu.pause.heading"), _unpause))
	frame.head.add_child(UiKit.hline(true))
	var to_general := UiKit.button(Loc.t("menu.pause.general"), UiKit.ACCENT, true)
	to_general.custom_minimum_size = Vector2(280, 36)
	to_general.pressed.connect(func() -> void: _pause_general(true))
	frame.rows.add_child(to_general)
	var to_controls := UiKit.button(Loc.t("controls.open"), UiKit.ACCENT, true)
	to_controls.custom_minimum_size = Vector2(280, 36)
	to_controls.pressed.connect(func() -> void: _pause_controls(true))
	frame.rows.add_child(to_controls)
	# The ways out of the menu, gathered at the bottom and ordered by what they
	# cost: back into the game, out to the title, and last the one that forfeits
	# a raid — its own act and its own colour, so it stays its own button. They
	# sit in the frame's foot, which is pinned: whatever is added to this menu
	# above them, they stay on the screen.
	#
	# Everywhere but a raid, leaving is leaving, and the button says where it
	# lands rather than what it is walking out of. The bench used to word it
	# LEAVE THE BENCH, which was the same act under a name that did not say
	# where it went. `_pause` shows whichever of these apply.
	frame.foot.add_child(UiKit.spacer(8))
	var resume := UiKit.button(Loc.t("menu.pause.resume"), UiKit.GOOD, true)
	resume.custom_minimum_size = Vector2(280, 40)
	resume.pressed.connect(_unpause)
	frame.foot.add_child(resume)
	pause_title = UiKit.button(Loc.t("menu.pause.title"), UiKit.ACCENT, true)
	pause_title.custom_minimum_size = Vector2(280, 36)
	pause_title.pressed.connect(func() -> void:
		_unpause()
		goto_title())
	frame.foot.add_child(pause_title)
	# The same destination from inside a raid, and the raid survives it: the run
	# is written into the save slot as it stands and walked back into when that
	# slot is opened again. It is the only way out of a raid that costs nothing,
	# which is why it says so on it.
	pause_park = UiKit.button(Loc.t("menu.pause.park"), UiKit.ACCENT, true)
	pause_park.custom_minimum_size = Vector2(280, 36)
	pause_park.pressed.connect(func() -> void:
		_unpause()
		if state == State.RAID and current != null and is_instance_valid(current):
			GameState.park_raid((current as Raid).park())
		goto_title())
	frame.foot.add_child(pause_park)
	pause_abandon = UiKit.button(Loc.t("menu.pause.abandon"), UiKit.BAD, true)
	pause_abandon.custom_minimum_size = Vector2(280, 36)
	pause_abandon.pressed.connect(func() -> void:
		_unpause()
		if state == State.RAID:
			var lost := GameState.die()
			_raid_finished("died", lost))
	frame.foot.add_child(pause_abandon)
	_build_pause_general()
	_build_pause_controls()
	overlay_layer.add_child(pause_menu)

## The page behind GENERAL SETTINGS: the volumes, the language, and the way back
## to PAUSED. The same three the title's settings hold, since this is the same
## menu reached from inside a game.
##
## A language switched here has to reach everything already on screen. Most of
## it costs nothing — the HUD and the bench's readout write their words in
## `_draw` and so are in whatever language is on by the next frame — and what is
## left is the handful of places that write once: this menu (`_rebuild_pause_menu`),
## the bench's buttons, and the hideout's signs. Each rebuilds itself on the
## signal.
func _build_pause_general() -> void:
	var frame := UiKit.screen_frame(608.0, 36.0, 28.0, true)
	frame.visible = false
	pause_general = frame
	pause_menu.add_child(frame)
	frame.head.add_child(_pause_heading(Loc.t("menu.pause.general"),
		func() -> void: _pause_general(false)))
	frame.head.add_child(UiKit.hline(true))
	frame.rows.add_child(_vol_row(Loc.t("menu.pause.music"), func() -> float: return Audio.music_volume, func(x: float) -> void: Audio.set_music_volume(x)))
	frame.rows.add_child(_vol_row(Loc.t("menu.pause.sound"), func() -> float: return Audio.sfx_volume, func(x: float) -> void: Audio.set_sfx_volume(x)))
	frame.rows.add_child(_pause_language_row())
	for row in VideoRows.rows():
		frame.rows.add_child(row)
	frame.foot.add_child(UiKit.spacer(8))
	var back := UiKit.button(Loc.t("menu.pause.back"), UiKit.ACCENT, true)
	back.custom_minimum_size = Vector2(280, 36)
	back.pressed.connect(func() -> void: _pause_general(false))
	frame.foot.add_child(back)

## The second page: the rebinding list, and the way back to the first. Built as
## a sibling frame rather than a panel swapped into the first one, so each page
## scrolls on its own and neither inherits the other's scroll position.
##
## Fifteen rows of two columns is longer than the screen on any window worth
## the name, so this is the page that shows what the frame is for: the list
## scrolls and the heading and the way back off it do not move.
func _build_pause_controls() -> void:
	var frame := UiKit.screen_frame(608.0, 36.0, 28.0, true)
	frame.visible = false
	pause_controls = frame
	pause_menu.add_child(frame)
	frame.head.add_child(_pause_heading(Loc.t("controls.open"),
		func() -> void: _pause_controls(false)))
	frame.head.add_child(UiKit.hline(true))
	var cp := ControlsPanel.new()
	cp.pixel = true
	frame.rows.add_child(cp)
	frame.foot.add_child(UiKit.spacer(8))
	var back := UiKit.button(Loc.t("controls.back"), UiKit.ACCENT, true)
	back.custom_minimum_size = Vector2(280, 36)
	back.pressed.connect(func() -> void: _pause_controls(false))
	frame.foot.add_child(back)

## Which of the pause menu's pages is on screen. Only one ever is: `page` is
## the one to show, or null for PAUSED itself.
func _pause_page(page: Control) -> void:
	pause_main.visible = page == null
	pause_general.visible = page == pause_general
	pause_controls.visible = page == pause_controls
	Audio.play("ui")

func _pause_general(on: bool) -> void:
	_pause_page(pause_general if on else null)

func _pause_controls(on: bool) -> void:
	_pause_page(pause_controls if on else null)

## A page's heading, with the way back out of it on its left: one press of the
## arrow is one level up, which on PAUSED itself is back into the game. Every
## page here has one, so the top-left corner always means the same thing.
func _pause_heading(text: String, back: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var arrow := UiKit.button(Loc.t("menu.pause.arrow"), UiKit.ACCENT, true)
	arrow.custom_minimum_size = Vector2(44, 34)
	arrow.pressed.connect(back)
	h.add_child(arrow)
	h.add_child(UiKit.title(text, 24, true))
	return h

## One button per language, written in itself, like the title's. Switching is a
## rebuild of everything holding words — see `_build_pause_general` — and this
## menu is one of them, so the button pressed is freed by its own press.
func _pause_language_row() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UiKit.label(Loc.t("menu.pause.language"), 16, UiKit.TEXT, true)
	l.custom_minimum_size = Vector2(UiKit.SETTING_LABEL_W, 0)
	h.add_child(l)
	for lang in Loc.languages():
		var picked: bool = lang == Loc.language
		var b := UiKit.button(Loc.language_name(lang),
			UiKit.ACCENT if picked else UiKit.DIM, true)
		if picked:
			UiKit.mark_chosen(b)
		b.pressed.connect(func() -> void:
			Audio.play("ui")
			Loc.set_language(lang))
		h.add_child(b)
	return h

func _vol_row(name: String, getter: Callable, setter: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UiKit.label(name, 16, UiKit.TEXT, true)
	l.custom_minimum_size = Vector2(UiKit.SETTING_LABEL_W, 0)
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
	# Every screen the player lives on: a raid, the bench, and the hideout —
	# which is a menu, but the one they stand in between raids, and the place
	# they are most likely to want the volume or a rebind from. The title and
	# the screens hanging off it have their own way back and do not want a
	# second one over the top of them. The workbench raised over the hideout
	# needs no guard here: it answers ESC by closing, and marks the press
	# handled, so this never sees the one that shut it.
	if get_tree().paused:
		return      # the menu itself answers this one; see PauseMenu above
	if state == State.RAID or state == State.SANDBOX or state == State.HIDEOUT:
		_pause()
		get_viewport().set_input_as_handled()

func _pause() -> void:
	_pause_exits()
	# Always on PAUSED, however it was left last time.
	pause_main.visible = true
	pause_general.visible = false
	pause_controls.visible = false
	get_tree().paused = true
	pause_menu.visible = true
	Audio.play("ui")

## Which ways out this screen offers. A raid forfeits or parks; everywhere else
## leaving is leaving, and lands on the title — the bench and the dragon test as
## surely as the hideout, and the dragon test had no way out of its pause menu
## at all. Called on opening the menu and after a rebuild, which is a new set of
## buttons that have never been told.
func _pause_exits() -> void:
	if pause_abandon == null or not is_instance_valid(pause_abandon):
		return
	pause_abandon.visible = state == State.RAID
	pause_title.visible = state != State.RAID
	pause_park.visible = state == State.RAID

func _unpause() -> void:
	get_tree().paused = false
	pause_menu.visible = false
