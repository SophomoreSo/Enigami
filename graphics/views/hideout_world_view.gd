class_name HideoutWorldView
extends Node2D

## The hideout's screen: the camera over the room, a sign standing at each
## station, and the panel a station opens.
##
## The panels are `graphics/ui/hideout.gd` built one column at a time — the same
## weapon list, the same loadout and library, the same counter the screen used
## to show all three of at once. Nothing about what is in them is decided here;
## this only decides when they are on screen.
##
## The assembly board is not here either: a board sent to the editor goes out
## through the world as `edit_requested` and `app/game.gd` opens the workbench
## editor it has always opened, over the top of all of this.

## The sign over a station: a post, a plate, and the name on it. Drawn rather
## than built out of Controls so it stands in the room at the station's feet and
## moves with the camera, the way a door's name does in a raid.
const SIGN_W := 150.0
const SIGN_H := 26.0
## How far above the station's feet the plate hangs.
const SIGN_LIFT := 78.0

var world: HideoutWorld
## The pixel grid, bound to this node: the signs are drawn, not built, so they
## stand in the room and move with it.
var _px := PixelDraw.new(self)
var camera: Camera2D
var pixels: PixelCamera
var layer: CanvasLayer
## The station panel on screen, or null. One at a time, like the stations.
var panel: Control = null
var _panel_host: PanelContainer = null

func _ready() -> void:
	world = get_parent() as HideoutWorld
	camera = Camera2D.new()
	camera.position = Vector2(Room.W * Room.CELL, Room.H * Room.CELL) * 0.5
	add_child(camera)
	camera.make_current()
	Fx.register_camera(camera)
	pixels = PixelCamera.new()
	add_child(pixels)

	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	world.panel_changed.connect(_on_panel_changed)
	set_process(true)

func _process(_delta: float) -> void:
	# The signs say what a press would do, and that changes as the player walks
	# and as the kit fills up: `queue_redraw` every frame is what the raid's own
	# prompts do, and the whole screen is four plates.
	queue_redraw()

## --- the room ---------------------------------------------------------------
func _draw() -> void:
	if world == null or not is_instance_valid(world):
		return
	for id in world.stations:
		_draw_station(world.stations[id] as Station)

func _draw_station(s: Station) -> void:
	if s == null or not is_instance_valid(s):
		return
	var lit: bool = s.near and s.open
	var ink: Color = Style.HIDEOUT_SIGN_LIT if lit else Style.HIDEOUT_SIGN
	var at := s.global_position - global_position

	# The thing itself: a block on the floor with a lit edge, so a station reads
	# as furniture before it reads as a sign.
	var body := Rect2(at - Vector2(s.extent.x * 0.5, s.extent.y), s.extent)
	draw_rect(body, Style.HIDEOUT_STATION)
	draw_rect(body, ink, false, 2.0)

	# The plate over it, on its post.
	var plate := Rect2(at + Vector2(-SIGN_W * 0.5, -SIGN_LIFT), Vector2(SIGN_W, SIGN_H))
	draw_line(Vector2(at.x, at.y - s.extent.y), Vector2(at.x, plate.end.y), ink, 2.0)
	_px.rect(plate, Style.HIDEOUT_PLATE)
	draw_rect(plate, ink, false, 2.0)
	# `text` takes a baseline, not a top: the plate is SIGN_H tall and capitals
	# stand 10 of it, so this sits them in the middle of it.
	_px.text_centered(Vector2(plate.position.x, plate.position.y + 18.0),
		s.label, ink, SIGN_W)

	# The line under the plate runs wider than the plate: it is a sentence, not a
	# name, and clipped to the plate's own width it lost its last two words.
	var band := SIGN_W * 2.4
	var under := Vector2(at.x - band * 0.5, plate.end.y + 18.0)
	if not s.open and s.closed_reason != "":
		_px.text_centered(under, s.closed_reason, Style.HIDEOUT_SIGN_SHUT, band)
	elif lit:
		_px.text_centered(under, s.prompt, Style.HIDEOUT_SIGN_LIT, band)

## --- the panels -------------------------------------------------------------
func _on_panel_changed(id: String) -> void:
	_clear_panel()
	if id == "":
		return
	if id == "bench":
		_open_bench()
		return
	_host(_column("weapons" if id == "weapons" else "shop"),
		Loc.t("hideout.station.%s" % id))

## The bench: the weapon's slots, the library under them, and the way onto the
## assembly board for any of it.
func _open_bench() -> void:
	_host(_column("loadout"), Loc.t("hideout.station.bench"))

## One column of the old hideout screen, pointed at the weapon the rack was left
## on and wired back to the room around it.
func _column(section: String) -> Hideout:
	var h := Hideout.new()
	h.section = section
	h.weapon_id = world.weapon_id
	h.edit_requested.connect(func(i: int) -> void: world.edit_requested.emit(i))
	# The rack is the one column that writes: what it picks is what the gate
	# carries, so the room has to hear about it.
	h.weapon_changed.connect(func(id: String) -> void: world.set_weapon(id))
	return h

## Puts a station's panel on screen inside the pixel frame every menu here uses,
## with the way out along the bottom. The panel itself never learns it is in a
## frame — it is the same column the whole screen used to hold.
func _host(inner: Control, heading: String) -> void:
	_panel_host = UiKit.panel(UiKit.PANEL, Color(0.22, 0.3, 0.38), true)
	_panel_host.custom_minimum_size = Vector2(660, 0)
	var scroll := UiKit.screen_scroll(_panel_host, Vector2(310, 40), 668.0, true)
	UiKit.pixel_scroll(scroll)
	layer.add_child(scroll)
	panel = scroll

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel_host.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UiKit.label(heading, 24, UiKit.ACCENT, true))
	head.add_child(_pad())
	head.add_child(UiKit.label(Loc.t("hideout.scrap", [GameState.scrap]), 16, UiKit.WARN, true))
	v.add_child(head)
	v.add_child(UiKit.hline(true))

	# The column says how tall it is (`Hideout._get_minimum_size`), the frame
	# grows to it, and the scroll around the frame is what keeps a long one on a
	# short screen.
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(inner)

	v.add_child(UiKit.spacer(8))
	var back := UiKit.button(Loc.t("hideout.station.back"), UiKit.ACCENT, true)
	back.pressed.connect(func() -> void: world.close_panel())
	v.add_child(back)

func _pad() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

func _clear_panel() -> void:
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	panel = null
	_panel_host = null

## The way out of a panel, by key rather than by the button. ESC is what closes
## every other screen here, and a panel that only a mouse could leave would be
## the one thing in the hideout a gamepad could not.
##
## The editor puts itself over this and takes its own keys first, so a press
## that closes a board does not also walk out of the bench behind it.
func _unhandled_input(event: InputEvent) -> void:
	if world == null or not is_instance_valid(world):
		return
	if event.is_action_pressed("ui_cancel") and world.open_panel != "":
		world.close_panel()
		get_viewport().set_input_as_handled()
