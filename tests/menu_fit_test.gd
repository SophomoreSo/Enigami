extends Node
## Menus must not run off the bottom of the screen. Both the pause menu and the
## title's settings are a fixed-position column that grows with its contents,
## and two new rebindable actions were enough to push the ABANDON RAID button
## clean out of the viewport with nothing on screen to say it was there.

const GameScript := preload("res://scripts/core/game.gd")

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
	title._toggle_settings()
	await frames(4)

	game._deploy("SWORD", [0, 1, 2])
	await frames(24)
	game._pause()
	await frames(8)
	var sc: ScrollContainer = null
	for c in game.pause_menu.get_children():
		if c is ScrollContainer:
			sc = c
	check(sc != null, "the pause menu scrolls")
	if sc != null:
		await audit("pause menu", sc)
	# The dimmer behind it still has to cover the whole screen.
	var vp := get_viewport().get_visible_rect().size
	for c in game.pause_menu.get_children():
		if c is ColorRect:
			check((c as ColorRect).size == vp,
				"and the dimmer behind it still covers the screen (%s)" % (c as ColorRect).size)
	game._unpause()

	print("[MENU] ---- %d failures ----" % fails)
	get_tree().quit()
