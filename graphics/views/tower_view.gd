class_name TowerView
extends Node2D

## The dragon test's building, after Katana ZERO's night interiors: a city seen
## through tall windows, concrete storeys with a neon strip along the underside
## of each floor, lamps throwing warm cones, and stairs up through the wells.
##
## The building never changes, so it is painted once onto its own layer when
## the room has been built. Only the light moves: the neon buzzes, the sign
## stutters, and rain runs down the glass.

const SKY_TOP := Color(0.03, 0.02, 0.08)
const SKY_LOW := Color(0.22, 0.05, 0.22)
const MOON := Color(0.98, 0.87, 0.93)
const CITY_FAR := Color(0.1, 0.05, 0.17)
const CITY_NEAR := Color(0.055, 0.03, 0.1)
const LIT := [Color(1.0, 0.78, 0.42), Color(0.45, 0.9, 1.0), Color(1.0, 0.4, 0.7)]
const WALL := Color(0.07, 0.055, 0.115)
const WALL_SEAM := Color(0.095, 0.075, 0.15)
const FRAME := Color(0.14, 0.11, 0.22)
const SLAB := Color(0.14, 0.12, 0.21)
const SLAB_EDGE := Color(0.36, 0.3, 0.5)
const SLAB_UNDER := Color(0.05, 0.04, 0.09)
const SHELL := Color(0.04, 0.03, 0.075)
const SHELL_SEAM := Color(0.07, 0.055, 0.12)
const PINK := Color(1.0, 0.24, 0.62)
const CYAN := Color(0.22, 0.92, 1.0)
const LAMP := Color(1.0, 0.8, 0.52)
const STEEL := Color(0.24, 0.2, 0.34)
const EXIT := Color(0.35, 1.0, 0.55)

const C := Room.CELL

var tower: DragonTower
var _still: Still
## Floor rows: the ceiling, every storey's slab, and the ground.
var _floors: Array[int] = []
## Glass the rain runs down, and neon strips with the phase they buzz at.
var _panes: Array[Rect2] = []
var _strips: Array = []
var _rain: Array = []

## The half that never moves, painted once.
class Still extends Node2D:
	var view: TowerView
	func _draw() -> void:
		if view != null:
			view.paint(self)

func _ready() -> void:
	tower = get_parent() as DragonTower
	_still = Still.new()
	_still.view = self
	_still.z_index = -1
	# A view's own layer is set for it, but a child of one is not, and anything
	# left on the default layer is drawn a second time under the pixel picture.
	_still.visibility_layer = PixelCamera.WORLD_LAYER
	add_child(_still)
	# The live light goes over the building and under everyone standing in it.
	z_index = 1
	if tower != null:
		tower.built.connect(_on_built)

func _on_built() -> void:
	_find_floors()
	_still.queue_redraw()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1515
	for i in 70:
		_rain.append(Vector2(rng.randf() * Room.W * C, rng.randf() * Room.H * C))

func _process(delta: float) -> void:
	for i in _rain.size():
		var p: Vector2 = _rain[i] + Vector2(-60.0, 420.0) * delta
		if p.y > Room.H * C:
			p = Vector2(fposmod(p.x + 300.0, Room.W * C), 0.0)
		_rain[i] = p
	queue_redraw()

## A row is a floor when most of it is solid; the gaps in it are stairwells.
func _find_floors() -> void:
	_floors.clear()
	for y in Room.H - 1:
		var n := 0
		for x in range(1, Room.W - 1):
			if tower.is_solid(x, y):
				n += 1
		if n * 2 >= Room.W - 2:
			_floors.append(y)

## --- the still half ---------------------------------------------------------
func paint(c: CanvasItem) -> void:
	if tower == null or not is_instance_valid(tower) or _floors.is_empty():
		return
	_panes.clear()
	_strips.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 15
	_paint_sky(c, rng)
	for i in range(_floors.size() - 1):
		_paint_storey(c, rng, _floors[i], _floors[i + 1], i)
	_paint_wells(c)
	_paint_solid(c)
	_paint_door(c)

