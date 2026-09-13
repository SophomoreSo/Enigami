class_name DragonTestHud
extends Control

## The dragon test's read-outs, set in the pixel face along the ceiling and the
## ground so the storeys between stay clear: the tape counter, the guards still
## standing, what the charge in hand would chain to, and the skill itself.

const FONT := preload("res://graphics/assets/fonts/Silkscreen-Regular.ttf")
const SIZE := 16
const BIG := 32

const INK := Color(0.93, 0.92, 0.98)
const DIM := Color(0.6, 0.56, 0.72)
const PINK := Color(1.0, 0.3, 0.62)
const CYAN := Color(0.35, 0.95, 1.0)
const AMBER := Color(1.0, 0.76, 0.35)
const RED := Color(1.0, 0.22, 0.28)
const SHADOW := Color(0.02, 0.01, 0.05, 0.9)
const CHARGE := Color(0.78, 0.68, 1.0)

var screen: DragonTest
var _banner: String = ""
var _banner_color: Color = CYAN
var _banner_time: float = 0.0
var _rewind_time: float = 0.0

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_clear(one_cast: bool) -> void:
	if one_cast:
		_banner = "ALL %d IN ONE CAST" % screen.total_guards
		_banner_color = CYAN
	else:
		_banner = "FLOOR CLEAR   BEST CAST %d OF %d" % [screen.best_cast, screen.total_guards]
		_banner_color = AMBER
	_banner_time = DragonTest.RESET_DELAY

func rewind() -> void:
	_banner_time = 0.0
	_rewind_time = 0.8

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_banner_time = maxf(0.0, _banner_time - delta)
	_rewind_time = maxf(0.0, _rewind_time - delta)
	queue_redraw()

func _draw() -> void:
	if screen == null or not is_instance_valid(screen) or screen.player == null:
		return
	var vp := get_viewport_rect().size
	_draw_tape()
	_draw_guards(vp)
	_draw_chain(vp)
	_draw_skill(vp)
	_draw_banners(vp)

