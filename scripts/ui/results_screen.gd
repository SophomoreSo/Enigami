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
	var b := UiKit.button("BACK TO THE HIDEOUT", UiKit.ACCENT)
	b.custom_minimum_size = Vector2(280, 44)
	b.position = Vector2(120, 560)
	b.pressed.connect(func() -> void: continued.emit())
	add_child(b)
	b.grab_focus()
	Audio.play("extract" if outcome == "extracted" else "death")

func _draw() -> void:
	var win := outcome == "extracted"
	var head := "EXTRACTED" if win else "LOST IN THE RAID"
	draw_string(_font, Vector2(120, 160), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 46,
		UiKit.GOOD if win else UiKit.BAD)
	var sub := "You carried it home through %s." % String(payload.get("exit", "the gate")) if win else \
		"The kit stayed behind. What you never took is still in the vault."
	draw_string(_font, Vector2(124, 196), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.DIM)

	var y := 260.0
	draw_string(_font, Vector2(120, y), "weapon %s" % Weapons.get_def(String(payload.get("weapon", "SWORD")))["name"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.TEXT if win else UiKit.BAD)
	y += 26.0
	draw_string(_font, Vector2(120, y), "scrap %d" % int(payload.get("scrap", 0)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.WARN if win else UiKit.BAD)
	var lost_skills: Array = payload.get("skills", [])
	if not lost_skills.is_empty():
		y += 26.0
		draw_string(_font, Vector2(120, y), "skills lost: %s" % ", ".join(lost_skills),
			HORIZONTAL_ALIGNMENT_LEFT, 700, 13, UiKit.BAD)
	y += 34.0
	draw_string(_font, Vector2(120, y), "COMPONENTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.ACCENT)
	y += 24.0
	var haul: Dictionary = payload.get("haul", {})
	if haul.is_empty():
		draw_string(_font, Vector2(120, y), "none", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.DIM)
	for id in haul:
		draw_string(_font, Vector2(120, y), "%s x%d" % [Components.get_def(id).get("name", id), int(haul[id])],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Components.color_of(id) if win else Color(0.5, 0.4, 0.4))
		y += 20.0
