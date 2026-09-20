class_name PixelDraw
extends RefCounted

## Drawing on the pixel grid, for a screen that draws itself rather than being
## built out of Controls. `UiKit`'s pixel look is the same thing for the ones
## that are built out of Controls, and the two have to agree: the same face at
## the same size, the same square unsmoothed borders a whole PIXEL wide.
##
## Everything here snaps to that grid. An edge half a PIXEL off puts a stroke
## across two rows of it instead of on one, which is the whole difference
## between pixel art and a smooth picture of pixel art.
##
## Bound to one CanvasItem and kept by it:
##
##     var _px := PixelDraw.new(self)
##     _px.rect(Rect2(0, 0, 100, 20), Color.BLACK)
##
## Screens using it: `SkillEditor`, `SandboxPanel`, `Hud`, and the hideout's
## station signs — which draw it over the world rather than on a screen, and say
## in `HideoutWorldView` why the words cannot go into the world itself.

const PX := UiKit.PIXEL
const FONT := UiKit.PIXEL_FONT
const SIZE := UiKit.PIXEL_TEXT
## Baseline to baseline. Capitals stand 10px tall at PIXEL_TEXT and nothing in
## the face descends, so this leaves 10px clear between rows.
const LINE := 20.0

var _c: CanvasItem

func _init(c: CanvasItem) -> void:
	_c = c

func snap(p: Vector2) -> Vector2:
	return (p / PX).floor() * PX

func rect(r: Rect2, col: Color) -> void:
	var a := snap(r.position)
	_c.draw_rect(Rect2(a, snap(r.end) - a), col)

## A border one PIXEL wide, inside `r`. Four rects rather than an unfilled
## draw_rect, whose corners overlap and double up a translucent colour.
func frame(r: Rect2, col: Color) -> void:
	var a := snap(r.position)
	var z := snap(r.end)
	_c.draw_rect(Rect2(a.x, a.y, z.x - a.x, PX), col)
	_c.draw_rect(Rect2(a.x, z.y - PX, z.x - a.x, PX), col)
	_c.draw_rect(Rect2(a.x, a.y + PX, PX, z.y - a.y - 2 * PX), col)
	_c.draw_rect(Rect2(z.x - PX, a.y + PX, PX, z.y - a.y - 2 * PX), col)

## A filled diamond centred on `c`, `radius` PIXELs from its middle to each point.
func diamond(c: Vector2, radius: int, col: Color) -> void:
	var mid := snap(c - Vector2.ONE * PX * 0.5)
	for dy in range(-radius, radius + 1):
		var half := radius - absi(dy)
		_c.draw_rect(Rect2(mid.x - half * PX, mid.y + dy * PX, (2 * half + 1) * PX, PX), col)

## The border of `r` lit clockwise from the middle of its top edge, `k` of the
## way round. Each side after the first starts a PIXEL past its corner, so no
## corner is lit twice and doubled up in a translucent colour.
func lap(r: Rect2, k: float, col: Color) -> void:
	var a := snap(r.position)
	var z := snap(r.end) - Vector2.ONE * PX
	var top := Vector2(snap(Vector2((a.x + z.x) * 0.5, 0.0)).x, a.y)
	var corners := [top, Vector2(z.x, a.y), z, Vector2(a.x, z.y), a, top]
	var total := 0.0
	for i in 5:
		var seg: Vector2 = corners[i + 1] - corners[i]
		total += absf(seg.x) + absf(seg.y)
	var lit := int(clampf(k, 0.0, 1.0) * total / PX)
	for i in 5:
		var seg: Vector2 = corners[i + 1] - corners[i]
		var steps := int((absf(seg.x) + absf(seg.y)) / PX)
		if steps == 0:
			continue
		var d := seg / float(steps)
		var start: Vector2 = corners[i] if i == 0 else corners[i] + d
		var n := mini(steps + (1 if i == 0 else 0), lit)
		if n <= 0:
			return
		var end := start + d * (n - 1)
		var lo := Vector2(minf(start.x, end.x), minf(start.y, end.y))
		_c.draw_rect(Rect2(lo, (start - end).abs() + Vector2.ONE * PX), col)
		lit -= n

