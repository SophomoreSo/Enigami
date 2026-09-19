class_name Dialogue
extends RefCounted

## Conversations, read from `data/dialogue/<id>.json` — one file per character.
## The format is described in `data/dialogue/README.md`.
##
## The rules only use a line's `text`, where it leads (`next`, `choices`), who
## says it (`speaker`, `name`) and how fast it types (`speed`). Everything else a
## line carries — emotion, camera, sprite, sound — belongs to the picture and the
## sound bank. It is passed through here untouched and never read, which is what
## lets a writer add a new kind of direction without a change to `feature/`.

const DIR := "res://data/dialogue"
## Who an NPC with no file of their own talks like.
const FALLBACK := "SAGE"

static var _cache: Dictionary = {}

## Every character with a dialogue file, by the id inside it.
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for file in DirAccess.get_files_at(DIR):
		if file.get_extension() != "json":
			continue
		var def := _read(DIR.path_join(file))
		if def.has("id"):
			out.append(String(def["id"]))
	return out

static func path_for(id: String) -> String:
	return DIR.path_join(id.to_lower() + ".json")

## A character's file, with its `defaults` filled into every line that does not
## set those keys itself. Read once and shared; treat it as read-only.
static func character(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var def := _read(path_for(id))
	if def.is_empty():
		if id == FALLBACK:
			return {}
		push_warning("Dialogue: no file for '%s', talking like %s" % [id, FALLBACK])
		return character(FALLBACK)
	_fill_defaults(def)
	_translate(def, id)
	_cache[id] = def
	return def

## Forgets what has been read, so an edited file — or a change of language — is
## picked up without a restart. `CutsceneScript.reload` is the same for scenes.
static func reload() -> void:
	_cache.clear()

## Lays the language's words over the file's own, from
## `localization/<lang>/dialogue/<id>.json`.
##
## Only the words move: what is said, the names on the tab and the answers on a
## question. Where a line leads, what the camera does and what it sounds like
## stay in `data/`, so a translator never touches the shape of a conversation
## and a writer never touches six languages. A line the language has not
## reached keeps what `data/` says, which is what lets a new conversation be
## written and played before any of it is translated.

## Mistakes in a character's file that would otherwise only show up as a
## conversation cut short, and only for whoever took that path through it.
static func problems(id: String) -> Array:
	var path := path_for(id)
	var def := _read(path)
	if def.is_empty():
		return ["no readable file at %s" % path]
	var found: Array = []
	if String(def.get("id", "")) != id:
		found.append("the file at %s says its id is '%s'" % [path, def.get("id", "")])
	var all = def.get("nodes", {})
	if not all is Dictionary or all.is_empty():
		return found + ["no lines"]
	if not all.has(def.get("start", "")):
		found.append("start -> %s" % def.get("start", ""))
	for key in all:
		var node = all[key]
		if not node is Dictionary:
			found.append("%s is not an object" % key)
			continue
		if String(node.get("text", "")) == "":
			found.append("%s has no text" % key)
		var links: Array = [node.get("next", "")]
		for c in node.get("choices", []):
			if not c is Dictionary or String(c.get("text", "")) == "":
				found.append("%s has an answer with no text" % key)
				continue
			links.append(c.get("next", ""))
		for to in links:
			if String(to) != "" and not all.has(to):
				found.append("%s -> %s" % [key, to])
	return found

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
		# the words in `data/`, and where each one leads is never touched.
		for i in mini(answers.size(), choices.size()):
			if choices[i] is Dictionary:
				(choices[i] as Dictionary)["text"] = String(answers[i])

static func _fill_defaults(def: Dictionary) -> void:
	var defaults: Dictionary = def.get("defaults", {})
	var nodes: Dictionary = def.get("nodes", {})
	for key in nodes:
		var node: Dictionary = nodes[key]
		for k in defaults:
			if not node.has(k):
				node[k] = defaults[k]

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("Dialogue: %s, line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		push_error("Dialogue: %s is not a JSON object" % path)
		return {}
	return json.data
