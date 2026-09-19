class_name CutsceneScript
extends RefCounted

## A directed scene, read from `data/scenes/<id>.json`. The format is written
## out for whoever writes one in `data/scenes/README.md`.
##
## Divided the way a dialogue file is divided. The rules read a beat's `text`
## and the directions that move something — `move`, `place`, `face`, `enter`,
## `exit`, `wait` — along with the cast and the marks those directions name.
## Everything else a direction carries (`anim`, `sfx`, `camera`, `fade`) belongs
## to the picture and the sound bank: it is handed out untouched on the
## `scene_direction` cue and never read here. A new kind of direction is a new
## key in the file and a handler on the presentation side, with nothing at all
## to change in `feature/`.
##
## Pure data, like the dialogue loader. Nothing here draws or moves anything.

const DIR := "res://data/scenes"

## The directions that move something, which are this module's business.
const STAGE_VERBS := ["move", "place", "face", "enter", "exit", "wait"]

## Every verb the format defines. The presentation ones are listed so that a
## misspelt direction is caught by `problems` rather than doing nothing quietly
## — what they mean is still none of this file's business.
const VERBS := ["move", "place", "face", "enter", "exit", "wait",
	"anim", "sfx", "camera", "fade"]

## Where the floor sits when a file does not say.
const DEFAULT_FLOOR := 420.0

static var _cache: Dictionary = {}

static func path_for(id: String) -> String:
	return DIR.path_join(id.to_lower() + ".json")

## Every scene with a file, by the id in its name.
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(DIR):
		return out
	for file in DirAccess.get_files_at(DIR):
		if file.get_extension() == "json":
			out.append(file.get_basename())
	return out

## A scene's file, with its `defaults` filled into every beat that does not set
## those keys itself. Read once and shared; treat it as read-only.
static func scene(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var def := _read(path_for(id))
	if def.is_empty():
		push_warning("CutsceneScript: no readable file at %s" % path_for(id))
		return {}
	_fill_defaults(def)
	_translate(def, id)
	_cache[id] = def
	return def

## Lays the language's words over the scene's own, from
## `localization/<lang>/scenes/<id>.json`. What is said and the names on the
## tab move; the staging — who walks where, the camera, the sound — stays in
## `data/`. Beats are addressed by their position in the file, so a beat
## inserted in the middle moves every translation under it: that is what
## `tests/shared/loc_test` checks the default language against the file for.
static func _translate(def: Dictionary, id: String) -> void:
	var over := Loc.overlay("scenes", id)
	if over.is_empty():
		return
	var names: Dictionary = over.get("cast", {})
	var cast: Dictionary = def.get("cast", {})
	for who in names:
		if cast.has(who) and cast[who] is Dictionary:
			(cast[who] as Dictionary)["name"] = String(names[who])
	var lines: Dictionary = over.get("beats", {})
	var beats: Array = def.get("beats", [])
	for i in beats.size():
		var line = lines.get(str(i), null)
		if not (line is Dictionary) or not (beats[i] is Dictionary):
			continue
		for k in ["text", "name"]:
			if (line as Dictionary).has(k):
				(beats[i] as Dictionary)[k] = String((line as Dictionary)[k])

## Forgets what has been read, so an edited file is picked up without a restart.
static func reload() -> void:
	_cache.clear()

## Mistakes in a scene file that would otherwise show up as a beat that quietly
## does nothing, or a cutscene that stops halfway through. Phrased the way
## `Dialogue.problems` phrases them, and checked by `tests/feature/intro_test`.
static func problems(id: String) -> Array:
	var path := path_for(id)
	var def := _read(path)
	if def.is_empty():
		return ["no readable file at %s" % path]
	return problems_in(def)

## The same check, against a scene already in hand rather than one on disk — so
## the checker itself can be put in front of a deliberately broken scene without
## a broken file having to live in the project.
static func problems_in(def: Dictionary) -> Array:
	var found: Array = []
	var cast = def.get("cast", {})
	if not cast is Dictionary:
		found.append("cast is not an object")
		cast = {}
	var marks = def.get("marks", {})
	if not marks is Dictionary:
		found.append("marks is not an object")
		marks = {}
	for who in cast:
		var entry = cast[who]
		if not entry is Dictionary:
			found.append("cast '%s' is not an object" % who)
			continue
		if entry.has("at") and not _is_place(entry["at"], marks):
			found.append("cast '%s' starts at '%s', which is not a mark" % [who, entry["at"]])

	var beats = def.get("beats", [])
	if not beats is Array or beats.is_empty():
		return found + ["no beats"]
	for i in beats.size():
		var beat = beats[i]
		var at := "beat %d" % (i + 1)
		if not beat is Dictionary:
			found.append("%s is not an object" % at)
			continue
		var directions = beat.get("do", [])
		if not directions is Array:
			found.append("%s has a 'do' that is not a list" % at)
			directions = []
		if String(beat.get("text", "")) == "" and directions.is_empty() \
				and not beat.has("hold"):
			found.append("%s has no text, no directions and no hold — it does nothing" % at)
		for d in directions:
			if not d is Dictionary:
				found.append("%s has a direction that is not an object" % at)
				continue
			found.append_array(_direction_problems(d, at, cast, marks))
	return found

## --- reading ----------------------------------------------------------------

static func _direction_problems(d: Dictionary, at: String, cast: Dictionary,
		marks: Dictionary) -> Array:
	var found: Array = []
	var verb := ""
	for key in d:
		if VERBS.has(String(key)):
			verb = String(key)
			break
	if verb == "":
		found.append("%s has a direction naming none of %s" % [at, ", ".join(VERBS)])
		return found
	# Who a stage direction is about is the value of its own verb, so a typo in
	# a name is a direction aimed at nobody rather than a crash later.
	if ["move", "place", "face", "anim", "enter", "exit"].has(verb):
		var who := String(d[verb])
		if not cast.has(who):
			found.append("%s directs '%s', who is not in the cast" % [at, who])
	if verb == "move" and not _is_place(d.get("to", null), marks):
		found.append("%s moves to '%s', which is not a mark" % [at, d.get("to", "")])
	if (verb == "place" or verb == "enter") and not _is_place(d.get("at", null), marks):
		found.append("%s puts someone at '%s', which is not a mark" % [at, d.get("at", "")])
	if verb == "face" and not ["left", "right"].has(String(d.get("dir", ""))):
		found.append("%s faces '%s' — it is left or right" % [at, d.get("dir", "")])
	return found

## A place is either the name of a mark or a pair of numbers written out.
static func _is_place(value, marks: Dictionary) -> bool:
	if value is String:
		return marks.has(String(value))
	if value is Array:
		return (value as Array).size() == 2
	return false

## Where `value` is, in world coordinates.
static func resolve_place(value, marks: Dictionary, floor_y: float) -> Vector2:
	if value is String and marks.has(String(value)):
		return resolve_place(marks[String(value)], marks, floor_y)
	if value is Array and (value as Array).size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(0.0, floor_y)

static func _fill_defaults(def: Dictionary) -> void:
	var defaults = def.get("defaults", {})
	if not defaults is Dictionary or (defaults as Dictionary).is_empty():
		return
	for beat in def.get("beats", []):
		if not beat is Dictionary:
			continue
		for key in defaults:
			if not (beat as Dictionary).has(key):
				beat[key] = defaults[key]

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}