func _paint_sky(c: CanvasItem, rng: RandomNumberGenerator) -> void:
	var w := float(Room.W * C)
	var h := float(Room.H * C)
	for i in 44:
		var k := float(i) / 43.0
		c.draw_rect(Rect2(0.0, h * float(i) / 44.0, w, h / 44.0 + 1.0), SKY_TOP.lerp(SKY_LOW, k * k))
	var moon := Vector2(w * 0.78, 110.0)
	for i in 5:
		c.draw_circle(moon, 70.0 - float(i) * 8.0, Color(MOON.r, MOON.g, MOON.b, 0.04))
	c.draw_circle(moon, 40.0, MOON)
	c.draw_circle(moon + Vector2(12, -6), 34.0, Color(0.9, 0.78, 0.86))
	# Two ranks of towers, the far one taller and paler, lit window by window.
	for layer in 2:
		var x := -20.0
		var col: Color = CITY_FAR if layer == 0 else CITY_NEAR
		while x < w:
			var bw := rng.randf_range(60.0, 150.0)
			var bh := rng.randf_range(260.0, 620.0) if layer == 0 else rng.randf_range(140.0, 420.0)
			var top := h - bh
			c.draw_rect(Rect2(x, top, bw, bh), col)
			var wy := top + 12.0
			while wy < h - 8.0:
				var wx := x + 8.0
				while wx < x + bw - 8.0:
					if rng.randf() < (0.16 if layer == 0 else 0.24):
						var lit: Color = LIT[rng.randi() % LIT.size()]
						c.draw_rect(Rect2(wx, wy, 4.0, 6.0), Color(lit.r, lit.g, lit.b, 0.35 + 0.4 * float(layer)))
					wx += 10.0
				wy += 14.0
			if layer == 1 and rng.randf() < 0.3:
				var sign: Color = PINK if rng.randf() < 0.5 else CYAN
				c.draw_rect(Rect2(x + 10.0, top + 18.0, bw - 20.0, 12.0), Color(sign.r, sign.g, sign.b, 0.55))
			x += bw + rng.randf_range(4.0, 30.0)

## One storey: back wall with tall windows, a lamp every few cells, and the
## furniture of a floor that was busy an hour ago.
func _paint_storey(c: CanvasItem, rng: RandomNumberGenerator, ceiling: int, floor_row: int, index: int) -> void:
	var top := float(ceiling + 1) * C
	var bottom := float(floor_row) * C
	var w := float(Room.W * C)
	var high := bottom - top
	var neon: Color = PINK if index % 2 == 0 else CYAN

	# Wall, with the city through the windows. Windows are left unpainted.
	var pane_top := top + 18.0
	var pane_bottom := bottom - 34.0
	var x := float(C)
	var pane_w := float(C) * 3.0
	var pier := float(C) * 2.0
	c.draw_rect(Rect2(0.0, top, w, pane_top - top), WALL)
	c.draw_rect(Rect2(0.0, pane_bottom, w, bottom - pane_bottom), WALL)
	c.draw_rect(Rect2(0.0, pane_top, x + pier * 0.5, pane_bottom - pane_top), WALL)
	x += pier * 0.5
	while x + pane_w < w - C:
		var pane := Rect2(x, pane_top, pane_w, pane_bottom - pane_top)
		_panes.append(pane)
		c.draw_rect(Rect2(pane.position, Vector2(pane.size.x, 2.0)), Color(0.1, 0.06, 0.18, 0.6))
		c.draw_rect(pane.grow(2.0), FRAME, false, 4.0)
		c.draw_rect(Rect2(pane.position.x + pane.size.x * 0.5 - 1.0, pane.position.y, 2.0, pane.size.y), FRAME)
		c.draw_rect(Rect2(pane.end.x, pane_top, pier, pane_bottom - pane_top), WALL)
		for s in 3:
			c.draw_rect(Rect2(pane.end.x + 8.0 + float(s) * 16.0, pane_top, 2.0, pane_bottom - pane_top), WALL_SEAM)
		x = pane.end.x + pier
	c.draw_rect(Rect2(x, pane_top, w - x, pane_bottom - pane_top), WALL)
	# Skirting, and the lit strip along the ceiling of this storey.
	c.draw_rect(Rect2(0.0, bottom - 8.0, w, 8.0), WALL_SEAM)
	_strips.append({"rect": Rect2(C, top, w - 2.0 * C, 4.0), "color": neon, "phase": float(index) * 1.7})

	# Lamps, where there is ceiling to hang one from.
	var lx := 3
	while lx < Room.W - 3:
		if tower.is_solid(lx, ceiling) and tower.is_solid(lx + 1, ceiling):
			var at := Vector2(float(lx + 1) * C, top)
			c.draw_rect(Rect2(at + Vector2(-12, 4), Vector2(24, 6)), STEEL)
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-10, 10), at + Vector2(10, 10),
				at + Vector2(46, high), at + Vector2(-46, high)]), Color(LAMP.r, LAMP.g, LAMP.b, 0.06))
			c.draw_rect(Rect2(at + Vector2(-44, high - 6.0), Vector2(88, 6)), Color(LAMP.r, LAMP.g, LAMP.b, 0.1))
		lx += 7

	# Furniture along the floor, kept off posts, the door and the wells.
	var fx := 3
	while fx < Room.W - 4:
		var clear := true
		for dx in 3:
			if not tower.is_solid(fx + dx, floor_row) or tower.mark_at(fx + dx, floor_row - 1) in ["G", "P"]:
				clear = false
		if clear and rng.randf() < 0.55:
			_paint_prop(c, rng, Vector2(float(fx) * C, bottom), rng.randi() % 5)
			fx += 5
		else:
			fx += 2

