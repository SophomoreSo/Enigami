extends Node
## A board must survive being written down as a code and read back, and a code
## with a mistake in it must be refused rather than quietly building a different
## board. Also guards the two things that can never be reordered: the alphabet a
## code is spelled in, and the numbers parts are known by inside one.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[CODE] PASS ", what)
	else:
		fails += 1
		push_error("CODE FAIL: " + what)

## Two boards are the same board when the same parts face the same way in the
## same cells. Names and grids are deliberately not part of it: a code carries
## neither.
func same_parts(a: SkillBoard, b: SkillBoard) -> bool:
	if a.cells.size() != b.cells.size():
		return false
	for origin in a.cells:
		var here: Dictionary = a.cells[origin]
		var there: Dictionary = b.cells.get(origin, {})
		if there.is_empty() or String(there["id"]) != String(here["id"]) \
				or int(there["rot"]) != int(here["rot"]):
			return false
	return true

func round_trip(b: SkillBoard, what: String) -> String:
	var code := BoardCode.encode(b)
	var read := BoardCode.decode(code)
	if String(read["error"]) != "":
		check(false, "%s: encodes to something readable (%s)" % [what, read["error"]])
		return code
	var back: SkillBoard = read["board"]
	check(same_parts(b, back) and back.width == b.width and back.height == b.height,
		"%s: %d parts on a %dx%d board come back the same, in %d characters" % [
			what, b.cells.size(), b.width, b.height, BoardCode.clean(code).length()])
	return code

