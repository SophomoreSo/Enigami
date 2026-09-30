class_name SkillBoard
extends RefCounted

## A grid of placed components plus the rules for placing them.
## Pure data: the simulation lives in SkillRunner.
##
## Every board is rooted. The flow starts at `root`, the cell the weapon's own
## part sits in — the sword's DASHSLASH, the gun's PROJECTILE, a monster's
## SLASH — and whatever sits there is the source of every cycle. It is the one
## part nobody may lift, turn or drop something on: it is the weapon's, not the
## build's, and the build is everything wired on after it. There is no INPUT
## part any more; the root stands where INPUT stood.

signal changed()

## Where every board starts, on every grid the game makes: the left edge, on
## the middle row of the 7x5 the game ships and the third row of anything
## taller. One cell for all of them rather than a cell each, so a build shared
## as a code lands on any weapon's board with its wiring where its author had
## it, and that weapon's own part already there to feed it.
const ROOT := Vector2i(0, 2)

var width: int = 7
var height: int = 5
var skill_name: String = "Skill"

## Vector2i -> { "id": String, "rot": int }. Only origin cells are stored here.
var cells: Dictionary = {}
## Vector2i -> Vector2i origin, for every covered cell (including origins).
var occupancy: Dictionary = {}
## The cell the flow starts in. `ROOT` on every board the game makes; a test
## may root a board somewhere else to try a shape.
var root: Vector2i = ROOT

func _init(w: int = 7, h: int = 5, n: String = "Skill") -> void:
	width = w
	height = h
	skill_name = n

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height

func origin_at(c: Vector2i) -> Variant:
	return occupancy.get(c, null)

func comp_at(c: Vector2i) -> Dictionary:
	var o = occupancy.get(c, null)
	if o == null:
		return {}
	return cells.get(o, {})

## Component whose ORIGIN is exactly this cell (flows may only enter at origins).
func comp_origin_at(c: Vector2i) -> Dictionary:
	return cells.get(c, {})

## --- the root ---------------------------------------------------------------

## Whether the part filed under `origin` is the root: the weapon's own part.
func is_root(origin: Vector2i) -> bool:
	return origin == root and cells.has(root)

func has_root() -> bool:
	return cells.has(root)

## The root's cell, or null while nothing sits there.
func find_root() -> Variant:
	return root if cells.has(root) else null

## The part at the root: {id, rot}, or {} while nothing sits there.
func root_entry() -> Dictionary:
	return cells.get(root, {})

## Roots the board at `at` with `id`, facing `rot`. Whatever was the root
## before goes, and so does anything standing where the new one will: this is
## for whoever makes a board — a weapon, a monster, a test — not for a hand on
## the workbench, which never touches the root at all.
func set_root(id: String, at: Vector2i = ROOT, rot: int = 0) -> bool:
	if not Components.exists(id):
		return false
	var cover := Components.footprint(id, at, rot)
	for c in cover:
		if not in_bounds(c):
			return false
	if cells.has(root):
		_erase_origin(root)
	root = at
	for c in cover:
		var o = occupancy.get(c, null)
		if o != null:
			_erase_origin(o)
	cells[at] = {"id": id, "rot": rot}
	for c in cover:
		occupancy[c] = at
	changed.emit()
	return true

## --- placing ----------------------------------------------------------------

func can_place(id: String, origin: Vector2i, rot: int) -> bool:
	if not Components.exists(id):
		return false
	# The root is the weapon's: nothing is dropped on it. It is placed once,
	# onto an empty root cell, by whoever roots the board — and then it stays.
	if origin == root and cells.has(root):
		return false
	for c in Components.footprint(id, origin, rot):
		if not in_bounds(c):
			return false
		var o = occupancy.get(c, null)
		if o != null and o != origin:
			return false
	return true

func place(id: String, origin: Vector2i, rot: int) -> bool:
	if not can_place(id, origin, rot):
		return false
	erase_at(origin)
	cells[origin] = {"id": id, "rot": rot}
	for c in Components.footprint(id, origin, rot):
		occupancy[c] = origin
	changed.emit()
	return true

## Removes whatever covers `c` (clicking any cell of a two-cell part removes
## it), and says what it was — or "" for an empty cell, and for the root, which
## is never removed this way.
func erase_at(c: Vector2i) -> String:
	var o = occupancy.get(c, null)
	if o == null or o == root:
		return ""
	return _erase_origin(o)

## The part filed under `o`, taken off the board, root or not.
func _erase_origin(o: Vector2i) -> String:
	var entry: Dictionary = cells.get(o, {})
	if entry.is_empty():
		return ""
	var id: String = entry["id"]
	for cc in Components.footprint(id, o, entry["rot"]):
		occupancy.erase(cc)
	cells.erase(o)
	changed.emit()
	return id

