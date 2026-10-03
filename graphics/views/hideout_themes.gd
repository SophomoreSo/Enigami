class_name HideoutThemes
extends RefCounted

## The looks the hideout can be dressed in, and the one it is wearing.
##
## Here while one is being chosen, and for no longer. The room has one look in
## the end, and this is the question of which: each is a `HideoutScenery` of
## its own, the pause menu keeps a page that lists them while the player is
## in the hideout (`app/game.gd`, `ThemePicker`), and picking one dresses the
## room in it there and then (`HideoutWorldView`).
##
## Another look is three things: a script beside the others that extends
## `HideoutScenery`, its id in LOOKS and in `make` here, and its name under
## `hideout.theme.look` in every language. Nothing else names a look, and
## `tests/graphics/hideout_scenery_test` holds whatever is in LOOKS to what a
## look has to keep to.
##
## The pick is kept in a file of its own beside the language and the key
## bindings: it is a choice about the picture, not about the profile being
## played, and throwing a save away does not change the wallpaper.

## Where the pick is kept.
const PATH := "user://enigami_hideout_theme.json"
## The looks, in the order the page lists them. Their names are
## `hideout.theme.look.<id>` in `localization/`.
const LOOKS := ["city", "keep", "grove", "orbit", "brass"]
## The one a room wears until somebody picks another.
const DEFAULT := "city"

static var _picked := ""
## Whoever dresses a room in the pick, to be told when it changes — by a call
## and not by asking every frame, since the page that changes it stops the
## game, and a stopped room asks nothing.
static var _watchers: Array[Callable] = []

## The look in force.
static func picked() -> String:
	if _picked == "":
		_picked = _saved()
	return _picked

## Dresses the hideout in `id`, and keeps it for next time unless `keep` says
## not to — a test trying one on leaves the desk's own pick alone. A look that
## is not one of LOOKS is refused.
static func pick(id: String, keep: bool = true) -> void:
	if not LOOKS.has(id) or id == picked():
		return
	_picked = id
	if keep:
		_save()
	# Whoever was watching and has since gone is dropped on the way.
	var live: Array[Callable] = []
	for w in _watchers:
		if w.is_valid():
			live.append(w)
	_watchers = live
	for w in live:
		w.call(id)

## Has `on_pick` called with the look's id whenever the pick changes, for as
## long as whatever it belongs to lasts.
static func watch(on_pick: Callable) -> void:
	_watchers.append(on_pick)

## What a look is called, in the language being played.
static func name_for(id: String) -> String:
	return Loc.t("hideout.theme.look.%s" % id)

## The scenery of the look `id`, ready to be stood in a room.
static func make(id: String) -> HideoutScenery:
	var scenery: HideoutScenery
	match id:
		"keep":
			scenery = HideoutKeep.new()
		"grove":
			scenery = HideoutGrove.new()
		"orbit":
			scenery = HideoutOrbit.new()
		"brass":
			scenery = HideoutBrass.new()
		_:
			id = DEFAULT
			scenery = HideoutCity.new()
	scenery.look = id
	return scenery

## --- the file ---------------------------------------------------------------

static func _saved() -> String:
	if not FileAccess.file_exists(PATH):
		return DEFAULT
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary):
		return DEFAULT
	var id := String((parsed as Dictionary).get("look", DEFAULT))
	return id if LOOKS.has(id) else DEFAULT

static func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"look": _picked}))
	f.close()

## Forgets the pick, so the next thing to ask reads the file again: for a
## test, which is the only thing that changes the file behind this. (Not
## `reload`: a script has one of those already, and it empties the lot.)
static func reread() -> void:
	_picked = ""
