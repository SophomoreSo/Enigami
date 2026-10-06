class_name MapTiles
extends RefCounted

## A tileset: how a map made in the map creator (`MadeRoom`) is drawn, in code,
## a pixel of the buffer the world is drawn into at a time, with
## `HideoutScenery`'s brushes. There is no image behind any of it.
##
## A tileset says how its ground looks, kind by kind (`MadeRoom.GROUND`), and
## each cell of it as it meets its neighbours — what grows along a top, what
## hangs from an underside, what flares out where it meets the floor; what can
## stand behind the ground, and how that looks; what is past the map's edge;
## and what is out beyond the whole of it, far off. One is a script that
## extends this one, and says so: `GroveTiles` is the hideout's Moonlit Grove
## made into one, and `RockTiles` the plain rock a raid's rooms are cut from.
## Which there are is `IDS`; another is its script, its id there and in `of`,
## and its words under `hud.maker.tiles` in `localization/`. The kinds of
## ground a tileset draws are its own (`kind_marks`, `paint_kind`), and so is
## what can stand behind (`back_kind_marks`, `paint_back_kind`); glass is in
## every tileset, as ground and behind it both, and is drawn here (`GLASS`).
##
## What is put about a map — a lantern, a fire, the grass, a vine — is the
## same in every tileset, and is here: the marks (`PROPS`), and the pictures
## they are drawn with, on the creator's table as they stand and in a room as
## they move (`MadeRoomView`), which hangs them on the game's own ropes, grows
## them as its own foliage and lights them with its own lamps.
##
## It is a picture, and only that. It reads a map's cells (`MapCells`) and
## changes nothing.

# Pixel art halves whole numbers on purpose, all the way down.
@warning_ignore_start("integer_division")

const S := PixelCamera.SCALE
## A cell, in pixels of the buffer: what every painter here counts in.
const C := Room.CELL / PixelCamera.SCALE

## The tilesets, by id, in the order the map creator offers them. A map with
## none of these named is drawn in the last.
const IDS := ["grove", "rock"]

## What can be put about a map, by the mark that puts each, in the order the
## creator offers them.
const PROPS := {
	"L": "lantern", "F": "fire", "m": "mushrooms", "*": "fireflies",
	"g": "grass", "f": "flowers", "b": "bush", "n": "fern", "v": "vine", "r": "rope",
}
## Those that are foliage (`Foliage`), by the kind each grows.
const FOLIAGE := {"g": "grass", "f": "flowers", "b": "bush"}
## Those that hang from what is over them, and those that are lines: a run of
## them down a column is one, hung from the top of the run.
const HANGING := ["L", "v", "r"]
const LINES := {"v": "vine", "r": "cable"}
## Those that stand on the floor of their cell.
const STANDING := ["F", "m", "g", "f", "b", "n"]
## How far up a lantern, a vine or a rope looks for something to hang from,
## in cells, before it hangs from the top of its own.
const HANG_REACH := 8

## The light each thing that gives one gives (`Lamp`): its colour, how far it
## reaches in world units, how bright it is, how much of it the air catches,
## and whether what stands in it throws a shadow.
const LANTERN_LIGHT := {"color": Color(1.0, 0.76, 0.34), "reach": 140.0, "energy": 2.0, "volume": 0.16, "shadows": true}
const FIRE_LIGHT := {"color": Color(1.0, 0.62, 0.26), "reach": 180.0, "energy": 2.4, "volume": 0.08, "shadows": true}
const CAPS_LIGHT := {"color": Color(0.36, 0.96, 0.90), "reach": 64.0, "energy": 1.0, "volume": 0.04, "shadows": false}
const FLIES_LIGHT := {"color": Color(0.82, 1.0, 0.45), "reach": 48.0, "energy": 0.6, "volume": 0.02, "shadows": false}

