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
## The windows the shell raises over a screen — the hideout's workbench — and
## the layer they are drawn on: over the screen and its own panels, under the
## console and the pause menu, which is where a raid keeps its assembly board.
## It used to be the pause menu's layer, and put there the workbench covered
## the console without stopping it answering: the MENU key under its CLOSE
## button took the press and opened the pause menu underneath the workbench.
## It stops with the tree, so a paused game is paused behind the menu rather
## than answering keys under it.
var window_layer: CanvasLayer
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
## The questions MAIN MENU and ABANDON RAID ask in a raid before they go, by
## menu id: each a shade and a small frame over PAUSED, which stays where it is
## underneath. At most one is up; see `_pause_ask`.
var pause_asks: Dictionary = {}
## Whether the pause menu was built for a thumb (`UiKit.mobile`). It is built
## once and kept, so it is built again when the mode it was built for is no
## longer the one in force — see `_pause_remode`.
var pause_thumb: bool = false
var hideout_ref: HideoutWorld = null
## The menus the pause menu shows, each as a page of its own: PAUSED, and the
## two pages behind its doors — the same two the title's settings show, from
## the same rows. What is on each is its rows (`Menus`); `_pause_open` knows
## which page each is, and `_pause_acts` what its other items do.
const PAUSE_MENUS := ["pause", "general", "controls", "park", "abandon"]

func _ready() -> void:
	randomize()
	Controls.load_saved()
	Touch.load_saved()
	AimAssist.load_saved()
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	window_layer = CanvasLayer.new()
	window_layer.layer = 12
	add_child(window_layer)
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
	# The game as launched opens on one of the studio's logos, over the title
	# built under it in the same frame, which it fades into — see `LogoCard`.
	if LogoCard.wanted(self):
		overlay_layer.add_child(LogoCard.new())

## The pause menu, built again if mobile mode has been thrown since it was
## built: the title's settings throw it with this menu nowhere on screen, and
## the menu's own controls page throws it from inside. On that page the keyboard
## was on the switch if it was anywhere, so it is put on the one that took its
## place.
func _pause_remode() -> void:
	if pause_thumb == UiKit.mobile():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var on_switch: bool = focused is UiKit.Switch and pause_menu != null \
		and pause_menu.is_ancestor_of(focused)
	_rebuild_pause_menu(Loc.language)
	if on_switch and pause_controls != null and pause_controls.is_visible_in_tree():
		for c in pause_controls.find_children("*", "", true, false):
			if c is UiKit.Switch:
				(c as Control).grab_focus()
				break

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
		touch_pad.use_near = _use_nearby()
		touch_pad.kit = _kit_size()

## Which keys the pad shows. The shell answers because the shell is the one
## thing that knows both what screen is up and who has the controls.
##
## A scene has no player to ask — the prologue is a cast and a camera — and it
## turns its own pages on `interact`, so it wears the same face a conversation
## does. A screen that has taken the controls keeps only the keys that close it
## again: the map is opened and shut with the same key, and on a phone that key
## is on the pad or it is nowhere.
##
## The assembly board leaves the glass clear instead. It covers all of it, it is
## itself what the thumb is there for, and it has its own way out in CLOSE —
## which is where KIT, MAP and MENU stand, so with them up a press on CLOSE was
## a press on MENU. The pad stays up with nothing on it, so the words the board
## prints for a control are still the ones on the glass.
##
## So does a panel a world puts up over itself — a station's, in the hideout.
## In mobile mode it is a page nearly the width of the screen, with its own way
## out in each corner a thumb might look, and the three keys would stand on its
## heading.
func _touch_face() -> int:
	if state == State.INTRO:
		return TouchPad.Face.TALK
	if _assembling() or _paneled():
		return TouchPad.Face.CLEAR
	for p in get_tree().get_nodes_in_group("player"):
		if not p.controls_locked():
			return TouchPad.Face.PLAY
		return TouchPad.Face.TALK if p.talk_locked else TouchPad.Face.SCREEN
	return TouchPad.Face.NONE

## Whether a press of `interact` would do something where the player stands.
## The console's HIT button turns into USE while this holds. Each world answers
## for the things it stages — an exit, a station, a guest; see `World` — so the
## shell, which used to name a station and an NPC to work this out, names
## neither, and a new thing to use is an edit to the world that has it.
func _use_nearby() -> bool:
	if current == null or not is_instance_valid(current) or not (current is World):
		return false
	return (current as World).use_nearby()

