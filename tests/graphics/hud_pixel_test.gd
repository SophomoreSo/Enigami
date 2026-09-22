extends Node
## The raid HUD is drawn by hand, in UiKit's pixel look: every PIXEL×PIXEL block
## of what it draws is one colour, which is the standard `bench_pixel_test`
## holds the bench's readout to. It was the last screen still writing in the
## default face at nine pixels, which read as another game's interface laid over
## this one.
##
## Checked with everything it can show on it at once: a wounded player, a dash
## spent, a charge half drained, one slot armed, one mid-cooldown with the flash
## still on it, one the weapon refuses, a prompt, a toast and an extraction
## under way — so nothing that only shows sometimes goes unchecked.
##
## And the numbers the layout stands on, which the pixel face is what decides:
## a row of squares as wide as the bars over it at the most slots a weapon has,
## a square wide enough for the bindings the game ships with, and a health bar
## that holds the longest reading it can show.
##
## Needs a real renderer: the block check reads the frame back.

const GameScript := preload("res://app/game.gd")

var game: Node
var hud: Hud
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[HUD] PASS ", what)
	else:
		fails += 1
		push_error("HUD FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Leaves only what the HUD draws itself: the world goes through the pixel
## camera on a layer of its own, and every other screen in the game is a layer
## too. What the HUD shares its layer with — the editor, the map — is hidden as
## well, so a panel that opened on top of it cannot be mistaken for it.
func isolate() -> Array:
	var hidden: Array = []
	var own := hud.get_parent()
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var layer := n as CanvasLayer
		if layer != own and layer.visible:
			layer.visible = false
			hidden.append(layer)
	for c in own.get_children():
		if c != hud and c is CanvasItem and (c as CanvasItem).visible:
			(c as CanvasItem).visible = false
			hidden.append(c)
	return hidden

func restore(hidden: Array) -> void:
	for n in hidden:
		n.visible = true

## Every PIXEL×PIXEL block of the frame is one colour: shrunk to a pixel a block
## and blown back up, it only comes back unchanged if no block held two.
func blocks() -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	var dir := OS.get_environment("SHOTS_DIR") if OS.has_environment("SHOTS_DIR") else "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	im.save_png(dir.path_join("pixel_hud.png"))
	# The grid is Silkscreen's. A language written in a finer face is still
	# whole pixels, just smaller ones, so the shot is still saved and looked at
	# and this grid is not claimed of it — see the same note in
	# `bench_pixel_test`, and `tests/shared/loc_test` for what does hold them.
	if Loc.pixel_grid() < UiKit.PIXEL:
		print("[HUD] skip the block check: %s is written on a %d-pixel grid, not %d"
			% [Loc.language, Loc.pixel_grid(), UiKit.PIXEL])
		return
	var screen := Vector2i(get_viewport().get_visible_rect().size)
	if im.get_size() != screen:
		print("[HUD] skip the block check: the frame is %s, not %s" % [im.get_size(), screen])
		return
	var s := UiKit.PIXEL
	var round_trip := im.duplicate() as Image
	round_trip.resize(screen.x / s, screen.y / s, Image.INTERPOLATE_NEAREST)
	round_trip.resize(screen.x, screen.y, Image.INTERPOLATE_NEAREST)
	var same := round_trip.get_data() == im.get_data()
	var first := Vector2i(-1, -1)
	if not same:
		for y in range(0, screen.y - s + 1, s):
			for x in range(0, screen.x - s + 1, s):
				var c := im.get_pixel(x, y)
				for dy in s:
					for dx in s:
						if im.get_pixel(x + dx, y + dy) != c and first.x < 0:
							first = Vector2i(x, y)
	check(same, "every %d×%d block the HUD draws is one colour (the first split at %s)"
		% [s, s, first])

func _ready() -> void:
	GameState.reset_profile()
	seed(9)
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	# The Sword refuses the Gun's ranged board, so slot 2 is the card that says
	# a weapon will not carry it.
	game._deploy("SWORD", [0, 1, 2])
	await frames(24)
	var raid: Raid = game.current
	hud = Views.of(raid).hud
	check(hud != null, "the raid puts a HUD up")
	if hud == null:
		get_tree().quit(1)
		return

	raid.player.invuln = 999.0
	raid.player.health = raid.player.max_health * 0.7
	raid.player.stamina = Player.MAX_STAMINA * 0.55
	raid.player.mana = Player.MAX_MANA * 0.4
	raid.player.select_slot(0)
	var r: SkillRunner = raid.player.runners[0]
	r.cooldown = 10
	r.cycle_seconds = 2.0
	r._elapsed = 0.6
	r.ready_flash = 0.6
	# The view copies these onto the HUD every frame, so they are set where it
	# reads them rather than on the HUD itself.
	raid.prompt = Loc.t("hud.extract.hold")
	raid.extract_ratio = 0.4
	hud.show_toast(Loc.t("hud.burning"))
	await frames(4)

	var hidden := isolate()
	await blocks()
	restore(hidden)

	# --- what the pixel face costs the layout --------------------------------
	var vp := get_viewport().get_visible_rect().size
	# The slots are squares under the bars now, so what the layout stands on is
	# the column's own width rather than any card's: the widest weapon's slots,
	# plus the weapon's own attack, have to come to the width of the bars over
	# them or the corner stops reading as one column.
	var most := 0
	for id in Weapons.ids():
		most = maxi(most, Weapons.slots(String(id)))
	var row := float(most + 1) * Hud.SLOT.x + float(most) * Hud.SLOT_GAP
	check(row <= Hud.BAR_W + 0.5,
		"the row of slots is no wider than the bars over it at %d slots (%.0f of %.0f)"
			% [most, row, Hud.BAR_W])
	# The only text in a square is the binding, centred and cut short if it has
	# to be — but the bindings the game ships with have to fit whole, or every
	# square starts life with an ellipsis in it.
	var pad := 16.0
	for action in ["attack", "skill_1", "skill_2", "skill_3", "skill_4"]:
		var label := Controls.short_label_for(action)
		check(PixelDraw.text_width(label) <= Hud.SLOT.x - pad,
			"a slot square holds its binding whole, '%s' (%.0f of %.0f)"
				% [label, PixelDraw.text_width(label), Hud.SLOT.x - pad])
	# And the whole corner — bars, weapon, squares, the armed slot's name and the
	# reason under it — stays clear of the two lines of keys along the bottom.
	var column := Hud.SLOT_TOP + Hud.SLOT.y + 18.0 + PixelDraw.LINE
	check(column <= vp.y - 34.0,
		"the corner stops clear of the key hints under it (%.0f of %.0f)"
			% [column, vp.y - 34.0])
	var reading := Loc.t("hud.health", [999, 999])
	check(PixelDraw.text_width(reading) <= Hud.BAR_W - 16.0,
		"the health bar holds its longest reading, '%s' (%.0f of %.0f)"
			% [reading, PixelDraw.text_width(reading), Hud.BAR_W - 16.0])

	print("[HUD] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
