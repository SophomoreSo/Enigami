extends Node
## The skill boards the game ships with, and the tables they are read from.
##
## Each weapon's own attack, every monster's, a new profile's starter skill and
## the dragon test's board are rows in the content database
## (`data/db/boards/`): a grid, and the parts placed on it. Which part feeds
## which follows from their ports and the way each faces, so a row a cell out
## of place is a board that quietly does nothing — a monster that never
## attacks, a weapon that will not swing. Every board has to build whole, start
## somewhere and reach an OUTPUT; every board the code asks for by name has to
## be in the table; and what the schema promises to refuse is tried against a
## scratch copy of it.
##
## No renderer needed: nothing here draws. The refusals print an `SQL error`
## line each from the extension, which is the point of them.

const SRC := "res://data/db"
const SCRATCH := "user://boards_test.db"

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[BOARDS] PASS ", what)
	else:
		fails += 1
		push_error("BOARDS FAIL: " + what)

## Two boards are the same board when the same parts face the same way in the
## same cells.
func same_parts(a: SkillBoard, b: SkillBoard) -> bool:
	if a.cells.size() != b.cells.size():
		return false
	for origin in a.cells:
		var there: Dictionary = b.cells.get(origin, {})
		if there.is_empty() or String(there["id"]) != String(a.cells[origin]["id"]) \
				or int(there["rot"]) != int(a.cells[origin]["rot"]):
			return false
	return true

