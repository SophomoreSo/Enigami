class_name Hideout
extends Control

## Between raids. Pick the one weapon you will carry, fill its slots with
## compatible skills, spend loot on the facilities, and deploy.

signal deploy_requested(weapon: String, slots: Array)
signal sandbox_requested()
signal title_requested()
signal edit_requested(board_index: int)

var weapon_id: String = ""
var focus_slot: int = 0
var _root: VBoxContainer
var _status: Label

func _ready() -> void:
	UiKit.fill_screen(self)
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	set_process(true)
	if weapon_id == "" or not GameState.owned_weapons.has(weapon_id):
		weapon_id = GameState.owned_weapons[0] if GameState.owned_weapons.size() > 0 else "SWORD"
	rebuild()

func _process(_d: float) -> void:
	UiKit.sync_screen(self)

func rebuild() -> void:
	if _root != null:
		_root.queue_free()
	_root = VBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 28
	_root.offset_right = -28
	_root.offset_top = 20
	_root.offset_bottom = -20
	_root.add_theme_constant_override("separation", 10)
	add_child(_root)

	_root.add_child(_header())
	_root.add_child(UiKit.hline())

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	_root.add_child(cols)
	cols.add_child(_weapons_column())
	cols.add_child(_loadout_column())
	cols.add_child(_facilities_column())

	_status = UiKit.label("", 12, UiKit.DIM)
	_root.add_child(_status)
	_root.add_child(_footer())

func _header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.add_child(UiKit.title("HIDEOUT"))
	h.add_child(UiKit.label("scrap %d" % GameState.scrap, 14, UiKit.WARN))
	var r: Dictionary = GameState.records
	h.add_child(UiKit.label("raids %d · escaped %d · lost %d · kills %d" % [
		r["raids"], r["escapes"], r["deaths"], r["kills"]], 12, UiKit.DIM))
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(pad)
	var sb := UiKit.button("SANDBOX", UiKit.GOOD)
	sb.pressed.connect(func() -> void: sandbox_requested.emit())
	h.add_child(sb)
	var tb := UiKit.button("TITLE")
	tb.pressed.connect(func() -> void: title_requested.emit())
	h.add_child(tb)
	return h

## --- weapons ----------------------------------------------------------------
func _weapons_column() -> Control:
	var p := UiKit.panel()
	p.custom_minimum_size = Vector2(300, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UiKit.label("WEAPON — one per raid", 13, UiKit.ACCENT))
	v.add_child(UiKit.hline())
	for id in Weapons.ids():
		var owned: bool = GameState.owned_weapons.has(id)
		var d := Weapons.get_def(id)
		var selected: bool = id == weapon_id
		var wc := Style.weapon_color(id)
		var mark := "▸ " if selected else "   "
		var b := UiKit.button("%s%s%s" % [mark, d["name"], "" if owned else "  (lost)"],
			Style.weapon_color(id) if selected else UiKit.DIM)
		b.disabled = not owned
		b.custom_minimum_size = Vector2(0, 34 if selected else 28)
		if selected:
			b.add_theme_color_override("font_color", Style.weapon_color(id))
			b.add_theme_stylebox_override("normal", UiKit.style(
				Color(wc.r, wc.g, wc.b, 0.2), wc, 2))
		b.pressed.connect(func() -> void:
			weapon_id = id
			focus_slot = 0
			rebuild())
		v.add_child(b)
	v.add_child(UiKit.spacer(6))
	var d := Weapons.get_def(weapon_id)
	v.add_child(UiKit.label(String(d["desc"]), 11, UiKit.DIM))
	v.add_child(UiKit.spacer(4))
	v.add_child(UiKit.label("slots: %d" % int(d["slots"]), 12))
	v.add_child(UiKit.label("accepts: %s" % ", ".join(d["accepts"]), 11, UiKit.DIM))
	v.add_child(UiKit.label("melee x%.2f · ranged x%.2f · bolt speed x%.2f" % [
		float(d["melee_mul"]), float(d["ranged_mul"]), float(d["projectile_speed"])], 11, UiKit.DIM))
	if bool(d["gravity_shots"]):
		v.add_child(UiKit.label("thrown: shots arc under gravity", 11, UiKit.WARN))
	v.add_child(UiKit.spacer(8))
	v.add_child(UiKit.label("Dying loses this weapon and the skills slotted into it.", 11, UiKit.BAD))
	return p

