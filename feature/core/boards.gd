class_name Boards
extends RefCounted

## The skill boards the game ships with, read from the content database and
## built into the `SkillBoard`s the circuit runs: the rows of `boards` and
## `board_parts` (see `data/db/README.md`). Each weapon's own graph as a new
## profile gets it, every monster's, and the dragon test's are here. What a
## player builds onto a weapon's graph is theirs, and lives in the save.
##
## A board is its grid and the parts placed on it. Which part feeds which is
## written down nowhere: the parts' ports and the way each faces already say
## it, and `SkillBoard.trace` walks it. Where the flow starts is the root cell
## (`SkillBoard.ROOT`), and every board here has a part standing on it.
##
## Nothing here falls back. A board that is not in the table comes back with
## nothing on it, a part that cannot go where its row puts it — off the grid,
## over another — is left off, and a board with nothing on its root is a board
## that never fires; `problems` says which, and `build` says so loudly. A
## weapon or a monster cannot fight with half a board, and would do it without
## a word if nobody looked.

## Every board in the table, by id.
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for r in Db.rows("SELECT id FROM boards ORDER BY id"):
		out.append(String(r["id"]))
	return out

## A board as the table has it: the `boards` row, with its `parts` under it in
## the order they are listed, each {x, y, part, facing}. Empty when there is
## no such board.
static func source(id: String) -> Dictionary:
	var found := Db.records("boards", "id = ?", [id])
	if found.is_empty():
		return {}
	var def: Dictionary = found[0]
	def["parts"] = Db.records("board_parts", "board_id = ?", [id], "rowid")
	return def

## Builds `id`, called `name` — or, with none given, what the table calls it,
## or its id.
static func build(id: String, name: String = "") -> SkillBoard:
	var def := source(id)
	if def.is_empty():
		push_error("Boards: no board called '%s' in %s" % [id, Db.PATH])
		return SkillBoard.new(7, 5, name if name != "" else id)
	var laid := _lay(def, name)
	for problem in laid[1]:
		push_error("Boards: the %s board — %s" % [id, problem])
	return laid[0]

## The parts on `id`, each once, in the order they are listed — what a monster
## can drop is what it was seen using.
static func parts_of(id: String) -> Array:
	var out: Array = []
	for p in source(id).get("parts", []):
		var part := String(p.get("part", ""))
		if not out.has(part):
			out.append(part)
	return out

## Mistakes in a board that would otherwise show as a part missing from it.
static func problems(id: String) -> Array:
	var def := source(id)
	if def.is_empty():
		return ["no board called '%s' in %s" % [id, Db.PATH]]
	return problems_in(def)

## The same check against a board already in hand, in the shape `source`
## returns, so it can be put in front of a deliberately broken one.
static func problems_in(def: Dictionary) -> Array:
	return _lay(def, "")[1]

## `def` laid out on a board, and what would not go where it was put.
static func _lay(def: Dictionary, name: String) -> Array:
	var board := SkillBoard.new(int(def.get("width", 7)), int(def.get("height", 5)),
		name if name != "" else String(def.get("name", def.get("id", ""))))
	var wrong: Array = []
	for p in def.get("parts", []):
		var part := String(p.get("part", ""))
		var at := Vector2i(int(p.get("x", 0)), int(p.get("y", 0)))
		var facing := String(p.get("facing", "E"))
		var where := "%s at %d,%d facing %s" % [part, at.x, at.y, facing]
		if not Components.exists(part):
			wrong.append("%s: there is no such part" % where)
		elif Components.side(facing) < 0:
			wrong.append("%s: that is no way to face" % where)
		# `place` would take a part dropped on another's cell as the editor's
		# replace; in a table it is two parts in one cell, so it is refused.
		elif board.origin_at(at) != null or not board.place(part, at, Components.side(facing)):
			wrong.append("%s: it does not fit — off the grid, or over another part" % where)
	if not board.has_root():
		wrong.append("nothing stands on the root cell %d,%d, so the flow has nowhere to start"
			% [board.root.x, board.root.y])
	return [board, wrong]
