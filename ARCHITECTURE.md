# Five modules

The project is split so that **a change to what the game does**, **a change to
how the game looks**, **a change to what the game tells**, **a change to how a
skill board runs** and **a change to how a thumb plays it** are edits to
disjoint sets of files. Branches working in parallel — one per module — can
then be merged without any of them touching another's lines.

```
circuit/     the engine. A board, the pulse that runs it, the payload it builds.
feature/     the rules. What happens, and when.
graphics/    the picture. What that looks like.
story/       the telling. Who speaks, what is staged, and how that reads.
mobile/      the glass. The console a thumb plays on, and where its buttons stand.
app/         the shell they sit in: the seam, the screen flow, the sound bank.
tests/       circuit/ · feature/ · graphics/ · story/ · mobile/ · shared/, the same split

data/          the content database, and the scenes. Content the modules read.
localization/  every word the game says, one folder per language.
```

`circuit/` is the engine under the rules: `Components`, `SkillBoard`,
`SkillRunner`, `Payload` and `BoardCode`. It names nothing but itself and `Loc` —
not a weapon, not an actor, not a hit — so it can be tested on its own and
changed without a rule or a picture changing under it. Its parts are rows in
the content database, which `components.gd` reads through `Db`, the one other
name in it. What it needs from the game is handed in: a runner is given its base payload (`base_payload_provider`),
and the weapons, the player and the attacks are built on top of it in `feature/`.

`story/` and `mobile/` are whole subsystems rather than one side of one — a
conversation has both a shape and a look, and so does a console on the glass —
so each carries the same seam inside itself:

```
story/rules/   the conversation and the staging. What is said, and what follows.
story/view/    the box, the portraits, the camera. What that looks like.
mobile/input/  whether the console is up, and the actions a thumb holds down.
mobile/view/   the console drawn on the glass, and the screen that moves its buttons.
```

That is why they are modules and not a folder in each of the other two:
everything about a conversation, or about playing with thumbs, is in one place,
and a branch writing one opens no file the others touch.

## The rule

**A picture may read the rules it draws. A rule may never mention its picture.**

One rule, applied between the modules and again inside `story/` and `mobile/`:

```
circuit/       reads none of them, only Loc — and Db, for its parts
feature/       may read  circuit/
graphics/      may read  feature/ · circuit/ · mobile/input/
story/rules/   may read  feature/
story/view/    may read  story/rules/ · graphics/ · feature/
mobile/input/  reads none of them, only the shell it presses keys for
mobile/view/   may read  mobile/input/ · graphics/ · feature/
```

Nothing in `feature/`, `story/rules/` or `circuit/` draws, names a colour,
loads a sprite, plays a sound, or holds a reference to a screen. There is a
standing check for this: delete the four graphics autoloads (`Sprites`, `Fx`,
`Views`, `CueVisuals`) from `project.godot` and every test under
`tests/circuit`, `tests/feature` **and `tests/story`** still passes — raids run,
hits resolve, boards fire, conversations run to their last line, nothing is
drawn. CI runs it on every push. `tests/shared/module_test` checks the same rule
class by class, from the code: every row of the table above is a row in it, the
one-line exceptions below are pinned to the file that has each, an edge that
was cut on purpose is listed there so it cannot come back, and no rule folder
may name the engine's own drawing, sound or asset names either.

`story/view/` reads `graphics/` the way any screen does — `UiKit`, `PixelDraw`,
`Style`, `Sprites`, `Fx` — and adds nothing to it. Back the other way there is
exactly one line, `Views` handing an unrecognised node to `StoryViews`. That is
a hand-off and not a dependency on the telling: `graphics/` names that one entry
point and nothing else — no story node, no story view, nothing a conversation
does — so what the box looks like and what the HUD looks like are still never
the same edit.

The shell in `app/` is the one place allowed to know all of them: `app/game.gd`
is the composition root, and builds screens out of `graphics/`, `story/view/`
and `mobile/view/` to drive `feature/` and `story/rules/`. What it asks a world
while one is up — whether a board is open over it, whether a panel of its own
is, whether the player stands by something to use — it asks through `World`
(`feature/world/world.gd`), so a new thing to use is that world's edit and not
the shell's.

`graphics/` reads `mobile/input/` the way it reads any state — every menu has a
second layout for mobile mode — and names one thing in `mobile/view/`: `graphics/ui/controls_panel.gd`
opens `TouchLayoutEditor` from SET BUTTON POSITIONS, because the control
settings are where a player looks for it. It opens the screen and takes nothing
else.