## A meter: `ratio` of `r` filled, on its own ground, inside a one-PIXEL edge.
func bar(r: Rect2, ratio: float, fill: Color, ground: Color, edge: Color) -> void:
	rect(r, ground)
	rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y)), fill)
	frame(r, edge)

## The cooldown state a skill slot shows, on the grid: `UiKit.draw_cooldown` is
## the same thing drawn smooth, and carries why it looks the way it does. The
## flash thickens the edge by a PIXEL rather than growing a line width, which at
## this size is the only way to thicken anything.
func cooldown(r: Rect2, progress: float, flash: float, border: Color) -> void:
	var p := clampf(progress, 0.0, 1.0)
	if p < 1.0:
		var top := snap(Vector2(0.0, r.position.y + r.size.y * p)).y
		rect(Rect2(r.position.x, top, r.size.x, r.end.y - top), Color(0.55, 0.58, 0.65, 0.55))
		rect(Rect2(r.position.x, top, r.size.x, PX), Color(0.85, 0.9, 1.0, 0.75))
	var f := clampf(flash, 0.0, 1.0)
	var edge := border.lerp(Color(1, 1, 1), f * 0.85)
	frame(r, edge)
	if f > 0.2:
		frame(r.grow(-PX), edge)

## A bitmap — one string per row, `#` for a PIXEL — with its top-left at `at`,
## each bitmap pixel `zoom` PIXELs square. Each run along a row goes down as one
## rect.
func icon(at: Vector2, rows: Array, col: Color, zoom: int = 1) -> void:
	var o := snap(at)
	var s := PX * zoom
	for y in rows.size():
		var row := String(rows[y])
		var x := row.find("#")
		while x >= 0:
			var end := x
			while end < row.length() and row[end] == "#":
				end += 1
			_c.draw_rect(Rect2(o.x + x * s, o.y + y * s, (end - x) * s, s), col)
			x = row.find("#", end)

func icon_centered(c: Vector2, rows: Array, col: Color, zoom: int = 1) -> void:
	icon(c - Vector2(String(rows[0]).length(), rows.size()) * PX * zoom * 0.5, rows, col, zoom)

## A bitmap turned `steps` quarter turns clockwise.
static func turn(rows: Array, steps: int) -> Array:
	var out := rows
	for s in posmod(steps, 4):
		var turned: Array = []
		for x in String(out[0]).length():
			var line := ""
			for y in range(out.size() - 1, -1, -1):
				line += String(out[y])[x]
			turned.append(line)
		out = turned
	return out

## `text` in the pixel face, its baseline at `pos`, cut short with an ellipsis
## when it is wider than `width`.
func text(pos: Vector2, s: String, col: Color, width: float = -1.0) -> void:
	if width > 0.0:
		s = clip(s, width)
	_c.draw_string(FONT, snap(pos), s, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, col)

## The same, centred in `width` from `pos`.
func text_centered(pos: Vector2, s: String, col: Color, width: float) -> void:
	s = clip(s, width)
	text(pos + Vector2((width - ink_width(s)) * 0.5, 0.0), s, col)

static func text_width(s: String) -> float:
	return FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x

## The width of the letters alone: every advance carries a PIXEL of space after
## its letter, which would push anything centred on it off by half of one.
static func ink_width(s: String) -> float:
	return text_width(s) - PX

static func clip(s: String, width: float) -> String:
	if text_width(s) <= width:
		return s
	var lo := 0
	var hi := s.length()
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if text_width(s.left(mid) + "…") <= width:
			lo = mid
		else:
			hi = mid - 1
	return s.left(lo).strip_edges(false, true) + "…"

## `text` broken at spaces into rows no wider than `width`, at most `most` of
## them; the last row ends in an ellipsis if words were left over.
static func wrap(s: String, width: float, most: int) -> PackedStringArray:
	var words := s.split(" ", false)
	var rows := PackedStringArray()
	var row := ""
	for i in words.size():
		var trial := words[i] if row == "" else row + " " + words[i]
		if row == "" or text_width(trial) <= width:
			row = trial
		elif rows.size() == most - 1:
			rows.append(clip(row + " " + " ".join(words.slice(i)), width))
			return rows
		else:
			rows.append(row)
			row = words[i]
	if row != "":
		rows.append(row)
	return rows
