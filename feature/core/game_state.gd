extends Node

## Persistent player state: stash, skill library, weapons, hideout facilities,
## and the raid kit that is put at risk every time the player deploys.

signal stash_changed()
signal loadout_changed()
signal records_changed()

## How many profiles can be kept side by side. The title screen offers this
## many rows; `graphics/ui/title_screen.gd` reads it rather than counting its
## own, so the two cannot disagree.
const SAVE_SLOTS := 3

## Where a profile saved before there were slots lives. It is read once, at
## boot, and becomes slot 1 — see `_migrate_legacy_save`.
const SAVE_PATH := "user://enigami_save.json"

static func slot_path(n: int) -> String:
	return "user://enigami_save_%d.json" % clampi(n, 1, SAVE_SLOTS)

## Which profile is being played, 1..SAVE_SLOTS. Everything saved goes here,
## and the title screen sets it by opening one.
var slot: int = 1
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
## Skills and weapons picked back up off a previous death, riding along. They
## are cargo rather than kit: a recovered board cannot be slotted mid-raid and a
## recovered weapon cannot be drawn, so both only become the player's again by
## being walked out of the raid — and are dropped again by dying with them.
var raid_carried_boards: Array[SkillBoard] = []
var raid_carried_weapons: Array[String] = []
## A raid put down mid-run, or {}. MAIN MENU inside a raid writes the run here
## instead of ending it, and opening the slot again walks back into it.
##
## The map is rebuilt from `raid_seed`, so none of it is in here: what a run
## changes is which rooms hold what, where the player is standing and how they
## are doing, and the clock. See `Raid.park` for the shape, `RaidMap.to_save`
## for the rooms inside it.
var raid_progress: Dictionary = {}

## --- what a death leaves behind ---------------------------------------------
## Dying does not destroy the kit any more; it drops it. Everything the run was
## carrying is left lying on the spot the player fell on, and the next
## deployment goes back into the same map to fetch it: the seed is kept, so the
## floor is the same floor, the room is in the same place, and the drop is in
## the room it was left in.
##
## One drop at a time. Dying on the way back to it leaves a newer one and the
## older one is gone, which is what a second death costs. It is written into the
## save, because outliving the run that made it is the whole point of it.
##
## The shape:
##   {"seed": int, "room": [x, y], "pos": [x, y],
##    "weapons": [id], "boards": [serialized], "bag": {id: n}, "scrap": int}
var lost_kit: Dictionary = {}

## --- records ----------------------------------------------------------------
var records: Dictionary = {
	"raids": 0, "escapes": 0, "deaths": 0, "kills": 0, "best_haul": 0,
}

## Whether this profile has been shown the opening scene. It is kept with the
## profile rather than with the settings on purpose: starting a new game is what
## earns the prologue, and wiping a profile earns it again.
var intro_seen: bool = false

const FACILITY_INFO := {
	"workbench": {"name": "Workbench", "max": 5},
	"vault": {"name": "Vault", "max": 5},
	"forge": {"name": "Forge", "max": 5},
	"scrapper": {"name": "Scrapper", "max": 5},
	"medbay": {"name": "Medbay", "max": 5},
}

## A facility's name, in the language being played. The table above is the
## fallback under it, so a facility added there is named before anybody
## translates it.
##
## What each one does is not written anywhere: the counter had a line along the
## bottom that said so while the mouse was on a row, and it was taken out.
func facility_name(key: String) -> String:
	return Loc.opt("hideout.facilities.info.%s.name" % key,
		String((FACILITY_INFO.get(key, {}) as Dictionary).get("name", key)))

func _ready() -> void:
	_migrate_legacy_save()
	# The one last written, so the records under the title menu belong to the
	# profile the player was last in rather than to whichever slot is first.
	load_slot(last_played_slot())

## A profile saved before there were slots becomes slot 1, so nobody loses one
## by updating. It runs once: after the rename there is nothing left to move.
func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(slot_path(1)):
		return
	DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH),
		ProjectSettings.globalize_path(slot_path(1)))

func _ensure_free_weapon() -> void:
	if not owned_weapons.has(FREE_WEAPON):
		owned_weapons.append(FREE_WEAPON)

## Builds a starting profile in memory, and only in memory. It used to write
## itself to disk on the way out, which is wrong now that a slot can be empty:
## booting would have stamped the first slot before the player had touched it,
## and emptying a slot would have filled it straight back in. Whoever wants this
## one kept says so.
func _new_profile() -> void:
	stash.clear()
	loadout_slots.clear()
	_forget_raid()
	lost_kit = {}
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

