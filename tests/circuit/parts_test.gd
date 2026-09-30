extends Node
## The parts a skill board is built from, and the tables they are read from.
##
## Every part is rows in the content database (`data/db/parts/parts.sql`): its
## numbers, the sides its flow leaves by, and what it does to a flow, as
## effects on the payload the flow carries. What stays code is what each kind of
## effect means, and the handful of parts the runner names for itself. Three
## things can go wrong between the two and none says so at run time: a row can
## ask a payload for a field it does not have, or for something the field
## cannot take; the code can lean on a part the table no longer has, or has in
## another shape; and the runner can do an effect other than the row says. Each
## is a failure here, and what the schema promises to refuse is tried against
## a scratch copy of it.
##
## No renderer needed: nothing here draws. The refusals print an `SQL error`
## line each from the extension, which is the point of them.

const SRC := "res://data/db"
const SCRATCH := "user://parts_test.db"

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[PARTS] PASS ", what)
	else:
		fails += 1
		push_error("PARTS FAIL: " + what)

func _ready() -> void:
	# --- the tables -----------------------------------------------------------
	check(Db.available(), "the database opens (%s)" % Db.PATH)
	for table in ["categories", "codes", "parts", "ports", "effects", "retired_parts", "renamed_parts"]:
		check(Db.has_table(table), "there is a table of %s" % table)
	var faults := Components.faults()
	check(faults.is_empty(), "every row fits what reads it%s" % ("" if faults.is_empty() else " — " + "; ".join(faults)))
	var ids := Components.ids()
	check(ids.size() > 20, "the parts are read, %d of them" % ids.size())
	check(Components.structural() == ["OUTPUT"],
		"the OUTPUT is always at hand, and nothing else is (%s)" % str(Components.structural()))
	var pool := Components.loot_pool()
	check(pool.size() == ids.size() - 1 and not pool.has("OUTPUT"),
		"every other part drops, in the palette's order (%d)" % pool.size())

	# --- what the code leans on -----------------------------------------------
	# The runner and the attacks name a few parts for themselves: where a flow
	# ends, the triggers whose branches a payload carries, the forms the attacks
	# are spawned by, and the clock. Each has to be in the table, and in the
	# shape the code takes for granted. Where a flow starts is no part's: it is
	# the board's root cell, and INPUT, which was that, is retired.
	check(not Components.exists("INPUT") and Components.is_retired("INPUT")
			and Components.retired_out("INPUT") == Components.E,
		"INPUT is retired: it keeps its number, and its cell reads back empty the way WIRE's does")
	check(Components.world_inputs("SLASH", 0) == [Components.S, Components.W, Components.N],
		"no part is a source: every part takes flow on every side but its own outputs, the root's included")
	check(Components.world_outputs("OUTPUT", 0).is_empty() and Components.world_payload_out("OUTPUT", 0) < 0,
		"OUTPUT is where a flow ends: it sends nothing on")
	var nowhere: Array = []
	for id in ids:
		if id != "OUTPUT" and Components.world_outputs(id, 0).is_empty():
			nowhere.append(id)
	check(nowhere.is_empty(), "every other part sends its flow somewhere (%s)" % str(nowhere))
	var unbranched: Array = []
	for id in ["ON_HIT", "ON_KILL", "ON_PARRY"]:
		if Components.world_payload_out(id, 0) < 0 or String(Components.get_def(id).get("cat", "")) != Components.CAT_TRIGGER:
			unbranched.append(id)
	check(unbranched.is_empty(), "ON HIT, ON KILL and ON PARRY are triggers, each with a branch (%s)" % str(unbranched))
	# An attack is spawned by its form (`Attacks.spawn`), and six are drawn.
	# Each is a part that makes a flow that form, and no row makes any other.
	const DRAWN := ["PROJECTILE", "SLASH", "EXPLODE", "DASHSLASH", "DASHSLASH_AUTO", "ZAP"]
	var misformed: Array = []
	for id in DRAWN:
		if not Components.exists(id) or (_entered(id)["payload"] as Payload).form != id:
			misformed.append(id)
	check(misformed.is_empty(), "each form the attacks draw is a part that makes a flow that form (%s)" % str(misformed))
	var undrawn: Array = []
	for id in ids:
		for e in Components.effects_of(id):
			if e["field"] == &"form" and not DRAWN.has(String(e["value"])):
				undrawn.append("%s makes %s" % [id, e["value"]])
	check(undrawn.is_empty(), "and no part makes a form nothing draws (%s)" % ", ".join(undrawn))
	check(Components.exists("OVERCLOCK"), "OVERCLOCK is there for the board's clock to count")
	var categories: Array = []
	for r in Db.rows("SELECT id FROM categories"):
		categories.append(String(r["id"]))
	var unknown_cats: Array = []
	for cat in [Components.CAT_STRUCT, Components.CAT_FORM, Components.CAT_ELEMENT, Components.CAT_STAT,
			Components.CAT_BEHAVIOR, Components.CAT_FLOW, Components.CAT_TRIGGER]:
		if not categories.has(cat):
			unknown_cats.append(cat)
	check(unknown_cats.is_empty(), "every category the code names is in the table (%s)" % str(unknown_cats))

	# --- each kind of effect does what it says --------------------------------
	# Read off the part's own rows rather than written out here, so what is
	# checked is that the runner does what a row says, whatever it says.
	var p0 := Payload.new()
	var dmg := _value("DAMAGE", "add", &"damage")
	check(dmg > 0.0 and is_equal_approx((_entered("DAMAGE")["payload"] as Payload).damage, p0.damage + dmg),
		"add: DAMAGE adds its %s to the damage" % str(dmg))
	var grow := _value("SIZE", "multiply", &"size")
	check(grow > 0.0 and is_equal_approx((_entered("SIZE")["payload"] as Payload).size, p0.size * grow),
		"multiply: SIZE multiplies the size by its %s" % str(grow))
	var pierce := _entered("PIERCE")["payload"] as Payload
	check(pierce.pierce == int(_value("PIERCE", "add", &"pierce")) and typeof(pierce.pierce) == TYPE_INT,
		"a whole number stays one: PIERCE adds %d" % pierce.pierce)
	var dup := _entered("DUPLICATE")["payload"] as Payload
	check(dup.duplicates == p0.duplicates * int(_value("DUPLICATE", "multiply", &"duplicates")),
		"and DUPLICATE multiplies the count (%d)" % dup.duplicates)
	check((_entered("DASH")["payload"] as Payload).dash, "set: DASH sets its flag")
	var back := _entered("REVERSE", 1)["payload"] as Payload
	var forth := _entered("REVERSE", 2)["payload"] as Payload
	check(back.reverse and not forth.reverse, "toggle: one REVERSE flips a flow, and a second flips it back")
	var fire := _entered("FIRE", 2)["payload"] as Payload
	check(Array(fire.elements) == ["FIRE"], "include: FIRE joins the elements, once however often (%s)" % str(fire.elements))
	var split := _entered("SPLIT")["payload"] as Payload
	check(is_equal_approx(split.damage, p0.damage * _value("SPLIT", "multiply", &"damage")),
		"SPLIT takes its share off a flow as it enters (%.1f)" % split.damage)
	var dilated: Array = _entered("TIME_DILATION")["events"]
	check(dilated.size() == 1 and dilated[0] == ["dilate", _value("TIME_DILATION", "dilate", &"")],
		"dilate: TIME DILATION asks for the seconds its row gives (%s)" % str(dilated))
	var guarded: Array = _entered("ON_PARRY")["events"]
	check(guarded.size() == 1 and guarded[0] == ["guard", _value("ON_PARRY", "guard", &"")],
		"guard: ON PARRY opens a window as long as its row says (%s)" % str(guarded))
	var entry: Array = []
	for id in ids:
		var does := false
		for e in Components.effects_of(id):
			does = does or String(e["op"]) in ["dilate", "guard"]
		if does != Components.acts_on_entry(id):
			entry.append(id)
	check(entry.is_empty(), "a part acts on entry exactly when it dilates or guards (%s)" % str(entry))
	# And nothing else: a part changes the fields its rows name, and its heat.
	var strays: Array = []
	for id in ids:
		var named := {&"heat": true}
		for e in Components.effects_of(id):
			named[e["field"]] = true
		var after := _entered(id)["payload"] as Payload
		for prop in _fields(p0):
			if not named.has(StringName(prop)) and str(after.get(prop)) != str(p0.get(prop)):
				strays.append("%s changed %s" % [id, prop])
		if not is_equal_approx(after.heat, float(Components.get_def(id)["heat"])):
			strays.append("%s added %.2f heat, not %.2f" % [id, after.heat, float(Components.get_def(id)["heat"])])
	check(strays.is_empty(), "every part changes what its rows say and its own heat, and nothing else (%s)" % ", ".join(strays))

	# --- a row that does not fit is turned away, and says what would ----------
	var shape := Payload.new()
	var ok = Components._effect({"op": "add", "field": "damage", "value": 8}, shape)
	check(ok is Dictionary and typeof(ok["value"]) == TYPE_FLOAT and ok["field"] == &"damage",
		"a number added to a number is read as one (%s)" % str(ok))
	var whole = Components._effect({"op": "add", "field": "pierce", "value": 2.0}, shape)
	check(whole is Dictionary and typeof(whole["value"]) == TYPE_INT, "a whole one to a whole number, as a whole number")
	var flag = Components._effect({"op": "set", "field": "dash", "value": 1}, shape)
	check(flag is Dictionary and flag["value"] is bool and flag["value"], "and a 1 set on a flag as true")
	for bad in [
			[{"op": "add", "field": "damge", "value": 8}, "not a field of a payload", "a field a payload does not have"],
			[{"op": "add", "field": "heat", "value": 1}, "keeps for itself", "a field the runner keeps"],
			[{"op": "add", "field": "dash", "value": 1}, "it is a flag", "a number added to a flag"],
			[{"op": "include", "field": "elements", "value": 3}, "it is a list", "a number included in a list"],
			[{"op": "set", "field": "form", "value": 5}, "it is a word", "a word set to a number"],
			[{"op": "multiply", "field": "duplicates", "value": 1.5}, "it is a whole number", "a whole number multiplied by a fraction"],
			[{"op": "toggle", "field": "damage"}, "it is a number", "a number toggled"],
			[{"op": "dilate", "value": 0}, "no time at all", "a dilation of no time"]]:
		var said = Components._effect(bad[0], shape)
		check(said is String and String(said).contains(bad[1]), "%s is turned away (%s)" % [bad[2], str(said)])

	# --- what the schema refuses ----------------------------------------------
	# The build runs with foreign keys on and these same constraints, so what
	# is refused here is refused there.
	var db = _scratch()
	if db == null:
		check(false, "a scratch copy of the schema can be made to try it against")
	else:
		var cat := "INSERT INTO categories (id) VALUES ('form')"
		var code := "INSERT INTO codes (code, id) VALUES (0, 'BOLT')"
		var part := "INSERT INTO parts (id, name, category, heat, description) VALUES ('BOLT', 'BOLT', 'form', 0.5, 'Fires.')"
		var port := "INSERT INTO ports (part_id, side) VALUES ('BOLT', 'E')"
		var effect := "INSERT INTO effects (part_id, position, field, op, value) VALUES ('BOLT', 0, 'form', 'set', 'BOLT')"
		check(_accepted(db, [cat, code, part, port, effect]), "a sound part is accepted (%s)" % db.error_message)
		check(_accepted(db, [part, port, effect, code, cat]), "and it may be written before its number and its category")
		check(not _accepted(db, [code, part, port, effect]), "a part in a category nobody wrote is refused when the build commits")
		check(not _accepted(db, [cat, part, port, effect]), "a part with no number is refused")
		check(not _accepted(db, [cat, code, part, code.replace("'BOLT'", "'ARC'")]), "two parts on one number are refused")
		check(not _accepted(db, [cat, code, part.replace("'BOLT', 'BOLT'", "'bolt', 'BOLT'")]),
			"a part id that is not upper case is refused")
		check(not _accepted(db, [cat, code, part.replace("0.5", "-1")]), "heat below nothing is refused")
		check(not _accepted(db, [cat, code, part, port.replace("'E'", "'X'")]), "a port on a side that is not one is refused")
		check(not _accepted(db, [cat, code, part,
				"INSERT INTO ports (part_id, side, kind) VALUES ('BOLT', 'S', 'branch'), ('BOLT', 'N', 'branch')"]),
			"a part with two branches is refused")
		check(not _accepted(db, [cat, code, part, effect.replace("'form', 'set', 'BOLT'", "'damage', 'dilate', 1")]),
			"a dilation that names a field is refused")
		check(not _accepted(db, [cat, code, part, effect.replace("'form', 'set', 'BOLT'", "'reverse', 'toggle', 1")]),
			"a toggle with a value is refused")
		check(not _accepted(db, [cat, code, part, effect.replace("'set'", "'divide'")]), "an effect nobody can do is refused")
		db.close_db()
		DirAccess.remove_absolute(SCRATCH)

	print("[PARTS] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## A flow entering `id`, `times` times over, through a real runner: the payload
## it comes out with, and what the runner signalled on the way.
func _entered(id: String, times: int = 1) -> Dictionary:
	var r := SkillRunner.new(SkillBoard.new(7, 5, "bench"))
	var events: Array = []
	r.dilation_requested.connect(func(s: float) -> void: events.append(["dilate", s]))
	r.parry_opened.connect(func(s: float) -> void: events.append(["guard", s]))
	var p := Payload.new()
	for i in times:
		r._apply(id, p)
	return {"payload": p, "events": events}

## The value of `id`'s effect doing `op` to `field`, as its row gives it.
func _value(id: String, op: String, field: StringName) -> float:
	for e in Components.effects_of(id):
		if String(e["op"]) == op and e["field"] == field:
			return float(e["value"])
	return -1.0

## A payload's own fields, the ones an effect could touch.
func _fields(p: Payload) -> Array:
	var out: Array = []
	for prop in p.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(String(prop["name"]))
	return out

## A fresh database with the real schema in it, foreign keys on, or null.
func _scratch():
	if not ClassDB.class_exists("SQLite"):
		return null
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)
	var db = ClassDB.instantiate("SQLite")
	db.path = SCRATCH
	db.foreign_keys = true
	db.verbosity_level = 0
	if not db.open_db():
		push_error("PARTS: could not open %s: %s" % [SCRATCH, db.error_message])
		return null
	var schema := FileAccess.get_file_as_string(SRC.path_join("schema.sql"))
	if schema == "" or not db.query(schema):
		push_error("PARTS: the schema did not run: %s" % db.error_message)
		return null
	return db

## Whether `statements` go in and commit, the way build.sh commits them. What
## went in is taken out again afterwards, so every try starts from nothing.
func _accepted(db, statements: Array) -> bool:
	var ok: bool = db.query("BEGIN")
	for s in statements:
		ok = ok and db.query(s)
	ok = ok and db.query("COMMIT")
	if not ok:
		db.query("ROLLBACK")
		return false
	db.query("DELETE FROM parts")
	db.query("DELETE FROM codes")
	db.query("DELETE FROM categories")
	return true
