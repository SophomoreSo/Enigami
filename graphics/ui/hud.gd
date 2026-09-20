class_name Hud
extends Control

## Raid HUD: health, and the live state of each skill circuit.
##
## Drawn rather than built, in UiKit's pixel look: Silkscreen at its own size,
## boxes square and unsmoothed with a PIXEL of edge, everything on the PIXEL
## grid — the standard the assembly screen and the bench readout are held to,
## and `PixelDraw` is the kit for all three. This was the last screen still
## writing in the default face at nine pixels, which read as another game's
## interface laid over this one.
##
## The pixel face runs up to twice as wide as the one it replaced, so the
## numbers it stands on are bigger too: the bars, the cards and the gaps between
## them are all `PIXEL`-multiples now, and a card that used to hold a name at
## 128 wide holds it at CARD.x.
##
## What is not here is deliberate. The map is a window of its own now — see
## `MapPanel`, opened from `RaidView` — and the bag is gone: a list of parts
## nobody can spend until they are at the workbench was five lines of the screen
## saying nothing the assembly screen does not say better.

## The bars in the top-left corner: health, then the two thin ones under it.
const BAR_W := 264.0
const BAR_AT := Vector2(24, 24)
const HEALTH_H := 24.0
const THIN_H := 12.0
## A slot card, and the gap to the next one along. Wide enough for the longest
## title a card carries — a binding, two spaces and the weapon's own attack —
## in the pixel face, which runs up to twice as wide as the one this screen used
## to be written in.
const CARD := Vector2(240, 72)
const CARD_GAP := 8.0
## How far the row of cards sits above the bottom of the screen.
const CARD_LIFT := 36.0

## What a bar is drawn on, and the edge around it. Shared by all four of them,
## so a meter reads as a meter wherever it is.
const BAR_GROUND := Color(0, 0, 0, 0.55)
const BAR_EDGE := Color(0.5, 0.6, 0.7, 0.8)

var player: Player = null
var prompt: String = ""
var extract_ratio: float = 0.0
var toast: String = ""
var toast_time: float = 0.0
## The pixel grid, bound to this screen.
var _px := PixelDraw.new(self)

func _ready() -> void:
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
	_draw_prompts(vp)

func _draw_health() -> void:
	var bar := Rect2(BAR_AT, Vector2(BAR_W, HEALTH_H))
	_px.bar(bar, player.health_ratio(), Color(0.9, 0.35, 0.38), BAR_GROUND, BAR_EDGE)
	# Inside the bar rather than over it: at this size the numbers are tall
	# enough to sit in it, and it is one less line down the side of the screen.
	_px.text(bar.position + Vector2(8, 18),
		Loc.t("hud.health", [int(player.health), int(player.max_health)]),
		Color(1, 1, 1, 0.9), BAR_W - 16.0)
	_draw_stamina()
	_draw_mana()

	# The weapon, and what is burning or freezing whoever carries it, on one
	# line: each stands where the one before it ended, so a long name in any
	# language pushes them along rather than being written over.
	var at := Vector2(BAR_AT.x, 108.0)
	var weapon := Weapons.name_for(player.weapon_id).to_upper()
	_px.text(at, weapon, Style.weapon_color(player.weapon_id))
	at.x += PixelDraw.text_width(weapon) + 16.0
	if player.burn_time > 0.0:
		var burning := Loc.t("hud.burning")
		_px.text(at, burning, Color(1, 0.5, 0.2))
		at.x += PixelDraw.text_width(burning) + 16.0
	if player.chill_time > 0.0:
		_px.text(at, Loc.t("hud.chilled"), Color(0.5, 0.85, 1))

## Slimmer and quieter than health: this is a budget, not a life. It is divided
## into one segment per dash, so the question it answers at a glance is "how
## many more dashes", not "what percentage".
func _draw_stamina() -> void:
	var bar := Rect2(BAR_AT + Vector2(0, HEALTH_H + 4.0), Vector2(BAR_W, THIN_H))
	var col := Color(0.45, 0.82, 0.62)
	if player.stamina < Player.DASH_STAMINA:
		col = Color(0.85, 0.55, 0.3)   # not enough left for another dash
	_px.rect(bar, BAR_GROUND)
	_px.rect(Rect2(bar.position, Vector2(bar.size.x * player.stamina_ratio(), bar.size.y)), col)
	# The notches are cut out of the fill a whole PIXEL wide, inside the edge
	# that is drawn over them: a hairline between two segments is the one thing
	# a grid this size cannot draw.
	var segments := int(round(Player.MAX_STAMINA / Player.DASH_STAMINA))
	for i in range(1, segments):
		var sx := bar.position.x + bar.size.x * float(i) / float(segments)
		_px.rect(Rect2(sx - PixelDraw.PX, bar.position.y, PixelDraw.PX, bar.size.y), BAR_GROUND)
	_px.frame(bar, BAR_EDGE)

