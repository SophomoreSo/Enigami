class_name Hud
extends Control

## Raid HUD: health, the live state of each skill circuit, the bag you stand to
## lose, and a map of what you have walked through.

var player: Player = null
var map: RaidMap = null
var room = null
var prompt: String = ""
var extract_ratio: float = 0.0
var tutorial: String = ""
var toast: String = ""
var toast_time: float = 0.0
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_toast(t: String) -> void:
	toast = t
	toast_time = 2.6

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	if toast_time > 0.0:
		toast_time -= delta
	queue_redraw()

func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var vp := get_viewport_rect().size
	_draw_health()
	_draw_slots(vp)
	_draw_bag(vp)
	_draw_map(vp)
	_draw_prompts(vp)

func _draw_health() -> void:
	var w := 260.0
	draw_rect(Rect2(24, 24, w, 18), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(24, 24, w * player.health_ratio(), 18), Color(0.9, 0.35, 0.38))
	draw_rect(Rect2(24, 24, w, 18), Color(0.5, 0.6, 0.7, 0.8), false, 1.5)
	draw_string(_font, Vector2(30, 38), "%d / %d" % [int(player.health), int(player.max_health)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))
	_draw_stamina(w)
	_draw_mana(w)
	var wdef := Weapons.get_def(player.weapon_id)
	draw_string(_font, Vector2(24, 86), String(wdef["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Style.weapon_color(player.weapon_id))
	if player.burn_time > 0.0:
		draw_string(_font, Vector2(100, 86), "BURNING", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.5, 0.2))
	if player.chill_time > 0.0:
		draw_string(_font, Vector2(170, 86), "CHILLED", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.85, 1))

## Slimmer and quieter than health: this is a budget, not a life. It is divided
## into one segment per dash, so the question it answers at a glance is "how
## many more dashes", not "what percentage".
func _draw_stamina(w: float) -> void:
	var bar := Rect2(24, 46, w, 9)
	draw_rect(bar, Color(0, 0, 0, 0.55))
	var col := Color(0.45, 0.82, 0.62)
	if player.stamina < Player.DASH_STAMINA:
		col = Color(0.85, 0.55, 0.3)   # not enough left for another dash
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * player.stamina_ratio(), bar.size.y)), col)
	var segments := int(round(Player.MAX_STAMINA / Player.DASH_STAMINA))
	for i in range(1, segments):
		var sx := bar.position.x + bar.size.x * float(i) / float(segments)
		draw_line(Vector2(sx, bar.position.y), Vector2(sx, bar.end.y), Color(0, 0, 0, 0.55), 1.0)
	draw_rect(bar, Color(0.5, 0.6, 0.7, 0.8), false, 1.0)

## Mana pays for charging, so the charge bought so far is drawn riding on top of
## it: the two numbers only mean anything next to each other.
func _draw_mana(w: float) -> void:
	var bar := Rect2(24, 58, w, 9)
	draw_rect(bar, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * player.mana_ratio(), bar.size.y)),
		Color(0.38, 0.55, 0.95))
	if player.charge > 0.0:
		# A strip along the top rather than a second fill over the first: the
		# charge is what the mana was spent on, and both have to stay readable.
		var cw := bar.size.x * player.charge_ratio()
		draw_rect(Rect2(bar.position, Vector2(cw, 3.0)), PlayerView.CHARGE_COLOR)
		draw_string(_font, Vector2(bar.end.x + 8, bar.end.y), "+%d LIFE" % int(player.charge),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.82, 0.72, 1.0))
	draw_rect(bar, Color(0.5, 0.6, 0.7, 0.8), false, 1.0)

## The weapon's own attack sits first, then each slot. Which slot is armed has
## to be obvious at a glance: it is the one the cast button will run.
func _draw_slots(vp: Vector2) -> void:
	var x := 24.0
	var y := vp.y - 92.0
	if player.basic_runner != null:
		# The weapon's own board is always something the weapon carries.
		_draw_slot_card(Rect2(x, y, 128, 64), player.basic_runner,
			Controls.short_label_for("attack"), "Weapon attack", false, true)
		x += 136.0
	for i in player.runners.size():
		var armed := i == player.selected_slot
		var key := Controls.short_label_for("skill_%d" % (i + 1))
		_draw_slot_card(Rect2(x, y, 128, 64), player.runners[i], key,
			player.runners[i].board.skill_name, armed, player.can_cast(i))
		x += 136.0
	draw_string(_font, Vector2(24, y - 8),
		"%s attacks · number keys arm a skill · hold %s to charge, release to cast" % [
			Controls.short_label_for("attack"), Controls.short_label_for("cast_skill")],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.65, 0.78))

func _draw_slot_card(rect: Rect2, r: SkillRunner, key: String, name: String,
		armed: bool, usable: bool) -> void:
	draw_rect(rect, Color(0.10, 0.13, 0.17, 0.9) if armed else Color(0.08, 0.09, 0.12, 0.85))
	# Read from the binding rather than spelled out here, so the card stays
	# honest after a rebind.
	var title := Color(0.85, 0.92, 1.0)
	if not usable:
		title = Color(0.72, 0.55, 0.58)
	elif armed:
		title = Color(1, 1, 1)
	draw_string(_font, rect.position + Vector2(8, 18), "%s  %s" % [key, name],
		HORIZONTAL_ALIGNMENT_LEFT, 116, 10, title)
	if not usable:
		# The weapon is the reason, so name the weapon.
		draw_string(_font, rect.position + Vector2(8, 40),
			"NOT ON %s" % String(Weapons.get_def(player.weapon_id)["name"]).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, 116, 9, Color(1.0, 0.5, 0.48))
	elif armed:
		draw_string(_font, rect.position + Vector2(8, 40), "ARMED",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 1.0, 0.85))
	var pulses := r.pulses.size()
	draw_string(_font, rect.position + Vector2(8, 54), "%d pulse%s" % [pulses, "" if pulses == 1 else "s"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.7, 0.8))
	# Drawn last: the sheet covers the card's own text as it recedes, which is
	# what makes a slot read as unavailable at a glance.
	var border := Color(0.3, 0.35, 0.42)
	if not usable:
		border = Color(0.85, 0.35, 0.35)
	elif r.active:
		border = Color(0.5, 0.9, 1.0)
	elif armed:
		border = Color(0.45, 0.95, 0.8)
	UiKit.draw_cooldown(self, rect, r.ready_ratio(), r.ready_flash, border)

