class_name ScreenPages
extends RefCounted

## The two pages of the screen over a world with no map of its own — the bench,
## the hideout's workbench, a played map and the tests: the assembly board, and
## the map's page, which says there is no map (`MapPanel`, with none to show).
## The MAP tab stands along the top there as it does in a raid, and the map's
## key puts its page up as it does there.
##
## One page is up at a time. Whether the screen is up at all is the world's
## `editing`, and which page is up is this: a tab, or the other page's key, puts
## the other one up in its place without the screen going anywhere. A raid's
## pages are the raid's own states instead (`Raid.set_reading_map`, `RaidView`),
## since there reading the map is a thing the raid knows about.

var editor: SkillEditor
var map: MapPanel
## The page that is up, or the one the screen comes up on while it is away.
var page := ScreenTabs.GRAPH

## Builds the map's page beside `ed`, on the layer it is on, and puts the screen
## away through `close` from that page as the board does from its own.
func _init(ed: SkillEditor, close: Callable) -> void:
	editor = ed
	map = MapPanel.new()
	map.visible = false
	ed.get_parent().add_child(map)
	map.closed.connect(close)
	ed.page_picked.connect(put)
	map.page_picked.connect(put)

## Puts `id`'s page up and the other away.
func put(id: String) -> void:
	page = id
	editor.visible = id == ScreenTabs.GRAPH
	map.visible = id == ScreenTabs.MAP
	if editor.visible:
		editor.grab_focus()

## Both away, with the screen; it comes up on the graph's page next time,
## unless the map's key is what brings it up.
func away() -> void:
	editor.visible = false
	map.visible = false
	page = ScreenTabs.GRAPH
