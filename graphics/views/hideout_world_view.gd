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
## What the line under the plate is allowed to run to. It is a sentence, not a
## name, and held to the plate's own width it lost its last two words.
const SIGN_BAND := SIGN_W * 2.4

var world: HideoutWorld
## The pixel grid, bound to this node: the signs are drawn, not built, so they
## stand in the room and move with it.
var _px := PixelDraw.new(self)
## What the signs say, on its own layer over the pixel picture — and its own
## grid, bound to that layer.
##
## The plates are world art: blocks two units wide, which is one pixel of the
## buffer the world is drawn into at half the screen's resolution. Text cannot
## be. A glyph drawn in the world is rasterised at world size and shrunk into
## that buffer through a filter, so it arrives blurred before the picture is
## ever blown back up — and Hangul, whose face stands 16px where Silkscreen
## stands 8, arrived unreadable. Drawing it into the buffer at the buffer's own
## resolution is sharp, but then a Hangul name is twice the size of an English
## one, which is a high price for a sign.
##
## So the words go over the picture instead, at the screen's resolution, where a
## glyph pixel is a screen pixel: the same face at the same size the menus write
## it in, sharp, in any language. An NPC's talk prompt is drawn this way for the
## same reason (`NpcView`), and like it, this layer is not part of the world the
## pixel camera copies.
var _words: Node2D
var _words_px: PixelDraw
var camera: Camera2D
var pixels: PixelCamera
var layer: CanvasLayer
## The station panel on screen, or null. One at a time, like the stations.
var panel: Control = null
## The shade under it, over the room and the readout. Kept beside the panel
## rather than inside it: everything that reads `panel` wants the frame.
var _shade: ColorRect = null
## The same readout the raid draws, over the same room: health, the weapon in
## hand and a card per armed slot. What the gate would carry is a thing to look
## at while you are still deciding, and the player standing here is carrying it
## already — `HideoutWorld.refresh_kit` is what keeps that true.
var hud: Hud

func _ready() -> void:
	world = get_parent() as HideoutWorld
	camera = Camera2D.new()
	camera.position = Vector2(Room.W * Room.CELL, Room.H * Room.CELL) * 0.5
	add_child(camera)
	camera.make_current()
	Fx.register_camera(camera)
	pixels = PixelCamera.new()
	add_child(pixels)
	var words_layer := CanvasLayer.new()
	words_layer.layer = PixelCamera.LAYER + 1
	words_layer.follow_viewport_enabled = true
	add_child(words_layer)
	_words = Node2D.new()
	_words.draw.connect(_draw_words)
	words_layer.add_child(_words)
	_words_px = PixelDraw.new(_words)

	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	# Added before any panel is, so a station's panel opens over the readout
	# rather than under it: on one layer, later is higher.
	hud = Hud.new()
	layer.add_child(hud)

	world.panel_changed.connect(_on_panel_changed)
	world.noticed.connect(func(text: String) -> void: hud.show_toast(text))
	set_process(true)

func _process(_delta: float) -> void:
	if hud != null and is_instance_valid(hud):
		hud.player = world.player if world != null and is_instance_valid(world) else null
		# There is no map here and nothing to extract from, so the line along the
		# bottom names the keys this room actually answers to.
		hud.footer = Loc.t("hud.footer_lobby")
	# The signs say what a press would do, and that changes as the player walks
	# and as the kit fills up: `queue_redraw` every frame is what the raid's own
	# prompts do, and the whole screen is four plates.
	queue_redraw()
	if _words != null and is_instance_valid(_words):
		# The words hang over the picture rather than in it, so they are told
		# where the room is every frame.
		_words.position = global_position
		_words.queue_redraw()

## --- the room ---------------------------------------------------------------
func _draw() -> void:
	if world == null or not is_instance_valid(world):
		return
	for id in world.stations:
		_draw_station(world.stations[id] as Station)

func _draw_station(s: Station) -> void:
	if s == null or not is_instance_valid(s):
		return
	var at := s.global_position - global_position
	var ink := _sign_ink(s)

	# The thing itself: a block on the floor with a lit edge, so a station reads
	# as furniture before it reads as a sign.
	var body := Rect2(at - Vector2(s.extent.x * 0.5, s.extent.y), s.extent)
	draw_rect(body, Style.HIDEOUT_STATION)
	draw_rect(body, ink, false, 2.0)

	# The plate over it, on its post. What it says is `_draw_words`' half.
	var plate := _plate(s)
	draw_line(Vector2(at.x, at.y - s.extent.y), Vector2(at.x, plate.end.y), ink, 2.0)
	_px.rect(plate, Style.HIDEOUT_PLATE)
	draw_rect(plate, ink, false, 2.0)

