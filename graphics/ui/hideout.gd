class_name Hideout
extends Control

## Between raids. Pick the one weapon you will carry, fill its slots with
## compatible skills, spend loot on the facilities, and deploy.
##
## Built in UiKit's pixel look, like the title and the assembly screen: every
## piece of text is Silkscreen at a multiple of its native 8px and every box is
## square and unsmoothed.
##
## The pixel face runs up to twice as wide as the one it replaced, which this
## screen — three columns of dense text — has no room for. Two things give it
## back: a line that ran past its column now wraps inside it, and everything
## that only explains something moved to the status line along the bottom,
## which says what the mouse is on (see `_explain`). A description per facility
## cost five rows there and the stash the room to show anything.

signal deploy_requested(weapon: String, slots: Array)
signal title_requested()
signal edit_requested(board_index: int)
## The rack was left on a different weapon. On the whole screen nobody needs to
## know — the columns beside it are rebuilt with it — but as a station's panel
## the room outside it is what carries the choice to the gate.
signal weapon_changed(weapon: String)

## Wide enough for the longest line each column cannot wrap: a weapon's name on
## a button, and a stash row's part with a count beside it.
const COL_WEAPONS := 320.0
const COL_FACILITIES := 348.0

var weapon_id: String = ""
var focus_slot: int = 0
## Which of the three columns this screen is. "" builds all of them under a
## header and a deploy footer — the screen the hideout used to be, kept for
## anything that still wants it whole. Set to "weapons", "loadout" or "shop" and
## it builds that column alone, which is how the hideout's stations open them:
## the room is the header and the gate is the footer now.
var section: String = ""
var _root: VBoxContainer
var _status: Label
## What the status line says with nothing under the mouse: the last thing to
## happen, else the profile's own numbers. Held here rather than on the label
## because a rebuild throws the label away — which is why the forge's own
## message never used to survive the rebuild that followed it.
var _message: String = ""

func _ready() -> void:
	# Whole, this is the screen and owns the viewport. As one section it is the
	# contents of somebody else's panel: no screen-filling, no ground of its own
	# and no resizing itself every frame, or it would lay its column out against
	# the viewport while sitting in a box a third of the size.
	if section == "":
		UiKit.fill_screen(self)
		var bg := ColorRect.new()
		bg.color = UiKit.BG
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	# Off, and not merely un-asked-for: a script with a `_process` is processing
	# from the moment it enters the tree, so leaving it alone left `sync_screen`
	# stretching a panel's column back out to the whole viewport every frame,
	# with its buttons a screen and a half off to the right.
	set_process(section == "")
	Loc.language_changed.connect(_relanguage)
	if weapon_id == "" or not GameState.owned_weapons.has(weapon_id):
		weapon_id = GameState.owned_weapons[0] if GameState.owned_weapons.size() > 0 else "SWORD"
	rebuild()

func _process(_d: float) -> void:
	UiKit.sync_screen(self)

## Whole, this fills the viewport and its size is not up for discussion. As one
## section it is a block of rows inside somebody else's panel, and a plain
## Control reports no size at all — which let the column run straight out of the
## bottom of the frame it was put in, taking the way out with it.
func _get_minimum_size() -> Vector2:
	if section == "" or _root == null or not is_instance_valid(_root):
		return Vector2.ZERO
	return _root.get_combined_minimum_size()

## Every label here is written once in `rebuild`, so a change of language is
## the same rebuild a purchase or a slot change already asks for.
func _relanguage(_lang: String) -> void:
	_message = ""
	rebuild()

func rebuild() -> void:
	if _root != null:
		_root.queue_free()
	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if section == "":
		_root.offset_left = 28
		_root.offset_right = -28
		_root.offset_top = 20
		_root.offset_bottom = -20
	_root.add_theme_constant_override("separation", 10)
	add_child(_root)

	if section != "":
		_root.add_child(_section_column())
		_status = _label(_idle_status(), UiKit.DIM)
		_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_root.add_child(_status)
		update_minimum_size()
		return

	_root.add_child(_header())
	_root.add_child(UiKit.hline(true))

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	_root.add_child(cols)
	cols.add_child(_weapons_column())
	cols.add_child(_loadout_column())
	cols.add_child(_facilities_column())

	_status = _label(_idle_status(), UiKit.DIM)
	_root.add_child(_status)
	_root.add_child(_footer())

## The one column this screen was asked for, filling what it is given. On the
## whole screen a column is one of three side by side and keeps its own width;
## alone in a station's panel it takes the panel.
func _section_column() -> Control:
	var c: Control
	match section:
		"weapons": c = _weapons_column()
		"loadout": c = _loadout_column()
		_: c = _facilities_column()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(0, 0)
	return c

