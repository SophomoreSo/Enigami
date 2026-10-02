# Enigami

A single-player 2D platformer where skills are circuits you assemble on a grid,
and loot is only yours once you walk it out of the raid.

Built on Godot 4.5. Monsters and bystanders are animated sprites cut at
runtime from one CC0 atlas ([0x72's 16x16 DungeonTileset II](https://0x72.itch.io/dungeontileset-ii),
see `graphics/assets/sprites/CREDITS.md`). The player is the game's own, drawn
the map way: a skin, drawn once, and poses painted in the colours of a map
that names its pixels, so reskinning is one file
(`graphics/assets/sprites/player/README.md`). Everything else — rooms,
attacks, effects, the whole UI and the title screen's circuit board — is still
drawn from primitives, and every sound is synthesised at boot. The only other
assets are two OFL fonts (`graphics/assets/fonts/CREDITS.md`).

The rules and the picture are two separate modules, `feature/` and `graphics/`,
with a one-way seam between them — see [ARCHITECTURE.md](ARCHITECTURE.md).

## Running

```bash
godot                      # opens the project
godot res://tests/shared/smoke.tscn   # drives every screen and asserts the core rules
godot res://tests/feature/jump_test.tscn    # ground jump, wall kick and the air jump
godot res://tests/graphics/focus_test.tscn   # in-game buttons never steal the keyboard
godot res://tests/graphics/pointer_test.tscn # the drawn cursor, how far it moves, and whose it is: the hand's, the computer's or the system's
godot res://tests/graphics/player_skin_test.tscn # the player's poses name skin pixels, and the skin swaps under them
godot res://tests/feature/trigger_test.tscn # a trigger chain lands as separate attacks
godot res://tests/circuit/cooldown_test.tscn # the numbers behind the graph's cooldown wipe
godot res://tests/feature/speed_test.tscn   # the SPEED part, and bolt collision at speed
godot res://tests/feature/range_test.tscn   # how far a bolt carries before it fades
godot res://tests/feature/dash_test.tscn    # where a lunge lands, aimed and auto-aimed
godot res://tests/feature/dash_move_test.tscn # the dash key: flat, a step long, briefly untouchable
godot res://tests/feature/hurt_test.tscn    # the second of grace a blow that lands buys
godot res://tests/feature/lost_kit_test.tscn # dying drops the kit, and the next run goes back for it
godot res://tests/feature/climb_test.tscn   # going up a room and staying there
godot res://tests/feature/cast_test.tscn    # the two buttons: attack casts the graph, cast charges it
godot res://tests/feature/stamina_test.tscn # the dash budget under the health bar
godot res://tests/feature/input_test.tscn   # the input line: the hands, a hold, a gate, a walk that gives the body back, and the computer's hands
godot res://tests/feature/aim_assist_test.tscn # aim assist: the stick-to-weapon curve, and what it bends toward
godot res://tests/feature/pool_test.tscn    # pooling: lent, played out and handed back, and taken back when a screen goes
godot res://tests/graphics/fx_pool_test.tscn # sparks, rings and floating numbers come out of pools, never out of nothing
godot res://tests/graphics/menu_fit_test.tscn # menus stay on screen and scroll the rest
godot res://tests/graphics/title_mobile_test.tscn # mobile mode's title: a row of big square tiles
godot res://tests/graphics/screen_fit_test.tscn # a phone- or tablet-shaped screen is filled to its edges
godot res://tests/graphics/editor_pixel_test.tscn # every pixel of the assembly screen is on the grid
godot res://tests/graphics/hideout_pixel_test.tscn # the hideout's pixel look, and everything on it fits
godot res://tests/graphics/bench_pixel_test.tscn # the bench panel's pixel look and layout
godot res://tests/circuit/code_test.tscn    # a board survives being written down as a code
godot res://tests/circuit/parts_test.tscn   # every part's rows fit, and the runner does what they say
godot res://tests/circuit/invert_test.tscn  # INVERT turns round the one part before it, by that part's opposites
godot res://tests/feature/boards_test.tscn  # every board the game ships builds whole and reaches an OUTPUT
godot res://tests/graphics/menus_test.tscn  # every menu's rows name an act its screen has, in every language
godot res://tests/graphics/rope_test.tscn   # a cable's line of nodes: hung, pushed, settled, and where a room hangs them
godot res://tests/graphics/foliage_test.tscn # the grass, flowers and bushes a patch grows, its mask, and where a room grows them
godot res://tests/graphics/velocity_test.tscn # the velocity buffer: what moving things push, how it springs back, and the foliage leaning for it
godot res://tests/feature/impact_test.tscn  # GRAVITY, KNOCKBACK, SHATTER and MANA DRAIN, at the moment a hit lands
godot res://tests/feature/invert_hit_test.tscn # a stun, a heal, a cleanse, a push away and a haul back, as they land
godot res://tests/feature/reach_test.tscn   # how far an attack goes when the stick says how far
godot res://tests/feature/forge_test.tscn   # the forge's price, and a weapon is its graph: the profile's rules
godot res://tests/graphics/share_code_test.tscn # sharing a board, and what a pasted code costs
godot res://tests/circuit/ttl_test.tscn     # a pulse's life, and what bounds a loop
godot res://tests/feature/charge_test.tscn  # holding the cast button buys life for mana
godot res://tests/story/npc_test.tscn       # talking to an NPC, line by line
godot res://tests/story/free_talk_test.tscn # talking free: the most specific rule, walking off, picking it back up
godot res://tests/graphics/speech_bubble_test.tscn # the bubble over whoever talks free, on screen and on whole pixels
godot res://tests/shared/loc_test.tscn      # every language says everything, and can be drawn
godot res://tests/shared/module_test.tscn   # what each module may name, row by row, and what no rule may
godot res://tests/mobile/touch_layout_test.tscn # SET BUTTON POSITIONS: drag a button, keep it, play with it there
godot res://tests/feature/dragon_test.tscn  # one charged cast clears the whole tower
godot res://tests/graphics/shots.tscn   # writes a screenshot of each screen to user://shots
godot res://tests/graphics/dragon_shot.tscn  # ...and frames of the dragon test
godot res://tests/graphics/rope_shot.tscn    # ...and frames of a cable dashed through
godot res://tests/graphics/foliage_shot.tscn # ...and frames of the grass run, dashed and blasted through
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

The run points `HOME` at `.test-home/` in the project, so the thirty-odd scenes
that reset the profile never touch the save you play or the settings you chose;
`--live-save` runs against those on purpose. Anything a run writes to `user://`
— screenshots, say — lands under there too.

A fresh checkout has no `.godot/`, so nothing resolves a `class_name` until
`godot --headless --import` has run once. That is a step in making a worktree,
not a thing to reach for once it errors.

## Controls

| | |
|---|---|
| A / D, ← / → | move |
| SPACE | jump; again in mid-air to double jump; against a wall to kick off |
| SHIFT | dash — left or right only, never up; brief invulnerability from the press; spends stamina, four dashes to a full bar |
| LMB | cast the weapon's graph as it is — again and again while held, and it costs nothing |
| RMB | hold to charge the weapon's graph, release to cast it with what the hold paid for — a tap is a charge of nothing, and a graph still recovering cannot be charged |
| mouse / right stick | aim, and where a lunge lands. A stick's aim is bent toward a monster it is near — never snapped, and never the mouse's; how much is AIM ASSIST in the control settings |
| TAB | open assembly — **the raid keeps running**; TAB, ESC or the CLOSE button leaves it |
| C | in assembly: the board as a share code — copy it out, or build someone else's board from theirs |
| F | interact: talk to an NPC — the last step over to them is walked for you, and pushing the other way on it changes your mind — (again for the next line), and hold to extract. Someone who talks free goes on by themselves; F only hurries their line |
| W / S, ↑ / ↓ | when an NPC asks a question, move between answers; F gives the highlighted one |
| ESC | pause |

Gamepad: left stick moves, A jumps, B dashes, the right trigger attacks and the
left one charges and casts, select opens assembly, RB interacts. Every keyboard
binding is remappable from Settings (title screen) or the pause menu.

### The screen's shape

The game is laid out in 1280x720 and fills whatever it is shown on. A display
longer than 16:9 — most phones — gets more room either side, a squarer one — a
tablet — more above and below; nothing is stretched and nothing is letterboxed.
The room is the same size everywhere, so the extra room is more of the rock it
is cut out of rather than more of the fight; the HUD and the console keep to the
corners they belong to, and the menus stand in the middle. A window dragged to
another shape, or a phone turned, is followed as it happens.

### Touch — the console on the glass

**Mobile mode**, the switch on the second row of the control settings, draws a
console on the screen for two thumbs to play on, and lays the title's menu out
as a row of big square tiles — a mark over each name — for a thumb to land on.
A fresh install is in AUTO: on wherever the machine is one you touch and off
everywhere else, so an Android or iOS build has controls before anyone finds
the switch, and the switch shows what AUTO came to. Throwing it is an answer for
good, for the machines that are both and for looking at the thing on a desk.

It is laid out the way a phone MOBA is, because that is the scheme this game's
controls turn out to fit:

* **The left thumb is a stick, and there is nothing there until it moves.** The
  lower-left of the screen is empty; a thumb put down anywhere in it and dragged
  grows the stick where it landed, and lifting takes it away again. A thumb that
  only touches grows nothing — so it is never somewhere to reach for, never in
  the way of the fight, and never flashes up under a tap. It is analog — the
  game reads movement as the strength of two actions — so a stick half over
  walks and a stick hard over runs, which four keys could never say.
* **The cast button is a stick too.** Press it and the graph begins to charge;
  drag and the charge aims; let go and it casts, where you were pointing,
  carrying everything the hold paid for. The game's own hold-to-charge is
  already press-drag-release, so the two are one gesture and nothing had to be
  invented for the phone. The weapon key (**HIT**) is the same stick without
  the charge: the same graph, cast as it is for as long as the thumb is down.
  The two hands are independent: you can run right and throw a cast up and to
  the left in the same moment.
* **HIT is USE when there is something to use.** Beside an NPC, a station or an
  exit you are standing in, the weapon's button becomes the interact key; a
  thumb already down keeps what it pressed. One button fewer under the right
  thumb.
* **In a conversation the right of the screen is the page.** No button is
  drawn; a tap anywhere on the right turns the page or takes the answer the
  stick has picked.
* **Everything else is a key.** JUMP, DASH, and KIT / MAP / MENU in the far
  corner take no direction, so they are buttons and nothing more.

The buttons are twice the size they were first drawn at, words and all: on a
phone's glass the cast button was smaller than the thumb pressing it. The
movement stick kept its size, since it is not a button.

**SET BUTTON POSITIONS**, under the mobile mode switch while it is on, puts
every button up at once to be dragged where the player's thumbs want them. A
button let go on another one or over the HUD goes back where it was; one let go
anywhere else stays, and keeps its distance from the corner of the screen it is
nearest, so the arrangement holds on a screen of another shape. SAVE keeps it
for the machine, like the bindings; RESET puts the design back.

A control on the console presses the same action a keyboard does, so the rules
never learn what a finger is. What changes while it is up:

* **Aim is the throw, not a pointer.** A phone has nothing on the glass until a
  finger lands, and where it lands is where it is going. So the console aims the
  way a gamepad does — the cast being thrown if one is, the movement stick if
  it is pushed, and the way the player is facing otherwise, so a tap with no
  throw in it still goes somewhere they meant. A throw is measured from where
  the thumb came down, so a tap anywhere on a big button is still a tap. The
  crosshair and the pointer setting stand down.
* **How far is how far the thumb drags.** A cast dragged just past the dead
  zone goes a third of its distance, and one dragged out to the ring goes all
  of it — a bolt's range, a thrown shot's arc, a lunge, a DASH; a burst or a
  swing happens where the player stands either way. It rides on the same right
  stick, so a gamepad's push says the same thing; the mouse always asks for all
  of it (see `Player.aim_reach`). A cast keeps the aim and the distance it was
  let go with until it has gone off, whatever the left thumb does meanwhile.
* **A click stops attacking.** The system turns every touch into a click, and
  `attack` is bound to one, so a thumb resting on the stick would swing the
  weapon for as long as it rested there. The mouse bindings are set aside for as
  long as the console is up and handed straight back when it goes; the rebinding
  screen still shows them, and they are still what gets saved.
* **Every prompt names the control on the glass.** The graph's square, the
  extract prompt, the hint over an NPC — all of them ask
  `Controls.short_label_for`, which answers with the console's own word, so the
  square reads `HIT` rather than `LMB`. The two keyboard legends along the bottom of
  the HUD are dropped outright: with the controls drawn on the screen with their
  names on them, a line telling you to press one is two rows of a small screen
  spent saying nothing.
* **What is on the console follows the screen.** Playing shows everything; a
  conversation or a scene shows the stick that picks an answer and the key that
  turns the page; a window that has taken the controls — the map, a station's
  panel — keeps only the keys that close it again, since the map is opened and
  shut with the same key and on a phone that key is on the console or it is
  nowhere. The assembly board leaves the glass clear: it covers all of it, it is
  itself what the thumb is for, and its own CLOSE is right where KIT, MAP and
  MENU would stand. The pause menu replaces it: those are buttons you tap.

None of it is eyeballed. `tests/mobile/touch_pad_test` measures every control
against the HUD's two bands, against every other control, and against its own
word in both languages — then drives real fingers through a real raid: the stick
walks and runs, a stick dragged over a button does not press it, the cast button
charges while it is held, aims where it is thrown and casts what the hold paid
for.

The pointer you aim with is the game's own: a crosshair, drawn at boot from a
table of characters like every other asset here that is not a sprite or a font,
with the gap in the middle left open so what you are aiming at stays visible.
It is only on the screens you aim on — the battleground and the hideout floor.
Every window over them — the workbench, the settings, the weapon rack, the map,
the pause menu — is buttons, and points with the system's own arrow. **Mouse
sensitivity**, at the top of the control settings, decides how far it travels
for a given push of the mouse, from 0.4 to 2.5, and is kept per machine rather
than per save — a property of the desk, like the language and the bindings.

It moves the game crosshair, not the system pointer, which is the whole of the
design. While the player has the controls the game hides the system arrow — the
crosshair takes its place, and that is what the setting drives. Let go of the
controls for a menu or a map and the system pointer comes back
into sight for the buttons, wherever the hand has taken it and at whatever speed
the desk runs it at: the game never moves it. At 1.0 that is exactly where the
crosshair was; at any other speed the two have gone their own ways. Setting it is
therefore something you see in the game rather than on the settings page, the
way a shooter'''s sensitivity slider never moves its own menu cursor.

When it is the computer that has the controls, both pointers are on the screen,
and they are two things. That is any time your own hands are not what is
driving the character: someone talking to you holds you still, a stun stands
you where you are, the game walks you over to whoever you asked to talk to — or
something plays the character in your place, a demo or a test
(`ComputerHands`). The crosshair stays, and it is the computer's: it rests
where it was or goes where the computer points it, the character aims by it,
and the mouse does not move it. The system arrow is shown beside it, yours, free
to go anywhere on the desk and moving nothing in the game. Open the pause menu
and the arrow is the only pointer, as it is in every menu; put it away, and the
crosshair is back where the computer had it — or back under your hand, if the
controls are yours again by then.

It was built the other way first — the game moving the system pointer — which
works on a bench and not on a desk. The macOS call that moves a pointer unhooks
it from the mouse underneath and swallows what the hand does for a moment after,
so the two drift apart and the pointer is put back wherever the mouse had got
to; keeping it on the window instead unhooks it outright and it stops following
the mouse at all. Both were measured, and `app/pointer.gd` holds the finding so
nobody spends that week again.

## How a skill works

**A weapon is a graph.** Its own attack form stands on the root of a board —
the sword's `DASHSLASH`, the gun's and the rock's `PROJECTILE` — on the left of
the middle row, and everything you build is wired on after it. There are no
skills apart from weapons and no weapon without its graph: what you carry into
a raid is the weapon and whatever is on it, the rack picks the weapon and the
bench opens its graph. The root is the one part you cannot lift, turn or cover;
the cells after it are yours. `LMB` casts the graph as it is, again and again
while it is held, for nothing; `RMB` charges it (below) and casts on release.

A board is a circuit. A pulse leaves the root, spends **one tick in every cell**
it passes through, and mutates a payload on the way through — a part costs
exactly the room it takes up, so a two-cell part like `EXPLODE` costs two ticks
and everything else costs one. The root is entered like any other part, so the
weapon's own form is the first thing on the payload; a form placed after it
makes the flow that instead. When the pulse reaches an `OUTPUT`, whatever the
payload has become is fired into the world. The root only restarts once every
pulse from the previous cycle has resolved — **the length and shape of the board
is the cooldown**, which is why a bigger build is not automatically a better
one, and why a cycle can be counted off the grid rather than looked up part by
part. What still separates one part from another in time is heat, which is
added to the cooldown at the end of the cycle. Every cast off the weapon waits
ten times what its graph alone would, so a bare graph is a swing and not a
stream; everything built on after it lengthens that wait in proportion.

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
- `KNOCKBACK` throws the enemy it strikes on the way the attack was going:
  along a bolt's flight, out from a swing or an `EXPLODE`, down the line of a
  lunge. A hit on its own barely shifts anything; this throws an enemy standing
  its ground some five cells and one running at you back two, which buys room
  and can just as easily put it out of reach. With `GRAVITY` on the same board
  the struck enemy still flies, out of the crowd being dragged in.
- `SHATTER` hits an enemy frost has already slowed far harder. It never
  shatters the chill the same hit applied, so it is a pair: `ICE` to chill and a
  second arrival to collect, whether that is `DUPLICATE`, an `ON HIT` branch or
  simply the next cycle.
- `MANA DRAIN` takes mana back off every enemy an attack connects with. A board
  that lands often pays for its own charging.
- `STUN` stands the enemy it strikes still for a moment: it stops where it is,
  and neither attacks nor hurts by touch until it comes round. A stun cannot
  be stretched by another landing on it, and once it is over the enemy shrugs
  off the next one for a second and a half, so no board can hold one for good.
- `INVERT` turns round the part straight before it. `DAMAGE` heals the enemy
  struck instead; `FIRE`, `ICE` and `STUN` cleanse it of every burn, chill and
  stun it was carrying; `GRAVITY` drives the room away from the impact instead
  of gathering it; `KNOCKBACK` hauls the struck enemy back the way the attack
  came; and `SIZE`, `SPEED` and `RANGE` make the attack as much less as they
  would have made it more. Only the one part before it is turned round: `FIRE`,
  `FIRE`, `INVERT` puts out whatever the enemy came burning with and sets it
  alight again from the first `FIRE`, since a cleanse ends what was there
  before the hit and never what the hit itself brings. After a part with no
  opposite — a form, a trigger, `SPLIT`, `TEE` — it does nothing.
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
the board describe its behaviour completely. The one join that cannot carry
flow is two outputs meeting head-on; the root takes flow like any other part,
so a ring back through the weapon's own form is a build like any other.

Because a flow can enter from any side, rings are easy to build. Every pulse
therefore carries a **time to live** — how many more parts it may enter — and
dies when it runs out, which is what stops a cycle running forever. It is per
pulse rather than shared across the cast on purpose: with one pool between them,
two branches out of a `TEE` race for the last of it and which one starves comes
down to the order they happen to be stepped in. A pulse starts with one full
pass of its own board, so length alone never costs a board its shot.

Holding the cast button **charges** the weapon's graph, spending mana the whole
time it is held; **letting go is what casts it**, with whatever the hold paid
for. A tap is simply a charge of nothing, so a quick press casts as it always
did. A graph still recovering cannot be charged: the wait is the board's own
cadence, and a hold running alongside it would buy the next cast's life out of
time already being spent. Holding through the wait costs nothing and loses
nothing — the charge starts building the moment the graph comes free. Charging
engages on every graph alike — nothing is special-cased on the shape of the
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
round everything between the root and the part the flow finishes on, leaving
the side of the start the run departs by and meeting the side of the end it
arrives on: with a board laid out left to right the dots set off from the
middle of the root's right edge, go over and under what lies between, and
arrive at the middle of the OUTPUT's left edge. Nothing goes round in a
circle. A part the flow cannot reach keeps its own box, drawn faint and with
no dots on it. When a board produces nothing the preview names the first fault
rather than only saying nothing came out.

A ring the flow can never leave is **dead code**, and is drawn switched off:
the colour comes out of the parts, the silhouette round the whole ring goes
red, and the cursor anywhere on it brings up a box saying why — whatever gets
in goes round until its life runs out, and nothing comes of it. It counts
whether or not the root feeds it, and being fed is exactly what makes it dead
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
on a bigger one is turned away whole rather than in pieces. Nor the weapon: a
build arrives on the weapon you open it over, with that weapon's own part on
the root, and whatever the code had standing on that cell — its author's own
root — stays behind. **A code is a blueprint, not the parts.** Pasting one at
the workbench spends the stash exactly as building the same board by hand
would, the build it replaces goes back into the stash as it goes, and one you
cannot afford changes nothing at all and says what it is short of. At the
bench, where parts are free, it never asks.

The format is `circuit/board_code.gd`. The alphabet is fixed for good, and
the table that numbers the parts may only ever be appended to, or every code
anyone has written down stops meaning what it meant.

A retired part keeps its number. WIRE and BEND are gone — any part already
carries a flow and turns it — and a code or a save that still has one reads back
without it. Where one sat against an OUTPUT, the OUTPUT steps into its cell, so
a WIRE-led build comes back working; anywhere else the cell is left empty and
the board shows the break. INPUT is gone too: the root is where a flow starts
now, and a code or a save with an INPUT reads back with that cell empty, which
on any weapon's board is the cell the weapon's own part already fills.

A renamed part keeps its number too. EXPLODE was called AREA, and a code or a
save from then reads back with an EXPLODE wherever it had an AREA.

## The dragon test

Title → SANDBOX → **DRAGON TEST**. A four-storey tower with eight guards posted
across it, after the room in Katana ZERO where the Dragon tries out his dash:
one cut kills a guard, and the whole building is inside one cast of the board
the screen hands you.

That board is `DASHSLASH+` on the root with an `ON HIT` whose branch runs
three `OVERCLOCK`s back round into it, so **every lap the cast has life for is
one more lunge at the nearest guard still standing**. A tap is one lunge and one
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

1. **One graph per weapon.** A weapon is its graph: its own attack form
   stands on the root and everything you build is wired on after it. There
   are no slots and no skills apart from weapons — what you carry is the
   weapon and what is on it, and the rack, the bench and the gate are three
   ways of looking at the same thing.
2. **A weapon starts bare** — its own part and an `OUTPUT`, so it works the
   moment it is picked up, and every cell after the root is yours. Identity
   without locking the build.
3. **No compatibility rule.** The weapon's own form starts every flow, and a
   form placed after it makes the flow that instead: a bolt off the sword is a
   bolt off the sword, and is weighed as one (`Weapons.finalize`).
4. **Editing during a raid** — the graph you deployed with; the kit you
   deployed with is the kit you run. Edits made in the field come home with you
   when you extract.
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

Deploying binds the weapon and the graph on it into one kit. Dying costs you
the weapon, everything built onto its graph — the rock itself always comes back,
bare — and everything found along the way; but none of it is destroyed. It is left lying
on the spot you fell on, and the next deployment goes back in after it: the
same floor, grown from the same seed, with the room you died in still in the
same place and the drop still lying in it. The map marks the room; the hideout says how
much is waiting before you commit to the run.

Picking it up does not end the story. A recovered kit is **carried**, not
returned — the weapon cannot be drawn mid-raid — so it only becomes yours again
at an exit, where the weapon goes back on the rack with the graph it fell with
(or, for a weapon built on since, the graph's parts go to the shelves). Die on the way out and the
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

Five modules, and a shell around them. A picture may read the rules it draws;
a rule never mentions its picture. `circuit/` is the engine under the rules — a
board, the pulse that runs it, the payload it builds — and names nothing but
itself, the words, and the table its parts are rows in. `story/` and `mobile/` each carry both sides of one
subsystem and so repeat that seam inside themselves. See
[ARCHITECTURE.md](ARCHITECTURE.md) for how they talk.

```
app/               entry scene, screen flow, the cue bus, the sound bank, the words
                   pointer: the drawn cursor and how fast it moves
data/enigami.db    the content database: conversations, the player's state machine, the parts
                   and the boards the game ships with, as tables
                   built from data/db/, see its README
data/scenes/       directed scenes, one JSON file per scene — format in its README
localization/      every word the game says: eng/ and kor/, a file per screen
                   plus dialogue/ and scenes/ — format in its README
                   kor/font.woff: the Korean pixel face, Silkscreen has no Hangul
circuit/           the engine: components, board, runner, payload, share code
feature/core/      weapons, the profile and its saves, time control, the arena, the state machine,
                   the boards the game ships with
feature/actors/    actor base, player, monster catalogue, monster AI
feature/attacks/   projectile, melee arc, area burst, dash slash, spawner
feature/world/     room generation, raid map graph, raid loop, sandbox, pickups
                   lost kit: what a death leaves on the floor for the next run
                   dragon test: the hand-laid tower and its rules
story/rules/       conversations and directed scenes: what is said, and what follows
                   free talk: rules, the facts they are written against, and the ear
story/view/        the dialogue box, the speech bubble, the cutscene box, the portraits, the camera
mobile/input/      whether the console is on the glass, and what a key on it presses
mobile/view/       the two-thumb console drawn on the glass, and the screen that
                   moves its buttons (SET BUTTON POSITIONS)
graphics/          the atlas, screen effects, the pixel camera, the palette, view attachment
graphics/views/    one view per gameplay node: actors, attacks, rooms, loot
graphics/ui/       skill editor, HUD, hideout, title, results, bench panel
                   ui_kit: one look for screens built of Controls
                   pixel_draw: the same look for screens that draw themselves
graphics/skin/     characters drawn the map way: the map, the loader, the tool
graphics/assets/   the sprite atlas, the two actor shaders, two OFL fonts
graphics/assets/sprites/player/  the player: a skin, its map, poses painted in the map
tests/circuit/     board tracing, codes, cycle timing, a pulse's life — run headless
tests/feature/     movement, hits, raids, the bench — rules, run headless
tests/story/       conversations and scene files — rules, run headless
tests/graphics/    editor input, focus, menus, the pixel camera, screenshot capture — need a window
tests/mobile/      the console under a thumb, and moving its buttons — need a window
tests/shared/      the smoke test, which walks the whole game
```

`tests/circuit` and `tests/feature` run under `--headless`; `tests/graphics`
and `tests/mobile` drive the mouse and fingers and need a real window.
`tests/shared/loc_test` and `module_test` run headless too.

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
