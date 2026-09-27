extends Node2D
## Two rules the hideout's counter used to keep to itself: what the forge costs,
## and that one skill cannot sit in two slots at once. Both are the profile's
## now, so they hold for every caller and not only for the panel's buttons — and
## this is what says so, with no renderer.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[FORGE] PASS ", what)
	else:
		fails += 1
		push_error("FORGE FAIL: " + what)

func _ready() -> void:
	GameState.reset_profile()

	# --- the forge ------------------------------------------------------------
	# Three of one part on the shelves and nothing else, so what the forge takes
	# and what it gives back can be counted whatever it happens to make.
	GameState.stash.clear()
	GameState.stash["DAMAGE"] = GameState.FORGE_INPUTS
	GameState.scrap = GameState.FORGE_COST - 1
	check(not GameState.can_forge(), "a scrap short of the price, the forge is shut")
	GameState.scrap = GameState.FORGE_COST
	check(GameState.can_forge(), "at the price, with parts to melt, it is open")
	GameState.stash["DAMAGE"] = GameState.FORGE_INPUTS - 1
	check(not GameState.can_forge(), "a part short of the inputs, it is shut")
	GameState.stash["DAMAGE"] = GameState.FORGE_INPUTS

	var pick: Array[String] = []
	for i in GameState.FORGE_INPUTS:
		pick.append("DAMAGE")
	var made := GameState.forge_component(pick)
	check(made != "" and Components.exists(made), "the forge gives a part back (%s)" % made)
	check(GameState.scrap == 0, "and takes exactly the price (%d left)" % GameState.scrap)
	check(GameState.stash_total() == 1 and int(GameState.stash.get(made, 0)) == 1,
		"melts the inputs, and shelves the one part made (%s)" % str(GameState.stash))
	check(not GameState.can_forge(), "with the scrap gone it is shut again")
	check(GameState.forge_component(pick) == "" and GameState.stash_total() == 1,
		"and shut, it takes nothing")

	# --- one skill, one slot --------------------------------------------------
	var w := "SWORD"
	check(Weapons.slots(w) == 3, "(the sword has three slots)")
	var s := GameState.assign_skill(w, 0, 0)
	check(s == [0, -1, -1], "a skill goes into the slot it is put in (%s)" % str(s))
	s = GameState.assign_skill(w, 2, 0)
	check(s == [-1, -1, 0], "moved to another slot, it leaves the first (%s)" % str(s))
	s = GameState.assign_skill(w, 1, 1)
	check(s == [-1, 1, 0], "a second skill in a free slot moves nothing else (%s)" % str(s))
	s = GameState.assign_skill(w, 5, 1)
	check(s == [-1, 1, 0], "a slot the weapon does not have changes nothing (%s)" % str(s))
	# The rule holds on the way in, whoever is writing.
	GameState.set_loadout(w, [1, 1, 1])
	check(GameState.get_loadout(w) == [1, -1, -1],
		"a loadout written with one skill three times keeps it in the first slot only (%s)"
			% str(GameState.get_loadout(w)))
	GameState.set_loadout(w, [2, 0, 2])
	check(GameState.get_loadout(w) == [2, 0, -1],
		"and only the repeat is dropped (%s)" % str(GameState.get_loadout(w)))

	print("[FORGE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