## --- the kit, in the pixel look ---------------------------------------------
func _label(text: String, color: Color = UiKit.TEXT, size: int = UiKit.PIXEL_TEXT) -> Label:
	return UiKit.label(text, size, color, true)

## A line that is allowed to run on: it wraps inside its column instead of
## pushing the column wider.
func _wrapped(text: String, color: Color = UiKit.DIM) -> Label:
	var l := _label(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(text: String, accent: Color = UiKit.ACCENT) -> Button:
	return UiKit.button(text, accent, true)

## A button carrying a name of any length: it takes the row and cuts the name
## short rather than pushing the buttons beside it off the panel.
func _row_button(text: String, accent: Color = UiKit.ACCENT) -> Button:
	var b := _button(text, accent)
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

func _pad() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

## --- the status line --------------------------------------------------------
## `c` explains itself here while the mouse is on it: a facility's effect, a
## weapon's warning, why a skill will not fit. In place, each of those cost a
## row of its own, and five of them cost the stash its list.
##
## The exit only clears what this control put there, so moving from a row onto
## the button inside it does not blank the line on the way.
func _explain(c: Control, text: String) -> void:
	if text == "":
		return
	if c is Label:
		(c as Label).mouse_filter = Control.MOUSE_FILTER_PASS
	var show := func() -> void: _status.text = text
	var clear := func() -> void:
		if _status.text == text:
			_status.text = _idle_status()
	c.mouse_entered.connect(show)
	c.mouse_exited.connect(clear)
	# And on focus, so the line works for a player who never touches the mouse.
	if c.focus_mode != Control.FOCUS_NONE:
		c.focus_entered.connect(show)
		c.focus_exited.connect(clear)

func _idle_status() -> String:
	if _message != "":
		return _message
	return Loc.t("hideout.status", [
		GameState.board_size().x, GameState.board_size().y,
		int(GameState.max_health()), GameState.stash_cap()])

func _say(msg: String) -> void:
	_message = msg
	if _status != null and is_instance_valid(_status):
		_status.text = _idle_status()

func _header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.add_child(UiKit.title(Loc.t("hideout.heading"), 22, true))
	h.add_child(_label(Loc.t("hideout.scrap", [GameState.scrap]), UiKit.WARN))
	var r: Dictionary = GameState.records
	h.add_child(_label(Loc.t("hideout.records", [
		r["raids"], r["escapes"], r["deaths"], r["kills"]]), UiKit.DIM))
	h.add_child(_pad())
	var tb := _button(Loc.t("hideout.title"))
	tb.pressed.connect(func() -> void: title_requested.emit())
	h.add_child(tb)
	return h

## --- weapons ----------------------------------------------------------------
func _weapons_column() -> Control:
	var p := UiKit.panel(UiKit.PANEL, Color(0.22, 0.3, 0.38), true)
	p.custom_minimum_size = Vector2(COL_WEAPONS, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_label(Loc.t("hideout.weapons.heading"), UiKit.ACCENT))
	v.add_child(UiKit.hline(true))
	for id in Weapons.ids():
		var owned: bool = GameState.owned_weapons.has(id)
		var selected: bool = id == weapon_id
		var wc := Style.weapon_color(id)
		# Two characters either way, so the name does not shift as the mark moves.
		var b := _button(Loc.t("hideout.weapons.row", ["> " if selected else "  ",
			Weapons.name_for(id), "" if owned else Loc.t("hideout.weapons.lost")]),
			wc if selected else UiKit.DIM)
		b.disabled = not owned
		b.custom_minimum_size = Vector2(0, 40 if selected else 34)
		if selected:
			b.add_theme_color_override("font_color", wc)
			b.add_theme_stylebox_override("normal", UiKit.style(
				Color(wc.r, wc.g, wc.b, 0.2), wc, 2, 3, true))
		_explain(b, Weapons.desc_for(id))
		b.pressed.connect(func() -> void:
			weapon_id = id
			focus_slot = 0
			weapon_changed.emit(id)
			rebuild())
		v.add_child(b)
	v.add_child(UiKit.spacer(6))
	var d := Weapons.get_def(weapon_id)
	v.add_child(_wrapped(Weapons.desc_for(weapon_id)))
	v.add_child(UiKit.spacer(4))
	# Slots and what they take read as one fact about the weapon, and as two
	# labels they were two wrapped blocks with a gap down the middle.
	v.add_child(_wrapped(Loc.t("hideout.weapons.slots",
		[int(d["slots"]), Components.tag_names(d["accepts"])]), UiKit.TEXT))
	v.add_child(_wrapped(Loc.t("hideout.weapons.multipliers", [
		float(d["melee_mul"]), float(d["ranged_mul"]), float(d["projectile_speed"])])))
	if bool(d["gravity_shots"]):
		v.add_child(_wrapped(Loc.t("hideout.weapons.gravity"), UiKit.WARN))
	v.add_child(UiKit.spacer(8))
	v.add_child(_wrapped(Loc.t("hideout.weapons.warning"), UiKit.BAD))
	return p

## --- loadout + library ------------------------------------------------------
func _loadout_column() -> Control:
	var p := UiKit.panel(UiKit.PANEL, Color(0.22, 0.3, 0.38), true)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)

	var slots := GameState.get_loadout(weapon_id)
	v.add_child(_label(Loc.t("hideout.loadout.heading"), UiKit.ACCENT))
	v.add_child(UiKit.hline(true))
	for i in slots.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var idx := int(slots[i])
		# The tags ride in the button with the name rather than in a label beside
		# it: at this size the pair ran past the panel, and the button is the one
		# of the two that can give ground.
		var name_txt := Loc.t("hideout.loadout.empty")
		if idx >= 0:
			var b: SkillBoard = GameState.skill_library[idx]
			name_txt = Loc.t("hideout.loadout.named",
				[b.skill_name, Components.tag_names(b.compute_tags())])
		var sel := _row_button(Loc.t("hideout.loadout.row", [">" if i == focus_slot else " ", i + 1, name_txt]),
			UiKit.ACCENT if i == focus_slot else UiKit.DIM)
		sel.pressed.connect(func() -> void:
			focus_slot = i
			rebuild())
		row.add_child(sel)
		if idx >= 0:
			var ed := _button(Loc.t("hideout.loadout.edit"), UiKit.GOOD)
			ed.pressed.connect(func() -> void: edit_requested.emit(idx))
			row.add_child(ed)
			var cl := _button(Loc.t("hideout.loadout.clear"), UiKit.BAD)
			cl.pressed.connect(func() -> void:
				var s := GameState.get_loadout(weapon_id)
				s[i] = -1
				GameState.set_loadout(weapon_id, s)
				rebuild())
			row.add_child(cl)
		v.add_child(row)

	v.add_child(UiKit.spacer(8))
	var lib_head := HBoxContainer.new()
	lib_head.add_child(_label(Loc.t("hideout.loadout.library", [focus_slot + 1]), UiKit.ACCENT))
	lib_head.add_child(_pad())
	var nb := _button(Loc.t("hideout.loadout.new"), UiKit.GOOD)
	nb.pressed.connect(func() -> void:
		GameState.new_skill()
		edit_requested.emit(GameState.skill_library.size() - 1))
	lib_head.add_child(nb)
	v.add_child(lib_head)
	v.add_child(UiKit.hline(true))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 132)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiKit.pixel_scroll(scroll)
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
		var btn := _row_button(Loc.t("hideout.loadout.entry", [board.skill_name,
			Components.tag_names(tags) if tags.size() > 0 else Loc.t("hideout.loadout.utility")]),
			UiKit.GOOD if compatible else UiKit.BAD)
		btn.disabled = not compatible
		# Why it will not fit goes to the status line: the row it used to sit on
		# had no space left for it, and a tooltip is the theme's, not ours.
		_explain(btn, Weapons.rejection_reason(weapon_id, board) if not compatible else "")
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
		var ed := _button(Loc.t("hideout.loadout.edit"))
		ed.pressed.connect(func() -> void: edit_requested.emit(i))
		row.add_child(ed)
		# The pixel face has no ✕; an X in it is the same mark and one glyph.
		var del := _button(Loc.t("hideout.loadout.delete"), UiKit.BAD)
		del.pressed.connect(func() -> void:
			GameState.delete_skill(i)
			rebuild())
		row.add_child(del)
		list.add_child(row)
	return p

