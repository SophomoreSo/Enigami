extends Node
## The title's settings and the pause menu are built in UiKit's pixel look all
## the way down, including the controls list they share. Checked on both built
## trees: every piece of text is the pixel face at a multiple of its native 8px,
## every box is square, unsmoothed and evenly bordered, the sliders and
## scrollbars are replaced, the bindings still line up and fit, and the panel
## fits the width it is given. The pause menu is checked for one thing more —
## that its rows sit on something solid, since the raid behind it goes on being
## drawn and showed through them.

const GameScript := preload("res://app/game.gd")
const BOXES := ["panel", "normal", "hover", "pressed", "focus", "disabled", "slider",
	"grabber_area", "grabber_area_highlight", "scroll", "scroll_focus", "grabber",
	"grabber_highlight", "grabber_pressed"]

var game: Node
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[PIXUI] PASS ", what)
	else:
		fails += 1
		push_error("PIXUI FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

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

## Every check that says a built menu is in the pixel look, run over whatever is
## under `sc`: the settings and the pause menu are the same kit twice.
func audit(sc: ScrollContainer, what: String) -> void:
	var all := controls_under(sc)
	var texts := 0
	var plain: Array = []
	var boxes := 0
	var soft: Array = []
	var sliders := 0
	var knobs := 0
	for c in all:
		if c is Label or c is Button:
			texts += 1
			var size: int = c.get_theme_font_size("font_size")
			if c.get_theme_font("font") != UiKit.PIXEL_FONT or size < 16 or size % 8 != 0:
				plain.append("%s '%s' @%d" % [c.get_class(), c.text, size])
		if c is HSlider:
			sliders += 1
			if c.has_theme_icon_override("grabber"):
				knobs += 1
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
				soft.append("%s.%s at %s (aa=%s radius=%d border=%d)" % [c.get_class(), name,
					sc.get_path_to(c), sb.anti_aliasing, sb.get_corner_radius(CORNER_TOP_LEFT),
					sb.get_border_width(SIDE_LEFT)])
	check(texts > 20 and plain.is_empty(),
		"%s: every text is the pixel face at a multiple of 8px (%d checked, off: %s)" % [what, texts, str(plain)])
	check(boxes > 20 and soft.is_empty(),
		"%s: every box is square, unsmoothed and evenly bordered (%d checked, off: %s)" % [what, boxes, str(soft)])
	check(sliders == 2 and knobs == 2, "%s: both sliders have the square knob (%d of %d)" % [what, knobs, sliders])
	check(sc.get_v_scroll_bar().has_theme_stylebox_override("grabber"), "%s: the scrollbar is the pixel one" % what)

	var bar := sc.get_v_scroll_bar()
	var room := sc.size.x - (bar.size.x if bar.visible else 0.0)
	var wanted := (sc.get_child(0) as Control).get_combined_minimum_size().x
	check(wanted <= room + 0.5, "%s: the panel fits the width it is given (%.0f of %.0f)" % [what, wanted, room])


func _ready() -> void:
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(10)

	var title: TitleScreen = game.current
	title._toggle_settings()
	await frames(8)
	var sc: ScrollContainer = title._settings
	var all := controls_under(sc)
	audit(sc, "the settings")

	var cp: ControlsPanel = null
	for c in all:
		if c is ControlsPanel:
			cp = c
	check(cp != null and cp.pixel, "the settings build their controls list in the pixel look")
	if cp != null:
		var columns := {}
		var tight: Array = []
		for b: Button in cp._rows.values():
			columns[int(round(b.global_position.x))] = true
			if b.get_minimum_size().x > b.size.x + 0.5:
				tight.append(b.text)
		check(columns.size() == 1, "the bindings line up in one column (%d x positions)" % columns.size())
		check(tight.is_empty(), "every binding fits its button (too tight: %s)" % str(tight))

	# --- the language switch ------------------------------------------------
	# It lives in this panel, and pressing it has to rebuild the panel it was
	# pressed in, the menu behind it and the pause menu that outlives both —
	# none of which redraw themselves, since every word on them is written once.
	var was_language := Loc.language
	var other := ""
	for lang in Loc.languages():
		if lang != Loc.language:
			other = lang
	check(other != "", "there is a second language to switch to")
	if other != "":
		var pick: Button = null
		for c in controls_under(title._settings):
			if c is Button and (c as Button).text == Loc.language_name(other):
				pick = c
		check(pick != null, "the settings offer %s, written in itself ('%s')"
			% [other, Loc.language_name(other)])
		if pick != null:
			pick.emit_signal("pressed")
			await frames(8)
			check(Loc.language == other, "pressing it switches the game to %s" % other)
			check(title._settings != null and title._settings.visible,
				"and leaves the settings open, where the button was")
			var heading := ""
			for c in controls_under(title._settings):
				if c is Label and (c as Label).text == Loc.t("menu.settings.heading"):
					heading = (c as Label).text
			check(heading != "", "the panel is rebuilt in %s ('%s')" % [other, heading])
			check(title._start_button != null
					and title._start_button.text == Loc.t("menu.title.start"),
				"and so is the menu behind it ('%s')"
					% ("" if title._start_button == null else title._start_button.text))
			var paused_in := 0
			for c in controls_under(game.pause_menu):
				if c is Button and (c as Button).text == Loc.t("menu.pause.resume"):
					paused_in += 1
			check(paused_in == 1, "and the pause menu, which no screen owns (%d)" % paused_in)
			Loc.set_language(was_language)
			await frames(8)
			check(Loc.language == was_language, "switching back puts %s on again" % was_language)

	# --- the pause menu -------------------------------------------------------
	# The same kit again, from inside a raid. It is checked with the menu shown,
	# since a scroll that has never been on screen has not laid itself out.
	game.pause_menu.visible = true
	await frames(6)
	var paused := controls_under(game.pause_menu)
	var pause_scroll: ScrollContainer = null
	var pause_cp: ControlsPanel = null
	var resume: Button = null
	for c in paused:
		if c is ScrollContainer:
			pause_scroll = c
		if c is ControlsPanel:
			pause_cp = c
		if c is Button and (c as Button).text == Loc.t("menu.pause.resume"):
			resume = c
	check(pause_scroll != null, "the pause menu is a scroll that fits the screen")
	if pause_scroll != null:
		audit(pause_scroll, "the pause menu")
	check(pause_cp != null and pause_cp.pixel, "the pause menu's controls list is the pixel one too")
	# The raid goes on being drawn behind it, and a stopped tree leaves whatever
	# the HUD was saying where it was: the rows have to sit on something solid,
	# or those words come through a button lit under the cursor.
	var backing := ""
	var at: Node = resume
	while at != null and at != game.pause_menu:
		if at is PanelContainer:
			var sb := (at as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
			if sb != null and sb.bg_color.a >= 1.0:
				backing = at.get_class()
		at = at.get_parent()
	check(resume != null and backing != "",
		"and RESUME sits on a panel nothing shows through ('%s')" % backing)
	game.pause_menu.visible = false

	print("[PIXUI] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
