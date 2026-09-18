extends Node

## Persistent player state: stash, skill library, weapons, hideout facilities,
## and the raid kit that is put at risk every time the player deploys.

signal stash_changed()
signal loadout_changed()
signal records_changed()

const SAVE_PATH := "user://enigami_save.json"
## There is always another rock. It cannot be lost, so a run of bad raids never
## leaves the player with nothing to deploy.
const FREE_WEAPON := "ROCK"

## --- hideout property -------------------------------------------------------
var stash: Dictionary = {}              ## component id -> count, safe at home
var owned_weapons: Array[String] = []
var skill_library: Array[SkillBoard] = []
var scrap: int = 0
## weapon id -> array of skill-library indices, one per slot (-1 = empty)
var loadout_slots: Dictionary = {}
var facilities: Dictionary = {
	"workbench": 1,  ## skill board size
	"vault": 1,      ## stash capacity per component
	"forge": 1,      ## craft components from scrap
	"scrapper": 1,   ## scrap value when breaking things down
	"medbay": 1,     ## max health and between-raid healing
}

## --- raid state -------------------------------------------------------------
var in_raid: bool = false
var raid_weapon: String = ""
var raid_boards: Array[SkillBoard] = []   ## live copies carried into the raid
var raid_board_sources: Array[int] = []   ## library index each raid board came from
var raid_bag: Dictionary = {}             ## loose components found this raid
var raid_scrap: int = 0
var raid_seed: int = 0

## --- records ----------------------------------------------------------------
var records: Dictionary = {
	"raids": 0, "escapes": 0, "deaths": 0, "kills": 0, "best_haul": 0,
}

## Whether this profile has been shown the opening scene. It is kept with the
## profile rather than with the settings on purpose: starting a new game is what
## earns the prologue, and wiping a profile earns it again.
var intro_seen: bool = false

const FACILITY_INFO := {
	"workbench": {"name": "Workbench", "desc": "Enlarges every skill board.", "max": 5},
	"vault": {"name": "Vault", "desc": "Raises how many of each component the stash holds.", "max": 5},
	"forge": {"name": "Forge", "desc": "Melts spare components into new ones.", "max": 5},
	"scrapper": {"name": "Scrapper", "desc": "Breaks gear down for more scrap.", "max": 5},
	"medbay": {"name": "Medbay", "desc": "Raises max health and heals between raids.", "max": 5},
}

func _ready() -> void:
	if not load_game():
		_new_profile()
	_ensure_free_weapon()

func _ensure_free_weapon() -> void:
	if not owned_weapons.has(FREE_WEAPON):
		owned_weapons.append(FREE_WEAPON)

func _new_profile() -> void:
	stash.clear()
	loadout_slots.clear()
	records = {"raids": 0, "escapes": 0, "deaths": 0, "kills": 0, "best_haul": 0}
	intro_seen = false
	owned_weapons = ["ROCK", "SWORD", "GUN"]
	skill_library.clear()
	scrap = 40
	for id in ["PROJECTILE", "SLASH", "DAMAGE", "FIRE", "SPLIT", "PIERCE", "DASH"]:
		stash[id] = 2
	skill_library.append(Weapons.make_innate_board("SWORD"))
	skill_library.append(Weapons.make_innate_board("GUN"))
	var utility := SkillBoard.new(7, 5, "Blink Step")
	utility.place("INPUT", Vector2i(0, 2), 0)
	utility.place("BLINK", Vector2i(1, 2), 0)
	utility.place("OUTPUT", Vector2i(2, 2), 0)
	skill_library.append(utility)
	save_game()

## --- derived stats ----------------------------------------------------------
func max_health() -> float:
	return 80.0 + 20.0 * float(facilities["medbay"])

func board_size() -> Vector2i:
	var l: int = facilities["workbench"]
	return Vector2i(6 + l, 4 + l)

func stash_cap() -> int:
	return 4 + 3 * int(facilities["vault"])

func facility_cost(key: String) -> int:
	return 60 * int(facilities[key]) * int(facilities[key])

func can_upgrade(key: String) -> bool:
	return facilities[key] < int(FACILITY_INFO[key]["max"]) and scrap >= facility_cost(key)

func upgrade_facility(key: String) -> bool:
	if not can_upgrade(key):
		return false
	scrap -= facility_cost(key)
	facilities[key] += 1
	if key == "workbench":
		var s := board_size()
		for b in skill_library:
			b.resize_grid(s.x, s.y)
	stash_changed.emit()
	save_game()
	return true

