class_name SandboxPanel
extends Control

## Side panel with the controls and readouts a test bench needs: what weapon is
## in hand, what the last three seconds of damage came to, the meters a charge
## moves, and a button for every monster.

var sandbox: Sandbox
var _font: Font
var _sim: Array = []

## The cached cycle previews are only as good as the loadout they were run
## against; the bench clears them whenever it changes underneath.
func invalidate() -> void:
	_sim.clear()

func _ready() -> void:
	_font = ThemeDB.fallback_font
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	# Clear of the readout panel above, which carries the meters too.
	v.position = Vector2(20, 120)
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	var wb := UiKit.overlay_button("SWAP WEAPON", UiKit.ACCENT)
	wb.pressed.connect(func() -> void: sandbox.cycle_weapon())
	v.add_child(wb)
	for kind in Sandbox.MONSTER_BUTTONS:
		var b := UiKit.overlay_button("spawn %s" % Monsters.get_def(kind)["name"], UiKit.WARN)
		b.pressed.connect(func() -> void: sandbox.spawn_monster(kind))
		v.add_child(b)
	var db := UiKit.overlay_button("spawn dummy", UiKit.GOOD)
	db.pressed.connect(func() -> void: sandbox.spawn_dummy())
	v.add_child(db)
	var cb := UiKit.overlay_button("clear", UiKit.BAD)
	cb.pressed.connect(func() -> void: sandbox.clear_monsters())
	v.add_child(cb)
	var xb := UiKit.overlay_button("leave (ESC)")
	xb.pressed.connect(func() -> void: sandbox.leave())
	v.add_child(xb)

func _process(_d: float) -> void:
	UiKit.sync_screen(self)
	queue_redraw()

## Stamina and mana, so a charge is visible in the room skills are tested in
## and not only in a raid.
func _draw_meters() -> void:
	var p := sandbox.player
	var w := 276.0
	var st := Rect2(24, 82, w, 8)
	draw_rect(st, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(st.position, Vector2(w * p.stamina_ratio(), st.size.y)),
		Color(0.45, 0.82, 0.62))
	draw_rect(st, Color(0.5, 0.6, 0.7, 0.7), false, 1.0)
	var mn := Rect2(24, 93, w, 8)
	draw_rect(mn, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(mn.position, Vector2(w * p.mana_ratio(), mn.size.y)),
		Color(0.38, 0.55, 0.95))
	if p.charge > 0.0:
		draw_rect(Rect2(mn.position, Vector2(w * p.charge_ratio(), 3.0)),
			PlayerView.CHARGE_COLOR)
		draw_string(_font, Vector2(mn.end.x + 8, mn.end.y), "+%d LIFE" % int(p.charge),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.82, 0.72, 1.0))
	draw_rect(mn, Color(0.5, 0.6, 0.7, 0.7), false, 1.0)

func _draw() -> void:
	if sandbox == null or not is_instance_valid(sandbox) or sandbox.player == null:
		return
	var vp := get_viewport_rect().size
	draw_rect(Rect2(12, 16, 320, 92), Color(0.07, 0.08, 0.11, 0.85))
	draw_rect(Rect2(12, 16, 320, 92), Color(0.35, 0.5, 0.65, 0.6), false, 1.2)
	var weapon := sandbox.current_weapon()
	draw_string(_font, Vector2(24, 38), "SANDBOX · %s" % String(Weapons.get_def(weapon)["name"]).to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Style.weapon_color(weapon))
	draw_string(_font, Vector2(24, 58), "damage/sec (3s avg): %.1f" % sandbox.dps(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.GOOD)
	draw_string(_font, Vector2(24, 72), "TAB assemble · %s attacks · 1-3 arm · hold %s to charge" % [
			Controls.short_label_for("attack"), Controls.short_label_for("cast_skill")],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.DIM)
	_draw_meters()

	var x := 24.0
	var y := vp.y - 80.0
	for i in sandbox.player.runners.size():
		var r: SkillRunner = sandbox.player.runners[i]
		var armed := i == sandbox.player.selected_slot
		var usable := sandbox.player.can_cast(i)
		var card := Rect2(x, y, 150, 52)
		draw_rect(card, Color(0.10, 0.13, 0.17, 0.9) if armed else Color(0.07, 0.08, 0.11, 0.85))
		var title := UiKit.TEXT
		if not usable:
			title = Color(0.72, 0.55, 0.58)
		elif armed:
			title = Color(1, 1, 1)
		draw_string(_font, Vector2(x + 8, y + 18),
			"%s%d · %s%s" % ["▸ " if armed else "", i + 1, r.board.skill_name,
				"" if usable else "  ✕"],
			HORIZONTAL_ALIGNMENT_LEFT, 138, 10, title)
		while _sim.size() <= i:
			_sim.append({})
		if _sim[i].is_empty():
			var sim := SkillRunner.new(r.board)
			sim.base_payload_provider = func() -> Payload: return Weapons.base_payload(weapon)
			_sim[i] = sim.simulate()
		var res: Dictionary = _sim[i]
		draw_string(_font, Vector2(x + 8, y + 34), "cycle %.2fs · out %d" % [
			float(res["cycle_seconds"]), (res["outputs"] as Array).size()],
			HORIZONTAL_ALIGNMENT_LEFT, 138, 10, UiKit.DIM)
		var border := Color(0.3, 0.35, 0.42)
		if not usable:
			border = Color(0.85, 0.35, 0.35)
		elif r.active:
			border = Color(0.5, 0.9, 1.0)
		elif armed:
			border = Color(0.45, 0.95, 0.8)
		UiKit.draw_cooldown(self, card, r.ready_ratio(), r.ready_flash, border)
		x += 158.0