## The colours the things put about a map are drawn in: the Moonlit Grove's,
## whichever tileset they stand in.
const LAMP := HideoutGrove.LAMP
const FLAME_OUT := HideoutGrove.FLAME_OUT
const FLAME_MID := HideoutGrove.FLAME_MID
const FLAME_CORE := HideoutGrove.FLAME_CORE
const WOOD := HideoutGrove.WOOD
const WOOD_DARK := HideoutGrove.WOOD_DARK
const CAP := HideoutGrove.CAP
const SHROOM := HideoutGrove.SHROOM
const STEM := Color(0.64, 0.60, 0.48)
const FIREFLY := HideoutGrove.FIREFLY
const STONE := HideoutGrove.STONE
const STONE_SHADE := HideoutGrove.STONE_SHADE
const LEAF := HideoutGrove.LEAF
const MOSS := HideoutGrove.MOSS
const MOSS_LIT := HideoutGrove.MOSS_LIT
const FROND := Color(0.20, 0.38, 0.24)

static var _made: Dictionary = {}
## A patch of each kind of foliage, grown once, for the table to show where
## one is put (`_foliage`): kind -> [picture, margin].
static var _grown: Dictionary = {}

## The tileset called `called`; the last of `IDS` for one that is not there.
static func of(called: String) -> MapTiles:
	if not IDS.has(called):
		called = IDS[IDS.size() - 1]
	if not _made.has(called):
		match called:
			"grove":
				_made[called] = GroveTiles.new()
			_:
				_made[called] = RockTiles.new()
	return _made[called]

## --- what a tileset says about itself -----------------------------------------

func id() -> String:
	return ""

## What it is called, in the language being played.
func title() -> String:
	return id().to_upper()

## The ground it offers, by mark, in the order offered: its own kinds, and then
## the glass every tileset has.
func ground_marks() -> PackedStringArray:
	var marks := kind_marks()
	for mark: String in GLASS:
		marks.append(mark)
	return marks

## Its own kinds of ground, by mark.
func kind_marks() -> PackedStringArray:
	return PackedStringArray([MadeRoom.ROCK])

## What can stand behind the ground, by mark, in the order offered: its own,
## and then a pane of the glass every tileset has.
func back_marks() -> PackedStringArray:
	var marks := back_kind_marks()
	for mark: String in GLASS:
		marks.append(mark)
	return marks

## Its own of what can stand behind, by mark.
func back_kind_marks() -> PackedStringArray:
	return PackedStringArray()

## What a mark of its ground is called: glass alike in every tileset, and its
## own kinds as it calls them.
func ground_name(mark: String) -> String:
	if GLASS.has(mark):
		return Loc.t("hud.maker.glass.%s" % String(GLASS[mark]))
	return kind_name(mark)

func kind_name(mark: String) -> String:
	return mark

## What a mark of what stands behind is called: glass alike in every tileset,
## and its own as it calls them.
func back_name(mark: String) -> String:
	if GLASS.has(mark):
		return Loc.t("hud.maker.glass.%s" % String(GLASS[mark]))
	return back_kind_name(mark)

func back_kind_name(_mark: String) -> String:
	return ""

## What a thing put about a map is called: the same in every tileset.
static func prop_name(mark: String) -> String:
	return Loc.t("hud.maker.prop.%s" % String(PROPS.get(mark, "lantern")))

## The colour of an open cell on the creator's table, and of what is past the
## map's edge there.
func open_colour() -> Color:
	return Style.ROOM_BG

## The open air of a map on the creator's table, over `rect` of the sheet.
func paint_open(c: CanvasItem, rect: Rect2) -> void:
	c.draw_rect(rect, open_colour())

func outside_colour() -> Color:
	return Style.region_tint(0).darkened(0.4)

## The light there is in a room drawn in it with no lamp lit (`Lighting.ambient`).
func ambient() -> Color:
	return Color.WHITE

## The pixel down from the top of its cell that a cord hangs under, for what
## stands behind marked `mark`; -1 for something nothing hangs from.
func hangs_from(_mark: String) -> int:
	return -1

