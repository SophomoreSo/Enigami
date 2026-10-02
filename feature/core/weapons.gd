class_name Weapons
extends RefCounted

## Weapons are the top-level choice made before a raid. A weapon is a graph:
## its own attack form is the root of a board — the sword's DASHSLASH, the
## gun's PROJECTILE — and everything the player wires on round it is the skill
## that weapon casts. There is no skill without a weapon and no weapon without
## its graph; what a raid carries is the weapon and the graph on it.
##
## The graph a new profile is handed for each weapon is a board in the content
## database (`data/db/boards/weapons.sql`): the root part and nothing else,
## standing against the board's way out, which is enough to fire. `root` names
## that part, so a screen can say
## what a weapon is before its board is built; `tests/feature/boards_test`
## holds the two to each other.
##
## Numbers only: the colour a weapon is named in, and the tile it is drawn
## with, are in `graphics/style.gd`.

const DEFS := {
	"SWORD": {
		"name": "Sword",
		"desc": "Close work. A lunge that cuts everything on its line; melee flows hit far harder, and bolts leave the blade sluggish.",
		"root": "DASHSLASH",
		"board": "sword",
		"base_damage": 12.0,
		"melee_mul": 1.45,
		"ranged_mul": 0.7,
		"projectile_speed": 0.8,
		"reach_mul": 0.7,
		"size_mul": 1.15,
		"gravity_shots": false,
	},
	"GUN": {
		"name": "Gun",
		"desc": "Range and speed. Bolts fly flat and fast; the stock makes a poor club.",
		"root": "PROJECTILE",
		"board": "gun",
		"base_damage": 9.0,
		"melee_mul": 0.6,
		"ranged_mul": 1.3,
		"projectile_speed": 1.6,
		"reach_mul": 1.5,
		"size_mul": 0.95,
		"gravity_shots": false,
	},
	"ROCK": {
		"name": "Rock",
		"desc": "A thrown stone takes anything. Heavy, arcing, and fussy about nothing.",
		"root": "PROJECTILE",
		"board": "rock",
		"base_damage": 15.0,
		"melee_mul": 1.1,
		"ranged_mul": 1.15,
		"projectile_speed": 0.9,
		"reach_mul": 1.0,
		"size_mul": 1.25,
		"gravity_shots": true,
	},
}

static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["SWORD"])

## The weapon's name and what it is like to swing, in the language being
## played. The `name` and `desc` above are the fallback under them, the same
## way `Components.name_for` falls back.
static func name_for(id: String) -> String:
	return Loc.opt("weapons.%s.name" % id, String(get_def(id)["name"]))

static func desc_for(id: String) -> String:
	return Loc.opt("weapons.%s.desc" % id, String(get_def(id)["desc"]))

static func ids() -> Array:
	return DEFS.keys()

## The part on the root of this weapon's graph: its own attack form.
static func root_part(id: String) -> String:
	return String(get_def(id)["root"])

## The starting payload every flow on this weapon begins with.
static func base_payload(weapon_id: String) -> Payload:
	var d := get_def(weapon_id)
	var p := Payload.new()
	p.damage = float(d["base_damage"])
	p.size = float(d["size_mul"])
	p.speed = float(d["projectile_speed"])
	return p

## Weapon traits applied once the flow has resolved into an attack.
static func finalize(weapon_id: String, p: Payload) -> Payload:
	var d := get_def(weapon_id)
	match p.form:
		"SLASH", "DASHSLASH", "DASHSLASH_AUTO":
			p.damage *= float(d["melee_mul"])
		"PROJECTILE":
			p.damage *= float(d["ranged_mul"])
			p.speed *= float(d["projectile_speed"])
			# How far the thing throws, which is the weapon's own answer and not
			# a side effect of how fast it throws: the gun reaches across most
			# of a room, the rock a good throw, and a bolt off the sword barely
			# clears the space a swing would have covered.
			p.range_px *= float(d["reach_mul"])
		"ZAP":
			# Ranged, and it reaches as far as the weapon throws: a beam off the
			# gun crosses most of a room, one off a thrown rock a good throw.
			p.damage *= float(d["ranged_mul"])
			p.range_px *= float(d["reach_mul"])
		"EXPLODE":
			p.damage *= float(d["ranged_mul"])
	return p

static func uses_gravity_shots(weapon_id: String) -> bool:
	return bool(get_def(weapon_id)["gravity_shots"])

## The weapon's graph as a new profile gets it: its `board` in the content
## database (`data/db/boards/weapons.sql`), named after the weapon. What a
## player builds onto it is theirs and lives in the save; this is the bare one.
static func make_board(weapon_id: String) -> SkillBoard:
	return Boards.build(String(get_def(weapon_id)["board"]), name_for(weapon_id))
