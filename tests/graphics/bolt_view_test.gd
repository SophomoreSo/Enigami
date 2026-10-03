extends Node
## A bolt's trail is one tail at any pace. The view samples where the bolt is
## once a frame and draws a bead at each; where two beads do not reach each
## other it draws the gap in, so a quick bolt trails a line instead of a string
## of beads, and a slow one — whose beads already touch — is drawn as it always
## was. A bolt at laser speed is drawn as a beam, from the muzzle to the bolt.
##
## What is checked is what the view decides to draw (`ProjectileView.streaks`),
## with the bolt stepped by hand so a frame is the same length on any machine.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[BOLT] PASS ", what)
	else:
		fails += 1
		push_error("BOLT FAIL: " + what)

## A bolt at `speed` times the standard pace — or at laser speed — fired to the
## right from `at` and flown `steps` frames of `dt` seconds, and its view.
func flown(speed: float, laser: bool, at: Vector2, steps: int, dt: float = 1.0 / 60.0, size: float = 1.0) -> ProjectileView:
	var p := Payload.new()
	p.form = "PROJECTILE"
	p.speed = speed
	p.size = size
	p.range_px = 100000.0
	if laser:
		p.stacks["SPEED"] = Components.limit_of("SPEED")
	var n := Projectile.new()
	n.setup(p, at, Vector2.RIGHT, 0, null, null)
	add_child(n)
	var view := Views.of(n) as ProjectileView
	if view == null:
		return null
	n.set_process(false)
	view.set_process(false)
	for i in steps:
		n._process(dt)
		view._process(dt)
	return view

func _ready() -> void:
	Arena.register(self)

	# The sword's bolt, at the sword's own pace and size: a few pixels a frame,
	# and every bead that can be seen inside the next. The two oldest are the
	# smallest and all but clear, and may stand a hair apart; what joins them
	# is under a pixel of a colour that is barely there.
	var slow := flown(0.64, false, Vector2(0, 0), 12, 1.0 / 60.0, 1.15)
	check(slow != null, "a bolt is given its view")
	if slow == null:
		get_tree().quit(1)
		return
	var seen := 0
	for s: Dictionary in slow.streaks():
		if (s["from"] as Vector2).distance_to(s["to"]) >= 1.0 or (s["color"] as Color).a > 0.06:
			seen += 1
	check(not slow.beam and seen == 0,
		"a slow bolt's beads touch, so nothing that shows is added to it: it is drawn as it always was")

	# The gun's: four times its own radius a frame.
	var quick := flown(2.56, false, Vector2(0, 1000), 12)
	var lines := quick.streaks()
	check(lines.size() == quick._trail.size() - 1 and lines.size() >= 3,
		"a quick bolt's beads stand apart, and every gap between them is drawn in (%d)" % lines.size())
	var between := true
	var widening := true
	var solid := true
	for i in lines.size():
		var s: Dictionary = lines[i]
		# Each line lies between its two beads: it starts and ends on their
		# edges, on neither bead.
		var a: Vector2 = quick._trail[i]
		var b: Vector2 = quick._trail[i + 1]
		between = between and is_equal_approx((s["from"] as Vector2).x, a.x + quick._bead_radius(i)) \
			and is_equal_approx((s["to"] as Vector2).x, b.x - quick._bead_radius(i + 1)) \
			and (s["to"] as Vector2).x > (s["from"] as Vector2).x
		solid = solid and is_equal_approx((s["color"] as Color).a, quick._bead_alpha(i + 1))
		if i > 0:
			widening = widening and float(s["width"]) >= float(lines[i - 1]["width"])
	check(between, "from the edge of one bead to the edge of the next, lying over neither")
	check(solid and widening, "as solid as the bead it runs up to, and no thinner towards the bolt")

	# The same slow bolt on a machine drawing fifteen frames a second covers
	# four times the ground between samples, and still reads as one tail.
	var slow_frames := flown(0.64, false, Vector2(0, 2000), 12, 1.0 / 15.0, 1.15)
	check(not slow_frames.streaks().is_empty(), "at a slow frame rate the slow bolt's gaps are drawn in too")

	# A laser: SPEED at its limit.
	var from := Vector2(0, 3000)
	var laser := flown(1.0, true, from, 3)
	var beam := laser.streaks()
	check(laser.beam and is_equal_approx(laser.bolt.velocity.length(), Projectile.LASER_SPEED),
		"a bolt with SPEED at its limit is a beam")
	check(beam.size() == 3 and (beam[0]["from"] as Vector2).is_equal_approx(from)
			and (beam[beam.size() - 1]["to"] as Vector2).is_equal_approx(laser.bolt.global_position),
		"drawn from the muzzle to the bolt (%d stretches)" % beam.size())
	var joined := true
	var brighter := true
	for i in range(1, beam.size()):
		joined = joined and (beam[i]["from"] as Vector2).is_equal_approx(beam[i - 1]["to"])
		brighter = brighter and (beam[i]["color"] as Color).a > (beam[i - 1]["color"] as Color).a \
			and float(beam[i]["width"]) > float(beam[i - 1]["width"])
	check(joined, "in one unbroken line")
	check(brighter, "brighter and wider at the bolt than back where it came from")
	check((beam[beam.size() - 1]["color"] as Color).a > quick._bead_alpha(quick._trail.size() - 1),
		"and more solid than any trail")

	print("[BOLT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
