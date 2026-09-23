class_name SandboxPanel
extends Control

## The bench's own tools, in a drawer on the left edge of the screen: a weapon to
## swap to, the dragon test, a monster of every kind, a dummy, and the ways to
## clear the floor and to leave. It slides out on its tab and back in on it, and
## starts in, so the bench opens on the fight.
##
## Everything else on the screen is the raid's own `Hud` over the same player —
## the bars, the slots, the armed skill's name — so a skill tried here reads the
## way it will when it is carried. The one readout that is the bench's is what
## the last three seconds of damage came to, under the HUD's corner.
##
## While the drawer is out the bench holds the player still, the way any window
## over the fight does. Its buttons are pressed with the mouse the player would
## otherwise be aiming with, and on the console a thumb there would otherwise be
## the movement stick, whose zone is the whole left of the screen.
##
## The tab is hit-tested here in `_input` rather than being a Button, because it
## has to answer while the drawer is in and the player is aiming: the game has
## the mouse then and points with the crosshair, which no Button hears, and the
## console takes a press on the left of the screen for its stick before any
## Control is asked — but after this, which is later in the tree.
##
## Drawn in UiKit's pixel look: the buttons are the kit's pixel ones, and
## everything drawn here goes through `PixelDraw`.

## The damage readout's baseline, under the HUD's corner: clear of the armed
## skill's name, and of the line under it when the weapon refuses that skill.
const DPS_AT := Vector2(24, 246)
## The drawer's top edge, and the room inside its frame.
const TOP := 264.0
const PAD := 8.0
const GAP := 4
## The tab it is pulled by, and the chevron on it, which points the way a press
## will send the drawer.
const TAB := Vector2(32, 64)
const CHEVRON := ["#....", ".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#...", "#...."]
## Seconds to slide all the way.
const SLIDE := 0.16

const FILL := Color(0.07, 0.08, 0.11, 0.85)
const EDGE := Color(0.35, 0.5, 0.65, 0.6)

var sandbox: Sandbox
var _px := PixelDraw.new(self)
## The buttons, two to a row. Everything else here is drawn every frame and so
## is already in whatever language is on; these are words written once, and a
## switch has to build them again.
var _grid: GridContainer = null
## Whether the drawer is out, and how far it has got there: 0 in, 1 out.
var _out: bool = false
var _slide: float = 0.0
var _tab_hover: bool = false

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_buttons()
	Loc.language_changed.connect(func(_l: String) -> void: _build_buttons())

func _build_buttons() -> void:
	if _grid != null and is_instance_valid(_grid):
		remove_child(_grid)
		_grid.queue_free()
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	add_child(_grid)
	_add(Loc.t("hud.sandbox.swap_weapon"), UiKit.ACCENT, func() -> void: sandbox.cycle_weapon())
	_add(Loc.t("hud.sandbox.dragon_test"), UiKit.ACCENT, func() -> void: sandbox.open_dragon_test())
	for kind in Sandbox.MONSTER_BUTTONS:
		_add(Loc.t("hud.sandbox.spawn", [Monsters.name_for(kind)]), UiKit.WARN,
			func() -> void: sandbox.spawn_monster(kind))
	_add(Loc.t("hud.sandbox.spawn_dummy"), UiKit.GOOD, func() -> void: sandbox.spawn_dummy())
	_add(Loc.t("hud.sandbox.clear"), UiKit.BAD, func() -> void: sandbox.clear_monsters())
	_add(Loc.t("hud.sandbox.leave"), UiKit.ACCENT, func() -> void: sandbox.leave())
	# Both columns as wide as the widest button, so the drawer is a block and
	# not a ragged edge.
	var widest := 0.0
	for b in _grid.get_children():
		widest = maxf(widest, (b as Control).get_combined_minimum_size().x)
	for b in _grid.get_children():
		(b as Control).custom_minimum_size.x = widest
	_place()

func _add(text: String, accent: Color, press: Callable) -> void:
	var b := UiKit.overlay_button(text, accent, true)
	b.pressed.connect(press)
	_grid.add_child(b)

## Pulls the drawer out or pushes it back in. The bench holds the player still
## for as long as it is out.
func set_out(out: bool) -> void:
	if out == _out:
		return
	_out = out
	sandbox.set_tools_open(out)
	Audio.play("ui")

func is_out() -> bool:
	return _out

## The drawer where it stands this frame: all of its width off the left edge
## when it is in, none of it when it is out, and on the grid in between.
func drawer_rect() -> Rect2:
	var px := PixelDraw.PX
	var size := ((_grid.get_combined_minimum_size() + Vector2.ONE * PAD * 2.0) / px).ceil() * px
	var shift := floorf(-size.x * (1.0 - smoothstep(0.0, 1.0, _slide)) / px) * px
	return Rect2(Vector2(shift, TOP), size)

## On the drawer's right edge, sharing its border, so it comes and goes with it
## and is all that is left on the screen once the drawer is in.
func tab_rect() -> Rect2:
	return Rect2(Vector2(drawer_rect().end.x - PixelDraw.PX, TOP), TAB)

## Off the screen with the drawer while it is in, where nothing can press it
## and, since no button here takes focus, no key can reach it either.
func _place() -> void:
	_grid.position = drawer_rect().position + Vector2.ONE * PAD

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_slide = move_toward(_slide, 1.0 if _out else 0.0, delta / SLIDE)
	_place()
	# `Pointer.point` is wherever the pointing is being done from: the crosshair
	# while the game has the mouse, the system pointer otherwise.
	_tab_hover = tab_rect().has_point(Pointer.point)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var at := Vector2.INF
	var press := false
	var click := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		# While the game has the mouse, a click lands where the crosshair is.
		at = Pointer.point if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else click.position
		# The system hands a touch over as a click as well: the touch is the press.
		press = click.pressed and click.device != InputEvent.DEVICE_ID_EMULATION
	elif touch != null:
		at = touch.position
		press = touch.pressed
	else:
		return
	if not tab_rect().has_point(at):
		return
	get_viewport().set_input_as_handled()
	if press:
		set_out(not _out)

## ESC puts the drawer away, the way it closes every other window here, before
## it would pause the bench behind it.
func _unhandled_input(event: InputEvent) -> void:
	if _out and is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		set_out(false)
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if sandbox == null or not is_instance_valid(sandbox):
		return
	_px.text(DPS_AT, Loc.t("hud.sandbox.dps", [sandbox.dps()]), UiKit.GOOD)
	var d := drawer_rect()
	if d.end.x > 0.0:
		_px.rect(d, FILL)
		_px.frame(d, EDGE)
	var t := tab_rect()
	_px.rect(t, Color(0.12, 0.16, 0.21, 0.9) if _tab_hover else FILL)
	_px.frame(t, UiKit.ACCENT if _tab_hover else EDGE)
	_px.icon_centered(t.get_center(), PixelDraw.turn(CHEVRON, 2) if _out else CHEVRON,
		Color.WHITE if _tab_hover else UiKit.TEXT)
