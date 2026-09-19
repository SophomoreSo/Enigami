class_name ControlsPanel
extends PanelContainer

## Lists every action and lets one be rebound by pressing a key.

## Set before it enters the tree to build it in UiKit's pixel look. Both screens
## that hold one do — the title's settings and the pause menu.
var pixel: bool = false

var _listening: String = ""
var _rows: Dictionary = {}

func _ready() -> void:
	_build()
	# Self-sufficient, so the panel reads right wherever it is put. Both screens
	# that hold one happen to rebuild it themselves, and the one being thrown
	# away in that rebuild bows out below rather than redressing a corpse.
	Loc.language_changed.connect(_relanguage)

## Built rather than refreshed, so a change of language reaches the action
## names as well as the two buttons. Whatever was being listened for is
## dropped: the panel it was going to land in no longer exists.
func _relanguage(_lang: String) -> void:
	if is_queued_for_deletion():
		return
	_listening = ""
	_rows.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build()

func _build() -> void:
	add_theme_stylebox_override("panel", UiKit.style(UiKit.PANEL, Color(0.22, 0.3, 0.38), 1, 3, pixel))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4 if pixel else 3)
	add_child(v)
	v.add_child(UiKit.label(Loc.t("controls.heading"), 13, UiKit.ACCENT, pixel))
	v.add_child(UiKit.hline(pixel))
	# The pixel face runs up to twice as wide, so both columns widen with it:
	# 200 holds the longest action name, 352 the longest default binding.
	var name_width := 200 if pixel else 150
	var bind_width := 352 if pixel else 200
	for entry in Controls.ACTIONS:
		var action: String = entry[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := UiKit.label(Controls.action_name(action), 11, UiKit.TEXT, pixel)
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
	var rb := UiKit.button(Loc.t("controls.reset"), UiKit.BAD, pixel)
	rb.pressed.connect(func() -> void:
		Controls.reset()
		_refresh())
	v.add_child(rb)

func _refresh() -> void:
	for a in _rows:
		var b: Button = _rows[a]
		b.text = Loc.t("controls.listening") if a == _listening else Controls.label_for(a)

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
