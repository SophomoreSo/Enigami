class_name SandboxPanel
extends Control

## Side panel with the controls and readouts a test bench needs: what weapon is
## in hand, what the last three seconds of damage came to, the meters a charge
## moves, and a button for every monster.
##
## Drawn in UiKit's pixel look, like the assembly screen it shares the bench
## with: the buttons are the kit's pixel ones and everything drawn here goes
## through `PixelDraw`, which snaps it to the PIXEL grid.

## The readout, wide enough for the longest line it carries — the damage figure
## with four digits in front of the point.
const PANEL := Rect2(12, 16, 372, 120)
const TEXT_X := 24.0
const METER_W := 348.0
const METER_H := 8.0
## The buttons start under the readout.
const BUTTONS_AT := Vector2(20, 152)
## A slot card, wide enough for its cycle line; a longer skill name is cut short.
const CARD := Vector2(240, 56)
const CARD_GAP := 8.0
## Where the row of cards sits above the bottom of the screen.
const CARD_BOTTOM := 80.0

var sandbox: Sandbox
var _sim: Array = []
var _px := PixelDraw.new(self)

## The cached cycle previews are only as good as the loadout they were run
## against; the bench clears them whenever it changes underneath.
func invalidate() -> void:
	_sim.clear()

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var v := VBoxContainer.new()
	v.position = BUTTONS_AT
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	var wb := UiKit.overlay_button("SWAP WEAPON", UiKit.ACCENT, true)
	wb.pressed.connect(func() -> void: sandbox.cycle_weapon())
	v.add_child(wb)
	var dt := UiKit.overlay_button("DRAGON TEST ▶", UiKit.ACCENT, true)
	dt.pressed.connect(func() -> void: sandbox.open_dragon_test())
	v.add_child(dt)
	for kind in Sandbox.MONSTER_BUTTONS:
		var b := UiKit.overlay_button("spawn %s" % Monsters.get_def(kind)["name"], UiKit.WARN, true)
		b.pressed.connect(func() -> void: sandbox.spawn_monster(kind))
		v.add_child(b)
	var db := UiKit.overlay_button("spawn dummy", UiKit.GOOD, true)
	db.pressed.connect(func() -> void: sandbox.spawn_dummy())
	v.add_child(db)
	var cb := UiKit.overlay_button("clear", UiKit.BAD, true)
	cb.pressed.connect(func() -> void: sandbox.clear_monsters())
	v.add_child(cb)
	var xb := UiKit.overlay_button("leave (ESC)", UiKit.ACCENT, true)
	xb.pressed.connect(func() -> void: sandbox.leave())
	v.add_child(xb)

func _process(_d: float) -> void:
	UiKit.sync_screen(self)
	queue_redraw()

func _draw() -> void:
	if sandbox == null or not is_instance_valid(sandbox) or sandbox.player == null:
		return
	_draw_readout()
	_draw_cards()

func _draw_readout() -> void:
	_px.rect(PANEL, Color(0.07, 0.08, 0.11, 0.85))
	_px.frame(PANEL, Color(0.35, 0.5, 0.65, 0.6))
	var weapon := sandbox.current_weapon()
	var width := PANEL.size.x - (TEXT_X - PANEL.position.x) * 2.0
	_px.text(Vector2(TEXT_X, 40), "SANDBOX · %s" % String(Weapons.get_def(weapon)["name"]).to_upper(),
		Style.weapon_color(weapon), width)
	_px.text(Vector2(TEXT_X, 60), "damage/sec (3s avg): %.1f" % sandbox.dps(), UiKit.GOOD, width)
	# Two rows for the keys, since a rebound one can be a whole gamepad axis.
	var hint := "%s assemble · %s attacks · 1-3 arm · hold %s to charge" % [
		Controls.short_label_for("open_editor"), Controls.short_label_for("attack"),
		Controls.short_label_for("cast_skill")]
	var rows := PixelDraw.wrap(hint, width, 2)
	for i in rows.size():
		_px.text(Vector2(TEXT_X, 80 + i * PixelDraw.LINE), rows[i], UiKit.DIM)
	_draw_meters()

## Stamina and mana, so what a charge costs is visible in the room skills are
## tested in and not only in a raid. What it buys is over the player's head, the
## same as anywhere else.
func _draw_meters() -> void:
	var p := sandbox.player
	var ground := Color(0, 0, 0, 0.55)
	var edge := Color(0.5, 0.6, 0.7, 0.7)
	_px.bar(Rect2(TEXT_X, 106, METER_W, METER_H), p.stamina_ratio(),
		Color(0.45, 0.82, 0.62), ground, edge)
	_px.bar(Rect2(TEXT_X, 118, METER_W, METER_H), p.mana_ratio(),
		Color(0.38, 0.55, 0.95), ground, edge)

func _draw_cards() -> void:
	var y := get_viewport_rect().size.y - CARD_BOTTOM
	for i in sandbox.player.runners.size():
		var r: SkillRunner = sandbox.player.runners[i]
		var armed := i == sandbox.player.selected_slot
		var usable := sandbox.player.can_cast(i)
		var card := Rect2(Vector2(TEXT_X + i * (CARD.x + CARD_GAP), y), CARD)
		_px.rect(card, Color(0.10, 0.13, 0.17, 0.9) if armed else Color(0.07, 0.08, 0.11, 0.85))
		var title := UiKit.TEXT
		if not usable:
			title = Color(0.72, 0.55, 0.58)
		elif armed:
			title = Color(1, 1, 1)
		# Two characters of marker either way, so the name does not shift as the
		# armed slot moves. An X where the weapon will not carry the board.
		var text_w := card.size.x - 16.0
		_px.text(card.position + Vector2(8, 24), "%s%d · %s%s" % [
			"> " if armed else "  ", i + 1, r.board.skill_name, "" if usable else "  X"],
			title, text_w)
		_px.text(card.position + Vector2(8, 44), "cycle %.2fs · out %d" % [
			float(_preview(i, r)["cycle_seconds"]), (_preview(i, r)["outputs"] as Array).size()],
			UiKit.DIM, text_w)
		var border := Color(0.3, 0.35, 0.42)
		if not usable:
			border = Color(0.85, 0.35, 0.35)
		elif r.active:
			border = Color(0.5, 0.9, 1.0)
		elif armed:
			border = Color(0.45, 0.95, 0.8)
		_px.cooldown(card, r.ready_ratio(), r.ready_flash, border)

## The offline walk of slot `i`'s board, run once and kept until the loadout
## changes (see `invalidate`).
func _preview(i: int, r: SkillRunner) -> Dictionary:
	while _sim.size() <= i:
		_sim.append({})
	if _sim[i].is_empty():
		var sim := SkillRunner.new(r.board)
		var weapon := sandbox.current_weapon()
		sim.base_payload_provider = func() -> Payload: return Weapons.base_payload(weapon)
		_sim[i] = sim.simulate()
	return _sim[i]