## --- the merchant -----------------------------------------------------------
## What a part costs at the counter, by what kind of part it is. Every price is
## above what breaking one down pays — a scrapper at its cap returns 25 — so
## buying a part to scrap it is never a trade, at any level of the hideout.
const SHOP_PRICES := {
	Components.CAT_FORM: 60,
	Components.CAT_ELEMENT: 55,
	Components.CAT_STAT: 40,
	Components.CAT_BEHAVIOR: 65,
	Components.CAT_FLOW: 70,
	Components.CAT_TRIGGER: 55,
	Components.CAT_STRUCT: 30,
}

## What the counter is selling: the lootable parts, in palette order. Structural
## parts are not among them — the editor hands those out for nothing, so a price
## on one would be a price on having a board at all.
static func shop_stock() -> Array:
	return Components.LOOT_POOL

func shop_price(id: String) -> int:
	var cat := String(Components.get_def(id).get("cat", Components.CAT_STAT))
	return int(SHOP_PRICES.get(cat, 50))

func can_buy(id: String) -> bool:
	return Components.exists(id) and scrap >= shop_price(id) \
		and component_count(id, stash) < stash_cap()

## One part, bought. False when the scrap is short or the vault has no room for
## another of that part — the stash cap is per component, and a purchase that
## silently vanished into a full shelf would be scrap for nothing.
func buy_component(id: String) -> bool:
	if not can_buy(id):
		return false
	scrap -= shop_price(id)
	add_component(id, 1)
	save_game()
	return true

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
	# The name is filled in once, here, and then belongs to the profile: a skill
	# the player has named is theirs, and a language switch must not rename it.
	var b := SkillBoard.new(s.x, s.y, Loc.t("hideout.skill_default", [skill_library.size() + 1]))
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
	raid_carried_boards.clear()
	raid_carried_weapons.clear()
	# A kit still lying where a death left it decides which map this is. The
	# same seed builds the same floor, so the room it was dropped in is in the
	# same place with the same way in — going back for it is a route the player
	# has already walked. With nothing waiting, the floor is rolled fresh.
	raid_seed = int(lost_kit.get("seed", 0)) if has_lost_kit() else randi()
	if raid_seed == 0:
		raid_seed = 1   # 0 reads as "no seed" to the raid; never hand it one
	# A fresh deployment, not the one that was put down: nothing of the last
	# raid's progress belongs to this one.
	raid_progress = {}
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
	# Whatever was recovered from an earlier death comes home as its own. The
	# boards arrive as new entries rather than into the slots they were lost
	# from: those slots were cleared when they were lost, and a library that has
	# been edited since would put them back over somebody else.
	var recovered: Array[String] = []
	for b in raid_carried_boards:
		recovered.append(b.skill_name)
		skill_library.append(b)
	for w in raid_carried_weapons:
		if not owned_weapons.has(w):
			owned_weapons.append(w)
	var haul := raid_bag.duplicate()
	for id in haul:
		add_component(id, int(haul[id]))
	scrap += raid_scrap
	if not owned_weapons.has(raid_weapon):
		owned_weapons.append(raid_weapon)
	records["escapes"] = int(records["escapes"]) + 1
	records["best_haul"] = max(int(records["best_haul"]), _haul_size(haul))
	var result := {"haul": haul, "scrap": raid_scrap, "weapon": raid_weapon,
		"recovered": recovered}
	_end_raid()
	return result

## The whole kit leaves with the run: the weapon, the skills that were slotted
## into it (and every component built into them), and everything found on the
## way. None of it is destroyed — it is put down where the player fell, and
## `where` is that spot, as `{"room": [x, y], "pos": [x, y]}` from the raid.
##
## Called with nowhere to leave it, the kit is simply gone, which is what it has
## always been and what ABANDON RAID still means: forfeiting is a decision, and
## a decision does not leave a trail to follow back.
func die(where: Dictionary = {}) -> Dictionary:
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
		"skills": lost_skills, "dropped": false,
	}
	if _can_drop(where):
		lost_kit = _drop_at(where)
		lost["dropped"] = true
	records["deaths"] = int(records["deaths"]) + 1
	_end_raid()
	return lost

func has_lost_kit() -> bool:
	return not lost_kit.is_empty()

