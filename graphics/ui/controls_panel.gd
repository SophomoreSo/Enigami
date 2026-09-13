class_name ControlsPanel
extends PanelContainer

## Lists every action and lets one be rebound by pressing a key.

var _listening: String = ""
var _rows: Dictionary = {}

func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.style(UiKit.PANEL, Color(0.22, 0.3, 0.38)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	add_child(v)
	v.add_child(UiKit.label("CONTROLS — click a binding, then press a key", 13, UiKit.ACCENT))
	v.add_child(UiKit.hline())
	for entry in Controls.ACTIONS:
		var action: String = entry[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := UiKit.label(String(entry[1]), 11)
		l.custom_minimum_size = Vector2(150, 0)
		row.add_child(l)
		var b := UiKit.button(Controls.label_for(action))
		b.custom_minimum_size = Vector2(200, 24)
		b.pressed.connect(func() -> void:
			_listening = action
			_refresh())
		row.add_child(b)
		_rows[action] = b
		v.add_child(row)
	var rb := UiKit.button("RESET TO DEFAULTS", UiKit.BAD)
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
