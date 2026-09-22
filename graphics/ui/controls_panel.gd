class_name ControlsPanel
extends PanelContainer

## The input settings: how fast the pointer moves, whether the controls are
## drawn on the screen, and which key does what.
##
## The pointer and the console sit at the top rather than with the volumes,
## because what they belong with is this — they are controls, and this is the
## page controls are on. They are drawn in the same two columns as the bindings
## under them, so the name and the thing that sets it line up all the way down
## the panel.

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

## How fast the game's own pointer moves — the crosshair, while the player has
## the controls. Menus are the system pointer's and stay as the desk has them,
## so this is aim speed; `app/pointer.gd` says why it can be nothing else. It
## answers while the slider is being dragged, so it is set by feel and needs no
## number beside it. RESET below is the bindings' own and does not reach up.
func _pointer_row(name_width: int, bind_width: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UiKit.label(Loc.t("controls.sensitivity"), 11, UiKit.TEXT, pixel)
	l.custom_minimum_size = Vector2(name_width, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = Pointer.MIN_SENS
	s.max_value = Pointer.MAX_SENS
	s.step = Pointer.STEP
	s.value = Pointer.sensitivity
	s.custom_minimum_size = Vector2(bind_width, 24)
	UiKit.pixel_slider(s)
	s.value_changed.connect(func(v: float) -> void: Pointer.set_sensitivity(v))
	row.add_child(s)
	return row

## Whether the game puts a console on the screen for a thumb to play on —
## `graphics/ui/touch_pad.gd`, and `app/touch.gd` for what a key on it does.
##
## Three answers rather than a switch, because the right one is usually neither:
## AUTO is on wherever the machine is one you touch and off everywhere else,
## which is what a phone wants without anybody having to find this row first.
## OFF and ON are for the machines that are both — a tablet with a keyboard, a
## desk with a touchscreen — and for looking at the thing on a desk.
##
## Laid out like the language row and rebuilt like it: the button that was
## pressed is the one that has to come back disabled, so the panel is built
## again rather than refreshed.
func _touch_row(name_width: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UiKit.label(Loc.t("controls.touch.label"), 11, UiKit.TEXT, pixel)
	l.custom_minimum_size = Vector2(name_width, 0)
	row.add_child(l)
	for m in Touch.MODE_KEYS.size():
		var picked: bool = m == Touch.mode
		var b := UiKit.button(Touch.mode_name(m), UiKit.ACCENT if picked else UiKit.DIM, pixel)
		b.disabled = picked
		b.pressed.connect(func() -> void:
			Audio.play("ui")
			Touch.set_mode(m)
			_rebuild())
		row.add_child(b)
	return row

func _relanguage(_lang: String) -> void:
	if is_queued_for_deletion():
		return
	_rebuild()

## Built rather than refreshed, so a change of language reaches the action
## names as well as the two buttons, and a console mode picked above comes back
## as the one that is on. Whatever was being listened for is dropped: the panel
## it was going to land in no longer exists.
func _rebuild() -> void:
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
	v.add_child(_pointer_row(name_width, bind_width))
	v.add_child(_touch_row(name_width))
	v.add_child(UiKit.hline(pixel))
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
