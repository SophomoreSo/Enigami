class_name Controls
extends RefCounted

## Key rebinding. Overrides live in a small JSON file next to the save; the
## project's defaults stay untouched so a reset is always one click away.

const PATH := "user://enigami_controls.json"

const ACTIONS := [
	["move_left", "Move left"],
	["move_right", "Move right"],
	["move_up", "Aim up"],
	["move_down", "Aim down / drop"],
	["jump", "Jump"],
	["dash", "Dash"],
	["attack", "Attack (weapon)"],
	["cast_skill", "Cast armed skill"],
	["skill_1", "Arm slot 1"],
	["skill_2", "Arm slot 2"],
	["skill_3", "Arm slot 3"],
	["skill_4", "Arm slot 4"],
	["open_editor", "Skill assembly"],
	["interact", "Interact / extract"],
	["pause", "Pause"],
]

static var _defaults: Dictionary = {}

## Snapshot the project defaults once, so "reset" can restore them later.
static func capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for entry in ACTIONS:
		var a: String = entry[0]
		if InputMap.has_action(a):
			_defaults[a] = InputMap.action_get_events(a).duplicate()

static func label_for(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	var names: Array[String] = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			names.append(OS.get_keycode_string((e as InputEventKey).physical_keycode))
		elif e is InputEventMouseButton:
			var idx := (e as InputEventMouseButton).button_index
			names.append({1: "LMB", 2: "RMB", 3: "MMB"}.get(idx, "Mouse %d" % idx))
		elif e is InputEventJoypadButton:
			names.append("Pad %d" % (e as InputEventJoypadButton).button_index)
		elif e is InputEventJoypadMotion:
			var m := e as InputEventJoypadMotion
			names.append("Pad axis %d%s" % [m.axis, "+" if m.axis_value > 0 else "-"])
	if names.is_empty():
		return "unbound"
	return " / ".join(names)

## The single binding a HUD should print: the first keyboard or mouse one, with
## the pad and any alternates left off. `label_for` lists everything, which is
## right for the rebinding screen and far too long for a slot card.
static func short_label_for(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			# The game's own actions are bound by position on the board, so they
			# carry a physical code. Godot's built-in `ui_*` actions carry a
			# keycode instead and leave the physical one at zero, which read as
			# a binding with no name at all — an empty hint under a cutscene.
			var key := e as InputEventKey
			var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
			return OS.get_keycode_string(code)
		if e is InputEventMouseButton:
			var idx := (e as InputEventMouseButton).button_index
			return {1: "LMB", 2: "RMB", 3: "MMB"}.get(idx, "Mouse %d" % idx)
	return "—"

## Replaces the keyboard/mouse binding of `action`, leaving the gamepad one.
static func rebind(action: String, event: InputEvent) -> bool:
	if not InputMap.has_action(action):
		return false
	if not (event is InputEventKey or event is InputEventMouseButton):
		return false
	for e in InputMap.action_get_events(action):
		if e is InputEventKey or e is InputEventMouseButton:
			InputMap.action_erase_event(action, e)
	InputMap.action_add_event(action, event)
	save()
	return true

static func reset() -> void:
	capture_defaults()
	for a in _defaults:
		InputMap.action_erase_events(a)
		for e in _defaults[a]:
			InputMap.action_add_event(a, e)
	save()

static func save() -> void:
	var data: Dictionary = {}
	for entry in ACTIONS:
		var a: String = entry[0]
		if not InputMap.has_action(a):
			continue
		var list: Array = []
		for e in InputMap.action_get_events(a):
			if e is InputEventKey:
				list.append({"t": "key", "k": (e as InputEventKey).physical_keycode})
			elif e is InputEventMouseButton:
				list.append({"t": "mouse", "b": (e as InputEventMouseButton).button_index})
		if not list.is_empty():
			data[a] = list
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

static func load_saved() -> void:
	capture_defaults()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for a in parsed:
		if not InputMap.has_action(a):
			continue
		for e in InputMap.action_get_events(a):
			if e is InputEventKey or e is InputEventMouseButton:
				InputMap.action_erase_event(a, e)
		for entry in parsed[a]:
			if String(entry.get("t", "")) == "key":
				var k := InputEventKey.new()
				k.physical_keycode = int(entry["k"])
				InputMap.action_add_event(a, k)
			elif String(entry.get("t", "")) == "mouse":
				var m := InputEventMouseButton.new()
				m.button_index = int(entry["b"])
				InputMap.action_add_event(a, m)