## --- what the signs say -----------------------------------------------------
## The other half of every sign, over the picture rather than in it. See `_words`
## for why the words are not drawn with the plate that carries them.
func _draw_words() -> void:
	if world == null or not is_instance_valid(world):
		return
	for id in world.stations:
		_draw_station_words(world.stations[id] as Station)

func _draw_station_words(s: Station) -> void:
	if s == null or not is_instance_valid(s):
		return
	var at := s.global_position - global_position
	var plate := _plate(s)
	# `text` takes a baseline, not a top: the plate is SIGN_H tall and capitals
	# stand 10 of it, so this sits them in the middle of it.
	_words_px.text_centered(Vector2(plate.position.x, plate.position.y + 18.0),
		s.label, _sign_ink(s), SIGN_W)

	# The line under the plate runs wider than the plate: it is a sentence, not a
	# name, and clipped to the plate's own width it lost its last two words.
	var under := Vector2(at.x - SIGN_BAND * 0.5, plate.end.y + 18.0)
	if not s.open and s.closed_reason != "":
		_words_px.text_centered(under, s.closed_reason, Style.HIDEOUT_SIGN_SHUT, SIGN_BAND)
	elif s.near and s.open:
		_words_px.text_centered(under, s.prompt, Style.HIDEOUT_SIGN_LIT, SIGN_BAND)

## The plate's rect, in this view's own coordinates. Both halves of a sign ask
## for it: the one drawn into the picture and the words drawn over it.
func _plate(s: Station) -> Rect2:
	var at := s.global_position - global_position
	return Rect2(at + Vector2(-SIGN_W * 0.5, -SIGN_LIFT), Vector2(SIGN_W, SIGN_H))

## A station in reach and open for business is lit; everything else is not.
func _sign_ink(s: Station) -> Color:
	return Style.HIDEOUT_SIGN_LIT if s.near and s.open else Style.HIDEOUT_SIGN

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
## with the title along the top and the way out along the bottom. The panel
## itself never learns it is in a frame — it is the same column the whole screen
## used to hold.
##
## The rows are the only part of it that scrolls. The whole panel used to, and
## a list long enough to need a bar — the counter's, on any honest profile —
## carried its own title off the top of the screen and the way back to the room
## off the bottom.
func _host(inner: Hideout, heading: String) -> void:
	# The room goes dark behind it, the way the game does behind the pause menu:
	# the panel is what is being read, and the room is where it closes back to.
	_shade = UiKit.shade()
	layer.add_child(_shade)
	var frame := UiKit.screen_frame(668.0, 40.0, 28.0, true)
	layer.add_child(frame)
	panel = frame

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(_back_arrow())
	head.add_child(UiKit.label(heading, 24, UiKit.ACCENT, true))
	head.add_child(_pad())
	head.add_child(UiKit.label(Loc.t("hideout.scrap", [GameState.scrap]), 16, UiKit.WARN, true))
	frame.head.add_child(head)
	frame.head.add_child(UiKit.hline(true))

	# The column says how tall it is (`Hideout._get_minimum_size`), the frame
	# grows to it as far as the screen allows, and the scroll is what takes the
	# rest.
	frame.rows.add_child(inner)

	frame.foot.add_child(UiKit.spacer(8))
	var back := UiKit.button(Loc.t("hideout.station.back"), UiKit.ACCENT, true)
	back.pressed.connect(func() -> void: world.close_panel())
	frame.foot.add_child(back)

## The way out in the corner, the shape the pause menu's pages already use: one
## press is one level up, which from a station is back into the room. These
## panels were the last menus here with nothing in that corner.
##
## The button along the foot stays. It says where it goes in words, and at the
## end of the counter's list it is where the scroll has already put you.
func _back_arrow() -> Button:
	var b := UiKit.button(Loc.t("hideout.station.arrow"), UiKit.ACCENT, true)
	b.custom_minimum_size = Vector2(44, 34)
	b.pressed.connect(func() -> void: world.close_panel())
	return b

func _pad() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

func _clear_panel() -> void:
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	panel = null
	# Out of the tree at once rather than at the end of the frame: a panel built
	# again straight after — a board back from the workbench, a purchase — lays
	# a new shade down, and two for a frame is a flash of darker.
	if _shade != null and is_instance_valid(_shade):
		layer.remove_child(_shade)
		_shade.queue_free()
	_shade = null

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
