# Enigami

A single-player 2D platformer where skills are circuits you assemble on a grid,
and loot is only yours once you walk it out of the raid.

Built on Godot 4.5. Actors are animated sprites cut at runtime from one CC0
atlas ([0x72's 16x16 DungeonTileset II](https://0x72.itch.io/dungeontileset-ii),
see `graphics/assets/sprites/CREDITS.md`); everything else — rooms, attacks,
effects, the whole UI and the title screen's circuit board — is still drawn
from primitives, and every sound is synthesised at boot. The only other assets
are two OFL fonts (`graphics/assets/fonts/CREDITS.md`).

The rules and the picture are two separate modules, `feature/` and `graphics/`,
with a one-way seam between them — see [ARCHITECTURE.md](ARCHITECTURE.md).

## Running

```bash
godot                      # opens the project
godot res://tests/shared/smoke.tscn   # drives every screen and asserts the core rules
godot res://tests/feature/jump_test.tscn    # ground jump, wall kick and the air jump
godot res://tests/graphics/focus_test.tscn   # in-game buttons never steal the keyboard
godot res://tests/graphics/pointer_test.tscn # the drawn cursor, and how far it moves
godot res://tests/feature/trigger_test.tscn # a trigger chain lands as separate attacks
godot res://tests/feature/cooldown_test.tscn # the numbers behind the slot cooldown wipe
godot res://tests/feature/speed_test.tscn   # the SPEED part, and bolt collision at speed
godot res://tests/feature/range_test.tscn   # how far a bolt carries before it fades
godot res://tests/feature/dash_test.tscn    # where a lunge lands, aimed and auto-aimed
godot res://tests/feature/dash_move_test.tscn # the dash key: flat, a step long, briefly untouchable
godot res://tests/feature/hurt_test.tscn    # the second of grace a blow that lands buys
godot res://tests/feature/lost_kit_test.tscn # dying drops the kit, and the next run goes back for it
godot res://tests/feature/climb_test.tscn   # going up a room and staying there
godot res://tests/feature/select_test.tscn  # arming a slot, and what each button fires
godot res://tests/feature/weapon_fit_test.tscn  # a weapon refuses skills it cannot carry
godot res://tests/feature/stamina_test.tscn # the dash budget under the health bar
godot res://tests/graphics/menu_fit_test.tscn # menus stay on screen and scroll the rest
godot res://tests/graphics/editor_pixel_test.tscn # every pixel of the assembly screen is on the grid
godot res://tests/graphics/hideout_pixel_test.tscn # the hideout's pixel look, and everything on it fits
godot res://tests/graphics/bench_pixel_test.tscn # the bench panel's pixel look and layout
godot res://tests/feature/code_test.tscn    # a board survives being written down as a code
godot res://tests/feature/impact_test.tscn  # GRAVITY, SHATTER and MANA DRAIN, at the moment a hit lands
godot res://tests/graphics/share_code_test.tscn # sharing a board, and what a pasted code costs
godot res://tests/feature/ttl_test.tscn     # a pulse's life, and what bounds a loop
godot res://tests/feature/charge_test.tscn  # holding the cast button buys life for mana
godot res://tests/story/npc_test.tscn       # talking to an NPC, line by line
godot res://tests/shared/loc_test.tscn      # every language says everything, and can be drawn
godot res://tests/feature/dragon_test.tscn  # one charged cast clears the whole tower
godot res://tests/graphics/shots.tscn   # writes a screenshot of each screen to user://shots
godot res://tests/graphics/dragon_shot.tscn  # ...and frames of the dragon test
SHOTS_DIR=/tmp/shots godot res://tests/graphics/shots.tscn   # ...or wherever you point it
```

Or all of them at once, which is what CI runs:

```bash
tests/run.sh tests/feature tests/story tests/shared      # the headless half
tests/run.sh --display --exclude '*shot*' tests/graphics # these need a window
```

Every scene gets a deadline, because a test that waits for a window it will
never get does not fail — it hangs. A log per scene lands in `.test-logs/`, and
the run exits nonzero if anything failed that
[isn't quarantined](tests/quarantine.txt).

A fresh checkout has no `.godot/`, so nothing resolves a `class_name` until
`godot --headless --import` has run once. That is a step in making a worktree,
not a thing to reach for once it errors.

## Controls

| | |
|---|---|
| A / D, ← / → | move |
| SPACE | jump; again in mid-air to double jump; against a wall to kick off |
| SHIFT | dash — left or right only, never up; brief invulnerability from the press; spends stamina, four dashes to a full bar |
| LMB | attack with the weapon's own board — always available, never lost |
| 1 / 2 / 3 / 4 | arm a skill slot (numpad works too); arming does not fire it |
| RMB | hold to charge the armed skill, release to cast it — a tap is a charge of nothing; a skill still recovering cannot be charged, and a weapon refuses skills it cannot carry |
| mouse / right stick | aim, and where a lunge lands |
| TAB | open assembly — **the raid keeps running**; TAB, ESC or the CLOSE button leaves it |
| C | in assembly: the board as a share code — copy it out, or build someone else's board from theirs |
| F | interact: talk to an NPC (again for the next line), and hold to extract |
| W / S, ↑ / ↓ | when an NPC asks a question, move between answers; F gives the highlighted one |
| ESC | pause |

Gamepad: left stick moves, A jumps, B dashes, the right trigger attacks and the
left one casts, X/Y arm slots 1–2, select opens assembly, RB interacts. Every keyboard binding is remappable
from Settings (title screen) or the pause menu.

### Touch — the console on the glass

**Touch controls**, the second row of the control settings, draws a console on
the screen for two thumbs to play on. Three answers rather than a switch:
**AUTO** is on wherever the machine is one you touch and off everywhere else,
so an Android or iOS build has controls before anyone finds this row; **ON** and
**OFF** are for the machines that are both, and for looking at the thing on a
desk.

It is laid out the way a phone MOBA is, because that is the scheme this game's
controls turn out to fit:

* **The left thumb is a stick, and there is nothing there until it lands.** The
  lower-left of the screen is empty; a thumb put down anywhere in it grows the
  stick under itself, and lifting takes it away again — so it is never somewhere
  to reach for and never in the way of the fight. It is analog — the game reads
  movement as the strength of two actions — so a stick half over walks and a
  stick hard over runs, which four keys could never say.
* **A skill button is a stick too.** Press one and the slot is armed and begins
  to charge; drag and the charge aims; let go and it casts, where you were
  pointing, carrying everything the hold paid for. The game's own
  hold-to-charge is already press-drag-release, so the two are one gesture and
  nothing had to be invented for the phone. The weapon key (**HIT**) is the same
  stick without the arming. The two hands are independent: you can run right and
  throw a skill up and to the left in the same moment.
* **Everything else is a key.** JUMP, DASH, USE, and KIT / MAP / MENU in the far
  corner take no direction, so they are buttons and nothing more.

A slot the player is not carrying is not drawn; one the weapon refuses is drawn
in the same red the slot card uses, so a button that means *cast* says whether
it can before the thumb goes down.

A control on the console presses the same action a keyboard does, so the rules
never learn what a finger is. What changes while it is up:

* **Aim is the throw, not a pointer.** A phone has nothing on the glass until a
  finger lands, and where it lands is where it is going. So the console aims the
  way a gamepad does — the skill being thrown if one is, the movement stick if
  it is pushed, and the way the player is facing otherwise, so a tap with no
  throw in it still goes somewhere they meant. `Player._update_aim` needed no
  line changed for any of it; the crosshair and the pointer setting stand down.
* **A click stops attacking.** The system turns every touch into a click, and
  `attack` is bound to one, so a thumb resting on the stick would swing the
  weapon for as long as it rested there. The mouse bindings are set aside for as
  long as the console is up and handed straight back when it goes; the rebinding
  screen still shows them, and they are still what gets saved.
* **Every prompt names the control on the glass.** The slot cards, the extract
  prompt, the hint over an NPC — all of them ask `Controls.short_label_for`,
  which answers with the console's own word, so a card reads `HIT weapon attack`
  rather than `LMB weapon attack`. The two keyboard legends along the bottom of
  the HUD are dropped outright: with the controls drawn on the screen with their
  names on them, a line telling you to press one is two rows of a small screen
  spent saying nothing.
* **What is on the console follows the screen.** Playing shows everything; a
  conversation or a scene shows the stick that picks an answer and the key that
  turns the page; a window that has taken the controls — the map, the assembly
  bench — keeps only the keys that close it again, since the map is opened and
  shut with the same key and on a phone that key is on the console or it is
  nowhere. The pause menu replaces it: those are buttons you tap.

None of it is eyeballed. `tests/graphics/touch_pad_test` measures every control
against the HUD's two bands, against every other control, and against its own
word in both languages — then drives real fingers through a real raid: the stick
walks and runs, a stick dragged over a button does not press it, a skill button
arms its slot, charges while it is held, aims where it is thrown and casts what
the hold paid for.

The mouse pointer is the game's own: a crosshair, drawn at boot from a table of
characters like every other asset here that is not a sprite or a font, with the
gap in the middle left open so what you are aiming at stays visible. **Mouse
sensitivity**, at the top of the control settings, decides how far it travels
for a given push of the mouse, from 0.4 to 2.5, and is kept per machine rather
than per save — a property of the desk, like the language and the bindings.

It moves the game crosshair, not the system pointer, which is the whole of the
design. While the player has the controls the game takes the mouse — the system
arrow gives way to the crosshair, and that is what the setting drives. Let go of
the controls for a menu, a map or a conversation and the system pointer comes
back for the buttons, at whatever speed the desk runs it at. Setting it is
therefore something you see in the game rather than on the settings page, the
way a shooter'''s sensitivity slider never moves its own menu cursor.

It was built the other way first — the game moving the system pointer — which
works on a bench and not on a desk. The macOS call that moves a pointer unhooks
it from the mouse underneath and swallows what the hand does for a moment after,
so the two drift apart and the pointer is put back wherever the mouse had got
to; keeping it on the window instead unhooks it outright and it stops following
the mouse at all. Both were measured, and `app/pointer.gd` holds the finding so
nobody spends that week again.

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
- A bolt carries a fixed distance and then fades — a quarter of a room as
  standard, and the weapon scales it: a good third of a room off the Gun, a
  quarter off the Rock, a sixth off the Sword. You fight inside a part of a
  room rather than across it, and closing the gap is most of what a ranged
  build does with its feet.
  Range is not speed. A fast bolt arrives sooner, not further, which is why
  `SPEED` extends the reach a little as well: enough that a fast build does not
  run out of range on the way in. `RANGE` is the part for it — 1.75x a shot's
  reach and nothing else, so a board that cannot get close buys its distance
  outright. A monster is given whatever reach its own attack range needs, so
  nothing ever fires a shot that cannot arrive.
- `GRAVITY` pins the enemy it strikes instead of knocking it back, and drags
  every other enemy nearby onto it — a room gathered into one place for whatever
  the rest of the board does next.
- `SHATTER` hits an enemy frost has already slowed far harder. It never
  shatters the chill the same hit applied, so it is a pair: `ICE` to chill and a
  second arrival to collect, whether that is `DUPLICATE`, an `ON HIT` branch or
  simply the next cycle.
- `MANA DRAIN` takes mana back off every enemy an attack connects with. A board
  that lands often pays for its own charging.
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

The board also shows what is actually wired, by drawing it as one object.
Parts sit flush against each other, and the seam between two of them is drawn
only where the flow does not cross it: a wired run therefore fuses into a
single lit shape, its edge changing colour from one part to the next along it,
while two parts that merely touch stay two boxes with a red cross on the seam
between them. That outline stays lit the whole time — what is joined to what
does not change from moment to moment — and the movement is dots running a
track laid into the edge rather than sitting on top of it. The track goes
round everything between the INPUT and the part the flow finishes on, leaving
the side of the start the run departs by and meeting the side of the end it
arrives on: with a board laid out left to right the dots set off from the
middle of the INPUT's right edge, go over and under what lies between, and
arrive at the middle of the OUTPUT's left edge. Nothing goes round in a
circle. A part the flow cannot reach keeps its own box, drawn faint and with
no dots on it. When a board produces nothing the preview names the first fault
rather than only saying nothing came out.

A ring the flow can never leave is **dead code**, and is drawn switched off:
the colour comes out of the parts, the silhouette round the whole ring goes
red, and the cursor anywhere on it brings up a box saying why — whatever gets
in goes round until its life runs out, and nothing comes of it. It counts
whether or not the INPUT feeds it, and being fed is exactly what makes it dead
code rather than a part waiting to be wired up. A ring with a branch out of it
is not one of these and is drawn as it always was: laps through the stat parts
and out through a TEE is the pattern charging a skill exists to buy. Nor is one
with TIME DILATION or ON PARRY in it, which do their work on the way in and go
on doing it once a lap however trapped the flow is.

The editor previews the whole cycle offline: cadence in seconds, every output it
would produce, the trigger payloads, and total heat.

Monsters run boards through the exact same simulator, and a kill can drop the
components its attack was visibly built from.

## Sharing a board

`C` in the assembly screen — or the **CODE** button beside CLOSE — writes the
board on the grid out as a short code:

```
7kD3K2EZif3jtfN11111d
```

Every part, where it sits and which way it faces, in about twenty characters for
an ordinary skill — one unbroken run, with no dashes or spaces to copy along with
it, so it is a single word to a double-click. COPY takes it, and the same sheet
builds somebody else's board from theirs: paste it, or type it in and press
ENTER.

**Case matters** — the alphabet is the digits, the capitals and the small
letters, so `k` and `K` are different boards. The one character left out is `0`:
the pixel face draws `0` and `O` with the same pixels, so a round character is
always the letter, and typing a zero says so instead of quietly building
something else. That face has no small letters either — it draws them as
capitals — so **a code on screen does not show its own case**. Use COPY to take
one, rather than reading it off the screen and typing it back in.

The last character is a check character, so **a single wrong character, one in
the wrong case, or two neighbours swapped over is always refused** rather than
quietly building a different board. A board is always the same code however it
was built up, so two players can compare codes by eye. Paste the code on its own
rather than the line it came in: the letters of the words around it are code
characters too.

What a code does *not* carry is the name — that travels in the message beside it
— or the grid: a build arrives on your workbench's own board, and one laid out
on a bigger one is turned away whole rather than in pieces. **A code is a
blueprint, not the parts.** Pasting one at the workbench spends the stash
exactly as building the same board by hand would, the board it replaces goes
back into the stash as it goes, and one you cannot afford changes nothing at all
and says what it is short of. At the bench, where parts are free, it never asks.

The format is `feature/core/board_code.gd`. The alphabet is fixed for good, and
the table that numbers the parts may only ever be appended to, or every code
anyone has written down stops meaning what it meant.

A retired part keeps its number. WIRE and BEND are gone — any part already
carries a flow and turns it — and a code or a save that still has one reads back
without it. Where one sat against the INPUT or an OUTPUT, that end steps into its
cell, so the old starter boards and a WIRE-led build come back working; anywhere
else the cell is left empty and the board shows the break.

## The dragon test

Title → SANDBOX → **DRAGON TEST**. A four-storey tower with eight guards posted
across it, after the room in Katana ZERO where the Dragon tries out his dash:
one cut kills a guard, and the whole building is inside one cast of the board
the screen hands you.

That board is `DASHSLASH+` with an `ON HIT` whose branch runs three
`OVERCLOCK`s back round into it, so **every lap the cast has life for is one
more lunge at the nearest guard still standing**. A tap is one lunge and one
body; hold the cast button and the chain grows a link at a time — the read-out
along the top counts what a release right now would reach, the mark on the
charge bar is where that becomes all eight, and letting go there sends you
through the whole tower in one line. Guards stand far enough apart that each
lunge only carries the cut through its own, and the stairwells cut through the
floors are where the jumps between storeys pass, so the chain climbs.

`R` sets the floor again, `TAB` opens the board (parts are free), `ESC` goes
back to the bench. Nothing is at stake and the floor resets itself once it is
clear.

The layout is `LAYOUT` in `feature/world/dragon_tower.gd`, one string per row of
cells: `#` solid, `G` a guard's post, `P` the door. Moving a post or closing a
stairwell can break the chain — `tests/feature/dragon_test.tscn` is what says
whether one cast still clears it.

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
costs you the weapon, those skills (and every component built into them), and
everything found along the way — but none of it is destroyed. It is left lying
on the spot you fell on, and the next deployment goes back in after it: the
same floor, grown from the same seed, with the room you died in still in the
same place and the drop still lying in it. The map marks the room; the hideout says how
much is waiting before you commit to the run.

Picking it up does not end the story. A recovered kit is **carried**, not
returned — the skills cannot be slotted mid-raid and the weapon cannot be
drawn — so it only becomes yours again at an exit. Die on the way out and the
whole lot goes down a second time, wherever you fell that time; the older drop
is gone. There is one drop at a time, and dying is what moves it — extracting
without it does not lose it, it just leaves it there, and the run after that
goes back to the same floor again.

Abandoning a raid from the pause menu still forfeits the kit outright: walking
away is a decision, and a decision leaves no trail to follow back.

Anything left at home is untouched. There is always another rock, so a bad run
never leaves you unable to deploy — which is also what makes the trip back for
your own sword possible.

Extracting is a place, not a menu: gates sit in the map with different terms —
the entry gate is free but slow, a toll gate costs scrap, the Arbiter's gate is
sealed until it dies, and a crack in the wall is fast but sits somewhere nasty.
Extraction needs a held input so nothing ends by accident.

## Continuous integration

Every push runs the rules tests headless, the graphics tests under a virtual
display, and the standing module-split check — the four graphics autoloads
deleted, everything in `tests/feature` and `tests/story` expected to pass
anyway. Master and `v*` tags additionally build Linux, Windows, Android, macOS
and iOS, and a tag turns those into a GitHub Release.

See [.github/README.md](.github/README.md) for what each job does, which
secrets improve which build, and why the iOS artifact is an Xcode project
rather than something you can install.

## Layout

Three modules, and a shell around them. A picture may read the rules it draws;
a rule never mentions its picture. `story/` carries both sides of one subsystem
and so repeats that seam inside itself. See [ARCHITECTURE.md](ARCHITECTURE.md)
for how they talk.

```
app/               entry scene, screen flow, the cue bus, the sound bank, the words
                   pointer: the drawn cursor and how fast it moves
                   touch: whether the console is on the glass, and what a key on it presses
data/dialogue/     conversations, one JSON file per character — format in its README
data/scenes/       directed scenes, one JSON file per scene — format in its README
localization/      every word the game says: eng/ and kor/, a file per screen
                   plus dialogue/ and scenes/ — format in its README
                   kor/font.woff: the Korean pixel face, Silkscreen has no Hangul
feature/core/      components, payload, board, runner, state, time control
feature/actors/    actor base, player, monster catalogue, monster AI
feature/attacks/   projectile, melee arc, area burst, dash slash, spawner
feature/world/     room generation, raid map graph, raid loop, sandbox, pickups
                   lost kit: what a death leaves on the floor for the next run
                   dragon test: the hand-laid tower and its rules
story/rules/       conversations and directed scenes: what is said, and what follows
story/view/        the dialogue box, the cutscene box, the portraits, the camera
graphics/          the atlas, screen effects, the pixel camera, the palette, view attachment
graphics/views/    one view per gameplay node: actors, attacks, rooms, loot
graphics/ui/       skill editor, HUD, hideout, title, results, bench panel
                   touch_pad: the two-thumb console drawn on the glass, for Android and iOS
                   ui_kit: one look for screens built of Controls
                   pixel_draw: the same look for screens that draw themselves
graphics/assets/   the sprite atlas, the actor shader, two OFL fonts
tests/feature/     movement, board tracing, timing — rules, run headless
tests/story/       conversations and scene files — rules, run headless
tests/graphics/    editor input, focus, menus, the pixel camera, screenshot capture — need a window
tests/shared/      the smoke test, which walks the whole game
```

`tests/feature` runs under `--headless`; `tests/graphics` drives the mouse and
needs a real window. `tests/shared/loc_test` runs headless too.

## Language

English and Korean, picked in **SETTINGS** on the title screen and remembered
in `user://enigami_language.json` — outside the save, so wiping a profile
cannot strand you in a language you do not read. With nothing saved yet, the
game starts in the machine's own language if it has it.

Nothing on screen is spelled out in the code: every word comes from
`localization/<lang>/`, and a language is a folder and one entry in
`LANGUAGES` in `app/loc.gd`. Korean draws in **둥근모꼴 + Fixedsys**, a public
domain 16-pixel bitmap face carried in `localization/kor/` — Silkscreen has no
Hangul at all. See [localization/README.md](localization/README.md), in
particular **The face**, and [its credits](localization/CREDITS.md).
