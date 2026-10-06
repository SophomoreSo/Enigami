class_name GroveTiles
extends MapTiles

## The hideout's Moonlit Grove (`HideoutGrove`) made into a tileset, in its
## colours and after its pictures: a map drawn in it is what is left of a
## temple in a wood at night.
##
## Its ground is the temple's stone, coursed and green along every top; the
## wood's earth, with stones and roots in it; the bark of a trunk too great to
## go round, its roots flaring out where it meets the floor; planks, lashed
## where they end; and leaves too thick to go through, in clumps where they
## meet the air. Behind it can stand the ruin's wall, a column — whole under
## its capital, or broken off — a lintel with what was carved along it, a tree,
## the undergrowth, and the rail the grove's lanterns hang from. Past the map's
## edge the canopy closes overhead, the earth goes on underfoot, and either side
## stand trunks, or whatever ground the map's own edge is made of. And out
## beyond all of it is the grove's night: the sky, the moon low and big, the
## far wood with a fall of water in it, the mist, and the nearer trunks — each
## going along slower than the map as the camera goes, the further off the
## slower.
##
## Every cell is drawn as it meets its neighbours and the same every time:
## what is different from one to the next is worked out from where it is
## (`odd`), so a map looks the same every time it is drawn.

# Pixel art halves whole numbers on purpose, all the way down.
@warning_ignore_start("integer_division")

## The kinds of ground, in the order offered, and what stands behind.
const GROUND_MARKS := ["#", "%", "|", "=", "*"]
const BACK := {"#": "wall", "|": "column", "-": "lintel", "!": "tree", "~": "brush", "=": "rail"}
const RAIL := "="
const LINTEL := "-"

const SKY := HideoutGrove.SKY
const MOON_FACE := HideoutGrove.MOON_FACE
const MOON_SHADE := HideoutGrove.MOON_SHADE
const MOONLIGHT := HideoutGrove.MOONLIGHT
const FAR := HideoutGrove.FAR
const MID := HideoutGrove.MID
const DARK := HideoutGrove.DARK
const BARK := HideoutGrove.BARK
const WOOD_LIT := HideoutGrove.WOOD_LIT
const ROPE := HideoutGrove.ROPE
const SOIL := HideoutGrove.SOIL
const WATER := HideoutGrove.WATER
const INSIDE := GroveGroundView.INSIDE
const INSIDE_JOINT := GroveGroundView.INSIDE_JOINT

## Which sides of a cell meet the air, as bits.
const UP := 1
const DOWN := 2
const LEFT := 4
const RIGHT := 8

func id() -> String:
	return "grove"

func title() -> String:
	return Loc.t("hideout.theme.look.grove")

func ground_marks() -> PackedStringArray:
	return PackedStringArray(GROUND_MARKS)

func back_marks() -> PackedStringArray:
	return PackedStringArray(BACK.keys())

func ground_name(mark: String) -> String:
	return Loc.t("hud.maker.tiles.grove.%s" % String(MadeRoom.GROUND.get(mark, "stone")))

func back_name(mark: String) -> String:
	return Loc.t("hud.maker.tiles.grove.%s" % String(BACK.get(mark, "wall")))

func open_colour() -> Color:
	return SKY[3]

## The night on the creator's table, overhead down to the glow behind the
## trees, from the map's top to its foot.
func paint_open(c: CanvasItem, rect: Rect2) -> void:
	var band := rect.size.y / SKY.size()
	for i in SKY.size():
		c.draw_rect(Rect2(rect.position.x, rect.position.y + band * i, rect.size.x, band + 1.0), SKY[i])

func outside_colour() -> Color:
	return Color(0.03, 0.04, 0.045)

## The grove's night as the hideout has it, a little dimmed and blued: dark
## enough that a lantern or a fire shows what it lights, and no darker.
func ambient() -> Color:
	return Color(0.84, 0.88, 0.96)

## A cord hangs under the rail, and under a lintel.
func hangs_from(mark: String) -> int:
	match mark:
		RAIL:
			return 3
		LINTEL:
			return 15
	return -1

## --- the ground ---------------------------------------------------------------

