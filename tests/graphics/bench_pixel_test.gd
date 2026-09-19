extends Node
## The bench's panel is drawn in UiKit's pixel look: every PIXEL×PIXEL block of
## what it draws is one colour, its buttons are the pixel face, and what it
## draws fits — the readout's lines inside the panel, the slot cards across the
## screen with the most boards a bench can carry, and the buttons clear of both.
##
## The block check covers the drawn part and not the buttons, which are Controls
## and cannot meet it: Godot centres a Button's label inside its box, the pixel
## face is 21px tall, and no box height makes both the border and the baseline
## land on an even row. A Control-built screen is held to the other standard —
## the pixel face at a multiple of 8px, square unsmoothed boxes, as
## `settings_pixel_test` and `hideout_pixel_test` check — and a one-pixel offset
## between a letter and the box around it is not visible. What is drawn by hand
## has no such excuse, so it is held to the block.
##
## Needs a real renderer: the block check reads the frame back.

const GameScript := preload("res://app/game.gd")

var game: Node
var panel: SandboxPanel
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[BENCH] PASS ", what)
	else:
		fails += 1
		push_error("BENCH FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

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

## Leaves only what the panel draws itself. The world behind it goes through the
## pixel camera, slid by whatever the real camera had left over — a pixel off
## this grid on purpose — and the buttons are Controls, which the block check
## does not cover (see the note at the top).
func isolate() -> Array:
	var hidden: Array = []
	var own := panel.get_parent()
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var layer := n as CanvasLayer
		if layer != own and layer.visible:
			layer.visible = false
			hidden.append(layer)
	for c in own.get_children():
		if c != panel and c is CanvasItem and (c as CanvasItem).visible:
			(c as CanvasItem).visible = false
			hidden.append(c)
	for c in panel.get_children():
		if c is CanvasItem and (c as CanvasItem).visible:
			(c as CanvasItem).visible = false
			hidden.append(c)
	return hidden

## Every PIXEL×PIXEL block of the frame is one colour: shrunk to a pixel a block
## and blown back up, it only comes back unchanged if no block held two.
func blocks(name: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	var dir := OS.get_environment("SHOTS_DIR") if OS.has_environment("SHOTS_DIR") else "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	im.save_png(dir.path_join("pixel_bench.png"))
	# The grid is Silkscreen's. A language written in a finer face is still
	# whole pixels, just smaller ones — 둥근모꼴's Hangul is a 16px body where
	# Silkscreen's Latin is an 8px body drawn at twice the size — so the shot is
	# still saved and looked at, and this grid is not claimed of it.
	# `tests/shared/loc_test` is what holds those languages to whole pixels.
	if Loc.pixel_grid() < UiKit.PIXEL:
		print("[BENCH] skip the block check: %s is written on a %d-pixel grid, not %d"
			% [Loc.language, Loc.pixel_grid(), UiKit.PIXEL])
		return
	var screen := Vector2i(get_viewport().get_visible_rect().size)
	if im.get_size() != screen:
		print("[BENCH] skip the block check: the frame is %s, not %s" % [im.get_size(), screen])
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
	check(same, "%s: every %d×%d block on screen is one colour (the first split at %s)"
		% [name, s, s, first])

func _ready() -> void:
	GameState.reset_profile()
	seed(9)
	# A fourth skill, so the bench carries the most boards it can and the row of
	# cards is as wide as it ever gets.
	GameState.new_skill()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_sandbox()
	await frames(14)
	var sb: Sandbox = game.current
	panel = Views.of(sb).panel
	check(panel != null, "the bench builds its panel")

	# A monster on the floor, a slot armed, and one slot mid-cooldown with the
	# flash still on it, so the wipe and its lit edge are both in the frame.
	sb.spawn_monster("CRAWLER")
	sb.player.select_slot(1)
	await frames(6)
	var r: SkillRunner = sb.player.runners[0]
	r.cooldown = 10
	r.cycle_seconds = 2.0
	r._elapsed = 0.6
	r.ready_flash = 0.6
	await frames(2)

	var hidden := isolate()
	await blocks("bench")
	restore(hidden)

	# --- the pixel look on the buttons --------------------------------------
	var plain: Array = []
	var soft: Array = []
	var texts := 0
	var boxes := 0
	for c in controls_under(panel):
		if c is Button or c is Label:
			texts += 1
			var size: int = c.get_theme_font_size("font_size")
			if c.get_theme_font("font") != UiKit.PIXEL_FONT or size < UiKit.PIXEL_TEXT or size % 8 != 0:
				plain.append("%s '%s' @%d" % [c.get_class(), c.text, size])
		for name in ["normal", "hover", "pressed", "focus", "disabled"]:
			if not c.has_theme_stylebox_override(name):
				continue
			var sb_box := c.get_theme_stylebox(name) as StyleBoxFlat
			if sb_box == null:
				continue
			boxes += 1
			var bad := sb_box.anti_aliasing
			for i in 4:
				if sb_box.get_border_width(i) % UiKit.PIXEL != 0 or sb_box.get_corner_radius(i) != 0:
					bad = true
			if bad:
				soft.append("%s.%s" % [c.get_class(), name])
	check(texts >= 11 and plain.is_empty(),
		"every button is the pixel face at a multiple of 8px (%d checked, off: %s)" % [texts, str(plain)])
	check(boxes > 20 and soft.is_empty(),
		"every box is square, unsmoothed and evenly bordered (%d checked, off: %s)" % [boxes, str(soft)])

	# --- the layout ---------------------------------------------------------
	var vp := get_viewport().get_visible_rect().size
	var cards := sb.player.runners.size()
	check(cards == 4, "the bench carries four boards (%d)" % cards)
	var cards_right := SandboxPanel.TEXT_X + cards * (SandboxPanel.CARD.x + SandboxPanel.CARD_GAP)
	check(cards_right <= vp.x, "the row of cards fits the screen (%.0f of %.0f)" % [cards_right, vp.x])
	var cards_top := vp.y - SandboxPanel.CARD_BOTTOM
	check(cards_top + SandboxPanel.CARD.y <= vp.y, "and sits inside its bottom edge")

	var column: VBoxContainer = null
	for c in panel.get_children():
		if c is VBoxContainer:
			column = c
	check(column != null and column.position.y >= SandboxPanel.PANEL.end.y,
		"the buttons start below the readout (%.0f of %.0f)" % [
			column.position.y if column != null else -1.0, SandboxPanel.PANEL.end.y])
	check(column != null and column.get_global_rect().end.y <= cards_top,
		"and end above the cards (%.0f of %.0f)" % [
			column.get_global_rect().end.y if column != null else -1.0, cards_top])
	check(column != null and column.get_global_rect().end.x <= SandboxPanel.PANEL.end.x,
		"and stay inside the readout's width")

	# What the cards and the readout have to hold, at their longest.
	var card_text := SandboxPanel.CARD.x - 16.0
	check(PixelDraw.text_width("cycle 12.34s · out 12") <= card_text,
		"a card fits its cycle line (%.0f of %.0f)" % [
			PixelDraw.text_width("cycle 12.34s · out 12"), card_text])
	var panel_text := SandboxPanel.PANEL.size.x - (SandboxPanel.TEXT_X - SandboxPanel.PANEL.position.x) * 2.0
	check(PixelDraw.text_width("damage/sec (3s avg): 1234.5") <= panel_text,
		"the readout fits four digits of damage (%.0f of %.0f)" % [
			PixelDraw.text_width("damage/sec (3s avg): 1234.5"), panel_text])
	check(SandboxPanel.TEXT_X + SandboxPanel.METER_W <= SandboxPanel.PANEL.end.x,
		"and the meters fit inside the panel")

	print("[BENCH] ---- %d failures ----" % fails)
	get_tree().quit()

func restore(hidden: Array) -> void:
	for n in hidden:
		if is_instance_valid(n):
			n.visible = true