**The two layouts.** Which one a menu is in is one question, `UiKit.mobile()`,
asked through the kit so the telling's pictures can ask it too without naming
the console. A screen built of Controls gets its thumb's size from the kit — a
pixel button, a page's frame, a slider, a switch are each built at one size or
the other — and is built again by whoever holds it when the mode is thrown, the
way it is for a language. A screen that draws itself (`SkillEditor`,
`DialogueBox`, `CutsceneBox`) asks every frame and keeps both
layouts, the thumb's under its own "for a thumb" heading; the desk's is the
path nothing in that section touches.

**The one exception.** `feature/world/sandbox.gd` names `Npc`, to stand someone
on the bench to talk to. A world that stages a character has to name one, the
same way `app/game.gd` names `Cutscene` to play the intro. It spawns one and
says who it is; it reaches into nothing else, and it is the only file in
`feature/` that mentions `story/`.

## How the modules talk

Three mechanisms, and no others.

### 1. Views — for anything with a position

`graphics/views.gd` watches the scene tree. Whenever a node it recognises
enters, it attaches a view to it as a child. The gameplay node is never told.

```
Player  (feature/actors/player.gd)   ← moves, jumps, casts
└── View (graphics/views/player_view.gd)  ← the knight, the weapon, the rings
```

A view reads its parent's public state every frame and draws from it. It never
writes back. Adding a visual to something is therefore a graphics-only edit,
and adding a monster is a feature-only edit — an unrecognised node simply gets
no view, and a monster with no entry in `Style` draws with a fallback.

To give something a view, add a case to `Views.view_script_for` — or, for a
node in `story/rules/`, to `StoryViews.view_script_for` in
`story/view/story_views.gd`, which `Views` falls through to once its own table
has missed. One watcher, two tables, so putting a new character on screen is an
edit inside `story/` alone.

### 2. Cues — for moments

`Cues` (`app/cues.gd`) carries named moments out of the rules:

```gdscript
# feature/
Cues.at(&"jump", global_position, {"kind": "air"})

# graphics/cue_visuals.gd          # app/audio/audio_cues.gd
&"jump": _jump(pos, kind)          &"jump": Audio.play("jump", pitch)
```

Cue names are not declared anywhere central, on purpose: a new cue is one
`emit` in a feature file and one handler in a graphics file, and the two
branches never open the same file. An unhandled cue is silence, not an error.

**Moments are cues; state is polled.** Whether an actor is burning is state —
the view reads `actor.burn_time` each frame. The instant it was set alight is
a moment. If you find yourself emitting a cue every frame, it was state.

**A cue carries ids, never a line.** `refused` says `stamina`; `boss_phase`
says which monster and which phase. `graphics/cue_visuals.gd` spells them out
of `localization/` (`hud.fx`), so what a moment shows is in the language being
played, and `tests/shared/loc_test` fails a rule that writes a line into a cue.

**One listener sits on the rules' side.** Free talk (`story/rules/free_talk.gd`)
hears cues too: a character who talks free answers moments — a double jump, a
blow — and those are cues already, so the rules that send them never learn
anybody is watching. Which cues are moments a character can notice, and what
each has to carry, is the `events` table in the content database;
`tests/story/free_talk_test` fails on one that nothing sends.

### 3. Style — for the look of a thing the rules name

`graphics/style.gd` holds every colour, glyph and atlas character, keyed by the
ids the rules already use. `Components` carries heat and ports, never a colour;
`Monsters` carries hit points and AI, never a sprite; `Weapons` carries damage
multipliers, never a tint.

Every lookup in `Style` falls back, so the two branches can land in either
order: a part added on the feature branch draws in its category's colour until
someone gives it a glyph.

### Text — every word, in every language

Not a fourth mechanism either: like the conversations below, the words are
data every module reads. No screen and no rule spells out what it says. `Loc`
(`app/loc.gd`) reads it out of `localization/<lang>/<domain>.json`, and each
module asks by name:

```gdscript
# circuit/ · feature/                       # graphics/
Components.name_for(id)                     Loc.t("hud.map.title")
Loc.t("hud.extract.needs_scrap", [20, 4])   Loc.t("menu.title.start")
```

It sits in `app/` for the same reason `Cues` does. The rules name a part, a
monster and a facility; the picture names a button and a heading; neither
should have to reach into the other to find out how that word is spelled today.
The format, and how a translation falls back while it is half-written, are in
`localization/README.md`.