func _count_of(id: String) -> int:
	var n := 0
	for c in cells:
		if cells[c]["id"] == id:
			n += 1
	return n

## id -> count of every non-structural component the build put on the board.
## The root is not among them: it is the weapon's, and neither came out of a
## pool nor goes back into one.
func used_components() -> Dictionary:
	var used: Dictionary = {}
	for c in cells:
		if c == root:
			continue
		var id: String = cells[c]["id"]
		if Components.is_structural(id):
			continue
		used[id] = int(used.get(id, 0)) + 1
	return used

## Static properties the runner and the editor both need.
##
## Overclock speeds the board's clock up and charges a settling delay between
## cycles. The delay is real time, deliberately NOT measured in ticks: a cost
## denominated in ticks would be shrunk by the very speed-up it is meant to pay
## for, and the two would cancel out.
func analyze() -> Dictionary:
	var oc := _count_of("OVERCLOCK")
	# Each stack adds less than the one before, so the sum converges and speed
	# stays bounded however many are placed.
	var speed := 1.0
	var gain := 0.5
	for i in oc:
		speed += gain
		gain *= 0.85
	# The delay grows with the square of the count, so it overtakes the speed
	# gain after a handful: a few pay off, a wall of them does not.
	var penalty := 0.004 * float(oc) * float(oc)
	var forms := 0
	for c in cells:
		if Components.get_def(cells[c]["id"]).get("cat", "") == Components.CAT_FORM:
			forms += 1
	return {
		"overclock": oc,
		"speed_mul": speed,
		"penalty_seconds": penalty,
		"forms": forms,
		"cells_used": occupancy.size(),
		"has_root": has_root(),
	}

## Walks the board exactly as the runner will, reporting what is actually
## wired up. This is what lets the editor show a break instead of leaving the
## player to work out why a board that looks connected produces nothing.
##
## Returns:
##   reachable  origin -> true, for every part the flow can actually get to
##   links      [exit_cell, entry_cell] pairs that genuinely carry flow
##   breaks     joints where two parts touch but the receiving port faces away
##   leaks      places where the flow runs into empty space or off the board
##   dead       origin -> true, for every part caught in a loop with no way out
##   dead_links the links inside those loops, so the editor can draw one round
##              them instead of a box round each
func trace() -> Dictionary:
	var reachable: Dictionary = {}
	var links: Array = []
	var breaks: Array = []
	var leaks: Array = []
	# A loop is a property of the wiring and not of what the root happens to
	# reach, so it is found over the whole board and before the walk below.
	# Every link out of a caught part stays inside its loop — that is what being
	# caught means — so its ports are exactly the loop's own seams.
	var dead := dead_loops()
	var dead_links: Array = []
	for origin in dead:
		for port in _ports_from(origin):
			if String(port["why"]) == "":
				dead_links.append([port["from"], port["to"]])
	var start = find_root()
	if start == null:
		return {"reachable": reachable, "links": links, "breaks": breaks, "leaks": leaks,
			"dead": dead, "dead_links": dead_links,
			"has_root": false, "reaches_output": false}

	var reaches_output := false
	# Each part is queued the once, the first time the flow reaches it, so the
	# sweep is over when the board is — a ring is walked, not chased round.
	var queue: Array = [start]
	reachable[start] = true
	while not queue.is_empty():
		var origin: Vector2i = queue.pop_front()
		var entry: Dictionary = cells.get(origin, {})
		if entry.is_empty():
			continue
		if String(entry["id"]) == "OUTPUT":
			reaches_output = true
			continue
		for port in _ports_from(origin):
			var why := String(port["why"])
			if why == "edge" or why == "empty":
				leaks.append(port)
				continue
			if why != "":
				breaks.append(port)
				continue
			var to: Vector2i = port["to"]
			links.append([port["from"], to])
			if not reachable.has(to):
				reachable[to] = true
				queue.append(to)
	return {"reachable": reachable, "links": links, "breaks": breaks, "leaks": leaks,
		"dead": dead, "dead_links": dead_links,
		"has_root": true, "reaches_output": reaches_output}