func _draw_bag(vp: Vector2) -> void:
	var x := vp.x - 232.0
	draw_rect(Rect2(x - 12, 16, 224, 150), Color(0.07, 0.08, 0.11, 0.85))
	draw_rect(Rect2(x - 12, 16, 224, 150), Color(0.35, 0.5, 0.65, 0.6), false, 1.2)
	draw_string(_font, Vector2(x, 38), "BAG (lost on death)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.75, 0.5))
	draw_string(_font, Vector2(x, 58), "scrap %d" % GameState.raid_scrap, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.85, 0.45))
	var y := 78.0
	var n := 0
	for id in GameState.raid_bag:
		if n >= 5:
			draw_string(_font, Vector2(x, y), "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.75, 0.8))
			break
		draw_string(_font, Vector2(x, y), "%s x%d" % [Components.get_def(id).get("name", id), int(GameState.raid_bag[id])],
			HORIZONTAL_ALIGNMENT_LEFT, 200, 10, Style.component_color(id))
		y += 16.0
		n += 1
	if GameState.raid_bag.is_empty():
		draw_string(_font, Vector2(x, y), "empty", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.55, 0.6))

func _draw_map(vp: Vector2) -> void:
	if map == null:
		return
	var cell := 20.0
	var origin := Vector2(vp.x - 232.0, 182.0)
	draw_rect(Rect2(origin - Vector2(12, 12), Vector2(RaidMap.MW * cell + 24, RaidMap.MH * cell + 44)), Color(0.07, 0.08, 0.11, 0.85))
	draw_rect(Rect2(origin - Vector2(12, 12), Vector2(RaidMap.MW * cell + 24, RaidMap.MH * cell + 44)), Color(0.35, 0.5, 0.65, 0.6), false, 1.2)
	for c in map.rooms:
		var rec: Dictionary = map.rooms[c]
		var r := Rect2(origin + Vector2(c.x * cell, c.y * cell), Vector2(cell - 3, cell - 3))
		var visited := bool(rec.get("visited", false))
		var col := Color(0.2, 0.24, 0.3)
		if visited:
			match String(rec["kind"]):
				"entry": col = Color(0.4, 0.8, 0.6)
				"boss": col = Color(0.9, 0.4, 0.5)
				"treasure": col = Color(0.9, 0.8, 0.4)
				_: col = Color(0.4, 0.5, 0.62)
		draw_rect(r, col)
		if visited and rec.has("extraction"):
			draw_circle(r.get_center(), 3.5, Color(0.5, 1.0, 0.75))
		if room != null and c == room.coord:
			draw_rect(r.grow(2), Color(1, 1, 1, 0.9), false, 1.5)
	var press := map.pressure()
	var ptxt: String = ["quiet", "stirring", "alert", "hunting", "swarming"][clampi(press, 0, 4)]
	draw_string(_font, origin + Vector2(0, RaidMap.MH * cell + 20), "%02d:%02d  •  %s" % [
		int(map.elapsed / 60.0), int(map.elapsed) % 60, ptxt],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.8, 0.9) if press < 3 else Color(1.0, 0.6, 0.5))

func _draw_prompts(vp: Vector2) -> void:
	if prompt != "":
		draw_string(_font, Vector2(vp.x * 0.5 - 200, vp.y - 120), prompt, HORIZONTAL_ALIGNMENT_CENTER, 400, 13, Color(0.85, 0.95, 1.0))
	if extract_ratio > 0.0:
		var w := 300.0
		var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y * 0.5 + 120, w, 14)
		draw_rect(r, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(r.position, Vector2(w * extract_ratio, r.size.y)), Color(0.5, 1.0, 0.8))
		draw_string(_font, r.position + Vector2(0, -6), "EXTRACTING", HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.7, 1.0, 0.9))
	if tutorial != "":
		var box := Rect2(vp.x * 0.5 - 300, 136, 600, 40)
		draw_rect(box, Color(0.07, 0.08, 0.11, 0.85))
		draw_rect(box, Color(0.45, 0.8, 1.0, 0.6), false, 1.2)
		draw_string(_font, box.position + Vector2(0, 25), tutorial, HORIZONTAL_ALIGNMENT_CENTER, 600, 13, Color(0.8, 0.92, 1.0))
	if toast_time > 0.0:
		var a := clampf(toast_time / 0.8, 0.0, 1.0)
		draw_string(_font, Vector2(vp.x * 0.5 - 250, 110), toast, HORIZONTAL_ALIGNMENT_CENTER, 500, 14, Color(1, 0.95, 0.8, a))
	draw_string(_font, Vector2(24, get_viewport_rect().size.y - 16), "TAB assemble   F interact   SHIFT dash",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.58, 0.66))
