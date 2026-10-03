extends Node
## Foliage: the plants of aarthificial's interactive foliage shaders, the
## tables their kinds and a room's growths are read from, the picture and the
## mask a patch grows, and where a room grows them.
##
## A kind is made with its row's numbers, and a kind that is not there is said
## and grows as grass. A patch stands on the floor — nothing in it floats, none
## of it is taller than the tallest, and the margin round it is clear for it to
## lean into — and the same seed grows the same plants. The mask is nothing on
## the floor and all of it at the tallest tip, rising all the way up, the same
## for a push and for the wind; a bush's foot does not move and its crown does.
## A room grows what the `growths` rows say, as many and as long, on floors
## with open air over them, never at the room's edge, never two
## of a kind on one cell, the same every time it is built. And what the schema
## promises to refuse is tried against a scratch copy.
##
## No renderer needed: a patch's picture and mask are made on the CPU and read
## as images. What the shader and the velocity buffer do with them is
## velocity_test's. The refusals print an `SQL error` line each from the
## extension, which is the point of them.

const SRC := "res://data/db"
const SCRATCH := "user://foliage_test.db"

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[FOLIAGE] PASS ", what)
	else:
		fails += 1
		push_error("FOLIAGE FAIL: " + what)

func _ready() -> void:
	_table()
	_patches()
	_masks()
	_rooms()
	_refusals()
	print("[FOLIAGE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the table --------------------------------------------------------------

func _table() -> void:
	check(Db.available(), "the database opens (%s)" % Db.PATH)
	for table in ["foliage", "growths"]:
		check(Db.has_table(table), "there is a table of %s" % table)
	check(Db.meta("schema_version") == str(Db.SCHEMA_VERSION),
		"the database is at the schema the code reads (file says %s, code says %d)"
			% [Db.meta("schema_version"), Db.SCHEMA_VERSION])
	var kinds := Foliage.kinds()
	for k in ["grass", "flowers", "bush"]:
		check(kinds.has(k), "%s is a kind of foliage (%s)" % [k, str(kinds)])
	var row := Foliage.source("grass")
	var grass := Foliage.of("grass")
	check(grass.kind == "grass" and not row.is_empty()
			and grass.form == String(row.get("form", "")) and grass.sway == String(row.get("sway", ""))
			and grass.shortest == int(row.get("shortest", -1)) and grass.tallest == int(row.get("tallest", -1))
			and grass.density == float(row.get("density", -1)) and grass.push == float(row.get("push", -1))
			and grass.wind == float(row.get("wind", -1)),
		"grass is made with its row's numbers (%s)" % str(row))
	var bush := Foliage.of("bush")
	check(bush.sway == "any" and grass.sway == "along", "a bush gives any way, and grass along the ground")
	bush.free()
	var plain := Foliage.new()
	var none := Foliage.of("nowhere")
	check(none.kind == "grass" and none.form == plain.form and none.push == plain.push,
		"a kind that is not there is said above, and grows as grass")
	var growths := Foliage.growths()
	check(growths.size() >= 1, "the rooms grow something (%s)" % str(growths))
	for g in growths:
		check(kinds.has(String(g.get("foliage", ""))), "a room grows %s, which is a kind" % g.get("foliage", ""))
	check(Style.foliage_look("nowhere") == Style.foliage_look("grass"),
		"a kind with no look of its own grows in grass's colours")
	grass.free()
	plain.free()
	none.free()

## --- a patch ----------------------------------------------------------------

## Every pixel of `f`'s plants that touches no other on its way to the floor:
## the pieces of it that would float. Eight-connected, so a blade leaning a
## pixel at the top is still one blade.
func _floating(f: Foliage) -> Array:
	var px := {}
	for p in f.plant_pixels():
		px[p] = true
	var reached := {}
	var todo: Array = []
	for p: Vector2i in px:
		if p.y == 1:
			reached[p] = true
			todo.append(p)
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var q := p + Vector2i(dx, dy)
				if px.has(q) and not reached.has(q):
					reached[q] = true
					todo.append(q)
	var out: Array = []
	for p in px:
		if not reached.has(p):
			out.append(p)
	return out

func _patches() -> void:
	for kind in Foliage.kinds():
		for width in [16, 64]:
			var f := Foliage.of(kind)
			f.grow(width, 7)
			var name := "%s %d wide" % [kind, width]
			var pixels := f.plant_pixels()
			check(not pixels.is_empty(), "%s grows something (%d pixels)" % [name, pixels.size()])
			check(f.picture.get_size() == f.mask.get_size()
					and f.picture.get_width() == f.span + f.margin * 2
					and f.picture.get_height() == f.tallest + f.margin,
				"%s: the picture and its mask are the patch and its margin all round (%s)"
					% [name, str(f.picture.get_size())])
			check(float(f.margin) >= f.push + f.wind,
				"%s: the margin (%d) is as wide as a push and the wind together move a tip (%.1f)"
					% [name, f.margin, f.push + f.wind])
			var tallest := 0
			var widest := Vector2i(1 << 20, -(1 << 20))
			for p in pixels:
				tallest = maxi(tallest, p.y)
				widest = Vector2i(mini(widest.x, p.x), maxi(widest.y, p.x))
			check(tallest <= f.tallest and tallest >= f.shortest,
				"%s: its tallest plant (%d) is between the shortest and the tallest of the kind (%d to %d)"
					% [name, tallest, f.shortest, f.tallest])
			check(widest.x >= -1 and widest.y <= f.span,
				"%s: it stands on its own floor, leaning a pixel past it at most (%d to %d of %d)"
					% [name, widest.x, widest.y, f.span])
			var afloat := _floating(f)
			check(afloat.is_empty(), "%s: nothing in it floats (%s)" % [name, str(afloat.slice(0, 4))])
			var again := Foliage.of(kind)
			again.grow(width, 7)
			check(again.picture.get_data() == f.picture.get_data() and again.mask.get_data() == f.mask.get_data(),
				"%s: the same seed grows the same plants" % name)
			var other := Foliage.of(kind)
			other.grow(width, 8)
			check(other.picture.get_data() != f.picture.get_data(), "%s: another seed grows others" % name)
			f.free()
			again.free()
			other.free()

## --- the mask ---------------------------------------------------------------

func _masks() -> void:
	for kind in Foliage.kinds():
		var f := Foliage.of(kind)
		f.grow(64, 3)
		var h := f.mask.get_height()
		var same := true
		var floor_still := true
		var rising := true
		for x in f.mask.get_width():
			var last := -1.0
			for k in range(1, h + 1):
				var m := f.mask.get_pixel(x, h - k)
				if absf(m.r - m.g) > 0.001:
					same = false
				if k == 1 and m.r != 0.0:
					floor_still = false
				if f.form != "bush" and m.r < last - 0.001:
					rising = false
				last = m.r
		check(same, "%s: the wind may move a pixel as far as a push may" % kind)
		check(floor_still, "%s: nothing on the floor moves" % kind)
		if f.form != "bush":
			check(rising, "%s: every pixel may move at least as far as the one under it" % kind)
			var tip := f.mask.get_pixel(f.margin, h - f.tallest).r
			check(tip > 0.99, "%s: the tallest tip moves all the way (%.2f)" % [kind, tip])
		else:
			var crown := f.mask.get_pixel(f.margin + f.span / 2, h - f.tallest).r
			var foot := f.mask.get_pixel(f.margin + f.span / 2, h - 2).r
			check(crown >= Foliage.CROWN and foot < crown,
				"a bush's crown moves (%.2f) and its foot hardly (%.2f)" % [crown, foot])
		f.free()

## --- a room -----------------------------------------------------------------

func _room(record: Dictionary, seed_base: int) -> Room:
	var room := Room.new()
	add_child(room)
	room.build(Vector2i.ZERO, record.duplicate(true), {}, seed_base)
	return room

func _layout(view: RoomView) -> Array:
	var out: Array = []
	for f: Foliage in view.plants:
		out.append([f.kind, f.position, f.span, f.picture.get_data().size()])
	return out

## Every patch of `view` stands on rock with open air over it, in from the
## edge; none crosses another of its kind; each is as long
## as its row says, and there are as many as it says.
func _grown_well(room: Room, view: RoomView, what: String) -> void:
	var taken := {}
	var on_ground := true
	var crossed := false
	var on_grid := true
	var behind := true
	for f: Foliage in view.plants:
		var cell := Vector2i(int(f.position.x) / Room.CELL, int(f.position.y) / Room.CELL)
		if fmod(f.position.x, float(Room.CELL)) != 0.0 or fmod(f.position.y, float(Room.CELL)) != 0.0:
			on_grid = false
		var cells := f.span * Foliage.S / Room.CELL
		for k in cells:
			var c := cell + Vector2i(k, 0)
			if not room.is_solid(c.x, c.y) or room.is_solid(c.x, c.y - 1) or c.x < 1 or c.x > Room.W - 2:
				on_ground = false
			if taken.has([f.kind, c]):
				crossed = true
			taken[[f.kind, c]] = true
		if f.get_parent() != view or f.z_index != -1 or f.visibility_layer != PixelCamera.WORLD_LAYER:
			behind = false
	check(on_grid, "%s: every patch stands on the room's grid" % what)
	check(on_ground, "%s: every patch grows on rock with open air over it, in from the edge" % what)
	check(not crossed, "%s: no two patches of a kind grow on one cell" % what)
	check(behind, "%s: every patch is under the room's view, behind everything that moves, seen by the pixel camera" % what)
	for row in Foliage.growths():
		var kind := String(row["foliage"])
		var of_kind: Array = view.plants.filter(func(f: Foliage) -> bool: return f.kind == kind)
		check(of_kind.size() >= int(row["fewest"]) and of_kind.size() <= int(row["most"]),
			"%s: it grows as many of kind %s as its row says, %d to %d (%d)"
				% [what, kind, int(row["fewest"]), int(row["most"]), of_kind.size()])
		var sized := true
		for f: Foliage in of_kind:
			var cells := f.span * Foliage.S / Room.CELL
			if cells < int(row["shortest"]) or cells > int(row["longest"]):
				sized = false
		check(sized, "%s: each %s patch %d to %d cells long" % [what, kind, int(row["shortest"]), int(row["longest"])])

func _rooms() -> void:
	var record := {"kind": "entry", "danger": 1, "region": 0, "variant": 7, "enemies": [], "loot": []}
	var a := _room(record, 12345)
	var view := Views.of(a) as RoomView
	check(view != null and not view.plants.is_empty(),
		"a room grows foliage when it is built (%d patches)" % (0 if view == null else view.plants.size()))
	if view == null:
		a.free()
		return
	_grown_well(a, view, "the bench")
	var b := _room(record, 12345)
	var vb := Views.of(b) as RoomView
	check(vb != null and _layout(vb) == _layout(view),
		"the same room grows the same foliage every time it is built")
	var flat := _room({"kind": "entry", "danger": 1, "region": 0, "variant": 3,
		"flat": true, "enemies": [], "loot": []}, 20260920)
	var vf := Views.of(flat) as RoomView
	var on_floor := vf != null and not vf.plants.is_empty()
	if vf != null:
		for f: Foliage in vf.plants:
			if f.position.y != float((Room.H - 2) * Room.CELL):
				on_floor = false
	check(on_floor, "a flat room grows on its floor, having nothing else")
	a.free()
	b.free()
	flat.free()

## --- what the schema refuses ------------------------------------------------

func _refusals() -> void:
	var db = _scratch()
	if db == null:
		check(false, "a scratch copy of the schema can be made to try it against")
		return
	var kind := "INSERT INTO foliage (id, form, sway, shortest, tallest, density, push, wind) VALUES ('fern', 'blades', 'along', 6, 14, 0.5, 8, 3)"
	var grow := "INSERT INTO growths (foliage, fewest, most, shortest, longest) VALUES ('fern', 0, 2, 1, 3)"
	check(_accepted(db, [kind, grow]), "a fourth kind, and the rooms growing it, are accepted (%s)" % db.error_message)
	check(not _accepted(db, [kind.replace("'blades', 'along'", "'vines', 'along'")]), "a picture nothing draws is refused")
	check(not _accepted(db, [kind.replace("'blades', 'along'", "'blades', 'up'")]), "a way of giving that is neither along nor any is refused")
	check(not _accepted(db, [kind.replace("6, 14,", "14, 6,")]), "a tallest under a shortest is refused")
	check(not _accepted(db, [kind.replace("6, 14,", "0, 14,")]), "a plant no pixels tall is refused")
	check(not _accepted(db, [kind.replace("0.5, 8", "0, 8")]), "a patch with nothing standing in it is refused")
	check(not _accepted(db, [kind.replace("0.5, 8", "1.5, 8")]), "more than every column is refused")
	check(not _accepted(db, [kind.replace("8, 3)", "-8, 3)")]), "a push under nothing is refused")
	check(not _accepted(db, [kind.replace("'fern'", "'Fern'")]), "a kind not in lower case is refused")
	check(not _accepted(db, [kind, grow.replace("0, 2, 1, 3", "2, 1, 1, 3")]), "a most under a fewest is refused")
	check(not _accepted(db, [kind, grow.replace("1, 3)", "3, 1)")]), "a longest under a shortest is refused")
	check(not _accepted(db, [kind, grow.replace("1, 3)", "0, 3)")]), "a patch no cells long is refused")
	check(not _accepted(db, [grow]), "growing a kind that is not there is refused")
	db.close_db()
	DirAccess.remove_absolute(SCRATCH)

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
		push_error("FOLIAGE: could not open %s: %s" % [SCRATCH, db.error_message])
		return null
	var schema := FileAccess.get_file_as_string(SRC.path_join("schema.sql"))
	if schema == "" or not db.query(schema):
		push_error("FOLIAGE: the schema did not run: %s" % db.error_message)
		return null
	return db

## Whether `statements` go in and commit, the way build.sh commits them. What
## went in is taken out again afterwards, so every try starts from nothing.
func _accepted(db, statements: Array) -> bool:
	var ok: bool = db.query("BEGIN")
	for st in statements:
		ok = ok and db.query(st)
	ok = ok and db.query("COMMIT")
	if not ok:
		db.query("ROLLBACK")
		return false
	db.query("DELETE FROM foliage")
	return true
