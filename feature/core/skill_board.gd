class_name SkillBoard
extends RefCounted

## A grid of placed components plus the rules for placing them.
## Pure data: the simulation lives in SkillRunner.

signal changed()

var width: int = 7
var height: int = 5
var skill_name: String = "Skill"
var tags: Array[String] = []  ## used for weapon compatibility, derived on demand

## Vector2i -> { "id": String, "rot": int }. Only origin cells are stored here.
var cells: Dictionary = {}
## Vector2i -> Vector2i origin, for every covered cell (including origins).
var occupancy: Dictionary = {}

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

func can_place(id: String, origin: Vector2i, rot: int) -> bool:
	if not Components.exists(id):
		return false
	if id == "INPUT" and _count_of("INPUT") >= 1 and not (cells.has(origin) and cells[origin]["id"] == "INPUT"):
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

## Removes whatever covers `c` (clicking any cell of a two-cell part removes it).
func erase_at(c: Vector2i) -> String:
	var o = occupancy.get(c, null)
	if o == null:
		return ""
	var entry: Dictionary = cells[o]
	var id: String = entry["id"]
	for cc in Components.footprint(id, o, entry["rot"]):
		occupancy.erase(cc)
	cells.erase(o)
	changed.emit()
	return id

func find_input() -> Variant:
	for c in cells:
		if cells[c]["id"] == "INPUT":
			return c
	return null

func _count_of(id: String) -> int:
	var n := 0
	for c in cells:
		if cells[c]["id"] == id:
			n += 1
	return n

## id -> count of every non-structural component currently on the board.
func used_components() -> Dictionary:
	var used: Dictionary = {}
	for c in cells:
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
		"has_input": find_input() != null,
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
func trace() -> Dictionary:
	var reachable: Dictionary = {}
	var links: Array = []
	var breaks: Array = []
	var leaks: Array = []
	var input_cell = find_input()
	if input_cell == null:
		return {"reachable": reachable, "links": links, "breaks": breaks, "leaks": leaks,
			"has_input": false, "reaches_output": false}

	var reaches_output := false
	# Each part is queued the once, the first time the flow reaches it, so the
	# sweep is over when the board is — a ring is walked, not chased round.
	var queue: Array = [input_cell]
	reachable[input_cell] = true
	while not queue.is_empty():
		var origin: Vector2i = queue.pop_front()
		var entry: Dictionary = cells.get(origin, {})
		if entry.is_empty():
			continue
		var id: String = entry["id"]
		var rot: int = entry["rot"]
		if id == "OUTPUT":
			reaches_output = true
			continue
		var ex := Components.exit_cell(id, origin, rot)
		var dirs: Array = Components.world_outputs(id, rot)
		var pd := Components.world_payload_out(id, rot)
		if pd >= 0:
			dirs = dirs + [pd]
		for d in dirs:
			var target: Vector2i = ex + Components.dir_to_vec(d)
			if not in_bounds(target):
				leaks.append({"from": ex, "dir": d, "why": "edge"})
				continue
			var t: Dictionary = comp_origin_at(target)
			if t.is_empty():
				var occ = occupancy.get(target, null)
				if occ == null:
					leaks.append({"from": ex, "dir": d, "why": "empty"})
				else:
					# Ran into the tail half of a two-cell part, which has no port.
					breaks.append({"from": ex, "to": target, "dir": d,
						"id": String(cells[occ]["id"]), "why": "side"})
				continue
			if not Components.world_inputs(t["id"], t["rot"]).has(Components.opposite(d)):
				breaks.append({"from": ex, "to": target, "dir": d,
					"id": String(t["id"]), "why": "facing"})
				continue
			links.append([ex, target])
			if not reachable.has(target):
				reachable[target] = true
				queue.append(target)
	return {"reachable": reachable, "links": links, "breaks": breaks, "leaks": leaks,
		"has_input": true, "reaches_output": reaches_output}

## The first thing wrong with this board, phrased for the player.
func first_problem() -> String:
	var t := trace()
	if not bool(t["has_input"]):
		return "No INPUT placed — the flow has nowhere to start."
	var breaks: Array = t["breaks"]
	if not breaks.is_empty():
		var b: Dictionary = breaks[0]
		var to: Vector2i = b["to"]
		if String(b["why"]) == "side":
			return "%s at %d,%d is entered through its tail. Flow can only go in the head cell." % [
				Components.get_def(b["id"]).get("name", b["id"]), to.x, to.y]
		# The only join that cannot carry flow is two outputs meeting head-on.
		return "%s at %d,%d sends its own flow back this way. Two outputs cannot meet." % [
			Components.get_def(b["id"]).get("name", b["id"]), to.x, to.y]
	var leaks: Array = t["leaks"]
	if not leaks.is_empty():
		var l: Dictionary = leaks[0]
		var f: Vector2i = l["from"]
		return "The flow leaves %d,%d heading %s and finds nothing there." % [
			f.x, f.y, Components.dir_name(int(l["dir"]))]
	if not bool(t["reaches_output"]):
		return "The chain never reaches an OUTPUT."
	return "The flow reaches an OUTPUT, but no attack form is on the path."

## Tags describe what a board does, which is what weapons check for compatibility.
func compute_tags() -> Array[String]:
	var t: Array[String] = []
	for c in cells:
		var id: String = cells[c]["id"]
		match id:
			"PROJECTILE": t.append("ranged")
			"SLASH", "DASHSLASH", "DASHSLASH_AUTO": t.append("melee")
			"AREA": t.append("area")
			"DASH", "BLINK": t.append("mobility")
			"ON_HIT", "ON_KILL", "ON_PARRY": t.append("trigger")
	var uniq: Array[String] = []
	for x in t:
		if not uniq.has(x):
			uniq.append(x)
	return uniq

func is_empty() -> bool:
	return cells.is_empty()

func serialize() -> Dictionary:
	var out: Array = []
	for c in cells:
		out.append({"x": c.x, "y": c.y, "id": cells[c]["id"], "rot": cells[c]["rot"]})
	return {"w": width, "h": height, "name": skill_name, "cells": out}

static func deserialize(d: Dictionary) -> SkillBoard:
	var b := SkillBoard.new(int(d.get("w", 7)), int(d.get("h", 5)), String(d.get("name", "Skill")))
	for e in d.get("cells", []):
		b.place(String(e["id"]), Vector2i(int(e["x"]), int(e["y"])), int(e["rot"]))
	return b

func duplicate_board() -> SkillBoard:
	return SkillBoard.deserialize(serialize())

## Grows the grid (hideout workbench upgrades do this).
func resize_grid(w: int, h: int) -> void:
	width = max(width, w)
	height = max(height, h)
	changed.emit()
