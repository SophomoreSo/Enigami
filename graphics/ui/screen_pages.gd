class_name ScreenPages
extends RefCounted

## The pages of the screen over a world with no map of its own — the bench,
## the hideout's workbench, a played map and the tests: the assembly board, the
## map's page, which says there is no map (`MapPanel`, with none to show), and
## the monster dictionary (`MonsterDex`). The MAP tab stands along the top there
## as it does in a raid, and the map's key puts its page up as it does there.
##
## One page is up at a time. Whether the screen is up at all is the world's
## `editing`, and which page is up is this: a tab, or another page's key, puts
## that page up in its place without the screen going anywhere. A raid's
## pages are the raid's own states instead (`Raid.set_reading_map`,
## `Raid.set_reading_dex`, `RaidView`), since there reading the map is a thing
## the raid knows about.

var editor: SkillEditor
var map: MapPanel
var dex: MonsterDex
## The page that is up, or the one the screen comes up on while it is away.
var page := ScreenTabs.GRAPH

## Builds the map's page and the dictionary beside `ed`, on the layer it is on,
## and puts the screen away through `close` from either as the board does from
## its own.
func _init(ed: SkillEditor, close: Callable) -> void:
	editor = ed
	map = MapPanel.new()
	map.visible = false
	ed.get_parent().add_child(map)
	dex = MonsterDex.new()
	dex.visible = false
	ed.get_parent().add_child(dex)
	for p in [map, dex]:
		p.closed.connect(close)
		p.page_picked.connect(put)
	ed.page_picked.connect(put)

## Puts `id`'s page up and the others away.
func put(id: String) -> void:
	page = id
	editor.visible = id == ScreenTabs.GRAPH
	map.visible = id == ScreenTabs.MAP
	dex.visible = id == ScreenTabs.DEX
	if editor.visible:
		editor.grab_focus()

## All away, with the screen; it comes up on the graph's page next time,
## unless the map's key is what brings it up.
func away() -> void:
	editor.visible = false
	map.visible = false
	dex.visible = false
	page = ScreenTabs.GRAPH

## The pages besides the board, for whoever frees them along with it.
func others() -> Array:
	return [map, dex]