## Where one part's ports lead, a port at a time. Every entry carries `from` —
## the cell the flow leaves by, which on a two-cell part is not the cell the
## part is filed under — and `dir`, the way it goes. A port that lands on a part
## also carries `to`, that part's origin, and `id`. `why` is what stopped the
## flow, or "" when nothing did:
##
##   edge    the board runs out
##   empty   there is nothing there
##   side    the tail half of a two-cell part, which has no port
##   facing  the receiving part sends its own flow back this way
##
## One place knows how a port resolves, so the walk above and the loop check
## below cannot come to different answers about the same joint.
func _ports_from(origin: Vector2i) -> Array:
	var entry: Dictionary = cells.get(origin, {})
	if entry.is_empty():
		return []
	var id: String = entry["id"]
	var rot: int = entry["rot"]
	var ex := Components.exit_cell(id, origin, rot)
	var dirs: Array = Components.world_outputs(id, rot)
	var pd := Components.world_payload_out(id, rot)
	if pd >= 0:
		dirs = dirs + [pd]
	var out: Array = []
	for d in dirs:
		var target: Vector2i = ex + Components.dir_to_vec(d)
		if not in_bounds(target):
			out.append({"from": ex, "dir": d, "why": "edge"})
			continue
		var t: Dictionary = comp_origin_at(target)
		if t.is_empty():
			var occ = occupancy.get(target, null)
			if occ == null:
				out.append({"from": ex, "dir": d, "why": "empty"})
			else:
				out.append({"from": ex, "to": target, "dir": d,
					"id": String(cells[occ]["id"]), "why": "side"})
			continue
		if not Components.world_inputs(String(t["id"]), int(t["rot"])).has(Components.opposite(d)):
			out.append({"from": ex, "to": target, "dir": d,
				"id": String(t["id"]), "why": "facing"})
			continue
		out.append({"from": ex, "to": target, "dir": d, "id": String(t["id"]), "why": ""})
	return out

## Every part caught in a loop the flow can never leave, as origin -> true.
##
## A part is caught when it can reach itself and everything it can reach can
## reach it back: whatever goes in goes round and round, and nothing past it
## ever sees anything. A ring with a branch out of it is not caught — that
## branch is where the flow leaves, and a ring running its payload back through
## its own stat parts on the way to an OUTPUT is the whole point of building
## one.
##
## Read off the whole board rather than out from the root, because a ring with
## nothing feeding it is the same trap with nothing in it yet.
##
## The exception is a part that does its work on the way in rather than at an
## OUTPUT — TIME DILATION, ON PARRY. A loop with one of those in it fires it
## once a lap for as long as the pulse's life holds out, so the parts round it
## are working, not dead.
func dead_loops() -> Dictionary:
	var out: Dictionary = {}
	var links: Dictionary = {}
	for origin in cells:
		var to: Array = []
		for port in _ports_from(origin):
			if String(port["why"]) == "":
				to.append(port["to"])
		links[origin] = to
	# What each part leads to, however far away. A board is a few dozen cells at
	# most, so this is one walk per part and no cleverness.
	var reach: Dictionary = {}
	for origin in cells:
		reach[origin] = _reach_from(links, origin)
	for origin in cells:
		var seen: Dictionary = reach[origin]
		if not seen.has(origin):
			continue                                    # not on a loop at all
		var trapped := true
		for other in seen:
			if not (reach[other] as Dictionary).has(origin):
				trapped = false                         # and there is the way out
				break
			if Components.acts_on_entry(String(cells[other]["id"])):
				trapped = false                         # going nowhere, but working
				break
		if trapped:
			out[origin] = true
	return out

## Everything `start` leads to, directly or through others. Seeded with what
## `start` links to rather than with `start` itself, so a part turns up in its
## own answer only when the wiring really does come back round to it.
static func _reach_from(links: Dictionary, start: Vector2i) -> Dictionary:
	var seen: Dictionary = {}
	var queue: Array = (links.get(start, []) as Array).duplicate()
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		if seen.has(at):
			continue
		seen[at] = true
		queue.append_array(links.get(at, []))
	return seen

## Tags describe what a board does: the `tag` of every part on it, once each.
## The share sheet reads them to say what a code builds.
func compute_tags() -> Array[String]:
	var t: Array[String] = []
	for c in cells:
		var tag := String(Components.get_def(String(cells[c]["id"])).get("tag", ""))
		if tag != "" and not t.has(tag):
			t.append(tag)
	return t

func is_empty() -> bool:
	return cells.is_empty()

func serialize() -> Dictionary:
	var out: Array = []
	for c in cells:
		out.append({"x": c.x, "y": c.y, "id": cells[c]["id"], "rot": cells[c]["rot"]})
	return {"w": width, "h": height, "name": skill_name, "root": [root.x, root.y], "cells": out}

static func deserialize(d: Dictionary) -> SkillBoard:
	var b := SkillBoard.new(int(d.get("w", 7)), int(d.get("h", 5)), String(d.get("name", "Skill")))
	var at: Array = d.get("root", [])
	if at.size() == 2:
		b.root = Vector2i(int(at[0]), int(at[1]))
	var retired: Array = []
	for e in d.get("cells", []):
		var id := Components.current_id(String(e["id"]))
		var cell := Vector2i(int(e["x"]), int(e["y"]))
		if Components.is_retired(id):
			retired.append([id, cell, int(e["rot"])])
			continue
		b.place(id, cell, int(e["rot"]))
	b.drop_retired(retired)
	return b

