extends Node
## The hideout's panels are built in UiKit's pixel look and everything on them
## fits, with the profile at its widest: every facility maxed (the longest
## numbers), a full stash, a skill with a name too long for its row, and each
## weapon selected in turn. Checked on the built tree — every piece of text is
## the pixel face at a multiple of its native 8px, every box is square,
## unsmoothed and evenly bordered, the panel stays on the screen, and no text is
## wider than what holds it unless it is allowed to wrap or be cut short.
##
## The hideout is a room now, so these are the panels its stations open — the
## rack, the workbench and the counter, one column each. They are the columns
## the old screen showed all three of at once, which is why one test still
## covers all of them.
##
## Also the status line, which is what pays for all that: it says what the mouse
## is on, and keeps the last thing that happened when the mouse is on nothing.

const GameScript := preload("res://app/game.gd")
const BOXES := ["panel", "normal", "hover", "pressed", "focus", "disabled",
	"scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]

var game: Node
var world: HideoutWorld
## The column on screen: whichever station was opened last.
var hideout: Hideout
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

## What the status line says the moment the mouse lands somewhere. Read straight
## back rather than a frame later: the control answers the motion while
## `push_input` is still running, and a real cursor sitting over the window
## moves the mouse-over off again on the very next frame.
func status_at(p: Vector2) -> String:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	get_viewport().push_input(e)
	return hideout._status.text

func status_over(c: Control) -> String:
	return status_at(c.get_global_rect().get_center())

## Every Control under `root`, scrollbars included: they are internal children.
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

## Opens a station and hands back the column inside its panel. That column is a
## `Hideout` built with `section` set — the same object the old screen was, with
## two of its three columns left out — so everything below reads it the same way
## it always did.
func open_section(id: String) -> Hideout:
	world.close_panel()
	await frames(2)
	world.open_station(id)
	await frames(6)
	var view = Views.of(world)
	for c in controls_under(view.panel):
		if c is Hideout:
			return c
	return null

func label_with(prefix: String) -> Label:
	for c in controls_under(hideout):
		if c is Label and (c as Label).text.begins_with(prefix):
			return c
	return null

func button_with(prefix: String) -> Button:
	for c in controls_under(hideout):
		if c is Button and (c as Button).text.begins_with(prefix):
			return c
	return null

## The pixel look, and the fit, over the column on screen right now. `least` and
## `boxes_least` are how much text and how many styled boxes that column is
## expected to carry — the rack is a handful of weapons, the counter is two long
## lists — so a column that quietly came up empty is still a failure.
func audit(what: String, least: int, boxes_least: int) -> void:
	await frames(4)
	var all := controls_under(hideout)
	var plain: Array = []
	var soft: Array = []
	var wide: Array = []
	var texts := 0
	var boxes := 0
	for c in all:
		if c is Label or c is Button:
			texts += 1
			var size: int = c.get_theme_font_size("font_size")
			if c.get_theme_font("font") != UiKit.PIXEL_FONT or size < UiKit.PIXEL_TEXT or size % 8 != 0:
				plain.append("%s '%s' @%d" % [c.get_class(), c.text, size])
			# A label that wraps, or a control that cuts its text short, is meant
			# to be narrower than its text. Everything else has to fit.
			var may_shrink: bool = (c is Label and ((c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF
				or (c as Label).clip_text)) or (c is Button and (c as Button).clip_text)
			if not may_shrink and c.get_combined_minimum_size().x > c.size.x + 0.5:
				wide.append("%s '%s' (%.0f of %.0f)" % [c.get_class(), c.text,
					c.get_combined_minimum_size().x, c.size.x])
		for name in BOXES:
			if not c.has_theme_stylebox_override(name):
				continue
			var sb := c.get_theme_stylebox(name) as StyleBoxFlat
			if sb == null:
				continue
			boxes += 1
			var bad := sb.anti_aliasing
			for i in 4:
				if sb.get_border_width(i) % UiKit.PIXEL != 0 or sb.get_corner_radius(i) != 0:
					bad = true
			if bad:
				soft.append("%s.%s (aa=%s radius=%d border=%d)" % [c.get_class(), name,
					sb.anti_aliasing, sb.get_corner_radius(CORNER_TOP_LEFT), sb.get_border_width(SIDE_LEFT)])
	check(texts > least and plain.is_empty(),
		"%s: every text is the pixel face at a multiple of 8px (%d checked, off: %s)" % [what, texts, str(plain)])
	check(boxes > boxes_least and soft.is_empty(),
		"%s: every box is square, unsmoothed and evenly bordered (%d checked, off: %s)" % [what, boxes, str(soft)])
	check(wide.is_empty(), "%s: every text fits what holds it (too wide: %s)" % [what, str(wide)])

	# The column has to fit the frame it was given, and the frame has to fit the
	# screen. A column longer than the frame is not a failure by itself — the
	# frame scrolls — but one wider than it is, since nothing scrolls sideways.
	var vp := get_viewport().get_visible_rect().size
	check(hideout.get_combined_minimum_size().x <= hideout.size.x + 0.5,
		"%s: the column fits the width of its panel (%.0f of %.0f)"
			% [what, hideout.get_combined_minimum_size().x, hideout.size.x])
	var frame := (Views.of(world).panel as Control).get_global_rect()
	check(frame.position.x >= -0.5 and frame.position.y >= -0.5
		and frame.end.x <= vp.x + 0.5 and frame.end.y <= vp.y + 0.5,
		"%s: the panel stays on the screen (%s in %s)" % [what, frame, vp])

func _ready() -> void:
	GameState.reset_profile()
	# A new profile keeps whatever facility levels the last one had — resetting
	# does not touch them — so this puts back what it raises, or every run after
	# it starts on a maxed hideout.
	var facilities_before: Dictionary = GameState.facilities.duplicate()
	# The widest profile there is: every facility maxed, so the numbers are the
	# longest they go, and a stash with every part in it at a two-digit count.
	for key in GameState.FACILITY_INFO:
		GameState.facilities[key] = int(GameState.FACILITY_INFO[key]["max"])
	for id in Components.LOOT_POOL:
		GameState.stash[id] = 19
	GameState.scrap = 99999
	GameState.skill_library[0].skill_name = "Sword Basic With A Very Long Name"
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_hideout()
	await frames(14)
	world = game.current

	# --- the rack, on every weapon in turn -----------------------------------
	hideout = await open_section("weapons")
	check(hideout != null, "the rack opens a column of its own")
	for id in Weapons.ids():
		hideout.weapon_id = id
		hideout.focus_slot = 0
		hideout.rebuild()
		await audit(Weapons.name_for(id), 8, 12)

	# --- the counter, which carries the longest lists ------------------------
	world.set_weapon("SWORD")
	hideout = await open_section("shop")
	await audit("the counter", 40, 40)

	# --- the status line ----------------------------------------------------
	await frames(4)
	var idle := hideout._idle_status()
	check(hideout._status.text == idle, "with the mouse on nothing it shows the profile ('%s')" % idle)

	var row := label_with(GameState.facility_name("workbench"))
	check(row != null, "the facilities list is there")
	if row != null:
		var desc: String = GameState.facility_desc("workbench")
		var over := status_over(row)
		check(over == desc, "hovering a facility explains it ('%s')" % over)
		check(status_at(Vector2(4, 4)) == idle, "and moving off puts the profile back")

	# The Sword refuses the Gun's ranged board, and the row has no room to say so.
	# That list is the bench's.
	hideout = await open_section("bench")
	await audit("the bench", 8, 40)
	var idle_bench := hideout._idle_status()
	var refused: Button = null
	for c in controls_under(hideout):
		if c is Button and (c as Button).disabled and (c as Button).text.begins_with(GameState.skill_library[1].skill_name):
			refused = c
	check(refused != null, "the sword shows the gun's board as refused")
	if refused != null:
		var why := status_over(refused)
		check(why == Weapons.rejection_reason("SWORD", GameState.skill_library[1]),
			"hovering it says why ('%s')" % why)
		status_at(Vector2(4, 4))

	# Keyboard and gamepad reach the same line, since they never hover. Back on
	# the rack, which is where the weapons are.
	hideout = await open_section("weapons")
	var gun := button_with("  " + Weapons.name_for("GUN"))
	check(gun != null, "the gun is on the weapon list")
	if gun != null:
		gun.grab_focus()
		await frames(2)
		check(hideout._status.text == Weapons.desc_for("GUN"),
			"focusing a weapon explains it, with no mouse involved ('%s')" % hideout._status.text)
		gun.release_focus()
		await frames(2)
		check(hideout._status.text == hideout._idle_status(),
			"and leaving it puts the profile back")

	# --- the forge's message outlives the rebuild it triggers ----------------
	# The forge is the counter's, like everything else that costs scrap.
	hideout = await open_section("shop")
	var before := int(GameState.stash.get("SLASH", 0))
	hideout._forge()
	await frames(4)
	# Which part came out decides what the line says, and the line reads
	# differently in every language — so the line is rebuilt for every part it
	# could name, rather than matched against a prefix that only holds in
	# English. (The stash cannot say which: the forge may well hand back one of
	# the three it just melted, and that part ends up two down, not one up.)
	var forged := false
	for id in Components.LOOT_POOL:
		if hideout._status.text == Loc.t("hideout.stash.forged", [Components.name_for(String(id))]):
			forged = true
	check(forged, "the forge says what it made, after the rebuild ('%s')" % hideout._status.text)
	check(int(GameState.stash.get("SLASH", 0)) != before or GameState.scrap < 99999,
		"and it really spent the parts")

	var dir := OS.get_environment("SHOTS_DIR") if OS.has_environment("SHOTS_DIR") else "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("pixel_hideout.png"))

	GameState.facilities = facilities_before
	GameState.save_game()
	print("[HIDE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
