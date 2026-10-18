extends Node
## The sound bank as the content database lists it (`sounds`): a row for every
## sound the code synthesises and no other, each with a path under
## res://audio/sfx/, a prompt, and a flag that is Y or N; every sound a line of
## dialogue names is one of them; and a sound flagged in use with no file at
## its path still plays, the synthesised one. Headless.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SOUNDS] PASS ", what)
	else:
		fails += 1
		push_error("SOUNDS FAIL: " + what)

func _ready() -> void:
	check(Db.available() and Db.has_table("sounds"), "there is a table of sounds")
	check(Db.meta("schema_version") == str(Db.SCHEMA_VERSION),
		"the database is at the schema the code reads (file says %s, code says %d)"
			% [Db.meta("schema_version"), Db.SCHEMA_VERSION])
	var rows := Db.rows("SELECT * FROM sounds ORDER BY id")
	var listed := {}
	var odd: Array = []
	for row in rows:
		var id := String(row["id"])
		listed[id] = true
		if not Audio.has(id):
			odd.append("%s: no synthesised sound" % id)
		if String(row["path"]) != "res://audio/sfx/%s.wav" % id:
			odd.append("%s: path %s" % [id, row["path"]])
		if String(row["description"]).strip_edges().length() < 20:
			odd.append("%s: no prompt to speak of" % id)
		if not String(row["use_flag"]) in ["Y", "N"]:
			odd.append("%s: flag %s" % [id, row["use_flag"]])
	check(not rows.is_empty() and odd.is_empty(),
		"every row is a sound the bank synthesises, with its path under audio/sfx, a prompt and a flag (%s)" % str(odd))
	var unlisted: Array = []
	for id in Audio._sfx.keys():
		if not listed.has(id):
			unlisted.append(id)
	check(unlisted.is_empty(), "and every sound the bank synthesises has a row (%s)" % str(unlisted))
	var named: Array = []
	for t in ["nodes", "rules"]:
		for row in Db.rows("SELECT DISTINCT sfx FROM %s WHERE sfx IS NOT NULL" % t):
			if not listed.has(String(row["sfx"])):
				named.append(String(row["sfx"]))
	check(named.is_empty(), "every sound a line names is in the bank (%s)" % str(named))
	# Flagged in use with no file: the synthesised sound still plays.
	var flagged := 0
	for row in rows:
		if String(row["use_flag"]) == "Y":
			flagged += 1
			if not ResourceLoader.exists(String(row["path"])):
				check(Audio.has(String(row["id"])) and not Audio.from_file(String(row["id"])),
					"%s is flagged in use with no file at its path, and plays synthesised still" % row["id"])
	print("[SOUNDS] %d of %d flagged in use" % [flagged, rows.size()])
	print("[SOUNDS] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