## --- painting -------------------------------------------------------------------
## Every painter paints cell (x, y) in the world's units, its corner at
## (x, y) × `Room.CELL`, out of whatever it reads off `cells`.

## Cell (x, y)'s ground, whatever kind it is: glass as every tileset has it,
## and its own kinds as it draws them (`paint_kind`).
func paint_ground(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	if GLASS.has(cells.ground(x, y)):
		paint_glass(c, cells, x, y)
	else:
		paint_kind(c, cells, x, y)

## Cell (x, y)'s ground, of one of the tileset's own kinds.
func paint_kind(_c: CanvasItem, _cells: MapCells, _x: int, _y: int) -> void:
	pass

## What stands behind cell (x, y): a pane of glass as every tileset has it, and
## its own as it draws them (`paint_back_kind`).
func paint_back(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	if GLASS.has(cells.back_at(x, y)):
		paint_glass(c, cells, x, y, true)
	else:
		paint_back_kind(c, cells, x, y)

## What stands behind cell (x, y), of the tileset's own.
func paint_back_kind(_c: CanvasItem, _cells: MapCells, _x: int, _y: int) -> void:
	pass

## Cell (x, y) past the map's edge, which is all ground.
func paint_beyond(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	paint_ground(c, cells, x, y)

## The depths out beyond the whole map, back to front, for a room drawn in it
## (`Depth`); none for a tileset with nothing out there.
func depths() -> Array[Depth]:
	var out: Array[Depth] = []
	return out

## A depth of the picture out beyond the map: drawn once by `paint` — or again
## and again, if it `moves` — over `area`, the stretch of it the screen can
## ever show, with `rest` the screen as it stands with the camera at the map's
## foot and its left. It goes along with the camera by `drift`: 1 pinned to the
## screen, 0 to the map. What places it is the room's view (`MadeRoomView`).
class Depth extends Node2D:
	var paint: Callable
	var drift := 0.0
	var moves := false
	var area := Rect2()
	var rest := Rect2()
	var t := 0.0

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self, area, rest, t)

## A stretch of a map drawn once and kept: the cells of `area`, painted by
## `paint`. The tile field is drawn in pieces like this, so what is off the
## screen is never drawn and a change draws again only the piece it is in.
class Chunk extends Node2D:
	var paint: Callable
	var area := Rect2i()

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self, area)

## --- glass -----------------------------------------------------------------------

## Glass is the same in every tileset, of two kinds — clear glass, which shows
## what stands behind it, and a mirror, which shows what stands in front of it
## (`Glass`) — and stands in either of two places. As ground it is ground like
## any other, as solid: a mirror of it shows the world across its faces to the
## open air. Behind the ground it is a pane in the back wall, which nothing
## stands on: clear, a window on what is out beyond; a mirror, one that faces
## the eye and shows whoever stands in front of it, a little off
## (`Glass.Kind.BACK_MIRROR`). What it shows is worked out after the picture is
## drawn, by the pixel camera's glazing (`Glazing`), over a pane that a room's
## view puts on each cell of it (`glass_pane`, `MadeRoomView`). What is drawn of
## it here is what it is before that, on the creator's table as in a room: its
## frame, a pixel wide, wherever it meets anything but more of the same glass
## in the same place, lit along its top and its left; streaks of light across
## it, rising to the right, that run on from one cell into the next; and
## behind a mirror, its dark.
const GLASS := {"o": "clear", "@": "mirror"}
const GLASS_LIT := Color(0.80, 0.94, 0.97)
const GLASS_SHADE := Color(0.42, 0.58, 0.64)
const GLASS_SHINE := Color(0.88, 0.98, 1.0, 0.30)
const MIRROR_DARK := Color(0.08, 0.11, 0.14)
## How far apart the streaks of light are, in pixels along a row, and where in
## that each one lies: a broad one and, a little after it, a fine one.
const STREAK_EVERY := 40
const STREAKS := [0, 1, 6]
## How far into a mirror, in pixels, its sheen goes where nothing works out
## what it shows (`paint_mirror_sheen`).
const SHEEN := 6

## Cell (x, y), of glass — the ground's, or with `behind`, what stands behind
## it: its dark if it is a mirror, the streaks across it, and its frame.
func paint_glass(c: CanvasItem, cells: MapCells, x: int, y: int, behind: bool = false) -> void:
	var mark := _glass_at(cells, x, y, behind)
	var px := x * C
	var py := y * C
	if GLASS.get(mark, "") == "mirror":
		box(c, px, py, C, C, MIRROR_DARK)
	for i in C:
		for o: int in STREAKS:
			var j := posmod(o - px - i - py, STREAK_EVERY)
			if j < C:
				box(c, px + i, py + j, 1, 1, GLASS_SHINE)
	var up := _glass_at(cells, x, y - 1, behind) != mark
	var left := _glass_at(cells, x - 1, y, behind) != mark
	if _glass_at(cells, x, y + 1, behind) != mark:
		box(c, px, py + C - 1, C, 1, GLASS_SHADE)
	if _glass_at(cells, x + 1, y, behind) != mark:
		box(c, px + C - 1, py, 1, C, GLASS_SHADE)
	if up:
		box(c, px, py, C, 1, GLASS_LIT)
	if left:
		box(c, px, py, 1, C, GLASS_LIT)
	if up and left:
		# Where the light comes over the corner.
		box(c, px + 1, py + 1, 2, 1, GLASS_LIT)
		box(c, px + 1, py + 2, 1, 1, GLASS_LIT)

## A mirror where nothing works out what it shows — on the creator's table, and
## in its list of what there is to lay — as the light it would catch: a sheen
## along each face of it that meets the open air, brightest at the face and gone
## SHEEN pixels in. A room shows what the mirror does show instead, and draws
## none of this.
func paint_mirror_sheen(c: CanvasItem, cells: MapCells, x: int, y: int) -> void:
	if GLASS.get(cells.ground(x, y), "") != "mirror":
		return
	var pane := glass_pane(cells, x, y)
	var r := Rect2i(Vector2i((pane[0] as Rect2).position) / S, Vector2i((pane[0] as Rect2).size) / S)
	var faces: Vector4 = pane[1]
	var lit := func(far: float) -> Color:
		return HideoutScenery.faded(GLASS_LIT, 0.24 * (1.0 - far / SHEEN))
	for k in SHEEN:
		if faces.x >= 0.0 and faces.x + k < SHEEN and k < r.size.y:
			box(c, r.position.x, r.position.y + k, r.size.x, 1, lit.call(faces.x + k))
		if faces.y >= 0.0 and faces.y + k < SHEEN and k < r.size.y:
			box(c, r.position.x, r.end.y - 1 - k, r.size.x, 1, lit.call(faces.y + k))
		if faces.z >= 0.0 and faces.z + k < SHEEN and k < r.size.x:
			box(c, r.position.x + k, r.position.y, 1, r.size.y, lit.call(faces.z + k))
		if faces.w >= 0.0 and faces.w + k < SHEEN and k < r.size.x:
			box(c, r.end.x - 1 - k, r.position.y, 1, r.size.y, lit.call(faces.w + k))

## The pane over cell (x, y) of glass — the ground's, or with `behind`, what
## stands behind it — for a room's view to put there (`Glass.pane`): [the cell
## inside its frame, in the world's units; and for a mirror of the ground, how
## far past each edge of the pane — up, down, left, right — the face of its
## glass lies that meets the open air, in pixels of the buffer, or
## `Glass.NONE` that way]. A pane behind has no faces: it faces the eye.
static func glass_pane(cells: MapCells, x: int, y: int, behind: bool = false) -> Array:
	var mark := _glass_at(cells, x, y, behind)
	var top := 1 if _glass_at(cells, x, y - 1, behind) != mark else 0
	var bottom := 1 if _glass_at(cells, x, y + 1, behind) != mark else 0
	var left := 1 if _glass_at(cells, x - 1, y, behind) != mark else 0
	var right := 1 if _glass_at(cells, x + 1, y, behind) != mark else 0
	var rect := Rect2(Vector2(x * C + left, y * C + top) * S, Vector2(C - left - right, C - top - bottom) * S)
	var faces := Vector4(Glass.NONE, Glass.NONE, Glass.NONE, Glass.NONE)
	if GLASS.get(mark, "") == "mirror" and not behind:
		faces = Vector4(_face(cells, x, y, Vector2i.UP, top), _face(cells, x, y, Vector2i.DOWN, bottom),
			_face(cells, x, y, Vector2i.LEFT, left), _face(cells, x, y, Vector2i.RIGHT, right))
	return [rect, faces]

## How far past the edge of the pane over cell (x, y), going `way`, the face
## of its glass lies — the far edge of the last cell of the same glass that
## way — in pixels of the buffer, when what is past that face is open air;
## `Glass.NONE` when it is any other ground, or the map's edge. `inset` is how
## far in from its cell's own edge the pane stops that way.
static func _face(cells: MapCells, x: int, y: int, way: Vector2i, inset: int) -> float:
	var mark := cells.ground(x, y)
	var through := 0
	var at := Vector2i(x, y) + way
	while cells.ground(at.x, at.y) == mark:
		through += 1
		at += way
	if not cells.holds(at.x, at.y) or cells.solid(at.x, at.y):
		return Glass.NONE
	return float(through * C + inset)

## The mark of cell (x, y): its ground's, or with `behind`, what stands behind
## it.
static func _glass_at(cells: MapCells, x: int, y: int, behind: bool) -> String:
	return cells.back_at(x, y) if behind else cells.ground(x, y)

## --- what is put about a map ------------------------------------------------------

## The pixel row a lantern, a vine or a rope in cell (x, y) hangs from: the
## underside of the first ground over it, or of something behind it that takes
## a cord (`hangs_from`), no more than HANG_REACH cells up — or the top of its
## own cell, with nothing there. Past the map's top edge is ground.
func anchor(cells: MapCells, x: int, y: int) -> int:
	var own := hangs_from(cells.back_at(x, y))
	if own >= 0:
		return y * C + own
	for k in range(1, HANG_REACH + 1):
		var above := y - k
		if cells.solid(x, above):
			return (above + 1) * C
		var under := hangs_from(cells.back_at(x, above))
		if under >= 0:
			return above * C + under
		if above < 0:
			break
	return y * C

## Where the lantern in cell (x, y) hangs by its top: two pixels under what it
## hangs from, and no higher than two into its own cell.
func lantern_top(cells: MapCells, x: int, y: int) -> int:
	return maxi(anchor(cells, x, y) + 2, y * C + 2)

## The bottom row of the run of `mark` down column x that cell (x, y) is the
## top of; -1 when (x, y) is not the top of one.
static func run_down(cells: MapCells, x: int, y: int, mark: String) -> int:
	if cells.prop(x, y) != mark or cells.prop(x, y - 1) == mark:
		return -1
	var last := y
	while cells.prop(x, last + 1) == mark:
		last += 1
	return last

## A lantern, hung at (x, y) by its top: paper round a flame, `f` how bright it
## burns this moment (`HideoutScenery.flicker`), and the grove's own. It hangs
## still: what swings it is the cord it is on.
static func lantern(c: CanvasItem, x: int, y: int, f: float) -> void:
	var lx := x - 3
	box(c, lx + 1, y, 5, 1, WOOD_DARK)
	box(c, lx, y + 1, 7, 8, LAMP.darkened(0.25 - 0.2 * f))
	box(c, lx + 1, y + 2, 5, 6, LAMP.lerp(Color.WHITE, 0.15 + 0.25 * f))
	box(c, lx + 3, y + 3, 1, 4, FLAME_CORE)
	box(c, lx + 1, y + 9, 5, 1, WOOD_DARK)
	box(c, lx + 3, y + 10, 1, 2, CAP)
	HideoutScenery.halo(c, lx, y + 1, 7, 8, LAMP, 5, 0.05 * f)

## The room a lantern takes up from the pixel it hangs by: what a body has to
## go through to set it swinging.
const LANTERN_BODY := Rect2i(-3, 0, 7, 12)

## A flame standing on (x, y), `tall` at its fullest, `f` how high it burns
## this moment, leaning as `t` and `salt` say.
static func flame(c: CanvasItem, x: int, y: int, tall: int, f: float, t: float, salt: int) -> void:
	var h := maxi(int(round(float(tall) * (0.5 + 0.5 * f))), 2)
	var lean := int(round(sin(t * 6.0 + float(salt)) * 0.8))
	var body := h * 6 / 10
	box(c, x - 2, y - body, 5, body, FLAME_OUT)
	box(c, x - 1 + lean, y - h, 3, h - body, FLAME_OUT)
	box(c, x - 1, y - h * 7 / 10, 3, h * 7 / 10, FLAME_MID)
	box(c, x + lean, y - h + 1, 1, 2, FLAME_MID)
	box(c, x, y - h * 4 / 10, 1, h * 4 / 10, FLAME_CORE)

## A fire on the ground at (x, ground): the stones round it and what burns, as
## it stands. Its flames are `fire_flames`.
static func fire_ring(c: CanvasItem, x: int, ground: int) -> void:
	box(c, x - 5, ground - 2, 11, 2, WOOD_DARK)
	box(c, x - 4, ground - 3, 4, 1, WOOD)
	box(c, x + 1, ground - 3, 4, 1, WOOD.darkened(0.2))
	for stone in [x - 9, x - 6, x + 4, x + 7]:
		box(c, stone, ground - 3, 3, 3, STONE_SHADE)
		box(c, stone, ground - 3, 3, 1, STONE.darkened(0.15))

## Its flames, `t` into burning, with the sparks going up off them.
static func fire_flames(c: CanvasItem, x: int, ground: int, t: float, salt: int) -> void:
	var burn := HideoutScenery.flicker(t, salt)
	flame(c, x - 2, ground - 2, 8, burn, t, salt)
	flame(c, x + 2, ground - 2, 7, HideoutScenery.flicker(t, salt + 1), t, salt + 1)
	HideoutScenery.halo(c, x - 4, ground - 9, 9, 8, LAMP, 5, 0.06 * burn)
	for k in 3:
		var up := fmod(t * 0.8 + k * 0.37 + salt * 0.11, 1.0)
		box(c, x + int(round(sin(up * 9.0 + k * 3.0) * 3.0)), ground - 9 - int(up * 16.0), 1, 1,
			HideoutScenery.faded(FLAME_MID, 1.0 - up))

## Glowing caps on the ground at (x, ground), as they stand: three, on stems.
## Their glow is `caps_glow`.
const CAPS := [[-6, 4], [-1, 7], [4, 5]]

static func caps(c: CanvasItem, x: int, ground: int) -> void:
	for cap: Array in CAPS:
		var sx: int = x + int(cap[0])
		var tall: int = cap[1]
		box(c, sx + 2, ground - tall, 1, tall, STEM)
		box(c, sx, ground - tall - 2, 5, 2, SHROOM.darkened(0.2))
		box(c, sx + 1, ground - tall - 3, 3, 1, SHROOM.darkened(0.1))

static func caps_glow(c: CanvasItem, x: int, ground: int, t: float, salt: int) -> void:
	for i in CAPS.size():
		var cap: Array = CAPS[i]
		var breath := 0.55 + 0.45 * sin(t * 1.3 + i * 2.3 + salt * 0.7)
		var sx: int = x + int(cap[0])
		var top: int = ground - int(cap[1]) - 3
		box(c, sx + 1, top, 3, 1, HideoutScenery.faded(SHROOM.lightened(0.4), breath))
		HideoutScenery.halo(c, sx, top, 5, 3, SHROOM, 3, 0.06 * breath)

## A fern on the ground at (x, ground): fronds fanned out from its root, the
## tips of two of them catching the light.
const FRONDS := [[-7, -10], [-4, -13], [0, -14], [4, -12], [7, -9]]

static func fern(c: CanvasItem, x: int, ground: int) -> void:
	for tip: Array in FRONDS:
		HideoutScenery.line(c, x, ground - 1, x + int(tip[0]), ground + int(tip[1]), FROND)
	for i in [0, 3]:
		var tip: Array = FRONDS[i]
		box(c, x + int(tip[0]), ground + int(tip[1]), 2, 1, MOSS_LIT.darkened(0.15))

## A firefly at (x, y), `on` how lit it is.
static func firefly(c: CanvasItem, x: int, y: int, on: float) -> void:
	if on <= 0.0:
		return
	box(c, x, y, 1, 1, HideoutScenery.faded(FIREFLY, on))
	if on > 0.6:
		box(c, x - 1, y - 1, 3, 3, HideoutScenery.faded(FIREFLY, 0.16 * on))

## Where the fireflies of cell (x, y) hang about, each [x, y, a, b, c]: the
## pixel and how it is out of step with the rest.
static func flies_of(x: int, y: int) -> Array:
	var out: Array = []
	for k in 4:
		out.append([x * C + 2 + odd(x, y, 140 + k) % 12, y * C + 2 + odd(x, y, 150 + k) % 12,
			odd(x, y, 160 + k) * 0.0063, odd(x, y, 170 + k) * 0.0063, odd(x, y, 180 + k) * 0.0063])
	return out

## The fireflies of cell (x, y), `t` into the night.
static func fireflies(c: CanvasItem, x: int, y: int, t: float) -> void:
	for fly: Array in flies_of(x, y):
		var on := sin(t * 1.3 + float(fly[4]))
		var fx := int(fly[0]) + int(round(sin(t * 0.31 + float(fly[2])) * 9.0))
		var fy := int(fly[1]) + int(round(sin(t * 0.43 + float(fly[3])) * 6.0))
		firefly(c, fx, fy, on)

## A leaf on a vine, hanging by the pixel at its top.
static func vine_leaf(c: CanvasItem, flip: bool) -> void:
	box(c, -1 if flip else 0, 0, 2, 1, MOSS)
	box(c, -2 if flip else 1, 1, 2, 1, MOSS_LIT.darkened(0.2))

## --- the creator's table ---------------------------------------------------------

## What is put about cell (x, y), as it stands, `t` into the night: a lantern
## on its cord, a vine or a rope the length of its run, and the rest as each
## stands — foliage as a patch of the game's own grown once. A run of vine or
## rope is drawn from its top cell, and nothing from the cells under it.
func paint_prop_still(c: CanvasItem, cells: MapCells, x: int, y: int, t: float) -> void:
	var mark := cells.prop(x, y)
	var mid := x * C + C / 2
	var ground := (y + 1) * C
	match mark:
		"L":
			var top := anchor(cells, x, y)
			var at := lantern_top(cells, x, y)
			box(c, mid, top, 1, at - top, Style.rope_look("cord")["line"])
			HideoutScenery.disc(c, mid, at + 5, 26, HideoutScenery.faded(LAMP, 0.04))
			HideoutScenery.disc(c, mid, at + 5, 15, HideoutScenery.faded(LAMP, 0.05))
			lantern(c, mid, at, 0.85)
		"F":
			fire_ring(c, mid, ground)
			fire_flames(c, mid, ground, t, x + y)
		"m":
			caps(c, mid, ground)
			caps_glow(c, mid, ground, t, x)
		"*":
			fireflies(c, x, y, t)
		"n":
			fern(c, mid, ground)
		"v", "r":
			var last := run_down(cells, x, y, mark)
			if last < 0:
				return
			var top := anchor(cells, x, y)
			var foot := (last + 1) * C - 2
			var look := Style.rope_look(String(LINES[mark]))
			box(c, mid, top, 1, foot - top, look["line"])
			if mark == "v":
				for k in range(top + 3, foot - 1, 4):
					vine_leaf_at(c, mid, k, (k / 4) % 2 == 0)
			box(c, mid - 1, foot - 1, 3, 3, look["end"])
		_:
			if FOLIAGE.has(mark):
				_foliage(c, String(FOLIAGE[mark]), x * C, ground)

static func vine_leaf_at(c: CanvasItem, x: int, y: int, flip: bool) -> void:
	box(c, x - 1 if flip else x, y, 2, 1, MOSS)
	box(c, x - 2 if flip else x + 1, y + 1, 2, 1, MOSS_LIT.darkened(0.2))

## A patch of foliage of `kind` one cell wide, standing on (left, ground): a
## picture of the game's own foliage, grown the once.
static func _foliage(c: CanvasItem, kind: String, left: int, ground: int) -> void:
	if not _grown.has(kind):
		var patch := Foliage.of(kind)
		patch.grow(C, 7 + kind.length())
		_grown[kind] = [ImageTexture.create_from_image(patch.picture), patch.margin]
		patch.free()
	var grown: Array = _grown[kind]
	var tex: ImageTexture = grown[0]
	var margin: int = grown[1]
	var size := Vector2(tex.get_size())
	c.draw_texture_rect(tex, Rect2(Vector2(left - margin, ground - size.y) * S, size * S), false)

## A picture of `mark` of `layer` (`MapMaker.PLAN` and the rest) for the
## creator's list of what there is to lay: one cell of it, `k` of its size,
## its middle on `middle` — ground as a cell of it with the air all round it,
## and what stands behind or is put about as one standing alone.
func icon(c: CanvasItem, layer: int, mark: String, middle: Vector2, k: float) -> void:
	var laid := PackedStringArray(["...", "...", "..."])
	var behind := PackedStringArray(["...", "...", "..."])
	var about := PackedStringArray(["...", "...", "..."])
	match layer:
		MapMaker.BACK:
			behind[1] = "." + mark + "."
		MapMaker.DRESSING:
			about[1] = "." + mark + "."
		_:
			laid[1] = "." + mark + "."
	if layer == MapMaker.DRESSING:
		# Something over it to hang from, for what hangs; nothing is drawn of it.
		laid[0] = "###"
	var cells := MapCells.of_rows(laid, behind, about, id())
	c.draw_set_transform(middle - Vector2(1.5, 1.5) * Room.CELL * k, 0.0, Vector2(k, k))
	# On the map's own open air, as it is seen on the sheet.
	paint_open(c, Rect2(Vector2.ONE * Room.CELL, Vector2.ONE * Room.CELL))
	match layer:
		MapMaker.BACK:
			paint_back(c, cells, 1, 1)
		MapMaker.DRESSING:
			paint_prop_still(c, cells, 1, 1, 0.6)
		_:
			paint_ground(c, cells, 1, 1)
			paint_mirror_sheen(c, cells, 1, 1)
	c.draw_set_transform(Vector2.ZERO)

## --- brushes ------------------------------------------------------------------

static func box(c: CanvasItem, x: int, y: int, w: int, h: int, col: Color) -> void:
	HideoutScenery.box(c, x, y, w, h, col)

## Something that is the same for cell (x, y) every time and has no pattern to
## it: 0 to 999, different for every `salt`.
static func odd(x: int, y: int, salt: int = 0) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ ((salt + 1) * 83492791)) % 1000
