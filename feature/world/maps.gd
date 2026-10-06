class_name Maps
extends RefCounted

## The maps made in the map creator (`MapMaker`), as files: each a scene of one
## `MadeRoom`, named for the map — `data/maps/keep.tscn` is the map `keep`.
##
## A scene, so that a map is something Godot opens and anything in the game can
## pick up: `load_room` here, or `load(path).instantiate()` anywhere. What is in
## one is `MadeRoom`'s to say.
##
## Where they are kept depends on what is running. Run from the project — the
## editor, or `godot --path` — a map is saved into the project itself, beside
## the rest of the content, where it is committed and shipped with the game. An
## exported game cannot write into itself, so there a map goes to `user://maps`,
## and the ones the game shipped with are read from where they always were.

## The project's own maps, and the ones made on a machine the game was only
## installed on.
const PROJECT_DIR := "res://data/maps"
const USER_DIR := "user://maps"
const EXTENSION := "tscn"
## The most letters a map's name is kept to.
const ID_LENGTH := 24

## Somewhere else to keep them, in place of both: a test's scratch folder.
static var scratch_dir: String = ""

## Whether this run may write into the project's own folder.
static func in_project() -> bool:
	return OS.has_feature("editor")

## The folder a map is saved into.
static func save_dir() -> String:
	if scratch_dir != "":
		return scratch_dir
	return PROJECT_DIR if in_project() else USER_DIR

## The folders maps are looked for in, the one searched first leading: a map
## made on this machine stands in front of one the game shipped under its name.
static func dirs() -> PackedStringArray:
	if scratch_dir != "":
		return PackedStringArray([scratch_dir])
	if in_project():
		return PackedStringArray([PROJECT_DIR])
	return PackedStringArray([USER_DIR, PROJECT_DIR])

## The name a map is filed under, from one as it was typed: lower case, letters
## and digits, with an underscore for each run of anything set between them.
## "" for a name with nothing in it to keep.
static func id_for(typed: String) -> String:
	var out := ""
	for ch in typed.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif out != "" and not out.ends_with("_"):
			out += "_"
	return out.left(ID_LENGTH).trim_suffix("_")

## Every map there is, by id, in order.
static func ids() -> PackedStringArray:
	var found := {}
	for dir in dirs():
		if not DirAccess.dir_exists_absolute(dir):
			continue
		# Asked of the loader rather than of the folder: in an exported game a
		# scene is filed under another name, and this answers with its own.
		for file in ResourceLoader.list_directory(dir):
			if file.get_extension() == EXTENSION:
				found[file.get_basename()] = true
	var out := PackedStringArray(found.keys())
	out.sort()
	return out

## Where the map `id` is, or "" when there is none by that name.
static func path_of(id: String) -> String:
	if id == "":
		return ""
	for dir in dirs():
		var path := dir.path_join("%s.%s" % [id, EXTENSION])
		if ResourceLoader.exists(path):
			return path
	return ""

static func exists(id: String) -> bool:
	return path_of(id) != ""

## Keeps `room` as the map `id`: a scene whose one node is that `MadeRoom`,
## carrying its layers and its tileset, named for the map. Over whatever was
## kept under that name. The room is the caller's still, and out of the tree.
static func save(id: String, room: MadeRoom) -> Error:
	if id == "" or id != id_for(id) or room == null or room.is_inside_tree():
		return ERR_INVALID_PARAMETER
	room.name = id.to_pascal_case()
	var scene := PackedScene.new()
	var err := scene.pack(room)
	if err != OK:
		return err
	err = DirAccess.make_dir_recursive_absolute(save_dir())
	if err != OK:
		return err
	return ResourceSaver.save(scene, save_dir().path_join("%s.%s" % [id, EXTENSION]))

## The map `id` as a room of its own, not yet in the tree and not yet stood
## (`MadeRoom.stand`) — or null when there is no such map, or the scene under
## that name is not one. Read off the file each time: a map saved over while
## the game runs is the map that comes back.
static func load_room(id: String) -> MadeRoom:
	var path := path_of(id)
	if path == "":
		return null
	var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if scene == null or not scene.can_instantiate():
		return null
	var node := scene.instantiate()
	if node is MadeRoom:
		return node
	node.free()
	return null

## Throws the map `id` away, where this run may: out of the folder it saves
## into. A map the game shipped with is not an exported game's to remove.
static func remove(id: String) -> Error:
	var path := save_dir().path_join("%s.%s" % [id, EXTENSION])
	if id == "" or not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(path)
