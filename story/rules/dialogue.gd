class_name Dialogue
extends RefCounted

## Conversations, read from the content database (`Db`, `data/enigami.db`): a
## character is a row in `characters`, their lines are rows in `nodes`, and a
## question's answers are rows in `choices`. The tables, and how to write a
## conversation into them, are in `data/db/README.md`.
##
## The rules only use a line's `text`, where it leads (`next`, `choices`), who
## says it (`speaker`, `name`) and how fast it types (`speed`). Every other
## column a line carries — emotion, camera, sprite, sound — belongs to the
## picture and the sound bank. It is handed on here as it came out of the
## table, keyed by column name and never named in this file, which is what
## lets a writer add a new kind of direction as a column with no change to
## the rules.

## Who an NPC with no conversation of their own talks like.
const FALLBACK := "SAGE"
## A character column starting with this is what their lines say when a line
## does not say it itself: `line_voice` fills an empty `voice`. Any column, so
## a default a writer adds to the table is a default here without a change.
const LINE_DEFAULT := "line_"

static var _cache: Dictionary = {}
## The language `_cache` was read in. The words are laid over a conversation
## as it is read, so what was read in one language is no use in the next, and
## the first thing asked for after a change of language finds it forgotten —
## which is how `Loc` never has to know this file exists.
static var _cache_language := ""

## Every character with a conversation, by id.
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for r in Db.rows("SELECT id FROM characters ORDER BY id"):
		out.append(String(r["id"]))
	return out

## A character's conversation, ready to play: their row, with `nodes` under it
## by name and each question's `choices` in order, the character's `line_`
## defaults filled into every line that does not set them, and the words in
## the language being played. Read once and shared; treat it as read-only.
static func character(id: String) -> Dictionary:
	_forget_another_language()
	if _cache.has(id):
		return _cache[id]
	var def := source(id)
	if def.is_empty():
		if id == FALLBACK:
			return {}
		push_warning("Dialogue: nobody called '%s' in %s, talking like %s" % [id, Db.PATH, FALLBACK])
		return character(FALLBACK)
	_fill_defaults(def)
	_translate(def, id)
	_cache[id] = def
	return def

## A character as the database has them, in no language and with no defaults
## filled: the `characters` row, with `nodes` under it by name and each
## question's `choices` under its line, in order. A column left NULL is a key
## that is not there. Empty when there is nobody by that id. Read fresh every
## call — `character` is the one to play.
static func source(id: String) -> Dictionary:
	var found := Db.records("characters", "id = ?", [id])
	if found.is_empty():
		return {}
	var def: Dictionary = found[0]
	var nodes: Dictionary = {}
	for node in Db.records("nodes", "character_id = ?", [id], "rowid"):
		nodes[String(node["id"])] = node
	for c in Db.records("choices", "character_id = ?", [id], "node_id, position"):
		var node = nodes.get(String(c["node_id"]), null)
		if node == null:
			continue
		if not node.has("choices"):
			node["choices"] = []
		(node["choices"] as Array).append(c)
	def["nodes"] = nodes
	return def

## Forgets what has been read, and lets `Db` go of the file, so a rebuilt
## database is picked up without a restart. A change of language needs no
## call: see `_cache_language`. `CutsceneScript.reload` is the same for scenes.
static func reload() -> void:
	_cache.clear()
	Db.reopen()

static func _forget_another_language() -> void:
	if _cache_language != Loc.language:
		_cache.clear()
		_cache_language = Loc.language

## Mistakes in a character's conversation that would otherwise only show up
## as one cut short, and only for whoever took that path through it. The
## build refuses most of them already (`data/db/build.sh`); this is the same
## question asked of what the game actually read.
static func problems(id: String) -> Array:
	var def := source(id)
	if def.is_empty():
		return ["nobody called '%s' in %s" % [id, Db.PATH]]
	return problems_in(def)

## The same check against a conversation already in hand, in the shape
## `source` returns — so the checker itself can be put in front of a
## deliberately broken one without a broken row having to live in the
## database.
static func problems_in(def: Dictionary) -> Array:
	var found: Array = []
	var all = def.get("nodes", {})
	if not all is Dictionary or all.is_empty():
		return ["no lines"]
	if not all.has(String(def.get("start", ""))):
		found.append("start -> %s" % def.get("start", ""))
	for key in all:
		var node = all[key]
		if not node is Dictionary:
			found.append("%s is not a line" % key)
			continue
		if String(node.get("text", "")) == "":
			found.append("%s has no text" % key)
		var choices = node.get("choices", [])
		if not choices is Array:
			choices = []
		var links: Array = [node.get("next", "")]
		if not choices.is_empty() and _link(node.get("next", "")) != "":
			found.append("%s has both a next line and answers — the answers win" % key)
		for c in choices:
			if not c is Dictionary or String(c.get("text", "")) == "":
				found.append("%s has an answer with no text" % key)
				continue
			links.append(c.get("next", ""))
		for to in links:
			var name := _link(to)
			if name != "" and not all.has(name):
				found.append("%s -> %s" % [key, name])
	return found

## Where a `next` points, as a name — "" for none, however none was written.
static func _link(to) -> String:
	return "" if to == null else String(to)

## Lays the language's words over the database's own, from
## `localization/<lang>/dialogue/<id>.json`.
##
## Only the words move: what is said, the names on the tab and the answers on a
## question. Where a line leads, what the camera does and what it sounds like
## stay in the database, so a translator never touches the shape of a
## conversation and a writer never touches six languages. A line the language
## has not reached keeps what the database says, which is what lets a new
## conversation be written and played before any of it is translated.
static func _translate(def: Dictionary, id: String) -> void:
	var over := Loc.overlay("dialogue", id)
	if over.is_empty():
		return
	for k in ["name", "player_name"]:
		if over.has(k):
			def[k] = String(over[k])
	var nodes: Dictionary = def.get("nodes", {})
	var lines: Dictionary = over.get("nodes", {})
	for key in nodes:
		if not (nodes[key] is Dictionary) or not lines.has(key):
			continue
		var node: Dictionary = nodes[key]
		var line: Dictionary = lines[key]
		for k in ["text", "name"]:
			if line.has(k):
				node[k] = String(line[k])
		var answers: Array = line.get("choices", [])
		var choices: Array = node.get("choices", [])
		# Position for position: an answer the language has not reached keeps
		# the words in the database, and where each one leads is never touched.
		for i in mini(answers.size(), choices.size()):
			if choices[i] is Dictionary:
				(choices[i] as Dictionary)["text"] = String(answers[i])

## A line says what its character usually says unless it says otherwise: for
## every `line_<key>` column of the character, a line with no `<key>` gets it.
static func _fill_defaults(def: Dictionary) -> void:
	var nodes: Dictionary = def.get("nodes", {})
	for col in def:
		var key := String(col)
		if not key.begins_with(LINE_DEFAULT):
			continue
		var k := key.trim_prefix(LINE_DEFAULT)
		for name in nodes:
			var node: Dictionary = nodes[name]
			if not node.has(k):
				node[k] = def[col]
