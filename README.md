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
godot res://tests/jump_test.tscn    # ground jump, wall kick and the air jump
godot res://tests/focus_test.tscn   # in-game buttons never steal the keyboard
godot res://tests/trigger_test.tscn # a trigger chain lands as separate attacks
godot res://tests/cooldown_test.tscn # the numbers behind the slot cooldown wipe
godot res://tests/speed_test.tscn   # the SPEED part, and bolt collision at speed
godot res://tests/dash_test.tscn    # where a lunge lands, aimed and auto-aimed
godot res://tests/select_test.tscn  # arming a slot, and what each button fires
godot res://tests/weapon_fit_test.tscn  # a weapon refuses skills it cannot carry
godot res://tests/stamina_test.tscn # the dash budget under the health bar
godot res://tests/menu_fit_test.tscn # menus stay on screen and scroll the rest
godot res://tests/ttl_test.tscn     # a pulse's life, and what bounds a loop
godot res://tests/charge_test.tscn  # holding the cast button buys life for mana
godot res://tests/shots.tscn   # writes a screenshot of each screen to user://shots
SHOTS_DIR=/tmp/shots godot res://tests/shots.tscn   # ...or wherever you point it
```

## Controls

| | |
|---|---|
| A / D, ← / → | move |
| SPACE | jump; again in mid-air to double jump; against a wall to kick off |
| SHIFT | dash (brief invulnerability); spends stamina, four dashes to a full bar |
| LMB | attack with the weapon's own board — always available, never lost |
| 1 / 2 / 3 / 4 | arm a skill slot (numpad works too); arming does not fire it |
| RMB | hold to charge the armed skill, release to cast it — a tap is a charge of nothing; a skill still recovering cannot be charged, and a weapon refuses skills it cannot carry |
| mouse / right stick | aim, and where a lunge lands |
| TAB | open assembly — **the raid keeps running**; TAB, ESC or the CLOSE button leaves it |
| F | interact, and hold to extract |
| ESC | pause |

Gamepad: left stick moves, A jumps, B dashes, the right trigger attacks and the
left one casts, X/Y arm slots 1–2, select opens assembly, RB interacts. Every keyboard binding is remappable
from Settings (title screen) or the pause menu.

## How a skill works

A board is a circuit. A pulse leaves `INPUT`, spends **one tick in every cell**
it passes through, and mutates a payload on the way through — a part costs
exactly the room it takes up, so a two-cell part like `AREA` costs two ticks and
everything else costs one. When the pulse reaches an `OUTPUT`, whatever the
payload has become is fired into the world. `INPUT` only restarts once every
pulse from the previous cycle has resolved — **the length and shape of the board
is the cooldown**, which is why a bigger build is not automatically a better
one, and why a cycle can be counted off the grid rather than looked up part by
part. What still separates one part from another in time is heat, which is
added to the cooldown at the end of the cycle.

The board is the *cooldown*, not the cast time: the walk up to the cycle's
first `OUTPUT` is spent the moment you press, so the attack lands on the press,
and those ticks are charged back onto the cooldown instead. A long board makes
you wait for the *next* shot, never for this one. Everything the board does
after that first `OUTPUT` still plays out in real time, which is what lets
`DELAY` stagger branches and triggers against each other.

- `SPLIT` halves damage down two branches; `TEE` keeps the main line and grows
  a full-strength branch sideways.
- Triggers (`ON HIT`, `ON KILL`, `ON PARRY`) grow a second flow out of their
  side port. That branch inherits the numbers but not the attack form, so it
  defines its own payload, and it attaches to the attacks the skill fires.
  A branch that loops resolves once per lap and each lap is its own follow-up:
  they land in sequence, so a ring back through an attack form gives you that
  attack again and again rather than one strike carrying every lap's stats.
  The workbench lists the whole chain under the trigger.
- Heat accumulated along the path is added to the cycle cooldown.
- `OVERCLOCK` runs the board on a faster clock and charges a settling delay
  between cycles. Each stack adds less speed than the last while the delay grows
  with the square of the count, so two or three pay off, six is about break-even
  and a wall of them is far worse than none. The delay is measured in real
  seconds rather than ticks on purpose: a tick-denominated cost would be shrunk
  by the very speed-up it pays for, and the two would cancel.
- `DELAY` is a cell of waiting like any other; stagger a branch against another
  by giving it further to walk.
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

Because a flow can enter from any side, rings are easy to build. Every pulse
therefore carries a **time to live** — how many more parts it may enter — and
dies when it runs out, which is what stops a cycle running forever. It is per
pulse rather than shared across the cast on purpose: with one pool between them,
two branches out of a `TEE` race for the last of it and which one starves comes
down to the order they happen to be stepped in. A pulse starts with one full
pass of its own board, so length alone never costs a board its shot.

Holding the cast button **charges** the armed board, spending mana the whole
time it is held; **letting go is what casts it**, with whatever the hold paid
for. A tap is simply a charge of nothing, so a quick press casts as it always
did. A skill still recovering cannot be charged: the wait is the board's own
cadence, and a hold running alongside it would buy the next cast's life out of
time already being spent. Holding through the wait costs nothing and loses
nothing — the charge starts building the moment the slot comes free. Charging
engages on every skill alike — nothing is special-cased on the shape of the
board — but all it ever buys is life, and life is only ever spent
going round. A board with no cycle in it walks to its OUTPUT and stops there
however much it was given, so it fires **once** charged exactly as it fires once
uncharged. A cycle is what has somewhere to spend the life, and it spends it on
more laps; on a loop that runs its payload back through its own stat parts that
compounds, because every lap picks them up again.

The workbench previews all of it by running the board rather than describing
it: a private copy of the runner is driven through a whole cast and what it
fires is what the preview reports, so the editor and the game cannot disagree.

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
tests/             smoke, movement, board tracing, timing, screenshot capture
```
