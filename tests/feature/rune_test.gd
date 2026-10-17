extends Node
## The rune (`Weapons.is_rune`): a rock with mana in it. A hold charges its
## graph out of the rune's mana and not the player's; the cast that takes the
## last of it spends it; spent, it casts nothing and charges nothing; and a
## hold with it in hand pours the player's own mana into it until it is full
## and lit again. What is in it is kept with the profile.
##
## Headless: nothing here is looked at. The profile it plays with is wiped at
## the end, so nothing after it walks in with a spent rune.

var fails := 0
var cues: Array = []

func check(ok: bool, what: String) -> void:
	if ok:
		print("[RUNE] PASS ", what)
	else:
		fails += 1
		push_error("RUNE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	GameState.reset_profile()
	Cues.fired.connect(func(cue: StringName, _d: Dictionary) -> void: cues.append(cue))
	_the_weapon()
	await _the_player()
	_kept()
	GameState.reset_profile()
	print("[RUNE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## A thrown weapon like the rock, with mana in it, that every profile has.
func _the_weapon() -> void:
	check(Weapons.is_rune("RUNE") and Weapons.is_thrown("RUNE") and not Weapons.is_rune("ROCK"),
		"the rune is thrown as the rock is, and the rock is no rune")
	check(Weapons.root_part("RUNE") == "PROJECTILE" and Weapons.make_board("RUNE").has_root(),
		"its graph is a PROJECTILE at the root, as a new profile gets it")
	check(GameState.owned_weapons.has("RUNE") and GameState.HANDED_OUT.has("RUNE"),
		"a new profile has one, and an old one is handed it")
	check(is_equal_approx(GameState.rune_mana, GameState.RUNE_MANA) and not GameState.rune_spent,
		"full, to begin with (%.0f)" % GameState.rune_mana)

func _the_player() -> void:
	var p := Player.new()
	add_child(p)
	await frames(2)
	p.setup_kit(["RUNE"], [Weapons.make_board("RUNE")])
	check(p.holds("RUNE") and p.can_cast() and p.can_charge(), "in hand, it casts and charges")

	# A hold charges out of the rune, and the player's bar is not touched.
	p.mana = p.max_mana
	p.charge = 0.0
	p._update_charge(0.5, true)
	var spent := GameState.RUNE_MANA - GameState.rune_mana
	check(p.charge > 0.0 and is_equal_approx(spent, p.charge * Player.MANA_PER_TTL),
		"a hold charges out of the rune's mana (%.1f gone for %.1f of charge)" % [spent, p.charge])
	check(is_equal_approx(p.mana, p.max_mana), "and not the player's (%.0f)" % p.mana)

	# Down to nothing: the hold stops where the rune ran out.
	GameState.rune_mana = 2.0
	p.charge = 0.0
	for i in 20:
		p._update_charge(0.1, true)
	check(is_zero_approx(GameState.rune_mana) and is_equal_approx(p.charge, 2.0 / Player.MANA_PER_TTL),
		"it charges as far as the rune's mana goes, and no further (%.2f)" % p.charge)
	check(not GameState.rune_spent and p.can_cast(),
		"empty, it is not spent yet: the cast that drained it still goes out")
	cues.clear()
	p._on_cycle_started()
	check(GameState.rune_spent and cues.has(&"rune_spent"), "that cast starting spends it")

	# Spent: a dead stone.
	check(p.rune_spent_in_hand() and not p.can_cast() and not p.can_charge(),
		"spent, it casts nothing and charges nothing")

	# A hold pours the player's own mana into it, as long as there is any.
	p.mana = 30.0
	check(p.refill_rune(1.0, true) and p.refilling, "a hold with it in hand pours mana into it")
	check(is_zero_approx(p.mana) and is_equal_approx(GameState.rune_mana, 30.0) and GameState.rune_spent,
		"the player's as far as it goes, and it stays spent short of full (%.0f in it)" % GameState.rune_mana)
	check(not p.refill_rune(1.0, false) and not p.refilling, "let go, nothing is poured")
	p.mana = p.max_mana
	cues.clear()
	var steps := 0
	while GameState.rune_spent and steps < 200:
		p.refill_rune(0.1, true)
		steps += 1
	check(not GameState.rune_spent and is_equal_approx(GameState.rune_mana, GameState.RUNE_MANA)
			and cues.has(&"rune_lit"),
		"full, it lights again (%d steps of a tenth of a second)" % steps)
	check(is_equal_approx(p.mana, p.max_mana - 70.0), "for the mana poured into it (%.0f left)" % p.mana)
	check(p._hold_filled and p.can_cast(), "it casts again, but the hold that filled it is spent on that")

	# Away from the hand, nothing is poured: the rune lying on the floor.
	GameState.rune_spent = true
	GameState.rune_mana = 0.0
	p.let_go("RUNE")
	check(not p.refill_rune(1.0, true), "with the rune out of hand, nothing is poured into it")
	p.take_back("RUNE", p)
	GameState.rune_spent = false
	GameState.rune_mana = 64.0
	p.queue_free()
	await frames(1)

## What is in it, and whether it is spent, goes with the profile.
func _kept() -> void:
	GameState.rune_mana = 64.0
	GameState.rune_spent = true
	GameState.save_game()
	GameState.rune_mana = 0.0
	GameState.rune_spent = false
	GameState.load_slot(GameState.slot)
	check(is_equal_approx(GameState.rune_mana, 64.0) and GameState.rune_spent,
		"what is in the rune comes back with the profile (%.0f, spent %s)" % [GameState.rune_mana, GameState.rune_spent])