## Reads a board back from before WIRE, BEND and INPUT were retired, out of a
## save or a code. `retired` is every one of them it carried, as [id, cell,
## rot], and none is placed. A WIRE or a BEND was one cell of path and nothing
## more, so where one sat against the OUTPUT it fed, and nothing else on the
## board was joined to that OUTPUT, the OUTPUT steps into its cell: the flow
## goes exactly where it went, a cell sooner. Anywhere else the cell is left
## empty, and the board shows the break the way it shows any other. An INPUT's
## cell is simply left empty: the root stands where it stood.
func drop_retired(retired: Array) -> void:
	var left := retired.duplicate()
	var stepped := true
	# Again until nothing moves: a run of them closes up a cell at a time.
	while stepped:
		stepped = false
		for r in left.duplicate():
			var out := Components.rotate_dir(Components.retired_out(String(r[0])), int(r[2]))
			if _step_into(r[1], out):
				left.erase(r)
				stepped = true

## An OUTPUT ahead of `at` moving into it, the empty cell a retired part sending
## its flow `out` used to fill. False, with nothing moved, when it cannot.
func _step_into(at: Vector2i, out: int) -> bool:
	if occupancy.has(at) or at == root:
		return false
	var ahead := at + Components.dir_to_vec(out)
	var next := comp_origin_at(ahead)
	if String(next.get("id", "")) == "OUTPUT" and _arriving(ahead).is_empty():
		var rot := int(next["rot"])
		erase_at(ahead)
		return place("OUTPUT", at, rot)
	return false

## Every part whose flow lands on `cell`, as [origin, the way it is going].
func _arriving(cell: Vector2i) -> Array:
	var out: Array = []
	for origin in cells:
		for port in _ports_from(origin):
			if port["from"] + Components.dir_to_vec(int(port["dir"])) == cell:
				out.append([origin, int(port["dir"])])
	return out

func duplicate_board() -> SkillBoard:
	return SkillBoard.deserialize(serialize())

## Whether every part of `other` would land inside this board's grid. The grid
## belongs to the workbench that grew it, not to the build drawn on it, so a
## board that came off a bigger one fits only if nothing hangs over the edge.
func fits(other: SkillBoard) -> bool:
	for origin in other.cells:
		var entry: Dictionary = other.cells[origin]
		for c in Components.footprint(String(entry["id"]), origin, int(entry["rot"])):
			if not in_bounds(c):
				return false
	return true

## The parts of `other` that would come onto this board, as [id, origin, rot]:
## everything of it that lands inside the grid and clear of this board's own
## root. A shared build carries its author's root along with the rest — it is
## a part on their board like any other — and here that cell is already the
## weapon's, so whatever the code has standing on it stays behind.
func adoptable(other: SkillBoard) -> Array:
	var taken := {}
	var mine := root_entry()
	if not mine.is_empty():
		for c in Components.footprint(String(mine["id"]), root, int(mine["rot"])):
			taken[c] = true
	var out: Array = []
	for origin in other.cells:
		var entry: Dictionary = other.cells[origin]
		var id := String(entry["id"])
		var rot := int(entry["rot"])
		var clear := true
		for c in Components.footprint(id, origin, rot):
			if not in_bounds(c) or taken.has(c):
				clear = false
		if clear:
			out.append([id, origin, rot])
	return out

## What taking `other` on would cost from a pool: id -> how many of each part
## that would come onto the board, the structural ones left out, since they are
## never spent.
func adoption_cost(other: SkillBoard) -> Dictionary:
	var need: Dictionary = {}
	for part in adoptable(other):
		var id := String(part[0])
		if Components.is_structural(id):
			continue
		need[id] = int(need.get(id, 0)) + 1
	return need

## Takes on `other`'s parts, keeping this board's own grid, its own name and
## its own root — which is what a shared code hands over: a circuit, not the
## workbench it was drawn on, not what its author called it, and not the weapon
## it was built onto.
##
## All or nothing: a build that does not fit leaves this board exactly as it
## was. The parts are moved across rather than re-`place`d because `other` is
## already a board — its footprints are clear of each other — so the only thing
## that could have been wrong is the grid, and `fits` has just settled that;
## what stood on the root's cells is left behind, see `adoptable`.
func adopt(other: SkillBoard) -> bool:
	if not fits(other):
		return false
	for origin in cells.keys().duplicate():
		if origin != root:
			_erase_origin(origin)
	for part in adoptable(other):
		var id := String(part[0])
		var origin: Vector2i = part[1]
		var rot := int(part[2])
		cells[origin] = {"id": id, "rot": rot}
		for c in Components.footprint(id, origin, rot):
			occupancy[c] = origin
	changed.emit()
	return true

## Grows the grid (hideout workbench upgrades do this).
func resize_grid(w: int, h: int) -> void:
	width = max(width, w)
	height = max(height, h)
	changed.emit()
