extends Node
## START has to ask for a save slot before it leaves the title: three slots, the
## keyboard lands on the first, backing out returns to the menu, and it is a
## pick — not START — that moves the game on.
##
## The slots are real profiles in files of their own. Each row says when the one
## in it was last written, or that it is empty, and the trashcan beside it
## empties it — after asking twice, because there is no undo.

const GameScript := preload("res://app/game.gd")

var game: Node
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SAVE] PASS ", what)
	else:
		fails += 1
		push_error("SAVE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()

## The action itself rather than a key, so the test holds whatever Escape or
## the pad's back button is bound to.
func cancel() -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = "ui_cancel"
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await frames(2)

## A stamp is the local date and time, `YYYY-MM-DD HH:MM`, and nothing else.
func dated(line: String) -> bool:
	var re := RegEx.new()
	re.compile("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}$")
	return re.search(line) != null

func stamp_of(title: TitleScreen, i: int) -> String:
	return (title._slot_rows[i]["stamp"] as Label).text

func _ready() -> void:
	# The slots are files, so a run has to start from empty ones or it is
	# reading what the run before it left behind. The wipe comes first: it
	# writes the profile it makes, and emptying the slots is what has to last.
	GameState.reset_profile()
	for n in range(1, GameState.SAVE_SLOTS + 1):
		GameState.delete_slot(n)
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(10)

	var title: TitleScreen = game.current
	title._start_button.emit_signal("pressed")
	await frames(4)
	check(game.state == GameScript.State.TITLE, "START alone does not leave the title")
	check(title._save_slot_root.visible and not title._menu_root.visible,
		"START swaps the menu for the save slots")
	var rows: Array = []
	for row in title._slot_rows:
		rows.append((row["pick"] as Button).text)
	var want: Array = []
	for i in TitleScreen.SAVE_SLOTS:
		want.append(Loc.t("menu.title.slot", [i + 1]))
	check(rows == want, "three slots (%s)" % str(rows))
	check((title._save_slot_root.get_child(TitleScreen.SAVE_SLOTS) as Button).text
		== Loc.t("menu.title.back"), "and a way back under them")
	check(focus_owner() == title._first_save_slot,
		"the keyboard lands on SLOT 1 (owner=%s)" % str(focus_owner()))

	await cancel()
	check(title._menu_root.visible and not title._save_slot_root.visible,
		"cancel backs out to the menu")
	check(focus_owner() == title._start_button,
		"and gives the keyboard back to START (owner=%s)" % str(focus_owner()))

	title._start_button.emit_signal("pressed")
	await frames(4)
	(title._slot_rows[1]["pick"] as Button).emit_signal("pressed")
	check(title.save_slot == 2, "picking SLOT 2 records slot 2 (got %d)" % title.save_slot)
	await frames(6)
	# The profile was wiped at the top of this test, so it has never been
	# played: the pick opens the prologue rather than the hideout.
	check(game.state == GameScript.State.INTRO,
		"and the pick is what moves the game on — into the opening scene (state=%d)" % game.state)
	var intro: Cutscene = game.current
	intro.skip()
	await frames(6)
	check(game.state == GameScript.State.HIDEOUT,
		"which hands over to the hideout when it is done (state=%d)" % game.state)
	check(GameState.intro_seen, "and is marked seen, so the next start skips it")

	# Proved by doing it again: the same pick on a profile that has been played
	# goes straight in.
	game.goto_title()
	await frames(6)
	var again: TitleScreen = game.current
	again._start_button.emit_signal("pressed")
	await frames(4)
	(again._slot_rows[1]["pick"] as Button).emit_signal("pressed")
	await frames(6)
	check(game.state == GameScript.State.HIDEOUT,
		"a start on a played profile goes straight to the hideout (state=%d)" % game.state)

	# --- what each row says -------------------------------------------------
	game.goto_title()
	await frames(6)
	var t3: TitleScreen = game.current
	t3._start_button.emit_signal("pressed")
	await frames(4)
	check(stamp_of(t3, 0) == Loc.t("menu.title.slot_empty"),
		"a slot nothing has been saved into reads EMPTY (%s)" % stamp_of(t3, 0))
	check(dated(stamp_of(t3, 1)),
		"and one that has been played carries when it was last written (%s)"
		% stamp_of(t3, 1))

	# Something in slot 1 as well, so emptying slot 2 has a neighbour to spare.
	GameState.load_slot(1)
	GameState.save_game()
	await cancel()
	t3._start_button.emit_signal("pressed")
	await frames(4)
	check(dated(stamp_of(t3, 0)),
		"a slot saved since the list was last opened picks up its stamp (%s)"
		% stamp_of(t3, 0))

	# --- the trashcan asks twice --------------------------------------------
	var bin: Button = t3._slot_rows[1]["bin"]
	bin.emit_signal("pressed")
	await frames(2)
	check(GameState.slot_used(2), "one press on the can throws nothing away")
	check(stamp_of(t3, 1) == Loc.t("menu.title.slot_delete"),
		"it asks first (%s)" % stamp_of(t3, 1))

	await cancel()
	check(t3._armed_slot == -1, "cancel calls an armed can off")
	check(t3._save_slot_root.visible, "and leaves the list open to do it")
	check(GameState.slot_used(2), "with the profile still there")

	bin.emit_signal("pressed")
	await frames(2)
	bin.emit_signal("pressed")
	await frames(2)
	check(not GameState.slot_used(2), "a second press on an armed can empties the slot")
	check(stamp_of(t3, 1) == Loc.t("menu.title.slot_empty"),
		"which the row then says (%s)" % stamp_of(t3, 1))
	check(GameState.slot_used(1), "and the slot beside it is untouched")

	# --- and a row holds together in every language the game ships ----------
	# Three things share the width of a row, and the widest of them is a date
	# that never shortens. A face twice as wide is what would push them into
	# each other, so the check is made in each language rather than in English.
	var spoken := Loc.language
	for lang in Loc.languages():
		Loc.set_language(lang)
		await frames(6)
		var vp := get_viewport().get_visible_rect().size
		for row in t3._slot_rows:
			var name_at := (row["pick"] as Button).get_global_rect()
			var date_at := (row["stamp"] as Label).get_global_rect()
			var can_at := (row["bin"] as Button).get_global_rect()
			check(name_at.position.x >= 0.0 and can_at.end.x <= vp.x + 0.5,
				"%s: a slot row stays on screen (%.0f..%.0f of %.0f)"
				% [lang, name_at.position.x, can_at.end.x, vp.x])
			check(name_at.end.x <= date_at.position.x + 0.5,
				"%s: the name keeps clear of the date (%.0f vs %.0f)"
				% [lang, name_at.end.x, date_at.position.x])
			check(date_at.end.x <= can_at.position.x + 0.5,
				"%s: and the date keeps clear of the can (%.0f vs %.0f)"
				% [lang, date_at.end.x, can_at.position.x])
		var last := (t3._save_slot_root.get_child(TitleScreen.SAVE_SLOTS) as Button)
		check(last.get_global_rect().end.y <= vp.y + 0.5,
			"%s: and the way back is still on screen (%.0f of %.0f)"
			% [lang, last.get_global_rect().end.y, vp.y])
	Loc.set_language(spoken)
	await frames(4)

	print("[SAVE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