func _paint_prop(c: CanvasItem, rng: RandomNumberGenerator, at: Vector2, kind: int) -> void:
	match kind:
		0:  # a desk with a monitor still on
			c.draw_rect(Rect2(at + Vector2(0, -26), Vector2(58, 6)), STEEL)
			c.draw_rect(Rect2(at + Vector2(4, -20), Vector2(4, 20)), STEEL)
			c.draw_rect(Rect2(at + Vector2(50, -20), Vector2(4, 20)), STEEL)
			c.draw_rect(Rect2(at + Vector2(18, -46), Vector2(24, 18)), Color(0.08, 0.07, 0.12))
			c.draw_rect(Rect2(at + Vector2(20, -44), Vector2(20, 14)), Color(CYAN.r, CYAN.g, CYAN.b, 0.5))
		1:  # filing cabinet
			c.draw_rect(Rect2(at + Vector2(6, -44), Vector2(26, 44)), Color(0.18, 0.16, 0.26))
			for i in 3:
				c.draw_rect(Rect2(at + Vector2(10, -40 + i * 14), Vector2(18, 2)), SLAB_EDGE)
		2:  # a plant in a pot
			c.draw_rect(Rect2(at + Vector2(10, -16), Vector2(16, 16)), Color(0.3, 0.16, 0.2))
			for i in 5:
				var a := -PI * 0.5 + rng.randf_range(-0.9, 0.9)
				c.draw_line(at + Vector2(18, -16), at + Vector2(18, -16) + Vector2(cos(a), sin(a)) * rng.randf_range(12, 26),
					Color(0.2, 0.45, 0.35), 3.0)
		3:  # vending machine, lit from inside
			c.draw_rect(Rect2(at + Vector2(4, -60), Vector2(34, 60)), Color(0.12, 0.1, 0.2))
			c.draw_rect(Rect2(at + Vector2(8, -56), Vector2(20, 40)), Color(PINK.r, PINK.g, PINK.b, 0.55))
			c.draw_rect(Rect2(at + Vector2(30, -50), Vector2(4, 10)), Color(CYAN.r, CYAN.g, CYAN.b, 0.8))
		_:  # crates
			c.draw_rect(Rect2(at + Vector2(2, -24), Vector2(28, 24)), Color(0.26, 0.18, 0.2))
			c.draw_rect(Rect2(at + Vector2(2, -24), Vector2(28, 24)), Color(0.12, 0.08, 0.1), false, 2.0)
			c.draw_rect(Rect2(at + Vector2(30, -18), Vector2(20, 18)), Color(0.22, 0.16, 0.2))

## Each gap in a floor, dressed as what it is: a hole with a striped lip and a
## rail either side, and a caged ladder up to it from the storey below.
##
## Only the floors have collision, so the hole is genuinely open and the ladder
## is genuinely scenery — the way up is the jump. Drawing a staircase across the
## gap would have promised a floor that is not there.
func _paint_wells(c: CanvasItem) -> void:
	for i in range(1, _floors.size() - 1):
		var row := _floors[i]
		var x := 1
		while x < Room.W - 1:
			if tower.is_solid(x, row):
				x += 1
				continue
			var start := x
			while x < Room.W - 1 and not tower.is_solid(x, row):
				x += 1
			_paint_well(c, Rect2(float(start) * C, float(row) * C, float(x - start) * C, float(C)),
				float(_floors[i + 1]) * C)

