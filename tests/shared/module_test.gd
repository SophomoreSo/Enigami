extends Node
## Where each module may reach, read off the code itself: every class and
## autoload a script names, against the folder the script lives in.
##
## The circuit — a board, the pulse that runs it, the payload it builds, the
## code it is shared as — is the game's engine, and it names nothing but itself
## and `Loc`: it can be tested alone, and no rule or picture changes under it.
## The console's input half names nothing but the shell it presses keys for.
## And no rule — `feature/`, `story/rules/`, `circuit/` — names a picture or a
## thumb, which is ARCHITECTURE.md's one rule: the module-split job checks it by
## deleting the graphics autoloads, and this checks it for every class as well.
##
## Comments and strings are left out before looking, so a doc comment that
## mentions a class is not a dependency on it. No renderer needed.

## What a module's scripts may name: anything defined in these folders, and
## these names besides.
const MAY := [
	{"module": "res://circuit/", "folders": ["res://circuit/"], "names": ["Loc"],
		"what": "the circuit names nothing but itself and Loc"},
	{"module": "res://mobile/input/", "folders": ["res://mobile/input/", "res://app/"], "names": [],
		"what": "the console's input names nothing but itself and the shell"},
]

## What the rules never name: a picture, or anything that knows a finger.
const RULES := ["res://feature/", "res://story/rules/", "res://circuit/"]
const NEVER := ["res://graphics/", "res://story/view/", "res://mobile/"]

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[MODULE] PASS ", what)
	else:
		fails += 1
		push_error("MODULE FAIL: " + what)

func _ready() -> void:
	var defined := _defined()
	check(defined.size() > 40, "every class and autoload is found (%d of them)" % defined.size())
	var names := _named(defined)
	check(names.has("res://circuit/skill_runner.gd") and names.has("res://mobile/input/touch.gd"),
		"and every script is read, the two new modules' among them")
	for rule in MAY:
		var strays: Array = []
		for path: String in names:
			if not path.begins_with(String(rule["module"])):
				continue
			for n: String in names[path]:
				if (rule["names"] as Array).has(n):
					continue
				var home := String(defined[n])
				var allowed := false
				for folder: String in rule["folders"]:
					allowed = allowed or home.begins_with(folder)
				if not allowed:
					strays.append("%s names %s" % [path.get_file(), n])
		check(strays.is_empty(), "%s (%s)" % [rule["what"], ", ".join(strays)])
	var drawn: Array = []
	for path: String in names:
		if not _under(path, RULES):
			continue
		for n: String in names[path]:
			if _under(String(defined[n]), NEVER):
				drawn.append("%s names %s" % [path.get_file(), n])
	check(drawn.is_empty(),
		"no rule names a picture or the console (%s)" % ", ".join(drawn))
	print("[MODULE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _under(path: String, folders: Array) -> bool:
	for folder: String in folders:
		if path.begins_with(folder):
			return true
	return false

## Every global name in the project, and the script it lives in: the classes,
## and the autoloads by the name they are reached through.
func _defined() -> Dictionary:
	var out := {}
	var named := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	for path in _scripts("res://"):
		var m := named.search(FileAccess.get_file_as_string(path))
		if m != null:
			out[m.get_string(1)] = path
	for prop in ProjectSettings.get_property_list():
		var key := String(prop["name"])
		if key.begins_with("autoload/"):
			out[key.trim_prefix("autoload/")] = String(ProjectSettings.get_setting(key)).trim_prefix("*")
	return out

## Every script outside `tests/`, and the global names it uses other than its
## own. A name counts only as a word of its own — not the tail of another, and
## not a member after a dot, which is how `UiKit.Switch` names `UiKit` alone.
func _named(defined: Dictionary) -> Dictionary:
	var word := RegEx.create_from_string("(?<![\\w.])[A-Z]\\w*")
	var quoted := RegEx.create_from_string("\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'")
	var out := {}
	for path in _scripts("res://"):
		var used := {}
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var code := quoted.sub(line, "\"\"", true).get_slice("#", 0)
			for m in word.search_all(code):
				var n := m.get_string()
				if defined.has(n) and String(defined[n]) != path:
					used[n] = true
		out[path] = used.keys()
	return out

func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with(".") or (dir == "res://" and sub == "tests"):
			continue
		out.append_array(_scripts(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			out.append(dir.path_join(file))
	return out