func _ready() -> void:
	# --- the table ------------------------------------------------------------
	check(Db.available(), "the database opens (%s)" % Db.PATH)
	for table in ["boards", "board_parts"]:
		check(Db.has_table(table), "there is a table of %s" % table)
	var ids := Boards.ids()
	check(ids.size() > 5, "the boards are read, %d of them" % ids.size())
	for id in ids:
		var found := Boards.problems(id)
		var board := Boards.build(id)
		var t := board.trace()
		var inputs := 0
		for c in board.cells:
			if String(board.cells[c]["id"]) == "INPUT":
				inputs += 1
		check(found.is_empty() and board.cells.size() == (Boards.source(id)["parts"] as Array).size(),
			"%s builds whole%s" % [id, "" if found.is_empty() else " — " + "; ".join(found)])
		check(inputs == 1 and bool(t["reaches_output"]) and (t["dead"] as Dictionary).is_empty(),
			"%s starts at one INPUT and reaches an OUTPUT, with no loop to lose its flow in" % id)
		check(BoardCode.encode(board) != "", "%s can be written down as a code" % id)

	# --- every board the code asks for ----------------------------------------
	var asked: Array = []
	for w in Weapons.ids():
		asked.append(String(Weapons.get_def(w)["innate"]))
	for m in Monsters.DEFS:
		for key in ["board", "board_phase2"]:
			var board_id := String(Monsters.get_def(m).get(key, ""))
			if board_id != "":
				asked.append(board_id)
	asked.append_array(["blink_step", "zap", "dragon"])
	var missing: Array = []
	for id in asked:
		if not ids.has(id):
			missing.append(id)
	check(missing.is_empty(), "every board a weapon, a monster, the profile or a world asks for is there (%s)" % str(missing))
	var unasked: Array = []
	for id in ids:
		if not asked.has(id):
			unasked.append(id)
	check(unasked.is_empty(), "and nothing is there that nobody asks for (%s)" % str(unasked))

	# --- as the code hands them out -------------------------------------------
	var sword := Weapons.make_innate_board("SWORD")
	check(same_parts(sword, Boards.build("slash")) and sword.skill_name == Loc.t("weapons.basic_board", [Weapons.name_for("SWORD")]),
		"a weapon's own attack is its board, named after the weapon (%s)" % sword.skill_name)
	var crawler := Monsters.build_board("CRAWLER")
	check(same_parts(crawler, Boards.build("crawler")) and crawler.skill_name == Monsters.name_for("CRAWLER"),
		"a monster's attack is its board, named after the monster (%s)" % crawler.skill_name)
	var rage := Monsters.build_board("ARBITER", "board_phase2")
	check(same_parts(rage, Boards.build("arbiter_phase2")) and not same_parts(rage, Monsters.build_board("ARBITER")),
		"and the Arbiter turns to a second one")
	var dummy := Monsters.build_board("DUMMY")
	check(dummy.is_empty() and dummy.skill_name == Monsters.name_for("DUMMY"),
		"a monster with no board attacks with nothing")
	check(Boards.build("blink_step").skill_name == "Blink Step",
		"a board the code does not name is called what the table calls it")
	var zap := Boards.build("zap")
	check(zap.skill_name == "Zap" and zap.cells.size() == 3 and Boards.parts_of("zap").has("ZAP"),
		"the beam a new profile opens with is three parts called Zap (%s)" % zap.skill_name)
	var drops := Monsters.drop_pool("ARBITER")
	var on_boards: Array = []
	for id in Boards.parts_of("arbiter") + Boards.parts_of("arbiter_phase2"):
		if not Components.is_structural(id) and not on_boards.has(id):
			on_boards.append(id)
	check(drops == on_boards and drops.has("ON_HIT") and not drops.has("OUTPUT"),
		"a monster drops what it was seen using, second form included, and never INPUT or OUTPUT (%s)" % str(drops))

	# --- the checker catches what it is for -----------------------------------
	# Written out here rather than kept as broken rows in the database: these
	# are the mistakes a writer makes, and every one is silent at run time if
	# nothing goes looking.
	var base := {"id": "b", "width": 7, "height": 5, "parts": [
		{"x": 0, "y": 2, "part": "INPUT", "facing": "E"},
		{"x": 1, "y": 2, "part": "EXPLODE", "facing": "E"},
		{"x": 3, "y": 2, "part": "OUTPUT", "facing": "E"}]}
	check(Boards.problems_in(base).is_empty(), "a sound board has no problems (%s)" % str(Boards.problems_in(base)))
	check(_caught(base, {"x": 6, "y": 2, "part": "DASHSLASH", "facing": "E"}, "does not fit"),
		"a two-cell part hanging off the grid is caught")
	check(_caught(base, {"x": 2, "y": 1, "part": "SLASH", "facing": "S"}, "does not fit") == false
			and _caught(base, {"x": 2, "y": 2, "part": "SLASH", "facing": "E"}, "does not fit"),
		"a part on the cell another part covers is caught, and one beside it is not")
	check(_caught(base, {"x": 0, "y": 0, "part": "INPUT", "facing": "E"}, "does not fit"), "a second INPUT is caught")
	check(_caught(base, {"x": 5, "y": 0, "part": "WIRE", "facing": "E"}, "no such part"), "a part that is not one is caught")
	check(_caught(base, {"x": 5, "y": 0, "part": "SLASH", "facing": "U"}, "no way to face"), "a facing that is not one is caught")

	# --- what the schema refuses ----------------------------------------------
	var db = _scratch()
	if db == null:
		check(false, "a scratch copy of the schema can be made to try it against")
	else:
		var parts := [
			"INSERT INTO categories (id, loot) VALUES ('struct', 0)",
			"INSERT INTO codes (code, id) VALUES (0, 'INPUT'), (1, 'OUTPUT')",
			"INSERT INTO parts (id, name, category, source, description) VALUES ('INPUT', 'INPUT', 'struct', 1, 'In.'), ('OUTPUT', 'OUTPUT', 'struct', 0, 'Out.')"]
		var board := "INSERT INTO boards (id) VALUES ('b')"
		var laid := "INSERT INTO board_parts (board_id, x, y, part, facing) VALUES ('b', 0, 2, 'INPUT', 'E'), ('b', 1, 2, 'OUTPUT', 'E')"
		check(_accepted(db, parts + [board, laid]), "a sound board is accepted (%s)" % db.error_message)
		check(_accepted(db, [board, laid] + parts), "and it may be laid out before its parts are written")
		check(not _accepted(db, parts + [board, laid.replace("'OUTPUT', 'E')", "'SLASH', 'E')")]),
			"a board carrying a part that is not one is refused when the build commits")
		check(not _accepted(db, parts + [board, laid.replace("'OUTPUT', 'E')", "'OUTPUT', 'U')")]),
			"a part facing no way at all is refused")
		check(not _accepted(db, parts + [board, laid.replace("('b', 1, 2", "('b', 0, 2")]),
			"two parts in one cell are refused")
		check(not _accepted(db, parts + [board.replace("(id) VALUES ('b')", "(id, width) VALUES ('b', 17)"), laid]),
			"a board wider than a code carries is refused")
		check(not _accepted(db, parts + [board.replace("'b'", "'B'"), laid.replace("'b'", "'B'")]),
			"a board id that is not lower case is refused")
		check(not _accepted(db, parts + [laid]), "parts laid on a board nobody wrote are refused")
		db.close_db()
		DirAccess.remove_absolute(SCRATCH)

	print("[BOARDS] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Whether laying `base` with `extra` added complains about `want`.
func _caught(base: Dictionary, extra: Dictionary, want: String) -> bool:
	var def := base.duplicate(true)
	(def["parts"] as Array).append(extra)
	for problem in Boards.problems_in(def):
		if String(problem).contains(want):
			return true
	return false

## A fresh database with the real schema in it, foreign keys on, or null.
func _scratch():
	if not ClassDB.class_exists("SQLite"):
		return null
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)
	var db = ClassDB.instantiate("SQLite")
	db.path = SCRATCH
	db.foreign_keys = true
	db.verbosity_level = 0
	if not db.open_db():
		push_error("BOARDS: could not open %s: %s" % [SCRATCH, db.error_message])
		return null
	var schema := FileAccess.get_file_as_string(SRC.path_join("schema.sql"))
	if schema == "" or not db.query(schema):
		push_error("BOARDS: the schema did not run: %s" % db.error_message)
		return null
	return db

## Whether `statements` go in and commit, the way build.sh commits them. What
## went in is taken out again afterwards, so every try starts from nothing.
func _accepted(db, statements: Array) -> bool:
	var ok: bool = db.query("BEGIN")
	for s in statements:
		ok = ok and db.query(s)
	ok = ok and db.query("COMMIT")
	if not ok:
		db.query("ROLLBACK")
		return false
	db.query("DELETE FROM boards")
	db.query("DELETE FROM parts")
	db.query("DELETE FROM codes")
	db.query("DELETE FROM categories")
	return true