func _paint_well(c: CanvasItem, well: Rect2, below: float) -> void:
	# Hazard stripes along the two lips, so the hole reads before you fall in it.
	for side in [well.position.x - 12.0, well.end.x - 12.0]:
		for s in 3:
			c.draw_rect(Rect2(side, well.position.y + float(s) * 8.0, 24.0, 4.0),
				Color(1.0, 0.72, 0.2) if s % 2 == 0 else Color(0.1, 0.08, 0.12))
	# A rail on the upper floor at each side of the drop.
	for side in [well.position.x, well.end.x]:
		var dir: float = -1.0 if side == well.position.x else 1.0
		c.draw_rect(Rect2(side + dir * 4.0 - 2.0, well.position.y - 40.0, 4.0, 40.0), STEEL)
		c.draw_rect(Rect2(side + dir * 4.0 - 14.0, well.position.y - 40.0, 28.0, 4.0), SLAB_EDGE)
	# The ladder, hung under one lip and running down to the floor below.
	var lx := well.position.x + 14.0
	c.draw_rect(Rect2(lx - 4.0, well.position.y, 4.0, below - well.position.y), STEEL)
	c.draw_rect(Rect2(lx + 16.0, well.position.y, 4.0, below - well.position.y), STEEL)
	var rung := well.position.y + 10.0
	while rung < below - 6.0:
		c.draw_rect(Rect2(lx - 4.0, rung, 24.0, 3.0), SLAB_EDGE)
		rung += 14.0

func _paint_solid(c: CanvasItem) -> void:
	for y in Room.H:
		for x in Room.W:
			if not tower.is_solid(x, y):
				continue
			var r := Rect2(float(x) * C, float(y) * C, C, C)
			var shell := x == 0 or x == Room.W - 1 or y == 0 or y >= Room.H - 2
			c.draw_rect(r, SHELL if shell else SLAB)
			if shell:
				if (x + y) % 2 == 0:
					c.draw_rect(Rect2(r.position + Vector2(0, 14), Vector2(C, 2)), SHELL_SEAM)
			else:
				c.draw_rect(Rect2(r.position + Vector2(0, 20), Vector2(C, 2)), SLAB_UNDER)
			if not tower.is_solid(x, y - 1):
				c.draw_rect(Rect2(r.position, Vector2(C, 4)), SLAB_EDGE)
			if not tower.is_solid(x, y + 1) and y < Room.H - 2:
				c.draw_rect(Rect2(r.position + Vector2(0, C - 4), Vector2(C, 4)), SLAB_UNDER)

func _paint_door(c: CanvasItem) -> void:
	for d in tower.cells_marked("P"):
		var foot := float(d.y + 1) * C
		var at := Vector2((float(d.x) + 0.5) * C, foot)
		c.draw_rect(Rect2(at + Vector2(-22, -76), Vector2(44, 76)), Color(0.02, 0.015, 0.04))
		c.draw_rect(Rect2(at + Vector2(-22, -76), Vector2(44, 76)), FRAME, false, 4.0)
		c.draw_rect(Rect2(at + Vector2(-18, -96), Vector2(36, 14)), Color(0.04, 0.1, 0.06))
		PixelCamera.draw_text(c, at + Vector2(0, -85), "EXIT", EXIT)

## --- the live half ----------------------------------------------------------
func _draw() -> void:
	if tower == null or _floors.is_empty():
		return
	var t := float(Time.get_ticks_msec()) / 1000.0
	for s in _strips:
		var r: Rect2 = s["rect"]
		var col: Color = s["color"]
		var buzz := 0.75 + 0.25 * sin(t * 9.0 + float(s["phase"]))
		if fmod(t * 0.37 + float(s["phase"]), 7.0) < 0.12:
			buzz *= 0.3
		draw_rect(r, Color(col.r, col.g, col.b, buzz))
		draw_rect(Rect2(r.position + Vector2(0, 4), Vector2(r.size.x, 10)), Color(col.r, col.g, col.b, 0.12 * buzz))
	for p in _rain:
		for pane in _panes:
			if pane.has_point(p):
				draw_line(p, p + Vector2(-3, 14), Color(0.7, 0.75, 1.0, 0.35), 2.0)
				break
