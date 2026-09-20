extends Node
## The hideout is a room you walk around, not a screen. Four stations stand on
## its floor — the weapon rack, the workbench, the counter and the gate — and
## each answers to the interact key when the player is standing at it.
##
## What this holds to: a station only answers from close enough, opening one
## puts its panel up and holds the player still, the panel is the old screen's
## own column (so the lists and their buttons are all still there), the gate
## refuses to open until there is a kit to carry through it, and buying a part
## at the counter costs scrap and puts the part in the stash.
##
## And that the names on the signs are legible, which is a question about how
## they are drawn: world text goes into the pixel buffer at the buffer's own
## resolution (`PixelCamera.draw_text`), never at world size to be shrunk into
## it. Shrunk, it arrives blended — soft grey edges where a pixel face has none
## — and Hangul, whose face stands twice as tall, arrived unreadable.
##
## Needs a real renderer: that check reads the frame back.

const GameScript := preload("res://app/game.gd")

var game: Node
var world: HideoutWorld
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[HIDE] PASS ", what)
	else:
		fails += 1
		push_error("HIDE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Every Control under `root`, scrollbars included.
func controls_under(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			out.append(n)
		for c in n.get_children(true):
			stack.append(c)
	return out

func buttons_under(root: Node) -> Array:
	return controls_under(root).filter(func(c: Control) -> bool: return c is Button)

## Puts the player at a station's feet and lets a frame go by, so the station
## has recomputed whether anybody is standing at it.
func stand_at(id: String) -> void:
	world.player.global_position = (world.stations[id] as Station).global_position
	await frames(3)

## How the ink on the plates meets their ground. A glyph drawn at the buffer's
## own resolution puts down the ink colour and nothing else; one shrunk into the
## buffer leaves a fringe of everything in between. So this counts both, over
## the rows that run through a plate — the ones with the plate's own colour at
## each end and a name between them.
func sign_ink() -> void:
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	var ground := Style.HIDEOUT_PLATE
	var inked := 0
	var blended := 0
	for y in im.get_height():
		var first := -1
		var last := -1
		for x in im.get_width():
			# Near, not equal: the frame comes back as 8-bit colour, and a
			# ground of 0.06 is 15/255 by the time it is read.
			if mix_of(im.get_pixel(x, y), ground, Style.HIDEOUT_SIGN) == 0.0 \
					and _near(im.get_pixel(x, y), ground):
				if first < 0:
					first = x
				last = x
		if first < 0 or last - first < 100:
			continue
		for x in range(first, last):
			var c := im.get_pixel(x, y)
			for ink in [Style.HIDEOUT_SIGN, Style.HIDEOUT_SIGN_LIT]:
				var t := mix_of(c, ground, ink)
				if t > 0.9:
					inked += 1
				elif t > 0.15:
					blended += 1
	check(inked > 200, "the plates carry names at all (%d pixels of ink)" % inked)
	check(blended * 20 < inked,
		"and every one of them is ink or ground, never the wash in between (%d blended of %d)"
			% [blended, inked])

## Two colours the same to the eye, and to 8-bit colour.
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01

## How far along `ground` → `ink` the colour `c` sits, or 0 if it is not on that
## line at all. What a pixel of a glyph drawn straight into the buffer answers is
## 1; what the filter leaves behind on the way down answers somewhere in between.
func mix_of(c: Color, ground: Color, ink: Color) -> float:
	var d := Vector3(ink.r - ground.r, ink.g - ground.g, ink.b - ground.b)
	var v := Vector3(c.r - ground.r, c.g - ground.g, c.b - ground.b)
	var t := v.dot(d) / d.dot(d)
	if t < 0.0 or t > 1.05:
		return 0.0
	return 0.0 if (v - d * t).length() > 0.03 else t

func _ready() -> void:
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_hideout()
	await frames(24)
	world = game.current
	check(world != null and game.state == GameScript.State.HIDEOUT,
		"the hideout is a world, not a screen (%s)" % ("null" if world == null else world.get_class()))
	check(world.room != null and world.player != null, "with a room and somebody standing in it")
	check(world.stations.size() == 4, "and four stations on its floor (%d)" % world.stations.size())

	# --- a station only answers from close enough ----------------------------
	var rack: Station = world.stations["weapons"]
	world.player.global_position = rack.global_position + Vector2(600.0, 0.0)
	await frames(3)
	check(not rack.near, "a station across the room is out of reach")
	rack.interact()
	await frames(2)
	check(world.open_panel == "", "and pressing it from there does nothing")
	await stand_at("weapons")
	check(rack.near, "walking up to it puts it in reach")

	# --- opening one ---------------------------------------------------------
	rack.interact()
	await frames(8)
	check(world.open_panel == "weapons", "and a press opens its panel")
	check(world.player.controls_locked(),
		"which holds the player still while they read it")
	var view = Views.of(world)
	check(view != null and view.panel != null, "the panel is on screen")
	var picked := ""
	for b: Button in buttons_under(view.panel):
		if b.text.findn(Weapons.name_for("GUN")) >= 0 and not b.disabled:
			picked = "GUN"
			b.emit_signal("pressed")
			break
	check(picked == "GUN", "the rack lists the weapons the vault holds")
	await frames(6)
	check(world.weapon_id == "GUN",
		"picking one is what the room carries to the gate (%s)" % world.weapon_id)

	world.close_panel()
	await frames(6)
	check(world.open_panel == "" and not world.player.controls_locked(),
		"closing it gives the room and the keys back")

	# --- the counter sells parts --------------------------------------------
	await stand_at("shop")
	(world.stations["shop"] as Station).interact()
	await frames(8)
	check(world.open_panel == "shop", "the counter opens the same way")
	var scrap_was: int = GameState.scrap
	var held_was: int = GameState.component_count("PIERCE", GameState.stash)
	GameState.scrap = 500
	world.refresh_panel()
	await frames(8)
	var bought := false
	for b: Button in buttons_under(Views.of(world).panel):
		if b.text == Loc.t("hideout.shop.price", [GameState.shop_price("PIERCE")]) and not b.disabled:
			# Several parts share a price; the one wanted is the one whose row
			# is PIERCE's, so this walks back up to the row to be sure.
			var row := b.get_parent()
			var named := false
			for c in row.get_children():
				if c is Label and (c as Label).text.findn(Components.name_for("PIERCE")) >= 0:
					named = true
			if not named:
				continue
			b.emit_signal("pressed")
			bought = true
			break
	await frames(6)
	check(bought, "the counter offers a part for scrap")
	check(GameState.component_count("PIERCE", GameState.stash) == held_was + 1,
		"buying one puts it in the stash (%d)" % GameState.component_count("PIERCE", GameState.stash))
	check(GameState.scrap == 500 - GameState.shop_price("PIERCE"),
		"and takes the scrap for it (%d)" % GameState.scrap)
	check(GameState.shop_price("PIERCE") > 5 * int(GameState.FACILITY_INFO["scrapper"]["max"]),
		"a part costs more than breaking one down ever pays back")
	GameState.scrap = scrap_was
	world.close_panel()
	await frames(6)

	# --- the words on the signs ----------------------------------------------
	# In Korean, where it shows: Silkscreen at twice its size shrinks back to
	# exactly itself, so English survived being drawn the wrong way and 둥근모꼴
	# did not.
	var was_language := Loc.language
	Loc.set_language("kor")
	await frames(10)
	await sign_ink()
	Loc.set_language(was_language)
	await frames(6)

	# --- the gate ------------------------------------------------------------
	var gate: Station = world.stations["gate"]
	await stand_at("gate")
	check(not gate.open, "the gate is shut with nothing armed")
	check(gate.closed_reason == Loc.t("hideout.gate.no_skills"), "and says why")
	# Appended, not assigned: a GDScript lambda captures a local by value, so
	# `deployed = [...]` inside one is a write nobody out here would ever see.
	var deployed: Array = []
	world.deploy_requested.connect(func(w: String, slots: Array) -> void:
		deployed.append(w)
		deployed.append(slots))
	gate.interact()
	await frames(4)
	check(deployed.is_empty(), "a shut gate does not answer")

	# Arm something, and it opens.
	var slots := GameState.get_loadout("GUN")
	slots[0] = 1
	GameState.set_loadout("GUN", slots)
	world.set_weapon("GUN")
	await frames(4)
	check(gate.open, "arming a skill opens it")
	gate.interact()
	await frames(4)
	check(deployed.size() == 2 and String(deployed[0]) == "GUN",
		"and walking through deploys what was built (%s)" % str(deployed))

	print("[HIDE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