The English still in `Weapons.DEFS`, `Monsters.DEFS`,
`GameState.FACILITY_INFO`, `Controls.ACTIONS`, `Raid.TUTORIAL_STEPS`, and in
`data/` — a part's `name` and `description`, a line's `text` — is the
**fallback** under all of it, so a part added on the
feature branch is named on screen before anybody translates it — the same way
a part with no glyph yet draws in its category's colour.
`tests/shared/loc_test` compares the two and fails if they drift.

Silkscreen is Latin-only, so a language whose writing it does not carry brings
a face of its own, in its own folder — Korean ships 둥근모꼴, a 16-pixel bitmap
face. That makes two pixel grids on one screen: Latin on `UiKit.PIXEL`'s two,
Hangul on one, both whole pixels. `UiKit.pixel_grid()` is where that number
lives, and the pixel tests ask it before holding a screen to a grid. See **The
face** in that README.

### Conversations — content the modules read

Conversations are data, not a fourth mechanism: rows in the content database,
`data/enigami.db`, built from the SQL under `data/db/` (format in its README)
and read through `Db` (`app/db.gd`), the one script that names SQLite. Each
side reads only its own columns of a line:

| Columns | Read by |
|---|---|
| `text` `next` `choices` `speaker` `name` `speed` | `story/rules/dialogue.gd` and `npc.gd` — the conversation itself |
| `emotion` `sprite` | `story/view/dialogue_box.gd`, polling the NPC's current line |
| `camera` | `story/view/npc_view.gd`, through `Fx.direct` / `Fx.release` |
| `sfx` `voice` | `app/audio/audio_cues.gd`, from the `talk` and `talk_letter` cues, which carry the line |

Three of those four rows are inside `story/` now. That is the point of the
module: a new kind of direction — a column nobody reads yet — is written, read
and drawn without leaving it, and `app/audio/` stays the one outside hand,
because sound belongs to the shell wherever it is asked for.

`Db` sits in `app/` for the reason `Loc` does: it is content every module may
read, and none should have to know it is a table. It is read-only, opened
once, and answers with nothing rather than an error when the extension or the
file is missing on a platform. `feature/` and `story/rules/` may name it, as
they may `Loc`, and so may `circuit/components.gd`, for the parts;
`tests/shared/module_test` says so. Nothing else names
`SQLite` at all — a module asks `Db` for rows and gets dictionaries.

The player's movement is rows in it too — `machines`, `states`, `steps`,
`conditions` and `transitions` — built into `FSMNode`s by `Machine`
(`feature/core/machine.gd`). All of the machine is content: the states, what
each does every frame, which can follow which, and what opens each way,
which is a question about what the player senses —
`not dashing and on_floor and dir != 0`. What stays code is the words the
rows are written in, handed over by `Player._setup_fsm`: the actions a step
takes, each one thing the body does on a frame, and the senses a condition
reads. A row naming one the player does not have is reported, not guessed at.

So are the skill boards' parts — `parts`, their `ports`, their `effects` and
their numbers in a shared code, `codes` — read once by `Components`
(`circuit/components.gd`), and the boards the game ships with, `boards` and
`board_parts`, built by `Boards` (`feature/core/boards.gd`): each weapon's
graph as a new profile gets it, every monster's and the dragon test's. A part
is its numbers and what it does to a flow, each effect a change to one field
of the payload; what an effect *means* — what a form spawns, what a flag does
to a hit — is code, `SkillRunner._apply` and `feature/attacks/`, and the rows
name it by field. A board is its parts and the way each faces: which feeds
which is walked, not stored. Every board is rooted: its root, one of its parts
(`SkillBoard.root`), is where every cycle starts — a weapon's own attack form,
which the player moves but never takes off — and there is no INPUT part. A flow
goes from a part into the one beside it and leaves the board by the middle of
its right edge (`SkillBoard.way_out`), and there is no OUTPUT part either.
A weapon *is* its graph (`GameState.weapon_boards`): one each, carried into a
raid as a copy, lost and won back with the weapon. What a part looks like stays
in `Style`.

The `text` in a conversation's rows is the English fallback. What is actually said is
laid over it from `localization/<lang>/dialogue/<id>.json`, by node name —
words only, never where a line leads. Scenes are still files,
`data/scenes/<id>.json`, and work the same way, by beat.

