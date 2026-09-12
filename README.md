# Enigami

A single-player 2D platformer where skills are circuits you assemble on a grid,
and loot is only yours once you walk it out of the raid.

Built on Godot 4.5. Actors are animated sprites cut at runtime from one CC0
atlas ([0x72's 16x16 DungeonTileset II](https://0x72.itch.io/dungeontileset-ii),
see `assets/sprites/CREDITS.md`); everything else — rooms, attacks, effects and
the whole UI — is still drawn from primitives, and every sound is synthesised
at boot.

## Running

```bash
godot                      # opens the project
godot res://tests/smoke.tscn   # drives every screen and asserts the core rules
godot res://tests/shots.tscn   # writes a screenshot of each screen to user://shots
SHOTS_DIR=/tmp/shots godot res://tests/shots.tscn   # ...or wherever you point it
```

## Controls

| | |
|---|---|
| A / D, ← / → | move |
| SPACE | jump; press again against a wall to kick off |
| SHIFT | dash (brief invulnerability) |
| LMB / RMB / Q / E | hold to run skill slots 1–4 |
| mouse / right stick | aim |
| TAB | open assembly — **the raid keeps running**; TAB, ESC or the CLOSE button leaves it |
| F | interact, and hold to extract |
| ESC | pause |

Gamepad: left stick moves, A jumps, B dashes, triggers run slots 1–2, X/Y run
3–4, select opens assembly, RB interacts. Every keyboard binding is remappable
from Settings (title screen) or the pause menu.

## How a skill works

A board is a circuit. A pulse leaves `INPUT`, spends each component's tick cost
inside it, and mutates a payload on the way through. When the pulse reaches an
`OUTPUT`, whatever the payload has become is fired into the world. `INPUT` only
restarts once every pulse from the previous cycle has resolved — **the length
and shape of the board is the cooldown**, which is why a bigger build is not
automatically a better one.

- `SPLIT` halves damage down two branches; `TEE` keeps the main line and grows
  a full-strength branch sideways.
- Triggers (`ON HIT`, `ON KILL`, `ON PARRY`) grow a second flow out of their
  side port. That branch inherits the numbers but not the attack form, so it
  defines its own payload, and it attaches to attacks fired afterwards.
- Heat accumulated along the path is added to the cycle cooldown.
- `OVERCLOCK` runs the board on a faster clock and charges a settling delay
  between cycles. Each stack adds less speed than the last while the delay grows
  with the square of the count, so two or three pay off, six is about break-even
  and a wall of them is far worse than none. The delay is measured in real
  seconds rather than ticks on purpose: a tick-denominated cost would be shrunk
  by the very speed-up it pays for, and the two would cancel.
- `DELAY` exists only to stagger branches and triggers in time.
- `TIME DILATION` slows the world *and* the board together — it changes the
  pace of a fight rather than buffing attack speed.

Parts are placed by dragging: press a palette entry and drop it on the grid, or
lift a placed part and drop it somewhere else. The mouse wheel turns whatever
the cursor is on — a part already on the board rotates in place, otherwise the
wheel sets the facing for the next placement, mid-drag included. A bad drop puts
the part back where it came from; dropping it on the palette discards it into
the pool. Right-click removes.

Each part draws one triangle, on the edge its flow leaves by, and takes flow on
any other edge. Rotation therefore decides where a flow *goes*, never where it
may come from, so a flow can turn a corner through any part and the arrows on
the board describe its behaviour completely. The two joins that cannot carry
flow are two outputs meeting head-on, and anything aimed back at the INPUT.

Because a flow can enter from any side, rings are easy to build. A pulse gets a
budget of 64 hops and burns out if it never resolves, so a ring is a dead end
rather than a way to fire without ever paying the cooldown.

The board also shows what is actually wired: a green bridge on each joint that
carries flow, a red cross where two parts touch but cannot connect, and a faint
render for any part the flow cannot reach. When a board produces nothing the
preview names the first fault rather than only saying nothing came out.

The editor previews the whole cycle offline: cadence in seconds, every output it
would produce, the trigger payloads, and total heat.

Monsters run boards through the exact same simulator, and a kill can drop the
components its attack was visibly built from.

## Design decisions

The PRD left eight questions open. This build answers them as follows.

1. **Slots per weapon** — they differ. Sword and Gun get 3, the Rock gets 2.
   The slot count is part of a weapon's identity, not a uniform budget.
2. **Weapons and their starter skills** — each weapon ships with one fixed
   starter board so a fresh weapon is immediately usable; every other slot is
   free. Identity without locking the build.
3. **Compatibility** — by slot tags, not per-skill exceptions. A board's tags
   (`melee`, `ranged`, `area`, `mobility`, `trigger`) come from what is placed
   on it, and a weapon accepts a board that shares one. A board with no
   offensive tag is pure utility and fits anywhere. The Sword refuses `ranged`,
   the Gun refuses `melee`, the Rock takes everything.
4. **Editing during a raid** — components inside the slotted skills only. You
   cannot swap a whole skill into a slot mid-raid; the kit you deployed with is
   the kit you run. Edits made in the field come home with you when you extract.
5. **Rising danger** — a pressure clock rather than a timer. Staying longer
   raises the chance that a room you re-enter has picked up a wanderer. Nothing
   forces you out; the map just gets less friendly the longer you work it.
6. **Facilities** — the Workbench enlarges every board (that is the growth that
   matters), while the Vault, Forge, Scrapper and Medbay handle storage,
   crafting, breakdown and health. No facility grants convenience features that
   would flatten the assembly puzzle.
7. **Boss rewards** — the Arbiter drops three components from its own boards
   plus a large amount of scrap, and it unlocks its own fast gate. Components
   and access, not a unique weapon.
8. **Visual language** — silhouette carries meaning. Monsters are distinguished
   by polygon shape, colour marks role, an extra ring marks a modifier and a
   second ring marks an elite or boss. Components are coloured by category in
   both the world and the editor.

## Losing a raid

Deploying binds the weapon and the skills in its slots into one kit. Dying
loses the weapon, those skills (and every component built into them), and
everything found along the way. Anything left at home is untouched. There is
always another rock, so a bad run never leaves you unable to deploy.

Extracting is a place, not a menu: gates sit in the map with different terms —
the entry gate is free but slow, a toll gate costs scrap, the Arbiter's gate is
sealed until it dies, and a crack in the wall is fast but sits somewhere nasty.
Extraction needs a held input so nothing ends by accident.

## Layout

```
scripts/core/      components, payload, board, runner, state, audio, fx, controls
scripts/actors/    actor base, player, monster catalogue, monster AI
scripts/attacks/   projectile, melee arc, area burst, dash slash, spawner
scripts/world/     room generation, raid map graph, raid loop, sandbox, pickups
scripts/ui/        skill editor, HUD, hideout, title, results, controls panel
tests/             smoke test and screenshot capture
```