func _ready() -> void:
	# --- the table of part numbers ------------------------------------------
	var seen: Dictionary = {}
	var repeated: Array = []
	var unknown: Array = []
	for id in BoardCode.CODE_IDS:
		if seen.has(id):
			repeated.append(id)
		seen[String(id)] = true
		if not Components.exists(String(id)):
			unknown.append(id)
	check(repeated.is_empty(), "no part has two numbers (%s)" % str(repeated))
	check(unknown.is_empty(), "every number in the table names a part that exists (%s)" % str(unknown))
	var uncoded: Array = []
	for id in Components.DEFS:
		if not seen.has(String(id)):
			uncoded.append(id)
	check(uncoded.is_empty(),
		"every part has a number, or no board with one on it can be shared (%s)" % str(uncoded))
	check(BoardCode.CODE_IDS.size() <= (1 << BoardCode.ID_BITS),
		"the table still fits %d bits (%d of %d)" % [
			BoardCode.ID_BITS, BoardCode.CODE_IDS.size(), 1 << BoardCode.ID_BITS])

	# --- the alphabet -------------------------------------------------------
	var alphabet: String = BoardCode.ALPHABET
	check(alphabet.length() == BoardCode.CHECK_MOD,
		"the alphabet is %d characters long (%d)" % [BoardCode.CHECK_MOD, alphabet.length()])
	# Prime, or the check character stops catching everything it claims to.
	var prime := BoardCode.CHECK_MOD > 1
	for f in range(2, BoardCode.CHECK_MOD):
		if f * f <= BoardCode.CHECK_MOD and BoardCode.CHECK_MOD % f == 0:
			prime = false
	check(prime, "and %d is prime" % BoardCode.CHECK_MOD)
	var twice: Array = []
	for i in alphabet.length():
		if alphabet.find(alphabet[i]) != i:
			twice.append(alphabet[i])
	check(twice.is_empty(), "no character appears in it twice (%s)" % str(twice))
	check(not alphabet.contains("0"),
		"and there is no 0 in it — the pixel face draws 0 and O with the same pixels")
	check(alphabet.contains("O") and alphabet.contains("o") and alphabet.contains("Z")
		and alphabet.contains("z") and alphabet.contains("9"),
		"but both cases and the other digits are all in it")
	# Five characters must hold a whole word of the board, with nothing over.
	check(pow(BoardCode.CHECK_MOD, BoardCode.WORD_CHARS) > float(BoardCode.WORD_MAX),
		"%d characters hold %d bits" % [BoardCode.WORD_CHARS, BoardCode.WORD_BITS])
	# Weights are what make a wrong character and a swapped pair both move the
	# total: never zero, and never the same as the next one along.
	var bad_weight: Array = []
	for i in 200:
		var w := BoardCode._weight(i)
		if w % BoardCode.CHECK_MOD == 0 or w == BoardCode._weight(i + 1):
			bad_weight.append(i)
	check(bad_weight.is_empty(), "every character's weight is live and unlike its neighbour's (%s)"
		% str(bad_weight))

	# --- round trips --------------------------------------------------------
	var empty := SkillBoard.new(7, 5, "nothing")
	round_trip(empty, "an empty board")

	var one := SkillBoard.new(7, 5, "one part")
	one.place("INPUT", Vector2i(0, 2), 0)
	round_trip(one, "a single part")

	# A real skill, and the code it is expected to make. This literal is what
	# pins the format down: it can only change when the format does, and when it
	# does, every code anyone has written down has stopped working.
	var skill := SkillBoard.new(7, 5, "Fire Bolt")
	skill.place("INPUT", Vector2i(0, 2), 0)
	skill.place("WIRE", Vector2i(1, 2), 0)
	skill.place("FIRE", Vector2i(2, 2), 0)
	skill.place("DAMAGE", Vector2i(3, 2), 0)
	skill.place("PROJECTILE", Vector2i(4, 2), 0)
	skill.place("OUTPUT", Vector2i(5, 2), 0)
	var golden := round_trip(skill, "a six-part skill")
	print("[CODE] Fire Bolt is ", golden)
	check(golden == "7kDaN29S5g3bfg66lONvD", "the format has not moved under existing codes")

	# Every part in the table, turned every way — the two-cell ones included,
	# whose tail cell swings round with them. First fit, because a part facing
	# west starts a cell further in than one facing east.
	var all := SkillBoard.new(11, 9, "everything")
	var turn := 0
	for id in BoardCode.CODE_IDS:
		var landed := false
		for y in all.height:
			for x in all.width:
				var c := Vector2i(x, y)
				# Only ever onto clear ground: dropping a part on an origin that
				# is already taken replaces what was there, which is what the
				# editor wants and not what this is counting.
				if all.origin_at(c) == null and all.place(String(id), c, turn % 4):
					landed = true
					break
			if landed:
				break
		turn += 1
	check(all.cells.size() == BoardCode.CODE_IDS.size(),
		"every part in the table fits on one board (%d of %d)" % [
			all.cells.size(), BoardCode.CODE_IDS.size()])
	round_trip(all, "one of every part, at every rotation")

	# The biggest board the game can grow, filled: the longest code there is in
	# practice, and it has to stay inside the format's ceilings.
	var big := SkillBoard.new(11, 9, "full")
	for y in big.height:
		for x in big.width:
			big.place("WIRE", Vector2i(x, y), (x + y) % 4)
	check(big.cells.size() <= BoardCode.MAX_PARTS,
		"a full 11x9 board is inside the %d-part ceiling (%d)" % [BoardCode.MAX_PARTS, big.cells.size()])
	round_trip(big, "a full 11x9 board")

	# --- one board is one code ----------------------------------------------
	var other_order := SkillBoard.new(7, 5, "same, built backwards")
	other_order.place("OUTPUT", Vector2i(5, 2), 0)
	other_order.place("PROJECTILE", Vector2i(4, 2), 0)
	other_order.place("DAMAGE", Vector2i(3, 2), 0)
	other_order.place("FIRE", Vector2i(2, 2), 0)
	other_order.place("WIRE", Vector2i(1, 2), 0)
	other_order.place("INPUT", Vector2i(0, 2), 0)
	check(BoardCode.encode(other_order) == golden,
		"the same board built in a different order is the same code")
	var renamed := skill.duplicate_board()
	renamed.skill_name = "Something Else"
	check(BoardCode.encode(renamed) == golden, "and renaming it does not change it")

	# --- how a code is written down -----------------------------------------
	var body := BoardCode.clean(golden)
	check(body == golden, "a code is one unbroken run, nothing between its characters (%s)" % golden)
	check(not golden.contains("-") and not golden.contains(" "), "no dashes and no spaces")
	check(BoardCode.is_valid("  %s %s\n%s\n" % [body.left(7), body.substr(7, 7), body.substr(14)]),
		"but it still reads back written with spaces, or wrapped over a line")
	check(BoardCode.is_valid("%s." % golden), "and with a full stop stuck to the end")
	check(BoardCode.name_for(golden) == "CODE %s" % body.substr(0, 5),
		"a board with no name arrives as its own first five characters (%s)" % BoardCode.name_for(golden))
	# Case is half the alphabet, so it cannot be folded away on the way in.
	check(not BoardCode.is_valid(body.to_upper()) or body == body.to_upper(),
		"a code shouted in capitals is not the same code")

	# --- a mistyped code is refused -----------------------------------------
	# Every single wrong character, and every adjacent pair swapped: the two
	# mistakes a person makes copying a code down, neither of which may ever
	# produce a board. Case counts as wrong — `hBw4k` and `hBW4k` are two boards.
	var alpha: String = BoardCode.ALPHABET
	var slipped: Array = []
	var tried := 0
	for i in body.length():
		for k in alpha.length():
			if alpha[k] == body[i]:
				continue
			tried += 1
			if BoardCode.is_valid(body.left(i) + alpha[k] + body.substr(i + 1)):
				slipped.append("%d:%s" % [i, alpha[k]])
	check(slipped.is_empty(), "no single wrong character reads as a board (%d tried, %s)"
		% [tried, str(slipped)])
	var swaps := 0
	var swapped := 0
	for i in body.length() - 1:
		if body[i] == body[i + 1]:
			continue
		swaps += 1
		if BoardCode.is_valid(body.left(i) + body[i + 1] + body[i] + body.substr(i + 2)):
			swapped += 1
	check(swapped == 0, "no two neighbours can swap and still read (%d tried)" % swaps)

	# --- and so is everything else ------------------------------------------
	check(not BoardCode.is_valid(""), "an empty code is refused")
	check(BoardCode.decode("").error == BoardCode.error_text("empty"),
		"and says there is nothing there")
	check(not BoardCode.is_valid(".....'"), "punctuation alone is refused")
	check(not BoardCode.is_valid(body + alpha[0]), "a character stuck on the end is refused")
	check(not BoardCode.is_valid(body.left(body.length() - 1)), "one missing is refused")
	check(BoardCode.decode("abcdefg").error == BoardCode.error_text("length", [7]),
		"a code of the wrong length says so, rather than failing on the board")
	# A 0 is not in the alphabet at all, and the one slip worth naming.
	check(BoardCode.decode(body.left(2) + "0" + body.substr(3)).error
			== BoardCode.error_text(BoardCode.HAS_ZERO),
		"a 0 typed where an O was meant says so")
	# Five characters over what 29 bits hold are not a word of a board, whatever
	# the check character says: "zzzzz" is 61^5 - 1, far over it.
	var over := "zzzzz" + body.substr(5)
	over = over.left(over.length() - 1)
	over += BoardCode._check_char(over)
	check(BoardCode._checks_out(over), "(a word over the ceiling still checks out)")
	check(not BoardCode.is_valid(over), "but five characters no board could have written are refused")
	# A code from a version that does not exist yet.
	var future := _with_version(7)
	check(BoardCode.decode(future).error == BoardCode.error_text("version", [7, BoardCode.VERSION]),
		"a code from another version says which (%s)" % BoardCode.decode(future).error)

	# --- taking a board on -------------------------------------------------
	# The grid belongs to the workbench, not to the build drawn on it.
	var small := SkillBoard.new(7, 5, "mine")
	small.place("INPUT", Vector2i(0, 0), 0)
	var from_big := SkillBoard.new(11, 9, "theirs")
	from_big.place("SLASH", Vector2i(9, 7), 0)
	check(not small.fits(from_big), "a build off a bigger board does not fit a smaller one")
	check(not small.adopt(from_big), "so it is refused")
	check(String(small.comp_at(Vector2i(0, 0)).get("id", "")) == "INPUT",
		"and the board it was refused by is untouched")
	var inside := SkillBoard.new(11, 9, "theirs, but small")
	inside.place("SLASH", Vector2i(2, 1), 1)
	inside.place("AREA", Vector2i(3, 3), 0)
	check(small.adopt(inside), "a build that fits is taken on")
	check(same_parts(small, inside), "with every part where it was")
	check(small.width == 7 and small.height == 5 and small.skill_name == "mine",
		"on this board's own grid, under its own name")

	# --- what a pasted board costs ------------------------------------------
	var pool := {"FIRE": 1, "PROJECTILE": 1}
	var have := SkillBoard.new(7, 5, "old")
	have.place("INPUT", Vector2i(0, 2), 0)
	have.place("DAMAGE", Vector2i(1, 2), 0)
	var want := SkillBoard.new(7, 5, "new")
	want.place("INPUT", Vector2i(0, 2), 0)
	want.place("FIRE", Vector2i(1, 2), 0)
	want.place("PROJECTILE", Vector2i(2, 2), 0)
	want.place("SPLIT", Vector2i(3, 2), 0)
	var missing := GameState.trade_board(have, want, pool)
	check(int(missing.get("SPLIT", 0)) == 1, "a board you cannot afford says what is short")
	check(int(pool.get("FIRE", 0)) == 1 and not pool.has("DAMAGE"),
		"and nothing moved — the old board's parts are still in it")
	pool["SPLIT"] = 1
	check(GameState.trade_board(have, want, pool).is_empty(), "with the last part, the trade goes through")
	check(not pool.has("FIRE") and not pool.has("PROJECTILE") and not pool.has("SPLIT"),
		"the new board's parts came out of the pool")
	check(int(pool.get("DAMAGE", 0)) == 1, "and the old board's went back into it")
	check(GameState.trade_board(null, SkillBoard.new(7, 5, "free"), pool).is_empty(),
		"a board of nothing but structure costs nothing")

	print("[CODE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## A code claiming to be version `v`: the version is the first three bits, so it
## is the leading five characters that change, and the check character with them.
func _with_version(v: int) -> String:
	var b := SkillBoard.new(7, 5, "x")
	b.place("INPUT", Vector2i(0, 0), 0)
	var c := BoardCode.clean(BoardCode.encode(b))
	var head := BoardCode._chars_to_word(c.substr(0, BoardCode.WORD_CHARS))
	# Clear the top three bits of the first twenty-nine and write `v` into them.
	head = (head & ((1 << (BoardCode.WORD_BITS - BoardCode.VER_BITS)) - 1)) \
		| (v << (BoardCode.WORD_BITS - BoardCode.VER_BITS))
	var out := BoardCode._word_to_chars(head) \
		+ c.substr(BoardCode.WORD_CHARS, c.length() - BoardCode.WORD_CHARS - 1)
	return out + BoardCode._check_char(out)