## --- facilities & stash -----------------------------------------------------
func _facilities_column() -> Control:
	var p := UiKit.panel(UiKit.PANEL, Color(0.22, 0.3, 0.38), true)
	p.custom_minimum_size = Vector2(COL_FACILITIES, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	v.add_child(_label(Loc.t("hideout.facilities.heading"), UiKit.ACCENT))
	v.add_child(UiKit.hline(true))
	for key in GameState.FACILITY_INFO:
		var info: Dictionary = GameState.FACILITY_INFO[key]
		var lvl: int = GameState.facilities[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		_explain(row, GameState.facility_desc(key))
		var lbl := _label(Loc.t("hideout.facilities.row", [GameState.facility_name(key), lvl]))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		if lvl >= int(info["max"]):
			row.add_child(_label(Loc.t("hideout.facilities.max"), UiKit.DIM))
		else:
			var b := _button("%d" % GameState.facility_cost(key), UiKit.WARN)
			b.disabled = not GameState.can_upgrade(key)
			_explain(b, GameState.facility_desc(key))
			b.pressed.connect(func() -> void:
				if GameState.upgrade_facility(key):
					Audio.play("pickup")
					_say(Loc.t("hideout.facilities.upgraded", [GameState.facility_name(key), GameState.facilities[key]]))
					rebuild())
			row.add_child(b)
		v.add_child(row)

	v.add_child(UiKit.spacer(8))
	v.add_child(_shop_shelf())
	v.add_child(UiKit.spacer(8))
	var sh := HBoxContainer.new()
	sh.add_child(_label(Loc.t("hideout.stash.heading"), UiKit.ACCENT))
	sh.add_child(_pad())
	# No arrow in the pixel face: three of them go in, one comes out.
	var fb := _button(Loc.t("hideout.stash.forge"), UiKit.WARN)
	fb.disabled = GameState.scrap < 25 or _stash_total() < 3
	_explain(fb, Loc.t("hideout.stash.forge_hint"))
	fb.pressed.connect(_forge)
	sh.add_child(fb)
	v.add_child(sh)
	v.add_child(UiKit.hline(true))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 104)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiKit.pixel_scroll(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	v.add_child(scroll)
	var any := false
	for id in Components.LOOT_POOL:
		var n := int(GameState.stash.get(id, 0))
		if n <= 0:
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var l := _label(Loc.t("hideout.stash.row", [Components.name_for(id), n]), Style.component_color(id))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		_explain(l, Components.desc_for(id))
		row.add_child(l)
		var sc := _button(Loc.t("hideout.stash.scrap"), UiKit.DIM)
		_explain(sc, Loc.t("hideout.stash.scrap_hint"))
		sc.pressed.connect(func() -> void:
			var gain := GameState.scrap_component(id)
			if gain > 0:
				Audio.play("erase")
				_say(Loc.t("hideout.stash.scrapped", [Components.name_for(id), gain]))
			rebuild())
		row.add_child(sc)
		list.add_child(row)
	if not any:
		list.add_child(_wrapped(Loc.t("hideout.stash.empty")))
	return p

## --- the merchant's shelf ---------------------------------------------------
## Parts for scrap, which the hideout had no way to buy: everything in it was
## either found in a raid or melted out of three things that were. A part you
## are one short of is now a thing you can go and get.
##
## Priced by `GameState`, never here — what a part is worth is a rule.
func _shop_shelf() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_child(_label(Loc.t("hideout.shop.heading"), UiKit.ACCENT))
	head.add_child(_pad())
	head.add_child(_label(Loc.t("hideout.scrap", [GameState.scrap]), UiKit.WARN))
	v.add_child(head)
	v.add_child(UiKit.hline(true))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 104)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiKit.pixel_scroll(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	v.add_child(scroll)

	for id in GameState.shop_stock():
		var price: int = GameState.shop_price(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var l := _label(Components.name_for(id), Style.component_color(id))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		_explain(l, Components.desc_for(id))
		row.add_child(l)
		var b := _button(Loc.t("hideout.shop.price", [price]), UiKit.WARN)
		b.disabled = not GameState.can_buy(id)
		# A part the vault is already full of is refused for a different reason
		# than one you cannot afford, and a disabled button says neither.
		_explain(b, Loc.t("hideout.shop.full", [Components.name_for(id)])
			if GameState.component_count(id, GameState.stash) >= GameState.stash_cap()
			else Loc.t("hideout.shop.buy_hint", [Components.name_for(id), price]))
		b.pressed.connect(func() -> void:
			if GameState.buy_component(id):
				Audio.play("pickup")
				_say(Loc.t("hideout.shop.bought", [Components.name_for(id), price]))
			else:
				Audio.play("deny")
			rebuild())
		row.add_child(b)
		list.add_child(row)
	return v

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
		_say(Loc.t("hideout.stash.forged", [Components.name_for(made)]))
	rebuild()

## --- deploy -----------------------------------------------------------------
func _footer() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var slots := GameState.get_loadout(weapon_id)
	var filled := slots.filter(func(i: int) -> bool: return int(i) >= 0)
	h.add_child(_label(Loc.t("hideout.footer.filled", [filled.size(), slots.size()]), UiKit.DIM))
	h.add_child(_pad())
	# The standing warning, unless there is something more pressing to say: a
	# kit still lying in a raid is what this deployment is for, and it is the
	# last thing read before the button that starts one.
	if GameState.has_lost_kit():
		h.add_child(_label(Loc.t("hideout.footer.kit_waiting",
			[GameState.lost_kit_size()]), UiKit.WARN))
	else:
		h.add_child(_label(Loc.t("hideout.footer.warning"), UiKit.BAD))
	var b := _button(Loc.t("hideout.footer.deploy"), UiKit.GOOD)
	b.custom_minimum_size = Vector2(180, 40)
	b.disabled = filled.is_empty() or not GameState.owned_weapons.has(weapon_id)
	b.pressed.connect(func() -> void:
		deploy_requested.emit(weapon_id, filled))
	h.add_child(b)
	return h