## --- loadout + library ------------------------------------------------------
func _loadout_column() -> Control:
	var p := UiKit.panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)

	var slots := GameState.get_loadout(weapon_id)
	v.add_child(UiKit.label("SKILL SLOTS", 13, UiKit.ACCENT))
	v.add_child(UiKit.hline())
	for i in slots.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var idx := int(slots[i])
		var name_txt := "— empty —"
		var tag_txt := ""
		if idx >= 0:
			var b: SkillBoard = GameState.skill_library[idx]
			name_txt = b.skill_name
			tag_txt = ", ".join(b.compute_tags())
		var sel := UiKit.button("%s %d: %s" % ["▸" if i == focus_slot else " ", i + 1, name_txt],
			UiKit.ACCENT if i == focus_slot else UiKit.DIM)
		sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sel.pressed.connect(func() -> void:
			focus_slot = i
			rebuild())
		row.add_child(sel)
		if tag_txt != "":
			row.add_child(UiKit.label(tag_txt, 10, UiKit.DIM))
		if idx >= 0:
			var ed := UiKit.button("EDIT", UiKit.GOOD)
			ed.pressed.connect(func() -> void: edit_requested.emit(idx))
			row.add_child(ed)
			var cl := UiKit.button("CLEAR", UiKit.BAD)
			cl.pressed.connect(func() -> void:
				var s := GameState.get_loadout(weapon_id)
				s[i] = -1
				GameState.set_loadout(weapon_id, s)
				rebuild())
			row.add_child(cl)
		v.add_child(row)

	v.add_child(UiKit.spacer(8))
	var lib_head := HBoxContainer.new()
	lib_head.add_child(UiKit.label("SKILL LIBRARY — click to fit into slot %d" % (focus_slot + 1), 13, UiKit.ACCENT))
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lib_head.add_child(pad)
	var nb := UiKit.button("NEW SKILL", UiKit.GOOD)
	nb.pressed.connect(func() -> void:
		GameState.new_skill()
		edit_requested.emit(GameState.skill_library.size() - 1))
	lib_head.add_child(nb)
	v.add_child(lib_head)
	v.add_child(UiKit.hline())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	v.add_child(scroll)

	for i in GameState.skill_library.size():
		var board: SkillBoard = GameState.skill_library[i]
		var compatible := Weapons.accepts_board(weapon_id, board)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var tags := board.compute_tags()
		var txt := "%s   [%s]" % [board.skill_name, ", ".join(tags) if tags.size() > 0 else "utility"]
		var btn := UiKit.button(txt, UiKit.GOOD if compatible else UiKit.BAD)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = not compatible
		btn.tooltip_text = Weapons.rejection_reason(weapon_id, board)
		btn.pressed.connect(func() -> void:
			var s := GameState.get_loadout(weapon_id)
			# One skill cannot sit in two slots at once.
			for k in s.size():
				if int(s[k]) == i:
					s[k] = -1
			s[focus_slot] = i
			GameState.set_loadout(weapon_id, s)
			focus_slot = mini(focus_slot + 1, s.size() - 1)
			rebuild())
		row.add_child(btn)
		var ed := UiKit.button("EDIT")
		ed.pressed.connect(func() -> void: edit_requested.emit(i))
		row.add_child(ed)
		var del := UiKit.button("✕", UiKit.BAD)
		del.pressed.connect(func() -> void:
			GameState.delete_skill(i)
			rebuild())
		row.add_child(del)
		if not compatible:
			row.add_child(UiKit.label("incompatible", 10, UiKit.BAD))
		list.add_child(row)
	return p

