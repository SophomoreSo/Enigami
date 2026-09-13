class_name ControlsPanel
extends PanelContainer

## Lists every action and lets one be rebound by pressing a key.

## Set before it enters the tree to build it in UiKit's pixel look. The title's
## settings do; the pause menu keeps the plain one.
var pixel: bool = false

var _listening: String = ""
var _rows: Dictionary = {}

func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.style(UiKit.PANEL, Color(0.22, 0.3, 0.38), 1, 3, pixel))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4 if pixel else 3)
	add_child(v)
	v.add_child(UiKit.label("CONTROLS — click a binding, then press a key", 13, UiKit.ACCENT, pixel))
	v.add_child(UiKit.hline(pixel))
	# The pixel face runs up to twice as wide, so both columns widen with it:
	# 200 holds the longest action name, 352 the longest default binding.
	var name_width := 200 if pixel else 150
	var bind_width := 352 if pixel else 200
	for entry in Controls.ACTIONS:
		var action: String = entry[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := UiKit.label(String(entry[1]), 11, UiKit.TEXT, pixel)
		l.custom_minimum_size = Vector2(name_width, 0)
		row.add_child(l)
		var b := UiKit.button(Controls.label_for(action), UiKit.ACCENT, pixel)
		b.custom_minimum_size = Vector2(bind_width, 24)
		b.pressed.connect(func() -> void:
			_listening = action
			_refresh())
		row.add_child(b)
		_rows[action] = b
		v.add_child(row)
	var rb := UiKit.button("RESET TO DEFAULTS", UiKit.BAD, pixel)
	rb.pressed.connect(func() -> void:
		Controls.reset()
		_refresh())
	v.add_child(rb)

func _refresh() -> void:
	for a in _rows:
		var b: Button = _rows[a]
		b.text = "press a key…" if a == _listening else Controls.label_for(a)

func _input(event: InputEvent) -> void:
	if _listening == "" or not visible:
		return
	if not event.is_pressed():
		return
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		_listening = ""
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if Controls.rebind(_listening, event):
		Audio.play("place")
		_listening = ""
		_refresh()
		get_viewport().set_input_as_handled()
