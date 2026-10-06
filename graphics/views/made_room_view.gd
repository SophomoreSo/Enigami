class_name MadeRoomView
extends RoomView

## A room made in the map creator (`MadeRoom`), drawn in its tileset
## (`MapTiles`) — and lit, and hung with what was put about it.
##
## The ground and what stands behind it are drawn once, in chunks of the map
## a fifth of a screen or so across (`MapTiles.Chunk`), each as the screen
## comes near it; and out past the map's edge, as far as the screen goes, is
## the tileset's own ground. Behind it all are the tileset's depths, each going
## along with the camera by its own drift (`MapTiles.Depth`). What swings
## swings only while the screen is near it, and what flickers is drawn again
## only there, so a map four screens each way costs a frame not much more than
## the stretch of it the screen shows (`_wake`).
##
## What was put about the map is made of the game's own things. A lantern
## hangs on a cord (`Rope`) from whatever is over it, with a lamp in it
## (`Lamp`): it swings when somebody goes through it, and its light swings with
## it. A vine and a rope are lines of their own, the length of their run, that
## anything moving through them sets swinging. Grass, flowers and a bush are
## patches of foliage (`Foliage`) that lean where somebody walks. A fire burns
## and lights the room round it, glowing caps and fireflies give a little light
## of their own, and a fern stands where it was put. Nothing is rolled: a made
## room has what was put in it, and none of the cables and grass a raid's rooms
## are hung and grown with.
##
## Its glass is glass (`Glass`): a pane over every cell of it, clear or a
## mirror, which the pixel camera's glazing works from (`Glazing`) — what stands
## behind clear glass is seen through it, and what stands in front of a mirror
## is shown in it. The ground's mirrors show the world across their faces to
## the air; a mirror behind the ground faces the eye, and shows whoever stands
## in front of it a little off (`Glass.Kind.BACK_MIRROR`). Clear glass is no
## rock to the light: it throws no shadow, and the rock beside it faces it as
## it would the open air.
##
## The light the room is seen in is the world's to set — the map creator sets
## the tileset's own (`MapTiles.ambient`) — and how its rock faces, and the
## shadows it throws, are a room's like any other (`RoomView`).

# Pixel art halves whole numbers on purpose, all the way down.
@warning_ignore_start("integer_division")

const S := PixelCamera.SCALE
const C := MapTiles.C
## Cells to a chunk, each way.
const CHUNK := 8
## How many times a second what moves is drawn again: a flame, a lantern's
## flicker, the fireflies, the mist.
const REDRAWS := 30.0
## How hard the air leans on what hangs, in pixels a second squared at its
## strongest (`HideoutGrove.BREEZE`).
const BREEZE := 10.0
## How near the screen, in world units, a line has to be to swing, a chunk to
## be drawn, and what flickers to be drawn again: far enough that the screen
## never comes on any of it before it is.
const AWAKE := Room.CELL * 8.0
## How many chunks coming near the screen are drawn in a frame, over those
## the screen has come on, which are drawn there and then.
const REVEALS := 4

var made: MadeRoom
var tiles: MapTiles
var cells: MapCells
## The tile field, in chunks: what stands behind, and the ground in front of it.
var chunks: Array[MapTiles.Chunk] = []
## The depths out beyond the map, back to front.
var depths: Array[MapTiles.Depth] = []
## Every lamp what was put about the room lights it with.
var lamps: Array[Lamp] = []
## The lanterns, each riding the end of its cord.
var lanterns: Array[Lantern] = []
## The glass, a node of panes to each kind of it: the ground's, clear and
## mirror, and what stands behind, clear and mirror.
var glass: Array[Glass] = []
var _cords: Array[Rope] = []
## Vines, for the air to lean on.
var _vines: Array[Rope] = []
## How far each line of `ropes` could swing to, by the line, in the world.
var _spans: Array[Rect2] = []
## The screen, and AWAKE round it, as `_wake` last found it.
var _seen := Rect2()
## What stands still — a fire's stones, glowing caps, a fern — drawn once;
## and what moves — the flames, the glow, the fireflies — drawn again.
var _still: Node2D
var _life: Node2D
## A fire's lamp, flickering, and what puts it out of step: [lamp, salt].
var _fires: Array = []
## What was put about the room that is drawn by `_still` and by `_life`, each
## [mark, x, y]: found once, so a big map is not read through for it every
## time what moves is drawn again.
var _stills: Array = []
var _alive: Array = []
## Where the camera stands at the map's foot and its left, which every depth is
## drawn as seen from.
var _rest := Vector2.ZERO
var _t := 0.0
var _due := 0.0