## How many weapons the player on screen is carrying: the console keeps a key
## for changing weapon only while there is more than one.
func _kit_size() -> int:
	for p in get_tree().get_nodes_in_group("player"):
		return (p as Player).weapons.size()
	return 0

## Whether the world has a panel of its own up over it — see `World.paneled`.
func _paneled() -> bool:
	return current != null and is_instance_valid(current) and current is World \
		and (current as World).paneled()

## Whether an assembly board is up: the hideout's workbench, which is the
## shell's own, or the one the world under it carries.
func _assembling() -> bool:
	if editor != null and is_instance_valid(editor):
		return true
	if current == null or not is_instance_valid(current) or not (current is World):
		return false
	return (current as World).editing

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

## Between raids, as a room you stand in: the weapon rack, the counter and the
## gate are places you walk to, and TAB opens the weapon's graph anywhere on
## the floor. The panels behind them are the columns the old screen showed all
## at once — `graphics/ui/hideout.gd` still owns what is in them — and the view
## opens them.
##
## It is a world node rather than a Control, like the bench and the raid, so it
## is added to the tree rather than to `ui_layer` and gets its view from `Views`.
func goto_hideout() -> void:
	_clear()
	state = State.HIDEOUT
	var h := HideoutWorld.new()
	h.deploy_requested.connect(_deploy)
	h.title_requested.connect(goto_title)
	h.edit_requested.connect(_edit_weapon_graph)
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

## Through the gate holding `weapon`, with the rest of the kit the rack was
## left carrying. A weapon that is not in that kit goes out on its own.
func _deploy(weapon: String) -> void:
	if GameState.is_carried(weapon):
		GameState.deploy(GameState.carried(), weapon)
	else:
		GameState.deploy(weapon)
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
## The graph on the weapon the rack was left on, opened off the rack's BUILD
## button or with the key a raid opens assembly with — the same board however
## it is reached, and the profile's own, so what is built is what the gate
## carries.
func _edit_weapon_graph() -> void:
	if hideout_ref == null or not is_instance_valid(hideout_ref):
		return
	_open_board(hideout_ref.armed_board())

## The workbench editor over the board it is given, spending the stash.
func _open_board(board: SkillBoard) -> void:
	_close_editor()
	editor = SkillEditor.new()
	editor.weapon_id = hideout_ref.weapon_id if hideout_ref != null else "SWORD"
	editor.configure(board, GameState.stash, false, null)
	editor.closed.connect(_close_editor)
	editor.board_changed.connect(func() -> void: GameState.save_game())
	window_layer.add_child(editor)
	editor.grab_focus()
	# The room holds the player still under it, which is also what hands the
	# mouse back from their aim to the board.
	if hideout_ref != null and is_instance_valid(hideout_ref):
		hideout_ref.set_editing(true)