## Mana is what charging spends, so this draining is the price of a hold. What
## the price bought rides over the player's head instead — see `PlayerView`,
## which puts it where the eye is during the fight the hold is happening in.
func _draw_mana() -> void:
	var bar := Rect2(BAR_AT + Vector2(0, HEALTH_H + THIN_H + 8.0), Vector2(BAR_W, THIN_H))
	_px.bar(bar, player.mana_ratio(), Color(0.38, 0.55, 0.95), BAR_GROUND, BAR_EDGE)

## The weapon's own attack sits first, then each slot. Which slot is armed has
## to be obvious at a glance: it is the one the cast button will run.
func _draw_slots(vp: Vector2) -> void:
	var x := BAR_AT.x
	var y := vp.y - CARD.y - CARD_LIFT
	if player.basic_runner != null:
		# The weapon's own board is always something the weapon carries.
		_draw_slot_card(Rect2(x, y, CARD.x, CARD.y), player.basic_runner,
			Controls.short_label_for("attack"), Loc.t("hud.slot.weapon_attack"), false, true)
		x += CARD.x + CARD_GAP
	for i in player.runners.size():
		var armed := i == player.selected_slot
		var key := Controls.short_label_for("skill_%d" % (i + 1))
		_draw_slot_card(Rect2(x, y, CARD.x, CARD.y), player.runners[i], key,
			player.runners[i].board.skill_name, armed, player.can_cast(i))
		x += CARD.x + CARD_GAP
	_px.text(Vector2(BAR_AT.x, y - 10.0),
		Loc.t("hud.slot.hint", [
			Controls.short_label_for("attack"), Controls.short_label_for("cast_skill")]),
		Color(0.55, 0.65, 0.78), vp.x - BAR_AT.x * 2.0)

func _draw_slot_card(rect: Rect2, r: SkillRunner, key: String, name: String,
		armed: bool, usable: bool) -> void:
	_px.rect(rect, Color(0.10, 0.13, 0.17, 0.9) if armed else Color(0.08, 0.09, 0.12, 0.85))
	# Read from the binding rather than spelled out here, so the card stays
	# honest after a rebind.
	var title := Color(0.85, 0.92, 1.0)
	if not usable:
		title = Color(0.72, 0.55, 0.58)
	elif armed:
		title = Color(1, 1, 1)
	# A name too long for the card is cut short rather than written past its
	# edge and over the card beside it.
	var pad := 8.0
	var room := rect.size.x - pad * 2.0
	_px.text(rect.position + Vector2(pad, 26), "%s  %s" % [key, name], title, room)
	if not usable:
		# The weapon is the reason, so name the weapon.
		_px.text(rect.position + Vector2(pad, 46),
			Loc.t("hud.slot.not_on", [Weapons.name_for(player.weapon_id).to_upper()]),
			Color(1.0, 0.5, 0.48), room)
	elif armed:
		_px.text(rect.position + Vector2(pad, 46), Loc.t("hud.slot.armed"),
			Color(0.55, 1.0, 0.85), room)
	# One pulse and several are two lines rather than an "s" stuck on the end:
	# a language without plurals gives the same line twice and reads right.
	var pulses := r.pulses.size()
	_px.text(rect.position + Vector2(pad, 64),
		Loc.t("hud.slot.pulse_one" if pulses == 1 else "hud.slot.pulse_many", [pulses]),
		Color(0.6, 0.7, 0.8), room)
	# Drawn last: the sheet covers the card's own text as it recedes, which is
	# what makes a slot read as unavailable at a glance.
	var border := Color(0.3, 0.35, 0.42)
	if not usable:
		border = Color(0.85, 0.35, 0.35)
	elif r.active:
		border = Color(0.5, 0.9, 1.0)
	elif armed:
		border = Color(0.45, 0.95, 0.8)
	_px.cooldown(rect, r.ready_ratio(), r.ready_flash, border)

func _draw_prompts(vp: Vector2) -> void:
	var band := 600.0
	if prompt != "":
		_px.text_centered(Vector2((vp.x - band) * 0.5, vp.y - CARD.y - CARD_LIFT - 40.0),
			prompt, Color(0.85, 0.95, 1.0), band)
	if extract_ratio > 0.0:
		var w := 304.0
		var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y * 0.5 + 120.0, w, 16.0)
		_px.bar(r, extract_ratio, Color(0.5, 1.0, 0.8), Color(0, 0, 0, 0.6), BAR_EDGE)
		_px.text_centered(r.position + Vector2(0, -10.0), Loc.t("hud.extracting"),
			Color(0.7, 1.0, 0.9), w)
	if toast_time > 0.0:
		var a := clampf(toast_time / 0.8, 0.0, 1.0)
		_px.text_centered(Vector2((vp.x - band) * 0.5, 120.0), toast, Color(1, 0.95, 0.8, a), band)
	_px.text(Vector2(BAR_AT.x, vp.y - 14.0), Loc.t("hud.footer"), Color(0.5, 0.58, 0.66))