The menus are rows as well — `menus` and `menu_items` — read by `Menus`
(`graphics/ui/menus.gd`) for the title screen and the shell's pause menu: a
menu is its name, and its items in order, each opening a menu or naming an
act of the screen's by its id. The screen keeps only the acts, and the look.
An item that opens a menu says that menu's name, so a heading is written
once and every door to it says it; the English in the rows is laid under
`localization/<lang>/menu.json` by id.

`story/rules/` hands a line on as it came out of the table, keyed by column
name, and never names a column it does not use, so the rule above still holds:
a new kind of direction is a column in `data/db/schema.sql`, a value in a
character's file, and a handler on the presentation side. A column declared
`JSON` arrives parsed, which is how `camera` reaches the picture as the
dictionary it always read.

A character can also talk **free** — in a bubble over whoever is speaking,
while the player goes on playing — and that is rows as well: `rules`, each
with the event it answers, the `criteria` the `facts` must meet, and the
`changes` it makes once it has been said (**Free talk** in
`data/db/README.md`). The split is the same one. `story/rules/free_talk.gd`
reads a rule's `text`, `listens`, `once`, `next`, `triggers`, `speaker`,
`speed` and `hold`, and decides what is said and when; `story/view/speech_bubble.gd`
reads its `emotion`; the sound bank its `sfx` and `voice`, off the same `talk`
cues the box sends. What a free talker remembers is kept with the profile
(`GameState.memory`), which saves it without reading it, and what the game
counts `GameState.facts()` hands over by name — so nothing in `feature/`
knows what anybody said.

### The player's input — a line anything may stand on

The player never reads `Input`. Everything they are asked to do comes down one
line, `Player.input` (`feature/input/`), after aarthificial's devlog on
stealing control from players: an empty `InputState` goes in at the head,
every `InputMiddleware` on the line has its say, and the body does whatever
comes out of the far end.

```
Hands          the keys, a pad, the console, the pointer: what the player says
ComputerHands  something playing the body in their place — a demo, a test: what
               the player said dropped, and what the computer says instead
AimAssist      a stick's aim bent toward what it is near: what they meant
HandsOff       a screen over the game, a conversation in the box: the hands taken off
WalkTo         the walk over to talk: the body driven somewhere, and given back
               to a push the other way
```

Each stands at its rank — what fills the state in, what helps it, then what
holds it, then what steers — so a walk still moves a body nobody may move, the
way the devlog's navigation comes after its dialogue. What lasts (which way and how
hard, a button held, where to aim) is read for its value; what happens (a jump
pressed, a cast let go of) is an act, which any stop may raise and a gate shut
anywhere on the line drops. `input_locked` and `talk_locked` are two
`HandsOff`s on that line, and `controls_locked()` asks the line.

The line also says whose the body is. Anything on it may answer `takes_over()`:
a hold that is the game's own — a conversation, a stun — a walk, and the
computer's hands do; a hold that is a screen's does not, since a window over
the game is the player's own doing. `Player.taken_over()` asks the line, and
`Pointer` asks the player: while the computer has the body the crosshair is the
computer's — it rests where it was, or goes where `ComputerHands.point_at`
leads it — and the system pointer is shown beside it, moving nothing.

So a system that wants the player's body — `Npc` walks them over before a
conversation in the box — puts a middleware on the line and takes it off
again, or lets it finish, and nothing else on the line, the player included,
has to hear about it.

## Where does it go?

