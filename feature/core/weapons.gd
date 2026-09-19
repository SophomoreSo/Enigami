class_name Weapons
extends RefCounted

## Weapons are the top-level choice made before a raid. A weapon supplies the
## slots a build lives in, the traits every skill fired from it inherits, and
## the compatibility rule that decides which skills may be slotted at all.
##
## Compatibility is expressed as slot tags rather than per-skill exceptions:
## a board's tags come from the forms and behaviors placed on it, and a weapon
## accepts a board when it shares at least one tag (a board with no offensive
## tag is pure utility and fits anywhere).
##
## Numbers only: the colour a weapon is named in, and the tile it is drawn
## with, are in `graphics/style.gd`.

const DEFS := {
	"SWORD": {
		"name": "Sword",
		"desc": "Close work. Melee flows hit far harder; bolts leave the blade sluggish.",
		"slots": 3,
		"accepts": ["melee", "mobility", "trigger", "area"],
		"base_damage": 12.0,
		"melee_mul": 1.45,
		"ranged_mul": 0.7,
		"projectile_speed": 0.8,
		"size_mul": 1.15,
		"gravity_shots": false,
		"innate": "slash",
	},
	"GUN": {
		"name": "Gun",
		"desc": "Range and speed. Bolts fly flat and fast; the stock makes a poor club.",
		"slots": 3,
		"accepts": ["ranged", "area", "trigger", "mobility"],
		"base_damage": 9.0,
		"melee_mul": 0.6,
		"ranged_mul": 1.3,
		"projectile_speed": 1.6,
		"size_mul": 0.95,
		"gravity_shots": false,
		"innate": "bolt",
	},
	"ROCK": {
		"name": "Rock",
		"desc": "A thrown stone takes anything. Heavy, arcing, and fussy about nothing.",
		"slots": 2,
		"accepts": ["ranged", "melee", "area", "mobility", "trigger"],
		"base_damage": 15.0,
		"melee_mul": 1.1,
		"ranged_mul": 1.15,
		"projectile_speed": 0.9,
		"size_mul": 1.25,
		"gravity_shots": true,
		"innate": "lob",
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

static func slots(id: String) -> int:
	return int(get_def(id)["slots"])

## Does this weapon accept a board? Utility boards (no offensive tag) always fit.
static func accepts_board(weapon_id: String, board: SkillBoard) -> bool:
	if board == null or board.is_empty():
		return true
	var accepts: Array = get_def(weapon_id)["accepts"]
	var tags := board.compute_tags()
	var offensive := false
	for t in tags:
		if t in ["melee", "ranged", "area"]:
			offensive = true
		if accepts.has(t):
			return true
	return not offensive

## Why a board was refused, phrased for the loadout screen.
static func rejection_reason(weapon_id: String, board: SkillBoard) -> String:
	if accepts_board(weapon_id, board):
		return ""
	var tags := board.compute_tags()
	return Loc.t("weapons.rejection", [name_for(weapon_id), Components.tag_names(tags)])

## The same refusal, short enough to float over a fight. `rejection_reason` is
## a sentence for the loadout screen; this is a label for the moment a player
## presses the button and nothing happens.
static func rejection_note(weapon_id: String, board: SkillBoard) -> String:
	if accepts_board(weapon_id, board):
		return ""
	return Loc.t("weapons.rejection_note", [name_for(weapon_id).to_upper(),
		Components.tag_names(board.compute_tags())])

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
		"AREA":
			p.damage *= float(d["ranged_mul"])
	return p

static func uses_gravity_shots(weapon_id: String) -> bool:
	return bool(get_def(weapon_id)["gravity_shots"])

## Each weapon ships with one fixed starter board so a fresh weapon is usable.
## Remaining slots are free, which keeps the weapon's identity without locking
## the whole build.
static func make_innate_board(weapon_id: String) -> SkillBoard:
	var kind: String = get_def(weapon_id)["innate"]
	var b := SkillBoard.new(7, 5, Loc.t("weapons.basic_board", [name_for(weapon_id)]))
	match kind:
		"slash":
			b.place("INPUT", Vector2i(0, 2), 0)
			b.place("SLASH", Vector2i(1, 2), 0)
			b.place("WIRE", Vector2i(2, 2), 0)
			b.place("OUTPUT", Vector2i(3, 2), 0)
		"bolt":
			b.place("INPUT", Vector2i(0, 2), 0)
			b.place("PROJECTILE", Vector2i(1, 2), 0)
			b.place("WIRE", Vector2i(2, 2), 0)
			b.place("OUTPUT", Vector2i(3, 2), 0)
		"lob":
			b.place("INPUT", Vector2i(0, 2), 0)
			b.place("PROJECTILE", Vector2i(1, 2), 0)
			b.place("DAMAGE", Vector2i(2, 2), 0)
			b.place("OUTPUT", Vector2i(3, 2), 0)
	return b
