extends Node

## The perks: what a player buys for themselves with gold and keeps, a step at
## a time. The content database's `perks` and `perk_steps` say what each is and
## what its steps cost (see `data/db/README.md`); the profile keeps how many
## steps of each it has bought (`GameState.perks`); this buys the next one.
##
## A perk raises one of the player's own numbers — its stat — by as much again
## for every step bought. Its steps are bought in order, each for its own price,
## and any perk can be the first one started. What a stat does is the game's
## rules': the perks hand what they add to `GameState.boost`, which the rules
## ask, and the rules never name them. That is the one way in, so the perks can
## be changed — a step dearer, a perk more — without a rule changing under them.
##
## The page they are bought on is the module's other half, perks/view
## (`PerkPage`). Nothing here draws.

## id -> {name, stat, per_step, desc, costs}, in the order the page lists them:
## the table's. `name` and `desc` are the English, under the translations.
var _defs: Dictionary = {}

func _ready() -> void:
	_read()
	GameState.boost_sources.append(boost)

## Every perk, in the order the page lists them.
func ids() -> Array:
	return _defs.keys()

func exists(id: String) -> bool:
	return _defs.has(id)

## What the table says of `id`: {name, stat, per_step, desc, costs}, or empty.
func get_def(id: String) -> Dictionary:
	return _defs.get(id, {})

## What to call a perk, and what to say it does, in the language being played.
## The table's English is the fallback under both.
func name_for(id: String) -> String:
	return Loc.opt("perks.%s.name" % id, String(get_def(id).get("name", id)))

func desc_for(id: String) -> String:
	return Loc.opt("perks.%s.desc" % id, String(get_def(id).get("desc", "")))

## How many steps `id` has.
func steps(id: String) -> int:
	return (get_def(id).get("costs", []) as Array).size()

## How many of them the profile has bought.
func owned(id: String) -> int:
	return clampi(int(GameState.perks.get(id, 0)), 0, steps(id))

## What the next step of `id` costs in gold, or -1 once every step is bought.
func next_cost(id: String) -> int:
	var n := owned(id)
	if n >= steps(id):
		return -1
	return int(get_def(id)["costs"][n])

## Whether the next step of `id` can be bought: there is one, and the gold for it.
func can_buy(id: String) -> bool:
	var cost := next_cost(id)
	return cost >= 0 and GameState.scrap >= cost

## Buys the next step of `id`. The gold goes, the step is the profile's and is
## kept at once — a step bought is never lost to a quit — and whatever holds
## one of the player's numbers takes it again (`GameState.boosts_changed`),
## so it reaches the body standing in the hideout there and then. Whether it
## was bought.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	GameState.scrap -= next_cost(id)
	GameState.perks[id] = owned(id) + 1
	GameState.save_game()
	GameState.stash_changed.emit()
	GameState.boosts_changed.emit()
	return true

## What the steps bought add to `stat`, for `GameState.boost`.
func boost(stat: String) -> float:
	var total := 0.0
	for id in _defs:
		if String(_defs[id]["stat"]) == stat:
			total += float(_defs[id]["per_step"]) * float(owned(id))
	return total

## --- reading the tables -------------------------------------------------------

func _read() -> void:
	_defs.clear()
	for row in Db.records("perks", "", [], "rowid"):
		_defs[String(row["id"])] = {
			"name": String(row["name"]), "stat": String(row["stat"]),
			"per_step": float(row["per_step"]), "desc": String(row["description"]),
			"costs": [],
		}
	for row in Db.records("perk_steps", "", [], "perk_id, step"):
		var def: Dictionary = _defs.get(String(row["perk_id"]), {})
		if not def.is_empty():
			(def["costs"] as Array).append(int(row["cost"]))
