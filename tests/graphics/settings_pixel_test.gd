extends Node
## The title's settings are built in UiKit's pixel look all the way down,
## including the controls list — which the pause menu shares and must keep
## plain. Checked on the built tree: every piece of text is the pixel face at a
## multiple of its native 8px, every box is square, unsmoothed and evenly
## bordered, the sliders and scrollbars are replaced, the bindings still line
## up and fit, and the panel fits the width it is given.

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
		"every text is the pixel face at a multiple of 8px (%d checked, off: %s)" % [texts, str(plain)])
	check(boxes > 20 and soft.is_empty(),
		"every box is square, unsmoothed and evenly bordered (%d checked, off: %s)" % [boxes, str(soft)])
	check(sliders == 2 and knobs == 2, "both sliders have the square knob (%d of %d)" % [knobs, sliders])
	check(sc.get_v_scroll_bar().has_theme_stylebox_override("grabber"), "the scrollbar is the pixel one")

	var bar := sc.get_v_scroll_bar()
	var room := sc.size.x - (bar.size.x if bar.visible else 0.0)
	var wanted := (sc.get_child(0) as Control).get_combined_minimum_size().x
	check(wanted <= room + 0.5, "the panel fits the width it is given (%.0f of %.0f)" % [wanted, room])

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

	var leaked := 0
	for c in controls_under(game.pause_menu):
		if (c is Label or c is Button) and c.get_theme_font("font") == UiKit.PIXEL_FONT:
			leaked += 1
	check(leaked == 0, "the pause menu's controls list stays plain (%d pixel texts)" % leaked)

	print("[PIXUI] ---- %d failures ----" % fails)
	get_tree().quit()