## Whether there is a spot to leave the kit on at all. A room and a position in
## it are what the next raid needs to put it back on the floor; without both
## there is nowhere to go and get it.
func _can_drop(where: Dictionary) -> bool:
	return (where.get("room", []) as Array).size() == 2 \
		and (where.get("pos", []) as Array).size() == 2

## Everything this run was carrying, written down as one drop.
##
## What is dropped is the raid's own copies of the boards, edits and all, the
## same ones extracting would have written home — and only the ones that came
## out of the library, never the innate board a slotless deployment is handed,
## which was never the player's to lose or to find.
func _drop_at(where: Dictionary) -> Dictionary:
	var boards: Array = []
	for i in raid_boards.size():
		if i < raid_board_sources.size() and raid_board_sources[i] >= 0:
			boards.append(raid_boards[i].serialize())
	for b in raid_carried_boards:
		boards.append(b.serialize())
	var weapons: Array = []
	if raid_weapon != "" and raid_weapon != FREE_WEAPON:
		weapons.append(raid_weapon)
	for w in raid_carried_weapons:
		if not weapons.has(w):
			weapons.append(w)
	return {
		"seed": raid_seed,
		"room": (where["room"] as Array).duplicate(),
		"pos": (where["pos"] as Array).duplicate(),
		"weapons": weapons,
		"boards": boards,
		"bag": raid_bag.duplicate(),
		"scrap": raid_scrap,
	}

## Picking a drop up puts it back into the run, not into the vault: what is
## recovered is being carried, and it has to be walked out of the raid like
## everything else found down here. Dying with it drops the lot again.
##
## Returns what was in it, for whoever is announcing it, or {} when there was
## nothing to pick up.
func recover_lost_kit() -> Dictionary:
	if not has_lost_kit():
		return {}
	var kit := lost_kit.duplicate(true)
	for id in kit.get("bag", {}):
		add_component(String(id), int((kit["bag"] as Dictionary)[id]), raid_bag)
	raid_scrap += int(kit.get("scrap", 0))
	for b in kit.get("boards", []):
		raid_carried_boards.append(SkillBoard.deserialize(b))
	for w in kit.get("weapons", []):
		raid_carried_weapons.append(String(w))
	lost_kit = {}
	save_game()
	return kit

## How much is lying out there, as one number, for a screen that wants to say
## whether a drop is worth the walk rather than list it.
func lost_kit_size() -> int:
	if not has_lost_kit():
		return 0
	var n: int = (lost_kit.get("boards", []) as Array).size() \
		+ (lost_kit.get("weapons", []) as Array).size()
	return n + _haul_size(lost_kit.get("bag", {}))

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

## A raid is over and what it cost or paid has been settled. Written out on the
## spot: the drop a death leaves is the one piece of a run that is meant to be
## found by a later one, and a kit that only existed until the app closed would
## be a promise the save could not keep.
func _end_raid() -> void:
	_ensure_free_weapon()
	_forget_raid()
	records_changed.emit()
	save_game()

## Everything a raid holds, dropped. On its own this is not an outcome — the
## kit is neither carried home nor lost by it — so only `extract`, `die` and a
## new profile call it, each having already settled what became of the kit.
func _forget_raid() -> void:
	in_raid = false
	raid_weapon = ""
	raid_boards.clear()
	raid_board_sources.clear()
	raid_bag.clear()
	raid_scrap = 0
	raid_carried_boards.clear()
	raid_carried_weapons.clear()
	raid_progress = {}

## Puts the raid down where it stands, and writes it out. `where` is what the
## raid knows about itself; the kit it was carrying is already here.
##
## The run is not over: `in_raid` stays true, the weapon stays checked out of
## the vault, and nothing is counted. Picking the slot back up resumes it.
func park_raid(where: Dictionary) -> void:
	if not in_raid:
		return
	raid_progress = where
	save_game()

## Whether opening this slot walks back into a raid rather than the hideout.
func has_parked_raid() -> bool:
	return in_raid and not raid_progress.is_empty()

## A raid left in memory with nothing written down cannot be resumed — the app
## was closed mid-run rather than parked. The kit went with it, the way it
## always has; this only stops the flag outliving the raid it describes.
func drop_unparked_raid() -> void:
	if in_raid and raid_progress.is_empty():
		_end_raid()
		save_game()
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

