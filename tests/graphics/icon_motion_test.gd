extends Node
## The parts' icons move on the assembly screen, each through a film of its own
## (`Style.COMPONENT_MOTION`), and a setting stops them (`Video.icon_motion`).
##
## Every part has a film, cut into frames seven pixels square, the first being
## its icon at rest — so a board whose parts are kept still shows the icons it
## always did — and no frame the same as the one before it, or the part would
## sit still for a beat it was not given. The film goes round: every frame comes
## up in the order the strip draws them, held as long as it says, and then the
## first again. The screen asks the setting: on, a part is where its film has
## got to on the screen's clock; off, it is its icon at rest, whatever the clock
## says. And the setting is kept where the screen mode and the camera shake are,
## and is on where nobody has set it.
##
## No renderer needed: the films are pictures in a table, and which one the
## screen draws is a question it answers.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[MOTION] PASS ", what)
	else:
		fails += 1
		push_error("MOTION FAIL: " + what)

func _ready() -> void:
	_films()
	_round()
	_screen()
	_kept()
	print("[MOTION] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Every part has a film, and every film is pictures of the icon's own size.
func _films() -> void:
	var missing: Array = []
	var not_at_rest: Array = []
	var misshapen: Array = []
	var stuck: Array = []
	for id in Components.ids():
		if not Style.COMPONENT_MOTION.has(id):
			missing.append(id)
			continue
		var motion: Dictionary = Style.COMPONENT_MOTION[id]
		var frames := Style.component_frames(id)
		if frames.is_empty() or frames[0] != Style.component_icon(id):
			not_at_rest.append(id)
		for row in motion["strip"]:
			if (String(row).length() + 1) % 8 != 0 or String(row).length() != String(motion["strip"][0]).length():
				misshapen.append("%s's strip" % id)
				break
		var hold: Array = motion.get("hold", [])
		if not hold.is_empty() and hold.size() != frames.size():
			misshapen.append("%s's holds" % id)
		if frames.size() < 2:
			stuck.append("%s, which has one frame" % id)
		for i in frames.size():
			var rows: Array = frames[i]
			var ok := rows.size() == 7
			for r in rows:
				ok = ok and String(r).length() == 7 and String(r).replace("#", "").replace(".", "") == ""
			if not ok:
				misshapen.append("%s frame %d" % [id, i])
			if i > 0 and rows == frames[i - 1]:
				stuck.append("%s frame %d" % [id, i])
	check(missing.is_empty(), "every part has a film (%s)" % ", ".join(missing))
	check(not_at_rest.is_empty(), "and each starts on its icon at rest (%s)" % ", ".join(not_at_rest))
	check(misshapen.is_empty(), "every frame is seven pixels square, of # and . (%s)" % ", ".join(misshapen))
	check(stuck.is_empty(), "and none is the frame before it again (%s)" % ", ".join(stuck))
	var strays: Array = []
	for id in Style.COMPONENT_MOTION:
		if not Components.exists(String(id)):
			strays.append(id)
	check(strays.is_empty(), "no film is for a part the game does not have (%s)" % ", ".join(strays))

## A film goes round: tick by tick, each frame for as long as it is held, in
## the order its strip draws them, and back to the first.
func _round() -> void:
	var wrong: Array = []
	for id in Style.COMPONENT_MOTION:
		var motion: Dictionary = Style.COMPONENT_MOTION[id]
		var frames := Style.component_frames(String(id))
		var hold: Array = motion.get("hold", [])
		var want: Array = []
		for i in frames.size():
			for k in (int(hold[i]) if i < hold.size() else 1):
				want.append(frames[i])
		var fps := float(motion["fps"])
		for tick in want.size() + 1:
			if Style.component_icon_at(String(id), (float(tick) + 0.5) / fps) != want[tick % want.size()]:
				wrong.append("%s at tick %d" % [id, tick])
				break
	check(wrong.is_empty(), "every film goes round, each frame held as long as it says (%s)" % ", ".join(wrong))
	check(Style.component_icon_at("NO_SUCH_PART", 3.0) == Style.component_icon("NO_SUCH_PART"),
		"a part with no film stands on its icon")

## The screen asks the setting. Sampled every twentieth of a second, which is
## quicker than the quickest film's tick, for two seconds — longer than any
## film rests on its first frame.
func _screen() -> void:
	var was := Video.icon_motion
	var ed := SkillEditor.new()
	Video.icon_motion = true
	var follows := true
	var moved: Array = []
	for id in Components.ids():
		var off_rest := false
		for tick in 40:
			ed._flow_time = float(tick) * 0.05
			var drawn: Array = ed._icon(id)
			follows = follows and drawn == Style.component_icon_at(id, ed._flow_time)
			off_rest = off_rest or drawn != Style.component_icon(id)
		if off_rest:
			moved.append(id)
	check(follows, "with the parts let move, each is drawn where its film has got to on the screen's clock")
	check(moved.size() == Components.ids().size(),
		"and every part is off its icon at rest some time in its first two seconds (%d of %d)"
			% [moved.size(), Components.ids().size()])
	Video.icon_motion = false
	var still := true
	for id in Components.ids():
		for tick in 40:
			ed._flow_time = float(tick) * 0.05
			still = still and ed._icon(id) == Style.component_icon(id)
	check(still, "with them kept still, every part is its icon at rest, whatever the clock says")
	ed.free()
	Video.icon_motion = was

## Kept in Video's file, beside the screen mode and the camera shake, and on
## for a machine that has never said.
func _kept() -> void:
	var fresh: Node = (Video.get_script() as GDScript).new()
	check(bool(fresh.get("icon_motion")), "a machine that has never set it has the parts moving")
	fresh.free()
	var was := Video.icon_motion
	Video.set_icon_motion(not was)
	Video.icon_motion = was
	Video._load()
	check(Video.icon_motion == (not was), "the setting is written to %s and read back" % Video.PATH.get_file())
	Video.set_icon_motion(was)
