class_name JeanGreyHud
extends Control

## The Jean Grey test's read-outs, along the top and the bottom of the screen so
## the yard and the hall between stay clear: the body's health and, while the
## player is in a monster, whose and for how long; what is left to do; whether
## anyone has seen anything; the rock's graph and the keys; and a line across
## the middle when an attempt begins or ends.

const INK := Color(0.94, 0.93, 0.98)
const DIM := Color(0.62, 0.58, 0.74)
const GOLD := Color(1.0, 0.78, 0.32)
const FLAME := Color(1.0, 0.45, 0.28)
const CALM := Color(0.48, 0.95, 0.62)
const ALARM := Color(1.0, 0.3, 0.32)
const SHADOW := Color(0.02, 0.01, 0.05, 0.9)
const GROUND := Color(0.0, 0.0, 0.0, 0.65)
const EDGE := Color(0.5, 0.45, 0.72)
const CARD := Color(0.05, 0.03, 0.1, 0.88)
const BIG := PixelDraw.SIZE * 2
const MARGIN := 24.0
const BAR_W := 240.0
## How long the name of the test stays up once the screen opens.
const TITLE_TIME := 4.0
## How long the line saying the ground was set again stays up.
const AGAIN_TIME := 0.8

var screen: JeanGreyTest
var _px := PixelDraw.new(self)
var _banner: String = ""
var _banner_color: Color = GOLD
var _banner_time: float = 0.0
var _again_time: float = 0.0

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_stolen(seconds: float) -> void:
	_banner = Loc.t("hud.jean.stolen", [_clock(seconds)])
	_banner_color = GOLD
	_banner_time = JeanGreyTest.RESET_DELAY

func show_fell() -> void:
	_banner = Loc.t("hud.jean.fell")
	_banner_color = ALARM
	_banner_time = JeanGreyTest.RESET_DELAY

func again() -> void:
	_banner_time = 0.0
	_again_time = AGAIN_TIME

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_banner_time = maxf(0.0, _banner_time - delta)
	_again_time = maxf(0.0, _again_time - delta)
	queue_redraw()

func _draw() -> void:
	if screen == null or not is_instance_valid(screen):
		return
	var vp := get_viewport_rect().size
	var p := screen.player
	if p != null and is_instance_valid(p):
		_draw_body(p)
		_draw_skill(p, vp)
	_draw_goal(vp)
	_draw_watch(vp)
	_text(Vector2(vp.x - MARGIN - PixelDraw.ink_width(_keys()), vp.y - 22.0), _keys(), DIM)
	_draw_banners(vp)

func _text(at: Vector2, s: String, col: Color, font_size: int = PixelDraw.SIZE) -> void:
	_px.text(at + Vector2(2, 2), s, Color(SHADOW, SHADOW.a * col.a), -1.0, font_size)
	_px.text(at, s, col, -1.0, font_size)

func _centered(y: float, s: String, col: Color, width: float, font_size: int = PixelDraw.SIZE) -> void:
	_text(Vector2((width - PixelDraw.ink_width(s, font_size)) * 0.5, y), s, col, font_size)

func _keys() -> String:
	return Loc.t("hud.jean.keys", [Controls.short_label_for("step_out")])

## The body's health, and under it the monster the player is in with the time
## they have left in it.
func _draw_body(p: Player) -> void:
	var bar := Rect2(MARGIN, 18.0, BAR_W, 18.0)
	_px.bar(bar, p.health_ratio(), Color(0.9, 0.35, 0.38), GROUND, EDGE)
	_px.text(bar.position + Vector2(8, 15), Loc.t("hud.jean.body", [int(p.health), int(p.max_health)]),
		Color(1, 1, 1, 0.9))
	if p.vessel() == p:
		return
	var inside := Loc.t("hud.possessing", [Monsters.name_for(p.possessing.kind).to_upper(),
		ceili(p.possess_left)])
	_text(Vector2(MARGIN, 62.0), inside, Style.POSSESS_COLOR)
	_px.bar(Rect2(MARGIN, 70.0, BAR_W, 8.0), p.possess_left / maxf(p.possess_for, 0.01),
		Style.POSSESS_COLOR, GROUND, EDGE)

## What is left to do, from where the diamond is.
func _draw_goal(vp: Vector2) -> void:
	if screen.over:
		return
	var d := screen.diamond
	var says := Loc.t("hud.jean.take")
	var col := INK
	if d.carried_by_player():
		says = Loc.t("hud.jean.home")
		col = GOLD
	elif d.carrier != null:
		says = Loc.t("hud.jean.carry")
		col = Style.POSSESS_COLOR
	elif d.global_position.distance_to(screen.room.diamond_point()) > 2.0:
		says = Loc.t("hud.jean.down")
		col = FLAME
	_centered(34.0, says, col, vp.x)

## Whether anyone is after the player, and the clock.
func _draw_watch(vp: Vector2) -> void:
	var n := screen.alerted()
	var says := Loc.t("hud.jean.unseen") if n == 0 else Loc.t("hud.jean.seen", [n])
	_text(Vector2(vp.x - MARGIN - PixelDraw.ink_width(says), 34.0), says, CALM if n == 0 else ALARM)
	var clock := _clock(screen.attempt)
	if screen.best > 0.0:
		clock = Loc.t("hud.jean.best", [clock, _clock(screen.best)])
	_text(Vector2(vp.x - MARGIN - PixelDraw.ink_width(clock), 58.0), clock, DIM)

## The rock's graph on its card, cooling down; dimmed while the rock is not in
## the hands the player is in.
func _draw_skill(p: Player, vp: Vector2) -> void:
	if p.runner == null:
		return
	var card := Rect2(MARGIN, vp.y - 58.0, 300.0, 40.0)
	draw_rect(card, CARD)
	var held := p.can_cast()
	_px.text(card.position + Vector2(12, 26), "%s  %s" % [Controls.short_label_for("cast_skill"),
		p.runner.board.skill_name.to_upper()], INK if held else DIM, card.size.x - 20.0)
	UiKit.draw_cooldown(self, card, p.runner.ready_ratio(), p.runner.ready_flash, Style.POSSESS_COLOR)
	if not held:
		_text(Vector2(card.end.x + 16.0, card.position.y + 26.0), Loc.t("hud.jean.rock_out"), FLAME)

func _draw_banners(vp: Vector2) -> void:
	var y := 128.0
	if _banner_time > 0.0:
		var a := clampf(_banner_time / 0.4, 0.0, 1.0)
		_centered(y, _banner, Color(_banner_color, a), vp.x, BIG)
	elif _again_time > 0.0:
		_centered(y, Loc.t("hud.jean.again"), Color(INK, clampf(_again_time / 0.3, 0.0, 1.0)), vp.x, BIG)
	elif screen.elapsed < TITLE_TIME:
		var a := clampf((TITLE_TIME - screen.elapsed) / 0.6, 0.0, 1.0)
		_centered(y, Loc.t("hud.jean.title"), Color(Style.POSSESS_COLOR, a), vp.x, BIG)
		_centered(y + 30.0, Loc.t("hud.jean.subtitle"), Color(INK, a), vp.x)

## Seconds as minutes, seconds and tenths.
static func _clock(seconds: float) -> String:
	var tenths := int(seconds * 10.0)
	@warning_ignore("integer_division")
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]