## A lantern on the end of its cord, about the pixel it hangs by: paper round a
## flame, flickering, and its own light (`Lighting.glow`).
class Lantern extends Node2D:
	var salt := 0
	var t := 0.0
	func _draw() -> void:
		MapTiles.lantern(self, 0, 0, HideoutScenery.flicker(t, salt))

## A leaf on a vine, riding the node it hangs from.
class Leaf extends Node2D:
	var flip := false
	func _draw() -> void:
		MapTiles.vine_leaf(self, flip)

func _ready() -> void:
	super._ready()
	made = room as MadeRoom
	tiles = MapTiles.of(made.tileset if made != null else "")
	_still = _layer(_paint_still, false)
	_life = _layer(_paint_life, true)

func _layer(paint: Callable, glows: bool) -> Node2D:
	var n := Node2D.new()
	n.z_index = -1
	n.visibility_layer = PixelCamera.WORLD_LAYER
	if glows:
		n.material = Lighting.glow()
	n.draw.connect(paint.bind(n))
	add_child(n)
	return n

## The tileset draws the tile field, in chunks; RoomView's own draws nothing.
func draw_static(_c: CanvasItem) -> void:
	pass

func _on_built() -> void:
	cells = MapCells.of_room(made)
	super._on_built()
	_place()
	_glaze()

## The tile field as far as the screen shows past the map, and the depths for
## a screen of the shape it now is.
func _on_reshaped() -> void:
	super._on_reshaped()
	if cells != null:
		_chunk()
		_backdrop()

## --- the tile field -----------------------------------------------------------

func _chunk() -> void:
	for old in chunks:
		old.queue_free()
	chunks.clear()
	var out := RoomView.reach(get_viewport())
	var from := Vector2i(floori(float(-out.x) / CHUNK), floori(float(-out.y) / CHUNK))
	var to := Vector2i(floori(float(cells.cols + out.x - 1) / CHUNK), floori(float(cells.rows + out.y - 1) / CHUNK))
	var shown := Rect2i(-out, Vector2i(cells.cols, cells.rows) + out * 2)
	for cy in range(from.y, to.y + 1):
		for cx in range(from.x, to.x + 1):
			var area := Rect2i(cx * CHUNK, cy * CHUNK, CHUNK, CHUNK).intersection(shown)
			if area.has_area():
				chunks.append(_new_chunk(area, _paint_back, -8))
				chunks.append(_new_chunk(area, _paint_ground, -7))
	_wake()

func _new_chunk(area: Rect2i, paint: Callable, z: int) -> MapTiles.Chunk:
	var chunk := MapTiles.Chunk.new()
	chunk.area = area
	chunk.paint = paint
	chunk.z_index = z
	chunk.visibility_layer = Lighting.BACKDROP_LAYER
	# Not drawn until the screen comes near it (`_wake`).
	chunk.visible = false
	add_child(chunk)
	return chunk

