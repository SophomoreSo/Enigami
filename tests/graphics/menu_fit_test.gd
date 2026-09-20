extends Node
## Menus must not run off the bottom of the screen. Both the pause menu and the
## title's settings are a fixed-position column that grows with its contents,
## and two new rebindable actions were enough to push the ABANDON RAID button
## clean out of the viewport with nothing on screen to say it was there.
##
## Each is pages now — itself, and what sits behind its buttons: the title's
## settings keep the volumes and language behind GENERAL SETTINGS and the
## rebinding list behind CONTROL SETTINGS, the pause menu the list alone. The
## pages behind the buttons are the long ones, so every page of both is checked.

const GameScript := preload("res://app/game.gd")

var game: Node
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[MENU] PASS ", what)
	else:
		fails += 1
		push_error("MENU FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Every menu here is a ScrollContainer so it can outgrow the screen safely.
func audit(name: String, sc: ScrollContainer) -> void:
	var vp := get_viewport().get_visible_rect().size
	check(sc.position.y >= 0.0 and sc.position.y + sc.size.y <= vp.y + 0.5,
		"%s stays inside the viewport (%.0f..%.0f of %.0f)"
			% [name, sc.position.y, sc.position.y + sc.size.y, vp.y])
	check(sc.position.x >= 0.0 and sc.position.x + sc.size.x <= vp.x + 0.5,
		"%s stays inside it sideways too" % name)
	var content: Control = sc.get_child(0)
	var wanted := content.get_combined_minimum_size().y
	# Whatever will not fit has to be reachable by scrolling, not lost.
	sc.scroll_vertical = 100000
	await frames(3)
	var reach := float(sc.scroll_vertical) + sc.size.y
	check(reach >= wanted - 1.0,
		"%s can scroll to its last row (reaches %.0f of %.0f)" % [name, reach, wanted])
	sc.scroll_vertical = 0
	await frames(2)

## The settings pages and the pause menu sit in the middle of the screen, so the
## gap above one is the gap below it. Only a page that fits is centred — a
## longer one fills the room it has and scrolls — so this is for the short ones.
func centred(name: String, sc: ScrollContainer) -> void:
	var vp := get_viewport().get_visible_rect().size
	check(absf(sc.position.x - (vp.x - sc.size.x) * 0.5) <= 1.0,
		"%s is centred across the screen (%.0f..%.0f of %.0f)"
			% [name, sc.position.x, sc.position.x + sc.size.x, vp.x])
	check(absf(sc.position.y - (vp.y - sc.size.y) * 0.5) <= 1.0,
		"%s is centred down it too (%.0f above, %.0f below)"
			% [name, sc.position.y, vp.y - sc.position.y - sc.size.y])

func _ready() -> void:
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(10)

	var title = game.current
	title._toggle_settings()
	await frames(8)
	check(title._settings is ScrollContainer, "the title's settings panel scrolls")
	await audit("title settings", title._settings as ScrollContainer)
	centred("title settings", title._settings as ScrollContainer)
	title._toggle_general()
	await frames(8)
	check(title._general is ScrollContainer, "the title's general page scrolls")
	await audit("title general", title._general as ScrollContainer)
	centred("title general", title._general as ScrollContainer)
	title._toggle_general()
	await frames(4)
	title._toggle_controls()
	await frames(8)
	check(title._controls is ScrollContainer, "the title's controls page scrolls")
	await audit("title controls", title._controls as ScrollContainer)
	title._toggle_controls()
	await frames(4)
	title._toggle_settings()
	await frames(4)

	game._deploy("SWORD", [0, 1, 2])
	await frames(24)
	game._pause()
	await frames(8)
	var sc: ScrollContainer = game.pause_main as ScrollContainer
	check(sc != null, "the pause menu scrolls")
	if sc != null:
		await audit("pause menu", sc)
		centred("pause menu", sc)
	game._pause_general(true)
	await frames(8)
	var gc: ScrollContainer = game.pause_general as ScrollContainer
	check(gc != null, "the pause menu's general page scrolls")
	if gc != null:
		await audit("pause general", gc)
		centred("pause general", gc)
	game._pause_general(false)
	await frames(4)
	game._pause_controls(true)
	await frames(8)
	var cc: ScrollContainer = game.pause_controls as ScrollContainer
	check(cc != null, "and so does the controls page behind it")
	if cc != null:
		await audit("pause controls", cc)
	game._pause_controls(false)
	await frames(4)
	# The dimmer behind it still has to cover the whole screen.
	var vp := get_viewport().get_visible_rect().size
	for c in game.pause_menu.get_children():
		if c is ColorRect:
			check((c as ColorRect).size == vp,
				"and the dimmer behind it still covers the screen (%s)" % (c as ColorRect).size)
	game._unpause()

	print("[MENU] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
