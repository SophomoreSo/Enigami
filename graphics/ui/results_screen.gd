class_name ResultsScreen
extends Control

signal continued()

var outcome: String = "extracted"
var payload: Dictionary = {}
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	UiKit.fill_screen(self)
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var b := UiKit.button(Loc.t("menu.results.back"), UiKit.ACCENT)
	b.custom_minimum_size = Vector2(280, 44)
	b.position = Vector2(120, 560)
	b.pressed.connect(func() -> void: continued.emit())
	add_child(b)
	b.grab_focus()
	Audio.play("extract" if outcome == "extracted" else "death")

## As on the HUD: the default face at a small size, and a language with a face
## of its own drawn at the size that face was made for. See `Hud._line`.
func _line(at: Vector2, s: String, align: int, width: float, size: int, col: Color) -> void:
	draw_string(_font, at, s, align, width, Loc.text_size(s, size), col)

func _draw() -> void:
	var win := outcome == "extracted"
	var head := Loc.t("menu.results.won") if win else Loc.t("menu.results.lost")
	_line(Vector2(120, 160), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 46,
		UiKit.GOOD if win else UiKit.BAD)
	var sub := Loc.t("menu.results.won_sub", [String(payload.get("exit", Loc.t("menu.results.default_exit")))]) if win else \
		Loc.t("menu.results.lost_sub")
	_line(Vector2(124, 196), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.DIM)

	var y := 260.0
	_line(Vector2(120, y), Loc.t("menu.results.weapon", [Weapons.name_for(String(payload.get("weapon", "SWORD")))]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.TEXT if win else UiKit.BAD)
	y += 26.0
	_line(Vector2(120, y), Loc.t("menu.results.scrap", [int(payload.get("scrap", 0))]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.WARN if win else UiKit.BAD)
	var lost_skills: Array = payload.get("skills", [])
	if not lost_skills.is_empty():
		y += 26.0
		_line(Vector2(120, y), Loc.t("menu.results.skills_lost", [Loc.t("editor.payload.separator").join(lost_skills)]),
			HORIZONTAL_ALIGNMENT_LEFT, 700, 13, UiKit.BAD)
	# What came back out with the player, and what is still down there. Both are
	# the same fact from either end of a run: a kit is only ever lost until
	# somebody walks back in for it.
	var recovered: Array = payload.get("recovered", [])
	if win and not recovered.is_empty():
		y += 26.0
		_line(Vector2(120, y), Loc.t("menu.results.recovered", [Loc.t("editor.payload.separator").join(recovered)]),
			HORIZONTAL_ALIGNMENT_LEFT, 700, 13, UiKit.GOOD)
	if not win and bool(payload.get("dropped", false)):
		y += 26.0
		_line(Vector2(120, y), Loc.t("menu.results.kit_waits"),
			HORIZONTAL_ALIGNMENT_LEFT, 700, 13, UiKit.WARN)
	y += 34.0
	_line(Vector2(120, y), Loc.t("menu.results.components"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.ACCENT)
	y += 24.0
	var haul: Dictionary = payload.get("haul", {})
	if haul.is_empty():
		_line(Vector2(120, y), Loc.t("menu.results.none"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.DIM)
	for id in haul:
		_line(Vector2(120, y), Loc.t("menu.results.haul", [Components.name_for(id), int(haul[id])]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Style.component_color(id) if win else Color(0.5, 0.4, 0.4))
		y += 20.0
