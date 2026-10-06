# Maps

Rooms made in the map creator (title → **MAP CREATOR**), one scene each:
`keep.tscn` is the map `keep`. SAVE writes them here when the game is run from
the project — the editor, or `godot --path` — and what is here is committed
and ships with the game. An exported game cannot write into itself: it keeps
the maps made on that machine under `user://maps/`, and reads these as the
ones it came with. `Maps` (`feature/world/maps.gd`) is what knows where.

## What is in one

One node: a `MadeRoom` (`feature/world/made_room.gd`), which is a room laid by
hand (`HandLaidRoom`) rather than generated — the way the dragon test's tower
is, with its rows in the scene rather than in a script. It has two properties:

| Property | Meaning |
|---|---|
| `plan` | The rows of cells, top to bottom: one string a row, a character a cell, every row the same length. |
| `region` | 0 to 3: which region's rock the room is cut from. |

| Cell | Meaning |
|---|---|
| `#` | Rock. |
| `.` | Open. |
| `P` | Where the player starts. One a map. With none, the floor nearest the middle. |
| `T` | The room's treasure box. One a map. It is put down on the first floor under its cell. |
| `x` | Ground worth digging, put down the same way. |
| `c` `s` `l` `h` `d` | A post for a Crawler, a Sentry, a Lobber, a Hopper, a Drifter. |
| `w` `g` `u` `y` `a` | And for a Warden, a Gunman, a Grunt, a Test Dummy, the Arbiter. |

Anything else is open. A monster stands in its cell, on whatever is under it;
one that flies holds the middle of it. What the box and the ground hold is
rolled from the plan, so the same map always hides the same things.

Past the plan's edge there is rock on every side, drawn and solid, so a map
does not need a wall of its own to keep a body in.

The scene is text and `plan` is a list of strings, so a map reads in a diff
and can be mended by hand — in the file, or in Godot's inspector. The creator
squares off whatever it loads: rows made one length, and the whole kept
between one screen (40 by 22) and four each way.

## Picking one up

```gdscript
var room := Maps.load_room("keep")   # or load("res://data/maps/keep.tscn").instantiate()
add_child(room)
room.stand()                         # the rock, and whatever its cells say is in it
player.room = room
player.global_position = room.spawn_point()
```

Set `room.player` before `stand()` if the box and the ground to dig are to
answer to somebody. `MapMaker._stand` (`feature/world/map_maker.gd`) is the
whole of it, as PLAY does it.

A map is a `Room`, so everything that takes one takes it: the views that draw
a room draw it, with its cables and its grass, and a world that builds a
`Room.new()` can stand a made one in its place.