func _close_editor() -> void:
	if editor != null and is_instance_valid(editor):
		editor.queue_free()
		GameState.save_game()
		if hideout_ref != null and is_instance_valid(hideout_ref):
			hideout_ref.set_editing(false)
		# The board that came back may have a different name and different tags
		# on it, and the rack's panel is showing the old ones.
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
	# Built once and kept for the whole run, so the screen can change shape under
	# it — a window dragged, a phone turned — and its shade has to go on covering
	# the lot. The pages centre themselves.
	#
	# And it is the one thing running while the tree is stopped, so it is what
	# notices mobile mode thrown on its own controls page. The rebuild replaces
	# this node, so it is asked for and left to happen once this frame is done.
	func _process(_delta: float) -> void:
		UiKit.sync_screen(self)
		if visible and game != null and is_instance_valid(game) \
				and game.pause_thumb != UiKit.mobile() and not is_queued_for_deletion():
			game._pause_remode.call_deferred()
	func _unhandled_input(event: InputEvent) -> void:
		if not visible or not event.is_action_pressed("pause"):
			return
		if game != null and is_instance_valid(game):
			# One level at a time: from a page behind PAUSED the key goes back
			# to PAUSED, the way that page's BACK button does, rather than
			# dropping straight into a raid the player cannot see behind it.
			if game.pause_asking() != "":
				game._pause_ask("")
			elif game.pause_general != null and game.pause_general.visible:
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
## Three pages, not one. The rebinding list is eighteen rows of two columns,
## which is longer than everything else on the menu put together: inline, it
## pushed the way out so far down that the menu was a scrollbar with a RESUME
## button at the top. It sits behind CONTROL SETTINGS instead, on a page of its
## own, and the volumes sit behind GENERAL SETTINGS on another — the same two
## pages the title's settings keep, reached the same way, so the menu the player
## pauses into is the menu they already know.
func _build_pause_menu() -> void:
	pause_thumb = UiKit.mobile()
	pause_menu = PauseMenu.new()
	(pause_menu as PauseMenu).game = self
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.add_child(UiKit.shade())
	# The pixel face runs up to twice as wide as the one this menu was laid out
	# for, and the rebinding list is two columns of it: 600 holds them, as it
	# does on the title, and the frame adds its bar.
	var frame := UiKit.screen_frame(608.0, 36.0, 28.0, true)
	pause_menu.add_child(frame)
	pause_main = frame
	frame.head.add_child(_pause_heading(Menus.name_for("pause"), _unpause))
	frame.head.add_child(UiKit.hline(true))
	# The two doors, and the ways out of the menu gathered at the bottom and
	# ordered by what they cost: back into the game, out to the title, and last
	# the one that forfeits a raid — its own act and its own colour, so it stays
	# its own button. Which is which, and what each says, is the `pause` menu's
	# rows; the three ways to the title are kept by name, since `_pause` shows
	# whichever of them apply.
	#
	# Everywhere but a raid, leaving is leaving, and the button says where it
	# lands rather than what it is walking out of. The bench used to word it
	# LEAVE THE BENCH, which was the same act under a name that did not say
	# where it went.
	var made := _pause_items(frame, "pause")
	pause_title = made.get("title")
	pause_park = made.get("park")
	pause_abandon = made.get("abandon")
	for id in ["title", "park", "abandon"]:
		if not made.has(id):
			push_error("Game: PAUSED has no '%s' — see data/db/menus/menus.sql" % id)
	_build_pause_general()
	_build_pause_controls()
	for menu in ["park", "abandon"]:
		pause_asks[menu] = _build_pause_ask(menu)
	overlay_layer.add_child(pause_menu)

## A pause page's items, from its menu's rows: a button each, in order, under
## whatever the page already holds. The ways out of the page go in the
## frame's foot, which is pinned: whatever is added to the page above them,
## they stay on the screen. What each says and where it leads is the rows';
## what pressing it does is `_pause_open` for a door and `_pause_acts` for the
## rest; and its colour and height are this menu's own, by the item's id —
## BACK TO GAME stands taller, in the colour of a way in, and ABANDON RAID in
## the colour of a cost.
func _pause_items(frame: UiKit.ScreenFrame, menu: String) -> Dictionary:
	var acts := _pause_acts(menu)
	var made := {}
	var foot_open := false
	for item in Menus.items(menu):
		var id := String(item["id"])
		var tone := UiKit.ACCENT
		if id == "resume":
			tone = UiKit.GOOD
		elif id == "abandon" or (menu == "abandon" and id == "confirm"):
			tone = UiKit.BAD
		var b := UiKit.button(String(item["text"]), tone, true)
		b.custom_minimum_size = Vector2(280, maxf(40 if id == "resume" else 36, UiKit.thumb()))
		b.pressed.connect(Menus.press(menu, item, acts, _pause_open))
		if bool(item["exit"]):
			if not foot_open:
				frame.foot.add_child(UiKit.spacer(8))
				foot_open = true
			frame.foot.add_child(b)
		else:
			frame.rows.add_child(b)
		made[id] = b
	return made

## Opening a menu from an item that leads to one: the pause page it is. A row
## opening a menu the pause menu has no page for is said, not guessed at.
func _pause_open(menu: String) -> void:
	match menu:
		"general":
			_pause_general(true)
		"controls":
			_pause_controls(true)
		_:
			push_error("Game: the pause menu has no page for the %s menu" % menu)

## What an item that opens no menu does, by its id, on each page of the pause
## menu — the words its rows are written in. `back` is one level up.
## `tests/graphics/menus_test` holds every row to these.
func _pause_acts(menu: String) -> Dictionary:
	match menu:
		"pause":
			return {"resume": _unpause, "title": _pause_to_title,
				"park": _pause_ask.bind("park"), "abandon": _pause_ask.bind("abandon")}
		"park":
			return {"back": _pause_ask.bind(""), "confirm": _pause_park}
		"abandon":
			return {"back": _pause_ask.bind(""), "confirm": _pause_abandon}
		"general":
			return {"back": func() -> void: _pause_general(false)}
		"controls":
			return {"back": func() -> void: _pause_controls(false)}
	return {}

