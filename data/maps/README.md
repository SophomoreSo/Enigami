# Maps

Rooms made in the map creator (title → **MAP CREATOR**), one scene each:
`moonlit_grove.tscn` is the map `moonlit_grove`. SAVE writes them here when the
game is run from the project — the editor, or `godot --path` — and what is here
is committed and ships with the game. An exported game cannot write into
itself: it keeps the maps made on that machine under `user://maps/`, and reads
these as the ones it came with. `Maps` (`feature/world/maps.gd`) is what knows
where.

`moonlit_grove` is the hideout's Moonlit Grove laid in its own tileset, to play
and to start from.

## What is in one

One node: a `MadeRoom` (`feature/world/made_room.gd`), which is a room laid by
hand (`HandLaidRoom`) rather than generated — the way the dragon test's tower
is, with its rows in the scene rather than in a script. Its properties:

| Property | Meaning |
|---|---|
| `plan` | The ground, and what stands on it: the rows of cells, top to bottom, one string a row and a character a cell, every row the same length. The one layer the rules read. |
| `back` | What stands behind it, the same way, a row to each of the plan's. A row or a cell it does not have is nothing. |
| `dressing` | What is put about the map, the same way. |
| `tileset` | Which tileset draws it: `grove`, the Moonlit Grove, or `rock`, the plain rock a raid's rooms are cut from. A map that names neither is `rock`. |
| `region` | 0 to 3: which region's rock the plain rock is. Only `rock` reads it. |

`.` is nothing, in every layer.

### The plan

| Cell | Meaning |
|---|---|
| `#` `%` `\|` `=` `*` | Ground: stone, earth, bark, planks, leaves. Every kind is as solid as the next; the kind is how it looks. In `rock` every kind is the rock. |
| `o` `@` | Glass, in every tileset and as solid: clear glass, which shows what stands behind it, and a mirror, which shows what stands in front of it across its face to the open air. |
| `P` | Where the player starts. One a map. With none, the floor nearest the middle. |
| `T` | The room's treasure box. One a map. It is put down on the first floor under its cell. |
| `x` | Ground worth digging, put down the same way. |
| `c` `s` `l` `h` `d` | A post for a Crawler, a Sentry, a Lobber, a Hopper, a Drifter. |
| `w` `g` `u` `y` `a` | And for a Warden, a Gunman, a Grunt, a Test Dummy, the Arbiter. |

Anything else is open. A monster stands in its cell, on whatever is under it;
one that flies holds the middle of it. What the box and the ground hold is
rolled from the plan, so the same map always hides the same things.

Past the plan's edge there is ground on every side, drawn and solid, so a map
does not need a wall of its own to keep a body in. A grove has leaves over its
top and earth under it, and beside it, row by row, the kind of ground its
outermost cell is, or bark where that cell is open; `rock` has the rock.

### What stands behind

A cell behind is drawn as it meets its neighbours: a column ends in a foot
where it stops going down, and in a capital under what it carries — or broken
off, carrying nothing — and glass is framed wherever it meets anything but
more of the same glass. Glass behind a cell of ground is hidden by it, as
anything behind is.

| Cell | In `grove` | In `rock` |
|---|---|---|
| `#` | A ruin's wall | A wall of the rock, darker |
| `\|` | A column | |
| `-` | A stone lintel, carved | |
| `!` | A tree's trunk | |
| `~` | Undergrowth | |
| `=` | A rail, to hang lanterns from | |
| `o` | A pane of clear glass: a window on what is out beyond | The same |
| `@` | A mirror on the back wall, which shows whoever stands in front of it a little off | The same |

### What is put about

The same in every tileset. A lantern, a vine and a rope hang from the
underside of the first ground over them, or from a rail or a lintel behind or
over them, as far as eight cells up; with nothing there, from the top of their
own cell.

| Cell | Meaning |
|---|---|
| `L` | A lantern on its cord, with a lamp in it. |
| `F` | A campfire, and its light. |
| `m` | Glowing caps, and their light. |
| `*` | Fireflies, and their light. |
| `g` `f` `b` | Grass, flowers, a bush: the floor's foliage. A run of one along a row is one patch, standing on the floor of its cells. |
| `n` | A fern. |
| `v` `r` | A vine, a rope. A run of one down a column is one line, hanging from what is over its top cell to the foot of its last. |

The scene is text and the layers are lists of strings, so a map reads in a
diff and can be mended by hand — in the file, or in Godot's inspector. The
creator squares off whatever it loads: rows made one length, every layer the
plan's size, and the whole kept between one screen (40 by 22) and four each
way.

## Picking one up

```gdscript
var room := Maps.load_room("moonlit_grove")   # or load("res://data/maps/moonlit_grove.tscn").instantiate()
add_child(room)
room.stand()                                  # the ground, and whatever its plan says is in it
player.room = room
player.global_position = room.spawn_point()
```

Set `room.player` before `stand()` if the box and the ground to dig are to
answer to somebody. `MapMaker._stand` (`feature/world/map_maker.gd`) is the
whole of it, as PLAY does it.

A map is a `Room`, so everything that takes one takes it, and a world that
builds a `Room.new()` can stand a made one in its place. The view the game
gives it (`graphics/views/made_room_view.gd`) draws it in its tileset, hangs
and grows what was put about it out of the game's own ropes and foliage, and
lights it with their lamps. The light a played map is seen in is the world's
to set: the map creator sets the tileset's own (`MapTiles.ambient`).
