class_name TitleScreen
extends Control

signal start_requested()
signal sandbox_requested()

var _t: float = 0.0
var _shapes: Array = []
var _font: Font
var _settings: Control

func _ready() -> void:
	_font = ThemeDB.fallback_font
	UiKit.fill_screen(self)
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 26:
		_shapes.append({
			"p": Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)),
			"v": Vector2(rng.randf_range(-14, 14), rng.randf_range(-10, 10)),
			"r": rng.randf_range(8, 40),
			"n": rng.randi_range(3, 6),
			"a": rng.randf_range(0, TAU),
			"c": [Components.COL_FORM, Components.COL_FLOW, Components.COL_BEHAVIOR, Components.COL_TRIGGER][rng.randi() % 4],
		})

	var v := VBoxContainer.new()
	v.position = Vector2(120, 250)
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UiKit.spacer(80))
	var b1 := UiKit.button("DEPLOY", UiKit.GOOD)
	b1.custom_minimum_size = Vector2(240, 42)
	b1.pressed.connect(func() -> void: start_requested.emit())
	v.add_child(b1)
	var b2 := UiKit.button("SANDBOX")
	b2.custom_minimum_size = Vector2(240, 36)
	b2.pressed.connect(func() -> void: sandbox_requested.emit())
	v.add_child(b2)
	var b3 := UiKit.button("SETTINGS")
	b3.custom_minimum_size = Vector2(240, 36)
	b3.pressed.connect(_toggle_settings)
	v.add_child(b3)
	var b4 := UiKit.button("QUIT", UiKit.BAD)
	b4.custom_minimum_size = Vector2(240, 36)
	b4.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(b4)
	b1.grab_focus()
	_build_settings()
	Audio.play_music()

func _build_settings() -> void:
	_settings = UiKit.panel()
	_settings.position = Vector2(500, 90)
	_settings.custom_minimum_size = Vector2(560, 540)
	_settings.visible = false
	add_child(_settings)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_settings.add_child(v)
	v.add_child(UiKit.label("SETTINGS", 15, UiKit.ACCENT))
	v.add_child(UiKit.hline())
	v.add_child(_slider("Music", Audio.music_volume, func(val: float) -> void: Audio.set_music_volume(val)))
	v.add_child(_slider("Sound", Audio.sfx_volume, func(val: float) -> void:
		Audio.set_sfx_volume(val)
		Audio.play("ui")))
	v.add_child(UiKit.spacer(6))
	v.add_child(UiKit.label("Aim with the mouse, or the right stick on a gamepad.", 11, UiKit.DIM))
	v.add_child(UiKit.label("Gamepad: left stick moves, A jumps, B dashes, triggers fire slots 1-2.", 11, UiKit.DIM))
	v.add_child(UiKit.spacer(6))
	v.add_child(ControlsPanel.new())
	v.add_child(UiKit.spacer(8))
	var rb := UiKit.button("WIPE PROFILE", UiKit.BAD)
	rb.pressed.connect(func() -> void:
		GameState.reset_profile()
		Audio.play("deny"))
	v.add_child(rb)

func _slider(name: String, value: float, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UiKit.label(name, 12)
	l.custom_minimum_size = Vector2(70, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(240, 20)
	s.value_changed.connect(cb)
	h.add_child(s)
	return h

func _toggle_settings() -> void:
	_settings.visible = not _settings.visible
	Audio.play("ui")

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_t += delta
	for s in _shapes:
		s["p"] += s["v"] * delta
		s["a"] += delta * 0.25
		if s["p"].x < -60: s["p"].x = 1340
		if s["p"].x > 1340: s["p"].x = -60
		if s["p"].y < -60: s["p"].y = 780
		if s["p"].y > 780: s["p"].y = -60
	queue_redraw()

func _draw() -> void:
	for s in _shapes:
		var pts := PackedVector2Array()
		for i in int(s["n"]):
			var a: float = s["a"] + TAU * float(i) / float(s["n"])
			pts.append(s["p"] + Vector2(cos(a), sin(a)) * float(s["r"]))
		pts.append(pts[0])
		var c: Color = s["c"]
		draw_polyline(pts, Color(c.r, c.g, c.b, 0.16), 1.5)

	draw_string(_font, Vector2(120, 180), "ENIGAMI", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(0.9, 0.95, 1.0))
	draw_string(_font, Vector2(124, 214), "assemble the skill · carry it out alive",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiKit.DIM)
	var r: Dictionary = GameState.records
	draw_string(_font, Vector2(120, 660), "raids %d · escaped %d · lost %d · kills %d · best haul %d" % [
		r["raids"], r["escapes"], r["deaths"], r["kills"], r["best_haul"]],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.DIM)