## A question over PAUSED: its heading, the line under it that says what the
## answer costs, and the answers — CANCEL first, back to PAUSED, then the one
## that goes. A popup rather than a page, so PAUSED stays in sight under it and
## it is plain which button asked.
func _build_pause_ask(menu: String) -> Control:
	var holder := Control.new()
	holder.visible = false
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(UiKit.shade())
	var frame := UiKit.screen_frame(520.0, 36.0, 28.0, true)
	holder.add_child(frame)
	frame.head.add_child(UiKit.title(Menus.name_for(menu), UiKit.text(24), true))
	frame.head.add_child(UiKit.hline(true))
	var note := UiKit.label(Menus.note_for(menu), UiKit.text(16), UiKit.DIM, true)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.rows.add_child(note)
	_pause_items(frame, menu)
	pause_menu.add_child(holder)
	return holder

## Puts the question `menu` up over PAUSED, or takes whichever is up down for
## "". While one is up PAUSED cannot take the keyboard either: the shade stops
## a click reaching it, and this stops the arrow keys.
func _pause_ask(menu: String, sound: bool = true) -> void:
	for id in pause_asks:
		(pause_asks[id] as Control).visible = id == menu
	pause_main.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED if menu != "" \
		else Control.FOCUS_BEHAVIOR_INHERITED
	if sound:
		Audio.play("ui")

## The question up over PAUSED, or "" for none.
func pause_asking() -> String:
	for id in pause_asks:
		if (pause_asks[id] as Control).visible:
			return id
	return ""

## MAIN MENU: to the title from wherever it is pressed.
func _pause_to_title() -> void:
	_unpause()
	goto_title()

## The same destination from inside a raid, and the raid survives it: the run
## is written into the save slot as it stands and walked back into when that
## slot is opened again. It is the only way out of a raid that costs nothing,
## which is why its question says so.
func _pause_park() -> void:
	_unpause()
	if state == State.RAID and current != null and is_instance_valid(current):
		GameState.park_raid((current as Raid).park())
	goto_title()

## ABANDON RAID: the run ends where it stands, and the kit stays behind.
func _pause_abandon() -> void:
	_unpause()
	if state == State.RAID:
		var lost := GameState.die()
		_raid_finished("died", lost)

## The page behind GENERAL SETTINGS: the volumes, the language, and the way back
## to PAUSED. The same three the title's settings hold — the same rows, in fact,
## made by `SettingsRows` and `VideoRows` for both — since this is the same menu
## reached from inside a game.
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
	frame.head.add_child(_pause_heading(Menus.name_for("general"),
		func() -> void: _pause_general(false)))
	frame.head.add_child(UiKit.hline(true))
	for row in SettingsRows.rows() + VideoRows.rows():
		frame.rows.add_child(row)
	_pause_items(frame, "general")

## The second page: the rebinding list, and the way back to the first. Built as
## a sibling frame rather than a panel swapped into the first one, so each page
## scrolls on its own and neither inherits the other's scroll position.
##
## Eighteen rows of two columns is longer than the screen on any window worth
## the name, so this is the page that shows what the frame is for: the list
## scrolls and the heading and the way back off it do not move.
func _build_pause_controls() -> void:
	var frame := UiKit.screen_frame(608.0, 36.0, 28.0, true)
	frame.visible = false
	pause_controls = frame
	pause_menu.add_child(frame)
	frame.head.add_child(_pause_heading(Menus.name_for("controls"),
		func() -> void: _pause_controls(false)))
	frame.head.add_child(UiKit.hline(true))
	var cp := ControlsPanel.new()
	cp.pixel = true
	frame.rows.add_child(cp)
	_pause_items(frame, "controls")

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
	arrow.custom_minimum_size = UiKit.corner_button()
	arrow.pressed.connect(back)
	h.add_child(arrow)
	h.add_child(UiKit.title(text, UiKit.text(24), true))
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
	# In the layout the mode in force asks for, whichever it was built in.
	_pause_remode()
	_pause_exits()
	# Always on PAUSED, however it was left last time.
	pause_main.visible = true
	pause_general.visible = false
	pause_controls.visible = false
	_pause_ask("", false)
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
