class_name Monsters
extends RefCounted

## Monster attacks are built on the same boards the player uses. That is what
## makes their drops legible: a kill can yield a part the monster was visibly
## using, so watching an attack teaches you how to build it.
##
## Stats only. Which atlas character draws a monster, what colour its death
## bursts, and how a modifier is marked all live in `graphics/style.gd`, keyed
## by the same ids used here — so a monster added here still spawns and fights
## before anyone has chosen how it should look.

const DEFS := {
	"CRAWLER": {
		"name": "Crawler", "hp": 32.0, "speed": 165.0, "ai": "runner",
		"size": 14.0,
		"aggro": 420.0, "attack_range": 60.0, "contact": 6.0, "scrap": 3,
		"board": [["INPUT", 0, 2, 0], ["SLASH", 1, 2, 0], ["OUTPUT", 2, 2, 0]],
	},
	"SENTRY": {
		"name": "Sentry", "hp": 46.0, "speed": 0.0, "ai": "turret",
		"size": 16.0,
		"aggro": 560.0, "attack_range": 560.0, "contact": 0.0, "scrap": 4,
		"board": [["INPUT", 0, 2, 0], ["PROJECTILE", 1, 2, 0], ["WIRE", 2, 2, 0], ["OUTPUT", 3, 2, 0]],
	},
	"LOBBER": {
		"name": "Lobber", "hp": 38.0, "speed": 70.0, "ai": "walker",
		"size": 15.0,
		"aggro": 480.0, "attack_range": 420.0, "contact": 4.0, "scrap": 4,
		"board": [["INPUT", 0, 2, 0], ["PROJECTILE", 1, 2, 0], ["DAMAGE", 2, 2, 0], ["OUTPUT", 3, 2, 0]],
		"gravity": true,
	},
	"HOPPER": {
		"name": "Hopper", "hp": 52.0, "speed": 130.0, "ai": "jumper",
		"size": 17.0,
		"aggro": 440.0, "attack_range": 110.0, "contact": 8.0, "scrap": 5,
		"board": [["INPUT", 0, 2, 0], ["AREA", 1, 2, 0], ["OUTPUT", 3, 2, 0]],
	},
	"DRIFTER": {
		"name": "Drifter", "hp": 30.0, "speed": 95.0, "ai": "flyer",
		"size": 13.0,
		"aggro": 520.0, "attack_range": 400.0, "contact": 5.0, "scrap": 4,
		"board": [["INPUT", 0, 2, 0], ["PROJECTILE", 1, 2, 0], ["HOMING", 2, 2, 0], ["OUTPUT", 3, 2, 0]],
	},
	"WARDEN": {
		"name": "Warden", "hp": 105.0, "speed": 105.0, "ai": "runner",
		"size": 20.0,
		"aggro": 560.0, "attack_range": 460.0, "contact": 9.0, "scrap": 10,
		"elite": true,
		"board": [
			["INPUT", 0, 2, 0], ["PROJECTILE", 1, 2, 0], ["ICE", 2, 2, 0],
			["SPLIT", 3, 2, 0], ["BEND", 3, 1, 1], ["BEND", 3, 3, 3],
			["OUTPUT", 4, 1, 0], ["OUTPUT", 4, 3, 0],
		],
	},
	"DUMMY": {
		"name": "Test Dummy", "hp": 99999.0, "speed": 0.0, "ai": "turret",
		"size": 18.0,
		"aggro": 0.0, "attack_range": 0.0, "contact": 0.0, "scrap": 0,
		"board": [],
	},
	## The dragon test's guards. One cut from any weapon drops one, and they hold
	## their posts, so a chain of lunges is judged on reach and line alone.
	"GRUNT": {
		"name": "Grunt", "hp": 1.0, "speed": 0.0, "ai": "turret",
		"size": 14.0,
		"aggro": 900.0, "attack_range": 0.0, "contact": 0.0, "scrap": 0,
		"board": [],
	},
	"ARBITER": {
		"name": "Arbiter", "hp": 460.0, "speed": 120.0, "ai": "boss",
		"size": 34.0,
		"aggro": 900.0, "attack_range": 700.0, "contact": 14.0, "scrap": 60,
		"boss": true,
		"board": [
			["INPUT", 0, 2, 0], ["PROJECTILE", 1, 2, 0], ["FIRE", 2, 2, 0],
			["DUPLICATE", 3, 2, 0], ["OUTPUT", 4, 2, 0],
		],
		"board_phase2": [
			["INPUT", 0, 2, 0], ["AREA", 1, 2, 0], ["ON_HIT", 3, 2, 0],
			["OUTPUT", 4, 2, 0], ["BEND", 3, 3, 0], ["PROJECTILE", 4, 3, 0],
			["SPLIT", 5, 3, 0], ["OUTPUT", 5, 2, 0], ["OUTPUT", 5, 4, 0],
		],
	},
}

const NORMAL_POOL := ["CRAWLER", "SENTRY", "LOBBER", "HOPPER", "DRIFTER"]

static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["CRAWLER"])

static func build_board(id: String, key: String = "board") -> SkillBoard:
	var d := get_def(id)
	var b := SkillBoard.new(7, 5, String(d["name"]))
	for e in d.get(key, []):
		b.place(String(e[0]), Vector2i(int(e[1]), int(e[2])), int(e[3]))
	return b

## Parts the monster's own attack is assembled from — its possible drops.
static func drop_pool(id: String) -> Array:
	var pool: Array = []
	for e in get_def(id).get("board", []):
		var cid := String(e[0])
		if not Components.is_structural(cid) and not pool.has(cid):
			pool.append(cid)
	for e in get_def(id).get("board_phase2", []):
		var cid := String(e[0])
		if not Components.is_structural(cid) and not pool.has(cid):
			pool.append(cid)
	return pool

## Picks a monster appropriate to how deep and how long the raid has run.
static func pick(rng: RandomNumberGenerator, danger: int) -> String:
	if danger >= 3 and rng.randf() < 0.22:
		return "WARDEN"
	return NORMAL_POOL[rng.randi() % NORMAL_POOL.size()]