func paint_ground(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	_kind(c, cells, x, y, String(MadeRoom.GROUND.get(cells.ground(x, y), "stone")))

## Past the map's edge: the canopy overhead, the earth underfoot, and either
## side whatever the map's own edge is made of in that row — or a great trunk,
## where its edge is open.
func paint_beyond(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	var kind := "bark"
	if y < 0:
		kind = "leaves"
	elif y >= cells.rows:
		kind = "earth"
	else:
		var edge := cells.ground(clampi(x, 0, cells.cols - 1), y)
		if MadeRoom.is_ground(edge):
			kind = String(MadeRoom.GROUND[edge])
	_kind(c, cells, x, y, kind)

func _kind(c: CanvasItem, cells: MapCells, x: int, y: int, kind: String) -> void:
	var open := 0
	if not cells.solid(x, y - 1):
		open |= UP
	if not cells.solid(x, y + 1):
		open |= DOWN
	if not cells.solid(x - 1, y):
		open |= LEFT
	if not cells.solid(x + 1, y):
		open |= RIGHT
	match kind:
		"earth":
			_earth(c, x, y, open)
		"bark":
			_bark(c, x, y, open, _roots(cells, x, y, true))
		"wood":
			_wood(c, x, y, open, cells.ground(x - 1, y) == "=", cells.ground(x + 1, y) == "=")
		"leaves":
			_leaves(c, x, y, open)
		_:
			_stone(c, x, y, open)

## Which sides of a trunk in cell (x, y) its roots flare out on: where it
## stands on ground with the floor beside it open, as bits.
static func _roots(cells: MapCells, x: int, y: int, solid_trunk: bool) -> int:
	if not cells.solid(x, y + 1):
		return 0
	var out := 0
	for side in [-1, 1]:
		var beside := cells.solid(x + side, y) if solid_trunk else cells.back_at(x + side, y) == "!"
		if not beside and not cells.solid(x + side, y) and cells.solid(x + side, y + 1):
			out |= LEFT if side < 0 else RIGHT
	return out

## The temple's stone: blocks in courses, two to a cell, each course set half a
## block along from the one under it, lit along their tops; moss in the
## joints, green along every top that meets the air, and roots and vines
## hanging from the undersides.
func _stone(c: CanvasItem, x: int, y: int, open: int) -> void:
	var px := x * C
	var py := y * C
	box(c, px, py, C, C, STONE_SHADE)
	for k in 2:
		var cy := py + k * 8
		box(c, px, cy, C, 1, STONE.darkened(0.18))
		box(c, px, cy + 7, C, 1, STONE_SHADE.darkened(0.35))
		var joint := px + (8 if posmod(y * 2 + k + x, 2) == 0 else 0)
		box(c, joint, cy + 1, 1, 6, STONE_SHADE.darkened(0.35))
		box(c, joint + 1, cy + 1, 1, 6, STONE.darkened(0.3))
		if odd(x, y, 3 + k) % 5 == 0:
			box(c, px + 2 + odd(x, y, 5 + k) % 10, cy + 3, 3, 1, STONE_SHADE.darkened(0.25))
		if odd(x, y, 7 + k) % 7 == 0:
			box(c, px + odd(x, y, 9 + k) % 12, cy + 6, 4, 1, MOSS.darkened(0.35))
	if open & LEFT:
		box(c, px, py, 1, C, STONE.darkened(0.06))
	if open & RIGHT:
		box(c, px + C - 1, py, 1, C, STONE_SHADE.darkened(0.45))
	if open & DOWN:
		box(c, px, py + C - 1, C, 1, STONE_SHADE.darkened(0.5))
		_hanging(c, x, y, px, py + C)
	if open & UP:
		_moss(c, x, y, px, py)

## Moss along a top that meets the air: a band of it, lit here and there, with
## tufts standing up off it and a drip of it down the face.
func _moss(c: CanvasItem, x: int, y: int, px: int, py: int) -> void:
	box(c, px, py, C, 2, MOSS)
	box(c, px, py + 2, C, 1, MOSS.darkened(0.45))
	box(c, px + odd(x, y, 21) % 12, py, 3, 1, MOSS_LIT)
	for k in 2:
		var tall := 1 + odd(x, y, 24 + k) % 2
		box(c, px + odd(x, y, 22 + k) % 15, py - tall, 1, tall, MOSS_LIT if k == 0 else MOSS)
	if odd(x, y, 26) % 3 == 0:
		box(c, px + odd(x, y, 27) % 14, py + 3, 1, 2 + odd(x, y, 28) % 3, MOSS.darkened(0.2))

## What hangs from an underside meeting the air, here and there: a root, or a
## vine with a leaf at its end.
func _hanging(c: CanvasItem, x: int, y: int, px: int, under: int) -> void:
	if odd(x, y, 11) % 3 != 0:
		return
	var vx := px + 2 + odd(x, y, 12) % 12
	var long := 3 + odd(x, y, 13) % 7
	box(c, vx, under, 1, long, LEAF.lightened(0.06))
	box(c, vx - 1, under + long - 1, 2, 1, MOSS)

## The wood's earth: dark, specked, with a stone or a root through it here and
## there, grass and moss along a top that meets the air, and roots hanging out
## of an underside.
func _earth(c: CanvasItem, x: int, y: int, open: int) -> void:
	var px := x * C
	var py := y * C
	box(c, px, py, C, C, SOIL)
	for k in 3:
		box(c, px + odd(x, y, 31 + k) % 15, py + odd(x, y, 34 + k) % 15, 1, 1, SOIL.lightened(0.10))
	box(c, px + odd(x, y, 37) % 14, py + odd(x, y, 38) % 14, 2, 1, SOIL.darkened(0.3))
	if odd(x, y, 39) % 4 == 0:
		var sx := px + 1 + odd(x, y, 40) % 9
		var sy := py + 4 + odd(x, y, 41) % 8
		var w := 4 + odd(x, y, 42) % 4
		box(c, sx, sy, w, 3, STONE_SHADE.darkened(0.3))
		box(c, sx, sy, w, 1, STONE_SHADE)
	if odd(x, y, 43) % 5 == 0:
		HideoutScenery.line(c, px, py + 4 + odd(x, y, 44) % 10, px + C - 1, py + 4 + odd(x, y, 45) % 10,
			BARK.lightened(0.05))
	if open & LEFT:
		box(c, px, py, 1, C, SOIL.darkened(0.4))
		box(c, px - 1, py + 3 + odd(x, y, 46) % 10, 1, 2, SOIL)
	if open & RIGHT:
		box(c, px + C - 1, py, 1, C, SOIL.darkened(0.4))
		box(c, px + C, py + 3 + odd(x, y, 47) % 10, 1, 2, SOIL)
	if open & DOWN:
		box(c, px, py + C - 1, C, 1, SOIL.darkened(0.45))
		if odd(x, y, 48) % 2 == 0:
			var rx := px + 2 + odd(x, y, 49) % 12
			HideoutScenery.line(c, rx, py + C, rx + odd(x, y, 50) % 3 - 1, py + C + 2 + odd(x, y, 51) % 5,
				BARK.lightened(0.05))
	if open & UP:
		box(c, px, py, C, 2, MOSS.darkened(0.12))
		box(c, px, py + 2, C, 1, MOSS.darkened(0.5))
		box(c, px + odd(x, y, 52) % 12, py, 3, 1, MOSS_LIT.darkened(0.1))
		for k in 3:
			var tall := 1 + odd(x, y, 53 + k) % 3
			box(c, px + odd(x, y, 56 + k) % 15, py - tall, 1, tall, MOSS_LIT if k == 1 else MOSS)

## A trunk too great to go round: bark, furrowed down its length — the same
## furrows in every cell of a column, so a trunk runs whole — with a knot in it
## now and then, the moon down the side of it that meets the air on the left,
## shelf fungus glowing on a side, ivy, and its roots flaring out over the
## floor beside it (`roots`, as bits).
func _bark(c: CanvasItem, x: int, y: int, open: int, roots: int) -> void:
	var px := x * C
	var py := y * C
	box(c, px, py, C, C, BARK)
	for k in 3:
		var fx := px + 1 + odd(x, 0, 61 + k) % 13
		var gap := odd(x, y, 64 + k) % 5
		box(c, fx, py + gap, 1, C - gap, BARK.darkened(0.5))
		box(c, fx + 1, py + gap + 2, 1, C - gap - 2, BARK.lightened(0.11))
	if odd(x, y, 67) % 23 == 0:
		var kx := px + 4 + odd(x, y, 66) % 6
		box(c, kx - 1, py + 6, 6, 5, BARK.lightened(0.09))
		box(c, kx, py + 7, 4, 3, BARK.darkened(0.5))
		box(c, kx + 1, py + 8, 2, 1, BARK.darkened(0.7))
	if odd(x, y, 68) % 11 == 0:
		# A strand of ivy, a leaf either side of it by turns.
		var ix := px + 3 + odd(x, y, 69) % 10
		for k in 4:
			box(c, ix + k % 2, py + k * 4, 1, 4, LEAF.lightened(0.04))
			box(c, ix - 1 if k % 2 == 0 else ix + 1, py + k * 4 + 1, 2, 1, MOSS if k % 3 == 0 else MOSS.darkened(0.25))
	if open & LEFT:
		box(c, px, py + odd(x, y, 72) % 4, 1, 5, BARK.lerp(MOONLIGHT, 0.18))
		box(c, px, py + 8 + odd(x, y, 73) % 4, 1, 5, BARK.lerp(MOONLIGHT, 0.18))
		if odd(x, y, 74) % 11 == 0:
			_shelf(c, px - 3, py + 5 + odd(x, y, 75) % 6)
	if open & RIGHT:
		box(c, px + C - 1, py, 1, C, BARK.darkened(0.35))
		if odd(x, y, 76) % 11 == 0:
			_shelf(c, px + C - 2, py + 5 + odd(x, y, 77) % 6)
	if open & DOWN:
		box(c, px, py + C - 1, C, 1, BARK.darkened(0.45))
	if open & UP:
		_moss(c, x, y, px, py)
	for k in 6:
		var w := 6 - k
		if roots & LEFT:
			box(c, px - w, py + C - 1 - k, w, 1, BARK)
		if roots & RIGHT:
			box(c, px + C, py + C - 1 - k, w, 1, BARK)

## Fungus on bark that glows in the dark.
func _shelf(c: CanvasItem, x: int, y: int) -> void:
	box(c, x, y, 5, 2, SHROOM.darkened(0.25))
	box(c, x + 1, y + 2, 3, 1, SHROOM.darkened(0.5))

## Planks, three boards to a cell, lit along their tops, ended here and there
## with the grain in them; lashed where they end at the air.
func _wood(c: CanvasItem, x: int, y: int, open: int, wood_left: bool, wood_right: bool) -> void:
	var px := x * C
	var py := y * C
	box(c, px, py, C, C, WOOD)
	box(c, px, py, C, 1, WOOD_DARK)
	for b in 3:
		var by := py + 1 + b * 5
		box(c, px, by, C, 1, WOOD_LIT.darkened(0.12))
		box(c, px, by + 4, C, 1, WOOD_DARK)
		if odd(x, y, 81 + b) % 2 == 0:
			box(c, px + odd(x, y, 84 + b) % C, by + 1, 1, 3, WOOD_DARK)
		box(c, px + odd(x, y, 87 + b) % 12, by + 2, 3 + odd(x, y, 90 + b) % 3, 1, WOOD.darkened(0.2))
	if open & UP:
		box(c, px, py, C, 1, WOOD_LIT)
		if odd(x, y, 93) % 3 == 0:
			box(c, px + odd(x, y, 94) % 12, py - 1, 3, 1, MOSS)
	if open & DOWN:
		box(c, px, py + C - 1, C, 1, WOOD_DARK.darkened(0.4))
	if open & LEFT:
		box(c, px, py, 1, C, WOOD_DARK)
		if not wood_left:
			_lashing(c, px + 1, py)
	if open & RIGHT:
		box(c, px + C - 1, py, 1, C, WOOD_DARK.darkened(0.3))
		if not wood_right:
			_lashing(c, px + C - 4, py)

## Rope wound round the end of something, three pixels across.
func _lashing(c: CanvasItem, x: int, py: int) -> void:
	box(c, x, py + 1, 3, C - 2, ROPE)
	for k in [4, 8, 12]:
		box(c, x, py + k, 3, 1, ROPE.darkened(0.3))

## Leaves too thick to go through: dark, with leaves picked out in it, and
## where they meet the air not a wall but clumps, bulging out of it, with a
## vine trailing from an underside now and then.
func _leaves(c: CanvasItem, x: int, y: int, open: int) -> void:
	var px := x * C
	var py := y * C
	box(c, px, py, C, C, DARK)
	for k in 5:
		box(c, px + odd(x, y, 101 + k) % 14, py + odd(x, y, 106 + k) % 15, 2, 1, LEAF)
	box(c, px + odd(x, y, 111) % 13, py + odd(x, y, 112) % 13, 3, 2, LEAF.lightened(0.05))
	if odd(x, y, 113) % 3 == 0:
		box(c, px + odd(x, y, 114) % 14, py + odd(x, y, 115) % 14, 2, 1, MOSS.darkened(0.15))
	if open & DOWN:
		for k in 3:
			HideoutScenery.disc(c, px + 3 + k * 5, py + C - 2, 2 + odd(x, y, 116 + k) % 2, DARK)
		box(c, px + odd(x, y, 119) % 14, py + C, 2, 1, LEAF)
		if odd(x, y, 120) % 3 == 0:
			var vx := px + 2 + odd(x, y, 121) % 12
			var long := 4 + odd(x, y, 122) % 12
			for k in range(0, long, 3):
				box(c, vx + (k / 6) % 2, py + C + k, 1, mini(3, long - k), LEAF.lightened(0.04))
				if (k / 3) % 3 == 0:
					box(c, vx + (k / 6) % 2 - 1, py + C + k + 1, 2, 1, MOSS.darkened(0.15))
	if open & UP:
		for k in 3:
			HideoutScenery.disc(c, px + 3 + k * 5, py + 1, 2 + odd(x, y, 123 + k) % 2, DARK)
		box(c, px + odd(x, y, 126) % 12, py - 1, 3, 1, LEAF.lightened(0.1))
	if open & LEFT:
		HideoutScenery.disc(c, px + 1, py + 4 + odd(x, y, 127) % 8, 3, DARK)
	if open & RIGHT:
		HideoutScenery.disc(c, px + C - 2, py + 4 + odd(x, y, 128) % 8, 3, DARK)

## --- what stands behind -----------------------------------------------------------

func paint_back(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	match cells.back_at(x, y):
		"#":
			_wall(c, cells, x, y)
		"|":
			_column(c, cells, x, y)
		"-":
			_lintel(c, cells, x, y)
		"!":
			var open := 0
			if cells.back_at(x, y - 1) != "!" and not cells.solid(x, y - 1):
				open |= UP
			if cells.back_at(x - 1, y) != "!":
				open |= LEFT
			if cells.back_at(x + 1, y) != "!":
				open |= RIGHT
			_bark(c, x, y, open, _roots(cells, x, y, false))
		"~":
			_brush(c, cells, x, y)
		"=":
			_rail(c, cells, x, y)

## The ruin's wall: dark blocks, coursed, lighter at their joints, with moss
## and cracks in it — and where it ends at the open, blocks gone from its top.
func _wall(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	var px := x * C
	var py := y * C
	var top := cells.back_at(x, y - 1) != "#" and not cells.solid(x, y - 1)
	for k in 4:
		var bx := px + (k % 2) * 8
		var by := py + (k / 2) * 8
		if top and k < 2 and odd(x, y, 201 + k) % 3 == 0:
			continue
		box(c, bx, by, 8, 8, INSIDE)
		box(c, bx, by, 8, 1, INSIDE_JOINT)
		box(c, bx + (0 if (y * 2 + k / 2) % 2 == 0 else 4), by + 1, 1, 7, INSIDE_JOINT)
	if odd(x, y, 203) % 6 == 0:
		box(c, px + odd(x, y, 204) % 10, py + 2 + odd(x, y, 205) % 10, 4, 2, MOSS.darkened(0.55))
	if odd(x, y, 206) % 9 == 0:
		HideoutScenery.line(c, px + 3, py + 2, px + 6, py + 12, INSIDE.darkened(0.45))
	if cells.back_at(x - 1, y) != "#":
		box(c, px, py, 1, C, INSIDE.darkened(0.35))
	if cells.back_at(x + 1, y) != "#":
		box(c, px + C - 1, py, 1, C, INSIDE.darkened(0.35))

## A column of the ruin: fluted, in drums, with moss where the wet gets and ivy
## where it can climb. Its foot stands where the column stops going down; its
## top is its capital where it carries something — ground, or anything else
## behind — and broken off where it carries nothing, as the hideout's first
## column is.
func _column(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	var px := x * C
	var py := y * C
	var sx := px + 1
	box(c, sx, py, 14, C, STONE_SHADE)
	box(c, sx, py, 2, C, STONE)
	box(c, sx + 3, py, 2, C, STONE.darkened(0.14))
	box(c, sx + 7, py, 2, C, STONE_SHADE.lightened(0.10))
	box(c, sx + 12, py, 2, C, STONE_SHADE.darkened(0.3))
	if y % 2 == 0:
		box(c, sx, py + C - 1, 14, 1, STONE_SHADE.darkened(0.4))
	if odd(x, y, 211) % 3 == 0:
		box(c, sx + odd(x, y, 212) % 10, py + odd(x, y, 213) % 14, 2 + odd(x, y, 214) % 3, 1, MOSS.darkened(0.2))
	if odd(x, y, 215) % 3 == 0:
		for k in 3:
			box(c, sx + 11 + k % 2, py + k * 5, 1, 5, LEAF)
			box(c, sx + 10 + k % 3, py + k * 5 + 1, 2, 2, MOSS if k % 3 == 0 else LEAF.lightened(0.1))
	if cells.back_at(x, y - 1) != "|":
		var carries := cells.solid(x, y - 1) or cells.back_at(x, y - 1) != MadeRoom.OPEN
		if not carries:
			box(c, sx, py - 5, 4, 5, STONE_SHADE)
			box(c, sx, py - 5, 2, 5, STONE)
			box(c, sx + 6, py - 2, 3, 2, STONE_SHADE)
			box(c, sx + 10, py - 7, 3, 7, STONE_SHADE.darkened(0.2))
			box(c, sx, py - 6, 3, 1, MOSS)
		else:
			box(c, px - 2, py, 20, 4, STONE)
			box(c, px - 2, py, 20, 1, STONE.lightened(0.12))
			box(c, px - 1, py + 4, 18, 2, STONE_SHADE)
			box(c, px - 2, py - 1, 6, 1, MOSS)
			box(c, px + 9, py - 1, 4, 1, MOSS.darkened(0.2))
	if cells.back_at(x, y + 1) != "|":
		box(c, px, py + C - 9, 16, 3, STONE_SHADE)
		box(c, px - 1, py + C - 6, 18, 6, STONE.darkened(0.12))
		box(c, px - 1, py + C - 6, 18, 1, STONE.lightened(0.05))
		box(c, px - 1, py + C - 7, 7, 2, MOSS)
		box(c, px + 11, py + C - 7, 5, 1, MOSS.darkened(0.2))

## A lintel: a beam of the stone, with what was carved along it running on
## from one cell to the next, moss along its top and vines down from it.
func _lintel(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	var px := x * C
	var py := y * C
	box(c, px, py + 1, C, 14, STONE_SHADE)
	box(c, px, py + 1, C, 2, STONE)
	box(c, px, py + 13, C, 2, STONE_SHADE.darkened(0.35))
	for k in range(px, px + C - 4):
		if posmod(k, 9) == 0:
			box(c, k, py + 7, 5, 1, STONE_SHADE.darkened(0.3))
			box(c, k + 2, py + 5, 1, 5, STONE_SHADE.darkened(0.3))
	for k in range(px, px + C - 3, 4):
		if odd(k, y, 221) % 3 != 0:
			box(c, k, py - odd(k, y, 222) % 2, 3 + odd(k, y, 223) % 2, 2,
				MOSS if odd(k, y, 224) % 3 > 0 else MOSS_LIT.darkened(0.2))
	if odd(x, y, 225) % 3 == 0:
		var vx := px + 2 + odd(x, y, 226) % 12
		var long := 6 + odd(x, y, 227) % 14
		for k in range(0, long, 3):
			box(c, vx + (k / 3) % 2, py + 15 + k, 1, 3, LEAF.lightened(0.04))
			if (k / 3) % 2 == 0:
				box(c, vx - 1, py + 16 + k, 2, 1, MOSS)
	if cells.back_at(x - 1, y) != LINTEL:
		box(c, px, py + 1, 1, 14, STONE.darkened(0.1))
	if cells.back_at(x + 1, y) != LINTEL:
		box(c, px + C - 1, py + 1, 1, 14, STONE_SHADE.darkened(0.45))

## The undergrowth: dark, its top in clumps where it meets the air, with a
## leaf of it catching the light and a frond standing up out of it now and
## then.
func _brush(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	var px := x * C
	var py := y * C
	if cells.back_at(x, y - 1) == "~":
		box(c, px, py, C, C, DARK)
	else:
		for k in 3:
			HideoutScenery.disc(c, px + 2 + k * 6 + odd(x, y, 231 + k) % 3, py + 6 + odd(x, y, 234 + k) % 3,
				4 + odd(x, y, 237 + k) % 2, DARK)
		box(c, px, py + 7, C, C - 7, DARK)
		if odd(x, y, 240) % 3 == 0:
			HideoutScenery.line(c, px + 8, py + 9, px + 5 + odd(x, y, 241) % 7, py, FROND)
			box(c, px + 4 + odd(x, y, 241) % 7, py, 2, 1, MOSS)
	for k in 2:
		box(c, px + odd(x, y, 242 + k) % 14, py + 4 + odd(x, y, 244 + k) % 10, 2, 1, LEAF)

## The rail: a pole along the top of its cell, lashed where it ends, with what
## has started to grow along it. A cord hangs under it (`hangs_from`).
func _rail(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	var px := x * C
	var py := y * C
	box(c, px, py, C, 3, WOOD)
	box(c, px, py, C, 1, WOOD_LIT)
	if odd(x, y, 251) % 3 == 0:
		box(c, px + odd(x, y, 252) % 12, py + 1, 3, 1, WOOD_DARK)
	if odd(x, y, 253) % 4 == 0:
		box(c, px + odd(x, y, 254) % 13, py - 2, 3, 2, MOSS if odd(x, y, 255) % 2 == 0 else LEAF.lightened(0.1))
	for side in [-1, 1]:
		if cells.back_at(x + side, y) != RAIL:
			var tie := px if side < 0 else px + C - 4
			box(c, tie, py - 2, 4, 7, ROPE)
			box(c, tie, py, 4, 1, ROPE.darkened(0.3))

## --- out beyond it all -----------------------------------------------------------

func depths() -> Array[Depth]:
	var out: Array[Depth] = [
		_depth(_sky, 1.0, -14, false, false),
		_depth(_moon, 0.92, -13, true, false),
		_depth(_far, 0.6, -12, false, false),
		_depth(_falls, 0.6, -11, false, true),
		_depth(_mist, 0.45, -10, false, true),
		_depth(_mid, 0.25, -9, false, false),
	]
	return out

## A depth: what gives its own light — the moon — is drawn where the light
## can see it (`Lighting.glow`), and the rest is the back of the picture, the
## sky with it: a lantern lights the night round it, as the grove's are
## painted doing.
func _depth(paint: Callable, drift: float, z: int, glows: bool, moves: bool) -> Depth:
	var d := Depth.new()
	d.paint = paint
	d.drift = drift
	d.z_index = z
	d.moves = moves
	if glows:
		d.material = Lighting.glow()
		d.visibility_layer = PixelCamera.WORLD_LAYER
	else:
		d.visibility_layer = Lighting.BACKDROP_LAYER
	return d

## A stretch of the world, in pixels of the buffer.
static func _px(r: Rect2) -> Rect2i:
	var from := Vector2i((r.position / S).floor())
	return Rect2i(from, Vector2i((r.end / S).ceil()) - from)

## The night, from overhead down to the glow the moon puts behind the trees,
## top to foot of the screen; and the stars in it.
func _sky(c: CanvasItem, area: Rect2, rest: Rect2, _t: float) -> void:
	var a := _px(area)
	var r := _px(rest)
	var band := float(r.size.y) * 0.8 / SKY.size()
	for i in SKY.size():
		var from := r.position.y + int(round(band * i))
		var to := r.position.y + int(round(band * (i + 1)))
		if i == 0:
			from = mini(from, a.position.y)
		if i == SKY.size() - 1:
			to = maxi(to, a.end.y)
		box(c, a.position.x, from, a.size.x, to - from, SKY[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x620F
	for i in maxi(a.size.x * r.size.y / 3000, 1):
		box(c, a.position.x + rng.randi_range(0, a.size.x - 1), r.position.y + rng.randi_range(0, int(r.size.y * 0.42)),
			1, 1, Color(0.82, 0.95, 0.92, rng.randf_range(0.25, 0.85)))

## The moon, low and big, with its light in the air round it.
func _moon(c: CanvasItem, _area: Rect2, rest: Rect2, _t: float) -> void:
	var r := _px(rest)
	var mx := r.position.x + int(r.size.x * 0.37)
	var my := r.position.y + int(r.size.y * 0.38)
	var big := 30
	HideoutScenery.disc(c, mx, my, big + 22, HideoutScenery.faded(MOONLIGHT, 0.035))
	HideoutScenery.disc(c, mx, my, big + 13, HideoutScenery.faded(MOONLIGHT, 0.05))
	HideoutScenery.disc(c, mx, my, big + 6, HideoutScenery.faded(MOONLIGHT, 0.07))
	HideoutScenery.disc(c, mx, my, big, MOON_FACE)
	HideoutScenery.disc(c, mx - 11, my - 9, 6, MOON_SHADE)
	HideoutScenery.disc(c, mx + 9, my - 14, 4, MOON_SHADE)
	HideoutScenery.disc(c, mx + 12, my + 2, 5, MOON_SHADE)
	HideoutScenery.disc(c, mx - 4, my + 7, 3, MOON_SHADE)
	box(c, mx - 19, my + 2, 4, 3, MOON_SHADE)
	box(c, mx + 2, my - 23, 5, 2, MOON_SHADE)

## Where the far trees' tops stand at `x`, across the screen at rest: crown
## after crown.
static func _skyline(x: int, base: int) -> int:
	return base - int(16.0 * absf(sin(x * 0.060 + 0.4)) + 9.0 * absf(sin(x * 0.137 + 1.3))) - odd(x, 0, 303) % 2

## The far wood, a crown after another all the way across, and a cliff
## standing out of it with water coming down: the water itself is `_falls`.
func _far(c: CanvasItem, area: Rect2, rest: Rect2, _t: float) -> void:
	var a := _px(area)
	var r := _px(rest)
	var base := r.position.y + int(r.size.y * 0.43)
	for x in range(a.position.x, a.end.x):
		var top := _skyline(x, base)
		box(c, x, top, 1, a.end.y - top, FAR)
		if odd(x, 0, 304) % 9 == 0:
			box(c, x, top + 9, 1, a.end.y - top - 9, FAR.darkened(0.14))
		if odd(x, 0, 305) % 4 == 0:
			box(c, x, top, 1, 2, FAR.lightened(0.07))
	var cliff := _cliff(r)
	var rock := FAR.darkened(0.18)
	for x in range(cliff.x - 30, cliff.x + 31):
		var from := x - cliff.x
		var top := cliff.y + (absi(from) * absi(from)) / 22 - 6 + odd(x, 0, 311) % 3
		box(c, x, top, 1, maxi(_skyline(x, base) + 6 - top, 0), rock)
		if from < -3:
			box(c, x, top, 1, 2 + odd(x, 0, 312) % 4, rock.lightened(0.12))
	for crack in [[-13, 12, 22], [9, 10, 26], [-20, 26, 14], [20, 24, 16]]:
		box(c, cliff.x + int(crack[0]), cliff.y + int(crack[1]), 1, crack[2], rock.darkened(0.25))
	for pine in [-9, 5]:
		HideoutScenery.stamp(c, cliff.x + pine, cliff.y - 12 + absi(pine) * absi(pine) / 22,
			["..#..", ".###.", "..#..", ".###.", "#####", "..#..", "..#.."], FAR.darkened(0.3))
	box(c, cliff.x - 3, cliff.y, 6, base - cliff.y + 20, HideoutScenery.faded(WATER, 0.62))
	box(c, cliff.x - 3, cliff.y, 1, base - cliff.y + 20, HideoutScenery.faded(WATER, 0.30))
	box(c, cliff.x - 1, cliff.y, 2, base - cliff.y + 20, HideoutScenery.faded(Color.WHITE, 0.28))
	for k in 6:
		box(c, a.position.x, base + 36 + k * 9, a.size.x, 9, HideoutScenery.faded(MOONLIGHT, 0.03 + 0.018 * k))

## Where the cliff stands on the screen at rest, by the middle of its top.
static func _cliff(r: Rect2i) -> Vector2i:
	return Vector2i(r.position.x + int(r.size.x * 0.56), r.position.y + int(r.size.y * 0.43) - 50)

## The water coming down the cliff, and the spray at its foot.
func _falls(c: CanvasItem, _area: Rect2, rest: Rect2, t: float) -> void:
	var r := _px(rest)
	var cliff := _cliff(r)
	var base := r.position.y + int(r.size.y * 0.43)
	var fall := base - cliff.y + 14
	for k in 9:
		var y := cliff.y + int(fmod(t * 46.0 + k * 13.0, float(fall)))
		box(c, cliff.x - 3 + (k * 3) % 6, y, 1, 4, Color(1.0, 1.0, 1.0, 0.55))
	for k in 3:
		var puff := 0.5 + 0.5 * sin(t * 1.7 + k * 2.1)
		box(c, cliff.x - 10 + k * 5, cliff.y + fall - int(puff * 4.0), 9, 5, HideoutScenery.faded(WATER, 0.10 + 0.10 * puff))

## The mist, going by in bands in front of the far wood, and lying still under
## them.
func _mist(c: CanvasItem, area: Rect2, rest: Rect2, t: float) -> void:
	var a := _px(area)
	var r := _px(rest)
	var y0 := r.position.y + int(r.size.y * 0.56)
	var bands := maxi(4, a.size.x / 240)
	for i in bands:
		var w := 90 + odd(i, 0, 321) % 90
		var speed := 1.6 + float(odd(i, 0, 322) % 20) / 10.0
		var span := a.size.x + w
		var x := a.position.x - w + int(fmod(t * speed + float(odd(i, 0, 323)) * 7.0, float(span)))
		var y := y0 + odd(i, 0, 324) % 36
		box(c, x, y, w, 3, HideoutScenery.faded(MOONLIGHT, 0.07))
		box(c, x + 14, y - 2, w - 36, 2, HideoutScenery.faded(MOONLIGHT, 0.06))
		box(c, x + 22, y + 3, w - 50, 2, HideoutScenery.faded(MOONLIGHT, 0.06))

## The nearer trees: trunks from the foot of the screen at rest up out of
## sight, lit down the side the moon is on, each with a limb going up and out
## with its leaves at the end of it, their crowns overhead, and the bushes at
## their feet.
func _mid(c: CanvasItem, area: Rect2, rest: Rect2, _t: float) -> void:
	var a := _px(area)
	var r := _px(rest)
	var foot := r.end.y - 2 * C
	var moon_x := r.position.x + int(r.size.x * 0.37)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var x := a.position.x + rng.randi_range(0, 40)
	while x < a.end.x:
		var w := rng.randi_range(6, 11)
		box(c, x, a.position.y, w, foot - a.position.y, MID)
		box(c, x - 1, foot - 9, w + 2, 9, MID)
		box(c, x - 2, foot - 3, w + 4, 3, MID)
		var rim := x + w - 1 if x < moon_x else x
		box(c, rim, maxi(a.position.y, foot - 220), 1, mini(foot - 10 - a.position.y, 210), MID.lerp(MOONLIGHT, 0.20))
		for k in 8:
			box(c, x + 2 + (k * 5) % maxi(w - 3, 1), foot - 30 - k * 23, 1, 7, MID.darkened(0.3))
		var reach := 1 if rng.randf() < 0.5 else -1
		var from := x + w if reach > 0 else x - 1
		var limb := foot - rng.randi_range(110, 170)
		for k in 13:
			box(c, from + reach * k, limb - k, 1, 3, MID)
		for blob in [[14, -14, 5], [19, -11, 4], [10, -18, 4], [17, -19, 3]]:
			HideoutScenery.disc(c, from + reach * int(blob[0]), limb + int(blob[1]), blob[2], MID)
		HideoutScenery.oval(c, x + w / 2, a.position.y + 6, rng.randi_range(18, 30), rng.randi_range(10, 16), LEAF.darkened(0.25))
		x += rng.randi_range(70, 120)
	var bush := a.position.x
	while bush < a.end.x:
		HideoutScenery.disc(c, bush + rng.randi_range(0, 6), foot - 2 + rng.randi_range(0, 4), 7 + rng.randi_range(0, 4), MID)
		bush += 11