func _paint_back(c: CanvasItem, area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if cells.back_at(x, y) != MadeRoom.OPEN:
				tiles.paint_back(c, cells, x, y)

func _paint_ground(c: CanvasItem, area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not cells.holds(x, y):
				tiles.paint_beyond(c, cells, x, y)
			elif cells.solid(x, y):
				tiles.paint_ground(c, cells, x, y)

## --- out beyond it all ----------------------------------------------------------

## The tileset's depths, each drawn over the stretch of it the screen can ever
## show — wherever the camera goes, which is never past the map's edge — as
## seen with the camera resting at the map's foot and its left.
func _backdrop() -> void:
	for old in depths:
		old.queue_free()
	depths = tiles.depths()
	var view := get_viewport().get_visible_rect().size
	var half := view * 0.5
	var map := Vector2(cells.cols, cells.rows) * Room.CELL
	var lo := Vector2(half.x if map.x > view.x else map.x * 0.5, half.y if map.y > view.y else map.y * 0.5)
	var hi := Vector2(map.x - half.x if map.x > view.x else map.x * 0.5, map.y - half.y if map.y > view.y else map.y * 0.5)
	_rest = Vector2(lo.x, hi.y)
	var margin := Vector2.ONE * Room.CELL * 2
	for d in depths:
		var near := 1.0 - d.drift
		d.area = Rect2(lo * near + _rest * d.drift - half - margin, (hi - lo) * near + view + margin * 2)
		d.rest = Rect2(_rest - half, view)
		add_child(d)
		move_child(d, 0)
	# Back to front, at the back of everything.
	for i in depths.size():
		move_child(depths[i], i)
	_follow()

## Every depth where it stands for the camera as it is now: gone along with it
## by its drift, on whole pixels of the buffer.
func _follow() -> void:
	var cam := get_viewport().get_camera_2d()
	var at := cam.get_screen_center_position() if cam != null else _rest
	for d in depths:
		d.position = (((at - _rest) * d.drift) / S).round() * S

## --- what was put about it -------------------------------------------------------

## The lanterns, on their cords, and the vines and ropes, each the length of
## its run — in place of the cables a raid's rooms are hung with. Each is hung
## straight down from where it hangs, which is where it would settle, so none
## is settled: a line hung so does not move until something moves it.
func _hang_lines() -> void:
	for r in ropes:
		if is_instance_valid(r):
			r.queue_free()
	for l in lanterns:
		if is_instance_valid(l):
			l.queue_free()
	# And the lamps in the lanterns with them.
	lamps = lamps.filter(func(l: Lamp) -> bool: return is_instance_valid(l) and not (l.get_parent() is Lantern))
	ropes.clear()
	_spans.clear()
	lanterns.clear()
	_cords.clear()
	_vines.clear()
	for y in cells.rows:
		for x in cells.cols:
			var mark := cells.prop(x, y)
			if mark == "L":
				_hang_lantern(x, y)
			elif MapTiles.LINES.has(mark):
				_hang_line(x, y, mark)

func _hang_lantern(x: int, y: int) -> void:
	var top := tiles.anchor(cells, x, y)
	var hangs := tiles.lantern_top(cells, x, y)
	var cord := Rope.of("cord")
	var length := float((hangs - top) * S)
	cord.hang((Vector2(x * C + C / 2, top) + Vector2(0.5, 0.5)) * S, length,
		length / float(maxi(1, roundi(length / cord.segment))))
	cord.z_index = -1
	cord.visibility_layer = PixelCamera.WORLD_LAYER
	add_child(cord)
	var lantern := Lantern.new()
	lantern.salt = x * 7 + y * 3
	lantern.z_index = -1
	lantern.visibility_layer = PixelCamera.WORLD_LAYER
	lantern.material = Lighting.glow()
	add_child(lantern)
	var lamp := _lamp(MapTiles.LANTERN_LIGHT)
	lamp.position = Vector2(0, 5 * S)
	lantern.add_child(lamp)
	var body := MapTiles.LANTERN_BODY
	cord.attach(lantern, cord.nodes.size() - 1, Vector2.ZERO, Rect2(Vector2(body.position) * S, Vector2(body.size) * S))
	ropes.append(cord)
	_spans.append(Rect2(Vector2(x * C + C / 2, top) * S, Vector2.ZERO).grow(length + body.end.y * S))
	_cords.append(cord)
	lanterns.append(lantern)

func _hang_line(x: int, y: int, mark: String) -> void:
	var last := MapTiles.run_down(cells, x, y, mark)
	if last < 0:
		return
	var top := tiles.anchor(cells, x, y)
	var foot := (last + 1) * C - 2
	var line := Rope.of(String(MapTiles.LINES[mark]))
	line.z_index = -1
	line.visibility_layer = PixelCamera.WORLD_LAYER
	line.hang((Vector2(x * C + C / 2, top) + Vector2(0.5, 0.5)) * S, float(foot - top) * S)
	if mark == "v":
		# A leaf at every node, either side by turns.
		for i in range(1, line.nodes.size()):
			var leaf := Leaf.new()
			leaf.flip = i % 2 == 0
			leaf.z_index = -1
			leaf.visibility_layer = PixelCamera.WORLD_LAYER
			add_child(leaf)
			line.attach(leaf, i)
		_vines.append(line)
	add_child(line)
	ropes.append(line)
	_spans.append(Rect2(Vector2(x * C + C / 2, top) * S, Vector2.ZERO).grow(float(foot - top) * S))

## The foliage, a patch to each run of one kind along a row, standing on the
## floor of its cells — in place of what a raid's rooms are grown with.
func _grow_foliage() -> void:
	for p in plants:
		if is_instance_valid(p):
			p.queue_free()
	plants.clear()
	for y in cells.rows:
		var x := 0
		while x < cells.cols:
			var mark := cells.prop(x, y)
			if not MapTiles.FOLIAGE.has(mark):
				x += 1
				continue
			var start := x
			while x < cells.cols and cells.prop(x, y) == mark:
				x += 1
			var patch := Foliage.of(String(MapTiles.FOLIAGE[mark]))
			patch.grow((x - start) * C, MapTiles.odd(start, y, 401) + 1)
			patch.position = Vector2(start, y + 1) * Room.CELL
			patch.z_index = -1
			patch.visibility_layer = PixelCamera.WORLD_LAYER
			add_child(patch)
			plants.append(patch)

## The lamps of the fires, the caps and the fireflies.
func _place() -> void:
	for lamp in lamps:
		if is_instance_valid(lamp) and not (lamp.get_parent() is Lantern):
			lamp.queue_free()
	lamps = lamps.filter(func(l: Lamp) -> bool: return is_instance_valid(l) and l.get_parent() is Lantern)
	_fires.clear()
	_stills.clear()
	_alive.clear()
	for y in cells.rows:
		var row := cells.dressing[y] if y < cells.dressing.size() else ""
		for x in mini(row.length(), cells.cols):
			var mark := row[x]
			if mark == "F" or mark == "m" or mark == "n":
				_stills.append([mark, x, y])
			if mark == "F" or mark == "m" or mark == "*":
				_alive.append([mark, x, y])
			var at := Vector2(x * C + C / 2, (y + 1) * C - 6) * S
			match mark:
				"F":
					var fire := _lamp(MapTiles.FIRE_LIGHT)
					fire.position = at
					add_child(fire)
					_fires.append([fire, x + y])
				"m":
					var caps := _lamp(MapTiles.CAPS_LIGHT)
					caps.position = at
					add_child(caps)
				"*":
					var flies := _lamp(MapTiles.FLIES_LIGHT)
					flies.position = Vector2(x * C + C / 2, y * C + C / 2) * S
					add_child(flies)
	_still.queue_redraw()
	_life.queue_redraw()

func _lamp(light: Dictionary) -> Lamp:
	var lamp := Lamp.of(light["color"], float(light["reach"]), float(light["energy"]))
	lamp.volume = float(light["volume"])
	lamp.shadows = bool(light["shadows"])
	lamps.append(lamp)
	return lamp

func _paint_still(c: CanvasItem) -> void:
	for prop: Array in _stills:
		var x: int = prop[1]
		var y: int = prop[2]
		match String(prop[0]):
			"F":
				MapTiles.fire_ring(c, x * C + C / 2, (y + 1) * C)
			"m":
				MapTiles.caps(c, x * C + C / 2, (y + 1) * C)
			"n":
				MapTiles.fern(c, x * C + C / 2, (y + 1) * C)

func _paint_life(c: CanvasItem) -> void:
	for prop: Array in _alive:
		var x: int = prop[1]
		var y: int = prop[2]
		if not _seen.has_point(Vector2(x * C + C / 2, y * C + C / 2) * S):
			continue
		match String(prop[0]):
			"F":
				MapTiles.fire_flames(c, x * C + C / 2, (y + 1) * C, _t, x + y)
			"m":
				MapTiles.caps_glow(c, x * C + C / 2, (y + 1) * C, _t, x)
			"*":
				MapTiles.fireflies(c, x, y, _t)

## --- glass -------------------------------------------------------------------------

## A pane over every cell of glass (`MapTiles.glass_pane`), a node to each
## kind: in front of the stretch of the tile field it is part of, and behind
## everything that stands in the room. A pane behind the ground goes only
## where no ground stands in front of it — the marks are drawn without the
## tile field (`Glazing`), so nothing there would cover it.
func _glaze() -> void:
	for old in glass:
		if is_instance_valid(old):
			old.queue_free()
	glass.clear()
	var ground := {"clear": Glass.of(Glass.Kind.CLEAR), "mirror": Glass.of(Glass.Kind.MIRROR)}
	var behind := {"clear": Glass.of(Glass.Kind.CLEAR), "mirror": Glass.of(Glass.Kind.BACK_MIRROR)}
	for y in cells.rows:
		for x in cells.cols:
			var kind := String(MapTiles.GLASS.get(cells.ground(x, y), ""))
			if kind != "":
				var laid := MapTiles.glass_pane(cells, x, y)
				(ground[kind] as Glass).pane(laid[0], laid[1])
			kind = String(MapTiles.GLASS.get(cells.back_at(x, y), ""))
			if kind != "" and not cells.solid(x, y):
				var hung := MapTiles.glass_pane(cells, x, y, true)
				(behind[kind] as Glass).pane(hung[0], hung[1])
	for place: Array in [[behind, -8], [ground, -7]]:
		for pane: Glass in (place[0] as Dictionary).values():
			if pane.panes() == 0:
				pane.free()
				continue
			pane.z_index = int(place[1])
			add_child(pane)
			glass.append(pane)

## Clear glass is no rock to the light. A lamp shines through it, so it throws
## no shadow; and what is beside it faces it as it faces the open air, so a lamp
## on the far side of it lights that face.
func _rock(x: int, y: int) -> bool:
	if cells != null and cells.holds(x, y) and MapTiles.GLASS.get(cells.ground(x, y), "") == "clear":
		return false
	return super._rock(x, y)

## --- moving ------------------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	_follow()
	_wake()
	for fire: Array in _fires:
		(fire[0] as Lamp).energy = float(MapTiles.FIRE_LIGHT["energy"]) * (0.75 + 0.35 * HideoutScenery.flicker(_t, int(fire[1])))
	_due -= delta
	if _due > 0.0:
		return
	_due = maxf(_due + 1.0 / REDRAWS, 0.0)
	_life.queue_redraw()
	for i in lanterns.size():
		if _cords[i].is_physics_processing():
			lanterns[i].t = _t
			lanterns[i].queue_redraw()
	for d in depths:
		if d.moves:
			d.t = _t
			d.queue_redraw()

## What the screen is near, woken, and what it has gone from, left: a line
## swings while the screen is within AWAKE of where it could swing to, and
## hangs as it was left while it is not. And a chunk of the tile field is
## drawn as the screen comes that near it, REVEALS of them a frame, and kept:
## so the biggest map is not all drawn on the frame it is first seen, nor a
## row of chunks all on the one frame the screen comes up to them. One the
## screen is already on is drawn there and then, however many that is.
func _wake() -> void:
	var cam := get_viewport().get_camera_2d()
	var at := cam.get_screen_center_position() if cam != null else _rest
	var view := get_viewport().get_visible_rect().size
	var screen := Rect2(at - view * 0.5, view).grow(Room.CELL)
	_seen = screen.grow(AWAKE)
	for i in mini(ropes.size(), _spans.size()):
		var awake := _seen.intersects(_spans[i])
		if ropes[i].is_physics_processing() != awake:
			ropes[i].set_physics_process(awake)
	var spare := REVEALS
	for chunk in chunks:
		if chunk.visible:
			continue
		var covers := Rect2(Vector2(chunk.area.position * Room.CELL), Vector2(chunk.area.size * Room.CELL))
		if screen.intersects(covers):
			chunk.visible = true
		elif spare > 0 and _seen.intersects(covers):
			chunk.visible = true
			spare -= 1

## The air is never quite still: it leans on every lantern and vine a little,
## each out of step with the rest — every one that is swinging.
func _physics_process(delta: float) -> void:
	for i in _cords.size():
		if _cords[i].is_physics_processing():
			_cords[i].nudge(_cords[i].nodes.size() - 1, Vector2(sin(_t * 0.9 + i * 2.3) * BREEZE * delta, 0.0))
	for i in _vines.size():
		if _vines[i].is_physics_processing():
			var tip := _vines[i].nodes.size() - 1
			_vines[i].nudge(tip, Vector2(sin(_t * 0.7 + i * 1.9) * BREEZE * 0.6 * delta, 0.0))