## What the title screen needs to draw a slot without opening it: when it was
## last written, and what the profile in it has done. Reading a slot is not the
## same as playing it, so this never touches the live profile.
static func slot_info(n: int) -> Dictionary:
	var path := slot_path(n)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	return {"saved_at": int(d.get("saved_at", 0)), "records": d.get("records", {})}

## Whether there is a profile in slot `n` at all.
static func slot_used(n: int) -> bool:
	return not slot_info(n).is_empty()

## The slot written to most recently, or 1 when none has been.
static func last_played_slot() -> int:
	var best := 1
	var newest := 0
	for n in range(1, SAVE_SLOTS + 1):
		var at := int(slot_info(n).get("saved_at", 0))
		if at > newest:
			newest = at
			best = n
	return best

## Opens slot `n` — its profile if it has one, a fresh one if it does not — and
## makes it the slot everything saved from now on goes to.
func load_slot(n: int) -> bool:
	slot = clampi(n, 1, SAVE_SLOTS)
	var found := _read_save(slot_path(slot))
	if not found:
		_new_profile()
	_ensure_free_weapon()
	stash_changed.emit()
	loadout_changed.emit()
	records_changed.emit()
	return found

## Throws a profile away. There is no undo, which is why the screen that offers
## it asks twice. Emptying the slot being played leaves a new profile in memory,
## so nothing goes on showing the records of a save that no longer exists.
func delete_slot(n: int) -> void:
	var path := slot_path(n)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if clampi(n, 1, SAVE_SLOTS) == slot:
		_new_profile()
		_ensure_free_weapon()
		stash_changed.emit()
		loadout_changed.emit()
		records_changed.emit()

func save_game() -> void:
	var data := {
		"saved_at": int(Time.get_unix_time_from_system()),
		"stash": stash,
		"weapons": owned_weapons,
		"skills": skill_library.map(func(b: SkillBoard) -> Dictionary: return b.serialize()),
		"scrap": scrap,
		"facilities": facilities,
		"records": records,
		"loadout": loadout_slots,
		"intro_seen": intro_seen,
		# The raid in progress, if there is one. It used to be left out, so a
		# profile saved mid-raid came back with the weapon gone from the vault
		# and no raid to account for it.
		"in_raid": in_raid,
		"raid_weapon": raid_weapon,
		"raid_boards": raid_boards.map(func(b: SkillBoard) -> Dictionary: return b.serialize()),
		"raid_board_sources": raid_board_sources,
		"raid_bag": raid_bag,
		"raid_scrap": raid_scrap,
		"raid_seed": raid_seed,
		"raid_progress": raid_progress,
		"raid_carried_boards": raid_carried_boards.map(func(b: SkillBoard) -> Dictionary: return b.serialize()),
		"raid_carried_weapons": raid_carried_weapons,
		# Not raid state: a drop is what is left of a raid that is over, and it
		# has to still be there when the next one is deployed.
		"lost_kit": lost_kit,
	}
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

## Reads the slot being played back off disk.
func load_game() -> bool:
	return _read_save(slot_path(slot))

func _read_save(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
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
	lost_kit = parsed.get("lost_kit", {})
	_read_raid(parsed)
	return true

## The raid half of a save. A profile written before raids were kept has none
## of these keys, which reads as a profile standing in the hideout — which is
## what it was.
func _read_raid(parsed: Dictionary) -> void:
	_forget_raid()
	if not bool(parsed.get("in_raid", false)):
		return
	in_raid = true
	raid_weapon = String(parsed.get("raid_weapon", ""))
	for b in parsed.get("raid_boards", []):
		raid_boards.append(SkillBoard.deserialize(b))
	for i in parsed.get("raid_board_sources", []):
		raid_board_sources.append(int(i))
	for k in parsed.get("raid_bag", {}):
		raid_bag[String(k)] = int(parsed["raid_bag"][k])
	for b in parsed.get("raid_carried_boards", []):
		raid_carried_boards.append(SkillBoard.deserialize(b))
	for w in parsed.get("raid_carried_weapons", []):
		raid_carried_weapons.append(String(w))
	raid_scrap = int(parsed.get("raid_scrap", 0))
	raid_seed = int(parsed.get("raid_seed", 0))
	raid_progress = parsed.get("raid_progress", {})

## Starts this slot over. The wipe is meant to stick, so it is written out.
func reset_profile() -> void:
	_new_profile()
	_ensure_free_weapon()
	save_game()
	stash_changed.emit()
	loadout_changed.emit()