func _text(at: Vector2, s: String, col: Color, size: int = SIZE,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(FONT, at + Vector2(2, 2), s, align, width, size, Color(SHADOW, SHADOW.a * col.a))
	draw_string(FONT, at, s, align, width, size, col)

## The corner of a tape being played back: a recording light and the counter.
func _draw_tape() -> void:
	if fmod(screen.elapsed, 1.0) < 0.62:
		draw_rect(Rect2(24, 16, 12, 12), RED)
	_text(Vector2(46, 30), "PLAY", INK)
	var tip := Vector2(114, 22)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-10, -7), tip + Vector2(0, 0),
		tip + Vector2(-10, 7)]), INK)
	var t := int(screen.elapsed)
	_text(Vector2(130, 30), "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60], DIM)

## One figure per guard, struck through once they are down.
func _draw_guards(vp: Vector2) -> void:
	var n := screen.total_guards
	var step := 16.0
	var x0 := vp.x * 0.5 - float(n) * step * 0.5 + 60.0
	_text(Vector2(x0 - 118.0, 30), "GUARDS", DIM)
	for i in n:
		var at := Vector2(x0 + float(i) * step, 12)
		if i < screen.guards_left:
			draw_rect(Rect2(at + Vector2(3, 0), Vector2(6, 6)), PINK)
			draw_rect(Rect2(at + Vector2(1, 7), Vector2(10, 11)), PINK)
		else:
			draw_rect(Rect2(at + Vector2(1, 1), Vector2(10, 17)), Color(PINK, 0.3), false, 2.0)
			draw_line(at + Vector2(-1, 18), at + Vector2(13, 0), RED, 2.0)

## What a release right now would chain to, against the guards on the floor. It
## counts the hold as it builds, so the moment the charge is enough is visible.
## While a cast is on its way through it reports that cast instead — the charge
## it was bought with is spent and gone, and reading 1 through the run of a
## nine-link chain said nothing about what was happening on screen.
func _draw_chain(vp: Vector2) -> void:
	var p := screen.player
	var n := screen.cast_chain if not p.runners[p.selected_slot].is_ready() \
		else screen.chain_length(int(p.charge))
	var need := screen.total_guards
	_text(Vector2(vp.x - 424.0, 30), "CHAIN %d / %d" % [n, need], CYAN if n >= need else PINK,
		SIZE, HORIZONTAL_ALIGNMENT_RIGHT, 400.0)

## The armed skill on the ground: its card and cooldown, the charge with a mark
## where it reaches every guard, the mana paying for it, and the keys.
func _draw_skill(vp: Vector2) -> void:
	var p := screen.player
	var r: SkillRunner = p.runners[p.selected_slot]
	var y := vp.y - 58.0
	var card := Rect2(24, y, 272, 40)
	draw_rect(card, Color(0.05, 0.03, 0.1, 0.88))
	_text(card.position + Vector2(12, 27), "%s  %s" % [Controls.short_label_for("cast_skill"),
		r.board.skill_name.to_upper()], INK)
	UiKit.draw_cooldown(self, card, r.ready_ratio(), r.ready_flash, Color(0.55, 0.4, 0.9))

	var bar := Rect2(316, y + 4, 320, 14)
	var enough := screen.chain_length(int(p.charge)) >= screen.total_guards
	draw_rect(bar, Color(0, 0, 0, 0.65))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * p.charge_ratio(), bar.size.y)),
		CYAN if enough else CHARGE)
	var need := screen.charge_to_clear()
	if need >= 0:
		var nx := bar.position.x + bar.size.x * float(need) / Player.MAX_CHARGE_TTL
		draw_rect(Rect2(nx - 1.0, bar.position.y - 5.0, 3.0, bar.size.y + 10.0), AMBER)
	draw_rect(bar, Color(0.5, 0.45, 0.72), false, 2.0)
	var mana := Rect2(316, y + 26, 320, 8)
	draw_rect(mana, Color(0, 0, 0, 0.65))
	draw_rect(Rect2(mana.position, Vector2(mana.size.x * p.mana_ratio(), mana.size.y)),
		Color(0.38, 0.55, 0.95))

	_text(Vector2(656, y + 18), "HOLD TO CHARGE", DIM)
	_text(Vector2(656, y + 38), "RELEASE TO CAST", DIM)
	_text(Vector2(vp.x - 424.0, y + 38), "R RESET  TAB EDIT  ESC BACK", DIM,
		SIZE, HORIZONTAL_ALIGNMENT_RIGHT, 400.0)

func _draw_banners(vp: Vector2) -> void:
	# One line at a time in that space: clearing the floor inside the opening
	# four seconds used to print the result straight over the title.
	if screen.elapsed < 4.0 and _rewind_time <= 0.0 and _banner_time <= 0.0:
		var a := clampf((4.0 - screen.elapsed) / 0.6, 0.0, 1.0)
		_neon(Vector2(0, 96), "DRAGON TEST", Color(CYAN, a), BIG)
		_text(Vector2(0, 124), "%d GUARDS   ONE CAST" % screen.total_guards, Color(INK, a),
			SIZE, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	if _banner_time > 0.0:
		var a := clampf(_banner_time / 0.4, 0.0, 1.0)
		_neon(Vector2(0, 96), _banner, Color(_banner_color, a), BIG)
	if _rewind_time > 0.0:
		# The tape stutters as it winds back.
		if fmod(_rewind_time * 10.0, 1.0) < 0.7:
			var at := Vector2(vp.x * 0.5 - 96.0, 110)
			for i in 2:
				var tip := at + Vector2(float(i) * 16.0, 0)
				draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(16, -12),
					tip + Vector2(16, 12)]), INK)
			_text(at + Vector2(44, 12), "REWIND", INK, BIG)

## Neon: the colour laid over a pink ghost of itself, a little off register.
func _neon(at: Vector2, s: String, col: Color, size: int) -> void:
	var w := get_viewport_rect().size.x
	draw_string(FONT, at + Vector2(3, 3), s, HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(PINK, col.a * 0.8))
	draw_string(FONT, at, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)
