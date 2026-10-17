extends Node
## The phone on the screen (`PhoneScreen`): P slides it up over a raid and
## over the hideout, holding the player still and putting the HUD away, and P
## or ESC slides it down again; its apps come up on its own pages, and the ones
## that are pages of the screen over the world put the phone away and that
## page up; the camera keeps a photo of the screen the gallery then shows and
## throws away; and the alarm's page sets one, and puts the phone down on the
## floor.

const GameScript := preload("res://app/game.gd")
const PHOTOS := "user://phone_screen_test/photos"

var game: Node
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[PHONE] PASS ", what)
	else:
		fails += 1
		push_error("PHONE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	get_viewport().push_input(e)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	get_viewport().push_input(up)
	await frames(3)

func click(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	get_viewport().push_input(m)
	await get_tree().process_frame
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		get_viewport().push_input(e)
		await get_tree().process_frame
	await frames(3)

func phone() -> PhoneScreen:
	return game.phone

## A button on the phone's page, by the name it was given.
func button(named: String) -> Button:
	if phone() == null:
		return null
	for b in phone().find_children(named, "Button", true, false):
		return b
	return null

func press(named: String) -> void:
	var b := button(named)
	check(b != null, "the page has %s on it" % named)
	if b != null:
		await click(b.get_global_rect().get_center())

func tile(id: String) -> void:
	var t: Button = phone()._tiles.get(id)
	check(t != null, "the home screen has the %s app" % id)
	if t != null:
		await click(t.get_global_rect().get_center())

func _ready() -> void:
	GameState.reset_profile()
	Phone.photo_dir = PHOTOS
	_sweep()
	Phone.reset()
	seed(7)
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)

	# --- up and down over a raid ---------------------------------------------
	game._deploy("SWORD")
	await frames(10)
	var raid: Raid = game.current
	await key(KEY_P)
	check(game._phoning() and raid.on_phone, "P brings the phone up over a raid")
	check(raid.player.input_locked, "the player stands still under it")
	check(not Views.of(raid).hud.visible, "and the HUD is put away")
	await frames(40)
	check(phone().page == PhoneScreen.HOME and phone()._tiles.size() == PhoneScreen.APPS.size(),
		"it comes up on its home screen, an app a tile (%d)" % phone()._tiles.size())
	check(absf(phone()._handset.position.y - phone()._rest()) < 1.0, "slid up to where it rests")
	await key(KEY_P)
	check(not game._phoning() and not raid.on_phone, "P again puts it away")
	await frames(40)
	check(not phone().visible and not raid.player.input_locked and Views.of(raid).hud.visible,
		"slid down and gone, the player free and the HUD back")
	await key(KEY_P)
	await key(KEY_ESCAPE)
	check(not game._phoning() and not game.get_tree().paused, "ESC puts it away too, pausing nothing")
	await frames(40)

	# --- the apps that are the screen's pages -----------------------------------
	await key(KEY_P)
	await frames(40)
	await tile(ScreenTabs.GRAPH)
	check(not game._phoning() and raid.editing, "KIT puts the phone away and the board up")
	await key(KEY_TAB)
	await frames(40)
	await key(KEY_P)
	await frames(2)
	await key(KEY_M)
	check(not game._phoning() and raid.reading_map, "M on the phone puts the map up in its place")
	await key(KEY_M)
	await frames(40)
	await key(KEY_P)
	await frames(40)
	await tile(ScreenTabs.DEX)
	check(not game._phoning() and raid.reading_dex, "FOES puts the dictionary up")
	await key(KEY_ESCAPE)
	await frames(40)

	# --- the camera and the gallery -----------------------------------------------
	await key(KEY_P)
	await frames(40)
	await tile(PhoneScreen.CAMERA)
	check(phone().page == PhoneScreen.CAMERA, "CAMERA opens on its page")
	await press("Snap")
	await frames(8)
	check(Phone.photos().size() == 1, "SNAP keeps a photo (%d)" % Phone.photos().size())
	check(phone().up() and phone().visible, "and the phone is back on screen after it")
	await press("Back")
	check(phone().page == PhoneScreen.HOME, "the back arrow goes home")
	await tile(PhoneScreen.GALLERY)
	check(phone().page == PhoneScreen.GALLERY and phone()._thumbs.size() == 1, "GALLERY shows it, one tile")
	var thumb: TextureButton = phone()._thumbs.values()[0]
	await click(thumb.get_global_rect().get_center())
	check(phone().page == PhoneScreen.PHOTO, "a press on the tile opens the photo")
	await press("Delete")
	check(Phone.photos().is_empty() and phone().page == PhoneScreen.GALLERY,
		"DELETE throws it away and goes back to the gallery")
	await click(phone()._home_bar.get_global_rect().get_center())
	check(phone().page == PhoneScreen.HOME, "the bar along the bottom goes home")

	# --- the alarm ---------------------------------------------------------------------
	await tile(PhoneScreen.ALARM)
	check(phone().page == PhoneScreen.ALARM and not Phone.alarm_set(), "ALARM opens on its page, nothing set")
	await press("Set")
	# Counting already: the raid's clock has run a frame or two since.
	check(Phone.alarm_set() and Phone.alarm > PhoneScreen.ALARM_START - 2.0 and Phone.alarm <= PhoneScreen.ALARM_START,
		"SET sets it for the time shown (%.1f)" % Phone.alarm)
	check(button("Stop") != null and button("Down") != null, "set, the page offers STOP and PUT IT DOWN")
	await press("Down")
	check(not game._phoning() and not Phone.carried() and raid.phone_prop() != null,
		"PUT IT DOWN puts the phone on the floor and away")
	await key(KEY_P)
	await frames(40)
	await tile(PhoneScreen.ALARM)
	check(button("Down") == null and button("Stop") != null, "lying on the floor, it cannot be put down again")
	await press("Stop")
	check(not Phone.alarm_set(), "STOP takes the alarm off")
	await key(KEY_P)
	await frames(40)
	Phone.recover()

	# --- the settings ---------------------------------------------------------------
	await key(KEY_P)
	await frames(40)
	await tile(PhoneScreen.SETTINGS)
	check(phone().page == PhoneScreen.SETTINGS, "SETTINGS opens on its page")
	var sliders := phone().find_children("*", "HSlider", true, false)
	check(sliders.size() == 2, "with the two volumes on it (%d)" % sliders.size())
	await key(KEY_P)
	await frames(40)

	# --- over the hideout ---------------------------------------------------------
	game.goto_hideout()
	await frames(10)
	await key(KEY_P)
	check(game._phoning() and game.hideout_ref.editing, "P brings the phone up over the hideout, holding the player")
	check(not Views.of(game.hideout_ref).hud.visible, "with the HUD away")
	await frames(40)
	await tile(ScreenTabs.GRAPH)
	check(not game._phoning() and game.editor != null, "KIT puts the workbench up in its place")
	await key(KEY_ESCAPE)
	await frames(40)
	await key(KEY_P)
	await key(KEY_ESCAPE)
	check(not game._phoning() and not game.hideout_ref.editing and not game.get_tree().paused,
		"ESC puts it away, the player free, nothing paused")
	await frames(40)
	await key(KEY_ESCAPE)
	check(game.get_tree().paused, "ESC with no phone up pauses")
	await key(KEY_P)
	check(not game._phoning(), "and P over the pause menu does nothing")
	game._unpause()
	await frames(4)

	_sweep()
	Phone.reset()
	print("[PHONE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _sweep() -> void:
	var d := DirAccess.open(PHOTOS)
	if d != null:
		for f in d.get_files():
			DirAccess.remove_absolute(PHOTOS.path_join(f))