## --- stash ------------------------------------------------------------------
func add_component(id: String, n: int = 1, pool: Variant = null) -> void:
	var target: Dictionary = stash if pool == null else (pool as Dictionary)
	var cap := stash_cap() if target == stash else 99
	target[id] = mini(int(target.get(id, 0)) + n, cap)
	stash_changed.emit()

func component_count(id: String, pool: Dictionary) -> int:
	return int(pool.get(id, 0))

func take_component(id: String, pool: Dictionary) -> bool:
	if Components.is_structural(id):
		return true
	if int(pool.get(id, 0)) <= 0:
		return false
	pool[id] = int(pool[id]) - 1
	if pool[id] <= 0:
		pool.erase(id)
	stash_changed.emit()
	return true

func return_component(id: String, pool: Dictionary) -> void:
	if Components.is_structural(id):
		return
	pool[id] = int(pool.get(id, 0)) + 1
	stash_changed.emit()

## Trading one board in for another against a pool of parts: everything `have`
## is built out of goes back, everything `want` needs comes out. A shared code
## is a blueprint and not the parts, so pasting one costs exactly what building
## it by hand would have — which is also why the sandbox, where parts are free,
## never asks.
##
## All or nothing. If the pool cannot cover the difference nothing moves at all,
## so a refused paste leaves the bag exactly as it found it, and what is missing
## comes back instead: id -> how many more are needed. `{}` means it went
## through. `have` may be null, for a board being filled from nothing.
func trade_board(have: SkillBoard, want: SkillBoard, pool: Dictionary) -> Dictionary:
	var need: Dictionary = want.used_components()
	var back: Dictionary = have.used_components() if have != null else {}
	var missing: Dictionary = {}
	for id in need:
		var short := int(need[id]) - int(back.get(id, 0)) - int(pool.get(id, 0))
		if short > 0:
			missing[id] = short
	if not missing.is_empty():
		return missing
	for id in back:
		for i in int(back[id]):
			return_component(id, pool)
	for id in need:
		for i in int(need[id]):
			take_component(id, pool)
	return {}

## Forge: spend scrap and three spare parts for one random better part.
func forge_component(inputs: Array[String]) -> String:
	if inputs.size() < 3 or scrap < 25:
		return ""
	for id in inputs:
		if not take_component(id, stash):
			return ""
	scrap -= 25
	var pool := Components.LOOT_POOL.duplicate()
	var out: String = pool[randi() % pool.size()]
	add_component(out, 1)
	save_game()
	return out

func scrap_component(id: String) -> int:
	if not take_component(id, stash):
		return 0
	var gain := 5 * int(facilities["scrapper"])
	scrap += gain
	stash_changed.emit()
	save_game()
	return gain

## Slot assignment for a weapon, sized to that weapon and sanitised against a
## library that may have shrunk since it was saved.
func get_loadout(weapon_id: String) -> Array:
	var n := Weapons.slots(weapon_id)
	var cur: Array = loadout_slots.get(weapon_id, [])
	var out: Array = []
	for i in n:
		var v := int(cur[i]) if i < cur.size() else -1
		out.append(v if v >= 0 and v < skill_library.size() else -1)
	loadout_slots[weapon_id] = out
	return out

func set_loadout(weapon_id: String, slots_arr: Array) -> void:
	loadout_slots[weapon_id] = slots_arr.duplicate()
	loadout_changed.emit()
	save_game()

## --- skill library ----------------------------------------------------------
func new_skill() -> SkillBoard:
	var s := board_size()
	var b := SkillBoard.new(s.x, s.y, "Skill %d" % (skill_library.size() + 1))
	b.place("INPUT", Vector2i(0, int(s.y / 2)), 0)
	b.place("OUTPUT", Vector2i(s.x - 1, int(s.y / 2)), 0)
	skill_library.append(b)
	loadout_changed.emit()
	return b

func delete_skill(idx: int) -> void:
	if idx < 0 or idx >= skill_library.size():
		return
	# Components on a discarded board come back to the stash.
	for id in skill_library[idx].used_components():
		add_component(id, int(skill_library[idx].used_components()[id]))
	skill_library.remove_at(idx)
	loadout_changed.emit()
	save_game()