| Change | File |
|---|---|
| New skill component | a row in `data/db/parts/parts.sql` — its category, heat, cells, ports and what it does to a flow, as effects, and what it does instead after an INVERT, as `inversions` — and a number on the end of `codes` there, or no board carrying it can be shared; then `data/db/build.sh`. A new *kind* of effect, form or trigger is code: `SkillRunner._apply`, `Payload`, `feature/attacks/`. Its colour, glyph and icon in `graphics/style.gd` |
| The share code — what it carries, how long it is | `circuit/board_code.gd`; COPY and PASTE under the board, and the words for its refusals, `graphics/ui/skill_editor.gd` |
| New monster | `feature/actors/monsters.gd`; its attack, a board in `data/db/boards/monsters.sql`; its sprite and colour in `graphics/style.gd` |
| How the player looks — plate, cape, glow | `graphics/assets/sprites/player/player.skin.png`, and nothing else: every pose beside it is painted in the colours of a map that names its pixels, and takes theirs from it. See that folder's README and `graphics/skin/` |
| A new pose for the player | a strip beside the skin, painted in the map's colours; how it plays, `SkinnedCharacter.ANIMS`; when, `PlayerView._animate` |
| New NPC or dialogue | a file in `data/db/dialogue/`, then `data/db/build.sh` — see `data/db/README.md`; no code. New *kinds* of direction: a column in `data/db/schema.sql`, read in `story/view/dialogue_box.gd` (emotion, portrait), `story/view/npc_view.gd` (camera) or `app/audio/audio_cues.gd` (sound) |
| Content better kept as rows than as a file | a table in `data/db/schema.sql`, read through `Db` (`app/db.gd`) |
| A weapon that is thrown — the rock: one of it, out of the hand once thrown, lying where it lands until it is picked back up | `thrown` on its row of `Weapons.DEFS` (`feature/core/weapons.gd`). Whose hands it is in, `Player.holders`: thrown out of them in `_on_fired` — the flow that finds it in the hand is the rock, any other a copy of it (`Projectile.ghost`) — and taken back with `take_back`; a monster the player is in picks it up and lets it go on `release`. The bolt that is the rock comes down as a `LooseRock` (`feature/world/loose_rock.gd`), which a room writes into its record when it is walked out of (`Room.save_state`). How it looks: the rock tile, drawn in code in `Style.DRAWN_TILES` and handed out by `Sprites.texture` like an atlas tile; held upright, `Style.WEAPON`'s `upright` and `grip`; in the air, `ProjectileView._draw_thrown`; on the floor, `graphics/views/loose_rock_view.gd` |
| A board the game ships with — a weapon's graph as it starts, a monster's | `data/db/boards/`, then `data/db/build.sh`; the weapon or the monster names it by id, and a weapon names its root part beside it (`Weapons.DEFS`) |
| The player's movement — its states, what each does, which can follow which, and when | `data/db/machines/player.sql`, then `data/db/build.sh`. A new action for a step to take, or a new sense for a condition to read, `_setup_fsm` in `feature/actors/player.gd` |
| How the hideout looks — what is out past its wall, the room's fittings, what stands at each station and how it lights for somebody standing there | A look of it, each a script in `graphics/views/` that extends `HideoutScenery` (`hideout_scenery.gd`, the ground they share: the room's edges, the depths drawn once or drawn again as they move, what hangs on a cord and swings (`cord`, `hung`, `ride` — the grove's lanterns, the brass terrace's lamps, the keep's ring of candles and its stall's lantern), where each station's fittings stand and how lit they are, the shapes everything is made of): `HideoutCity` a floor over a city in the rain, `HideoutKeep` a castle's hall, `HideoutGrove` a ruin in a wood, `HideoutOrbit` a deck of a station, `HideoutBrass` a terrace of a clock tower over a city of brass. All of it drawn in code, in pixels of the buffer the world is drawn into, with no image behind any of it. A look's colours are its own, at the head of its script — the city's are the `CITY_`, `NEON_` and `HIDEOUT_` constants in `graphics/style.gd` — and so are the colours the stations' signs hang in. Where the stations stand is the rules' (`HideoutWorld.STATION_CELLS`), and a look stands each one's fittings under it; the sign hung over a station, and what it says, is `graphics/views/hideout_world_view.gd`. Any room can be dressed the same way: `RoomView.dress` |
| Which look the hideout wears, while one is being chosen — and another look to choose from | `graphics/views/hideout_themes.gd`: the looks by id, the one in force, and the file it is kept in. Another look is its script, its id in `HideoutThemes.LOOKS` and `make`, and its name under `hideout.theme.look` in `localization/`; `tests/graphics/hideout_scenery_test` then holds it to what every look keeps to. The player picks on HIDEOUT THEME, a page the pause menu has in the hideout — `_build_pause_looks` in `app/game.gd`, listing them with `graphics/ui/theme_picker.gd` — which is no row of the `pause` menu's: it goes when the look is settled, and a row is content |
| A kind of line that hangs — a cable, a chain — and its numbers: how stiff, how heavy, how much of a passing body it takes; and what a room hangs of each, how many, how long | a row of `ropes` and one of `hangings` in `data/db/ropes/ropes.sql`, then `data/db/build.sh` — see **A rope** in `data/db/README.md`. How a line moves and is drawn, `graphics/rope.gd`: a tree of nodes, each with a parent, a rest angle and distance — held at the distance, springing back to the angle, and pulling its parent the other way by as much, so a push anywhere swings the line from its anchor — pixel by pixel on the world's grid. Where in a room one may hang, `_hang_lines` in `graphics/views/room_view.gd`; its colours, `Style.ROPE_LOOK`. What swings one is whatever moves through it — `_movers`, the bodies, and `_attacks`, what an attack has put in the air: a bolt, a blast's ring, the path of a lunge or a beam, the fan of a slash. A thing hung on one — a lantern on its cord — rides it (`Rope.attach`), and with a body of its own is walked into, and cut at, like the line; the lights a look of the hideout hangs are hung that way, `cord` and `ride` in `graphics/views/hideout_scenery.gd`. Nothing in `feature/` knows they are there |
| What grows on the rooms' floors — grass, flowers, a bush — and how it sways: how tall and how thick it stands, how far a push or the wind moves it; and what a room grows of each, how many, how long | a row of `foliage` and one of `growths` in `data/db/foliage/foliage.sql`, then `data/db/build.sh` — see **Foliage** in `data/db/README.md`. How a patch is drawn — its picture and its mask, pixel by pixel — `graphics/foliage.gd`; how its pixels move for a push and for the wind, `graphics/assets/shaders/foliage.gdshader`. Where in a room a patch may grow, `_grow_foliage` in `graphics/views/room_view.gd`; its colours, `Style.FOLIAGE_LOOK`. Nothing in `feature/` knows it is there |
| What moving things do to the air the picture is drawn in — what writes into it (a body, a bolt, a blast's ring), how stiff it is and how fast a push dies — for the foliage, or anything else drawn that should give way | `graphics/velocity_buffer.gd`, aarthificial's velocity buffer, and the step it takes every frame, `graphics/assets/shaders/velocity.gdshader`; the `PixelCamera` carries one on its own grid. Any shader reads it through the globals `velocity_buffer`, `velocity_area` and `velocity_time`, declared in `project.godot` |
| A menu — what it is called, what is on it, in what order, and what each item says or opens | `data/db/menus/menus.sql`, then `data/db/build.sh` — see **A menu** in `data/db/README.md`. What an item that opens no menu *does* is the screen's, by the item's id: `acts_for` in `graphics/ui/title_screen.gd`, `_pause_acts` in `app/game.gd`. How the items look — a tile's mark, a button's colour — stays with the screen |
| A new directed scene, or a new staging direction | a file in `data/scenes/` — see its README; no code. A new direction is a case in `story/rules/cutscene.gd` and, if it shows, `story/view/cutscene_view.gd` |
| How a conversation behaves — range, reveal speed, who is held still, where the player is walked to stand | `story/rules/npc.gd`. How it reads on screen, `story/view/dialogue_box.gd` |
| Something that takes the player's controls for a while — holds them, walks them somewhere, presses for them | an `InputMiddleware` in `feature/input/`, put on `player.input` and taken off again or left to finish; see `InputProvider`. What the player's own hands say is `Hands`; how a walk gets there and is refused, `WalkTo`. If it leaves the body the computer's rather than the player's, it answers `takes_over()` |
| Something that plays the character in the player's place — a demo, a scripted test | a `ComputerHands` on `player.input`: told which way to walk, what is held and pressed, and where to point. It drops what the player's hands say and points with the game's crosshair. Which pointer is on the screen meanwhile, and what a window over it does, `app/pointer.gd` |
| How a stick's aim is helped — the least virtual size a target keeps, how far its pull reaches, how steep the ground between two may get | `feature/input/aim_curve.gd`, the curve from where the stick points to where the weapon does, after t3ssel8r's devlog on aim assist. What counts as a target, and how a change in them fades in, `feature/input/aim_assist.gd`; how much of it the player wants, a row in `graphics/ui/controls_panel.gd` |
| The crouch — how low, how small a thing to hit, what asks for it | `Player.CROUCH_BODY` and `CROUCH_HURT_RADIUS`; its steps and the ways in and out of it, rows in `data/db/machines/player.sql`; its pose, `player.crouch.png`. Down held is what asks (`Hands`): how far a gamepad's stick has to be pushed for that is `move_down`'s dead zone in `project.godot`; the console's stick has to be dragged far out below its ring, `TouchPad.STICK_CROUCH`, or as far as the glass goes, `TouchPad.gate` |
| The sprint — how fast, and what asks for it | `Player.SPRINT_SPEED`: a pace of the run, not a state. The `sprint` action asks (`Hands`): a key, a gamepad's stick clicked in, and the console's stick dragged far out to a side of its ring, `TouchPad.STICK_SPRINT` — beside `STICK_RUN`, how far it is dragged inside the ring before it walks, `STICK_FAR`, how far the knob follows a thumb, `gate`, which brings the sprint and the crouch in to what a thumb can reach where the glass ends first, and `_draw_reach`, which marks the walk on the ring and the other two on lines out past it, and lights them as they are reached |
| Someone who talks free, and what they notice | a file in `data/db/dialogue/` of `rules`, `criteria` and `changes` — see **Free talk** in `data/db/README.md`; no code. A new kind of moment to notice, a row of `events` in `data/db/schema.sql` naming the cue. How free talk is picked and paced, `story/rules/free_talk.gd`; how the bubble looks, `story/view/speech_bubble.gd` |
| What anyone actually says, on any screen, in any language | `localization/<lang>/` — see its README. A new language is a folder and an entry in `LANGUAGES` in `app/loc.gd` |
| What an emotion looks like | `EMOTIONS` in `graphics/style.gd` |
| Retune damage, room generation | `feature/` |
| The ways between a raid's rooms — a doorway in the wall to a room beside, a gate on the floor to a room above or below, gone through with F | `Room` (`feature/world/room.gd`): `DOOR_ROWS`, `GATE_COLS` and `_generate` cut them, `arrival_point` is where a body coming through is put down; a gate is a `Gate` (`feature/world/gate.gd`), and going through one is `Raid._take_gate`. How a gate looks, `graphics/views/gate_view.gd` |
| Retune a part — its heat, what it adds or multiplies, how long it slows the fight | `data/db/parts/parts.sql`, then `data/db/build.sh` |
| Retune a board's timing — ticks, cooldowns, a pulse's life | `circuit/skill_runner.gd` |
| The dragon test's tower — where the guards stand, where the stairwells are | `LAYOUT` in `feature/world/dragon_tower.gd`; how it is lit and dressed, `graphics/views/tower_view.gd` |
| A map made in the map creator — what a cell of one can hold, what stands where it says, and how one is picked up as a room | `feature/world/made_room.gd`: a `MadeRoom` is a hand-laid room whose rows of cells are a property of it, `plan`, so a scene holding one is the room. A new thing to lay is a mark there — a monster's is a letter in `MONSTERS` — and what `record` makes of it; then its picture on the table, `MapTable.paint_mark`, and its name under `hud.maker.mark` in `localization/`. Shut in by rock past its edge on every side (`_build_collision`), which is what `RoomView` already draws there. It is a `Room`, and is drawn as one: nothing in `graphics/` knows it was made |
| Where maps are kept, and what one is called | `feature/world/maps.gd`: `data/maps/` in the project when the game is run from it, `user://maps/` in an exported game; a map's id is its file's name (`Maps.id_for`). The scenes are content like the rest of `data/`, and a format note is beside them |
| The map creator — what laying is, a step back, a map's least and greatest size, what PLAY stands up and with what kit, what a fall does | `feature/world/map_maker.gd`, a `World` like the bench. It lays and it plays, one at a time, and keeps the map on its table between visits. `tests/feature/map_maker_test` |
| The map creator's table — the tiles, the bar, the sheet, what the pointer and the keys do on it, what a played map's screen is | `graphics/ui/map_table.gd`, a screen that draws its sheet only when the map changes and asks the maker for every change; `graphics/views/map_maker_view.gd` puts it up, and for a played map the camera, the raid's HUD and the assembly overlay. Its words are `hud.maker` in `localization/`; the door to it is a row of the `title` menu and an act of the title's. `tests/graphics/map_table_test` |
| Retune shake, sparks, hitstop *feel* | `graphics/cue_visuals.gd` — except hitstop and dilation, see below |
| Something spawned again and again — a spark, a ring, a number that floats off | borrow it from a `Pool` (`feature/core/pool.gd`, after aarthificial's devlog on pooling), lent to the screen it is for, and let it hand itself back once it has played out; a screen that goes takes back whatever it still had out. `graphics/fx.gd`'s sparks, rings and words are drawn that way |
| HUD layout, editor look — where a thing sits, not what it says | `graphics/ui/` |
| How a menu is laid out in mobile mode — a row's height, a word's size, a page's width | the kit's: `THUMB`, `THUMB_TEXT` and `THUMB_PAGE` in `graphics/ui/ui_kit.gd`, which every page built of Controls takes them from. What is *on* a page there is that screen's own — the "for a thumb" section of `skill_editor.gd`, `dialogue_box.gd` and the rest, `_build_for_a_thumb` in `controls_panel.gd` |
| The resolution the world is drawn at | `graphics/pixel_camera.gd` (the size comes from `Sprites.PIXEL_SCALE`) |
| A new sound | `app/audio/audio_cues.gd` |
| What a moment says on screen — WINDED, a boss's second form | `hud.fx` in `localization/`, spelled in `graphics/cue_visuals.gd`; the rule sends the id |
| A setting on both settings pages — a volume, the language, the screen | `graphics/ui/settings_rows.gd` for the game's, `graphics/ui/video_rows.gd` for the machine's; the title and the pause menu both ask for the rows |
| A new thing a press of `interact` can use in a world | that world's `use_nearby()`, see `feature/world/world.gd`; the shell asks and names nothing |
| What the forge costs, and that a weapon is its graph — one each, deployed as a copy, lost and won back with the weapon | `feature/core/game_state.gd` (`FORGE_COST`, `FORGE_INPUTS`, `weapon_board`, `die`, `extract`); the screens only ask |
| A control on the on-screen console — where it sits, whether it is a key or a stick, what it says | `CONTROLS` in `mobile/view/touch_pad.gd`, and its word in `controls.pad` in `localization/`. What pressing it does to the game is `mobile/input/touch.gd`, which sends the action a keyboard would and is the only thing that knows a finger from a key |
| Where a player may move a console button, and what is kept of it | `mobile/view/touch_layout_editor.gd`; the arrangement itself, `TouchPad.layout` in `mobile/view/touch_pad.gd` |
| A new screen | `app/game.gd`, plus its Control in `graphics/ui/` |
| A new place to stand a player, opened from the title | a `World` in `feature/world/`, its view in `graphics/views/` and a case for it in `Views.view_script_for`, a state and a `goto_` in `app/game.gd`, and its door: a row of the `title` menu in `data/db/menus/menus.sql` and an act in `TitleScreen.acts_for`, with a mark for its tile in `TitleScreen.MARKS`. The map creator is one made this way |

### The one thing that looks like a picture but is not

Hitstop and time dilation scale `Engine.time_scale`, so they move the
simulation: a dilated fight really is slower for everything in it, which is the
whole point of the `TIME DILATION` part. They are a rule, and they live in
`feature/core/time_control.gd`. Screen shake, sparks and damage numbers change
nothing and live in `graphics/fx.gd`.

## Autoloads

| Name | Module | What it is |
|---|---|---|
| `Loc` | app | every word, in the language being played |
| `Db` | app | the content database, `data/enigami.db` — the conversations, the state machines, the parts and the boards the game ships with, the menus, the lines that hang in the rooms and what grows on their floors, as tables — read-only |
| `Cues` | app | the seam |
| `Audio`, `AudioCues` | app | the synthesised sound bank, and what each cue sounds like |
| `Pointer` | app | where the game is pointing and who is doing it — the player's hand, at the speed the setting asks, with the system's arrow hidden under it; the computer, with the arrow shown beside it; or the system alone, for a window |
| `Video` | app | whether the window takes the whole display, and whether an impact may move the camera |
| `Arena` | feature | the node live world objects are parented to |
| `TimeCtl` | feature | hitstop and dilation |
| `GameState` | feature | the profile, the stash, the raid in progress |
| `Sprites` | graphics | the atlas, sliced |
| `Fx` | graphics | shake, and the sparks, rings and floating numbers it lends out of its pools |
| `Views` | graphics | attaches views to gameplay nodes |
| `CueVisuals` | graphics | what each cue looks like |

`story/`, `circuit/` and `mobile/` add none. Story's nodes are spawned by
whatever stages them — `app/game.gd` for the intro, `Sandbox` for the bench —
and their views are attached by `Views` like any other. The circuit is classes
the rules make instances of. The console's input is a static class, `Touch`,
and its picture is built by `app/game.gd`. Keep it that way: an autoload is the
one thing a module's branch cannot add without touching `project.godot`.

`project.godot` is the one file any branch may need to touch — adding an
autoload, an input action, a collision layer or a global shader uniform. Its autoload block is grouped
by module so two additions rarely collide.