## --- facilities & stash -----------------------------------------------------
func _facilities_column() -> Control:
	var p := UiKit.panel()
	p.custom_minimum_size = Vector2(340, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	v.add_child(UiKit.label("FACILITIES", 13, UiKit.ACCENT))
	v.add_child(UiKit.hline())
	for key in GameState.FACILITY_INFO:
		var info: Dictionary = GameState.FACILITY_INFO[key]
		var lvl: int = GameState.facilities[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lbl := UiKit.label("%s  lv%d" % [info["name"], lvl], 12)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		if lvl >= int(info["max"]):
			row.add_child(UiKit.label("max", 11, UiKit.DIM))
		else:
			var cost := GameState.facility_cost(key)
			var b := UiKit.button("%d" % cost, UiKit.WARN)
			b.disabled = not GameState.can_upgrade(key)
			b.pressed.connect(func() -> void:
				if GameState.upgrade_facility(key):
					Audio.play("pickup")
					rebuild())
			row.add_child(b)
		v.add_child(row)
		v.add_child(UiKit.label(String(info["desc"]), 10, UiKit.DIM))
	v.add_child(UiKit.spacer(4))
	v.add_child(UiKit.label("board %dx%d · max hp %d · stash cap %d" % [
		GameState.board_size().x, GameState.board_size().y,
		int(GameState.max_health()), GameState.stash_cap()], 11, UiKit.DIM))

	v.add_child(UiKit.spacer(8))
	var sh := HBoxContainer.new()
	sh.add_child(UiKit.label("STASH", 13, UiKit.ACCENT))
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(pad)
	var fb := UiKit.button("FORGE 3→1 (25)", UiKit.WARN)
	fb.disabled = GameState.scrap < 25 or _stash_total() < 3
	fb.pressed.connect(_forge)
	sh.add_child(fb)
	v.add_child(sh)
	v.add_child(UiKit.hline())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	v.add_child(scroll)
	var any := false
	for id in Components.LOOT_POOL:
		var n := int(GameState.stash.get(id, 0))
		if n <= 0:
			continue
		any = true
		var row := HBoxContainer.new()
		var l := UiKit.label("%s x%d" % [Components.get_def(id)["name"], n], 11, Style.component_color(id))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var sc := UiKit.button("scrap", UiKit.DIM)
		sc.pressed.connect(func() -> void:
			var gain := GameState.scrap_component(id)
			if gain > 0:
				Audio.play("erase")
			rebuild())
		row.add_child(sc)
		list.add_child(row)
	if not any:
		list.add_child(UiKit.label("Nothing stored. Bring something home.", 11, UiKit.DIM))
	return p

func _stash_total() -> int:
	var n := 0
	for k in GameState.stash:
		n += int(GameState.stash[k])
	return n

func _forge() -> void:
	# Spend the most plentiful spares first, so a unique part is never melted.
	var ids: Array = GameState.stash.keys()
	ids.sort_custom(func(a, b) -> bool:
		return int(GameState.stash[a]) > int(GameState.stash[b]))
	var pick: Array[String] = []
	for id in ids:
		var n := int(GameState.stash[id])
		for i in n:
			if pick.size() < 3:
				pick.append(String(id))
	if pick.size() < 3:
		return
	var made := GameState.forge_component(pick)
	if made != "":
		Audio.play("pickup")
		_status.text = "The forge yielded %s." % Components.get_def(made)["name"]
	rebuild()

## --- deploy -----------------------------------------------------------------
func _footer() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var slots := GameState.get_loadout(weapon_id)
	var filled := slots.filter(func(i: int) -> bool: return int(i) >= 0)
	h.add_child(UiKit.label("%d of %d slots filled" % [filled.size(), slots.size()], 12, UiKit.DIM))
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(pad)
	var warn := UiKit.label("Everything you take can be lost.", 12, UiKit.BAD)
	h.add_child(warn)
	var b := UiKit.button("DEPLOY  ▶", UiKit.GOOD)
	b.custom_minimum_size = Vector2(180, 40)
	b.disabled = filled.is_empty() or not GameState.owned_weapons.has(weapon_id)
	b.pressed.connect(func() -> void:
		deploy_requested.emit(weapon_id, filled))
	h.add_child(b)
	return h