## --- raid lifecycle ---------------------------------------------------------
## Deploying binds the weapon and its slotted skills into a kit that is lost on
## death. Everything left at home stays safe.
func deploy(weapon_id: String, slot_indices: Array) -> void:
	in_raid = true
	raid_weapon = weapon_id
	raid_boards.clear()
	raid_board_sources.clear()
	for i in slot_indices:
		if i >= 0 and i < skill_library.size():
			raid_boards.append(skill_library[i].duplicate_board())
			raid_board_sources.append(int(i))
	if raid_boards.is_empty():
		raid_boards.append(Weapons.make_innate_board(weapon_id))
		raid_board_sources.append(-1)
	raid_bag.clear()
	raid_scrap = 0
	raid_seed = randi()
	if weapon_id != FREE_WEAPON:
		owned_weapons.erase(weapon_id)
	records["raids"] = int(records["raids"]) + 1
	records_changed.emit()
	save_game()

func extract() -> Dictionary:
	# Edits made mid-raid come home with the kit: the parts spent on them left
	# the bag when they were placed, so nothing is counted twice.
	for i in raid_board_sources.size():
		var src: int = raid_board_sources[i]
		if src >= 0 and src < skill_library.size() and i < raid_boards.size():
			skill_library[src] = raid_boards[i]
	var haul := raid_bag.duplicate()
	for id in haul:
		add_component(id, int(haul[id]))
	scrap += raid_scrap
	if not owned_weapons.has(raid_weapon):
		owned_weapons.append(raid_weapon)
	records["escapes"] = int(records["escapes"]) + 1
	records["best_haul"] = max(int(records["best_haul"]), _haul_size(haul))
	var result := {"haul": haul, "scrap": raid_scrap, "weapon": raid_weapon}
	_end_raid()
	return result

func die() -> Dictionary:
	# The whole kit is gone: the weapon, the skills that were slotted into it
	# (and every component built into them), and everything found on the way.
	var lost_skills: Array[String] = []
	var indices := raid_board_sources.duplicate()
	indices.sort()
	indices.reverse()
	for src in indices:
		if src >= 0 and src < skill_library.size():
			lost_skills.append(skill_library[src].skill_name)
			skill_library.remove_at(src)
			_shift_loadouts_after(src)
	var lost := {
		"weapon": raid_weapon, "haul": raid_bag.duplicate(), "scrap": raid_scrap,
		"skills": lost_skills,
	}
	records["deaths"] = int(records["deaths"]) + 1
	_end_raid()
	return lost

## Keeps saved loadouts pointing at the right skills after one is destroyed.
func _shift_loadouts_after(removed: int) -> void:
	for w in loadout_slots:
		var arr: Array = loadout_slots[w]
		for i in arr.size():
			var v := int(arr[i])
			if v == removed:
				arr[i] = -1
			elif v > removed:
				arr[i] = v - 1

func _end_raid() -> void:
	_ensure_free_weapon()
	in_raid = false
	raid_weapon = ""
	raid_boards.clear()
	raid_board_sources.clear()
	raid_bag.clear()
	raid_scrap = 0
	records_changed.emit()
	save_game()

func _haul_size(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n

func register_kill() -> void:
	records["kills"] = int(records["kills"]) + 1

## The opening scene has been played, or skipped. Saved on the spot: a prologue
## sat through once is never sat through again, whatever happens after it.
func mark_intro_seen() -> void:
	if intro_seen:
		return
	intro_seen = true
	save_game()

## --- persistence ------------------------------------------------------------
func save_game() -> void:
	var data := {
		"stash": stash,
		"weapons": owned_weapons,
		"skills": skill_library.map(func(b: SkillBoard) -> Dictionary: return b.serialize()),
		"scrap": scrap,
		"facilities": facilities,
		"records": records,
		"loadout": loadout_slots,
		"intro_seen": intro_seen,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	stash.clear()
	for k in parsed.get("stash", {}):
		stash[String(k)] = int(parsed["stash"][k])
	owned_weapons.clear()
	for w in parsed.get("weapons", ["SWORD"]):
		owned_weapons.append(String(w))
	skill_library.clear()
	for s in parsed.get("skills", []):
		skill_library.append(SkillBoard.deserialize(s))
	scrap = int(parsed.get("scrap", 0))
	var fac: Dictionary = parsed.get("facilities", {})
	for k in facilities:
		if fac.has(k):
			facilities[k] = int(fac[k])
	loadout_slots = parsed.get("loadout", {})
	# A profile saved before there was an opening scene has already played the
	# game, so it is not shown one now.
	intro_seen = bool(parsed.get("intro_seen", true))
	var rec: Dictionary = parsed.get("records", {})
	for k in records:
		if rec.has(k):
			records[k] = int(rec[k])
	return true

func reset_profile() -> void:
	_new_profile()
	stash_changed.emit()
	loadout_changed.emit()
