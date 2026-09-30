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
while one is up — whether a board is open over it, whether the player stands by
something to use — it asks through `World` (`feature/world/world.gd`), so a new
thing to use is that world's edit and not the shell's.

`graphics/` reads `mobile/input/` the way it reads any state — the HUD drops its
key hints while the console is up, the title lays its menu out as tiles — and
names one thing in `mobile/view/`: `graphics/ui/controls_panel.gd` opens
`TouchLayoutEditor` from SET BUTTON POSITIONS, because the control settings are
where a player looks for it. It opens the screen and takes nothing else.

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
own attack, every monster's, the starter skills and the dragon test's. A part
is its numbers and what it does to a flow, each effect a change to one field
of the payload; what an effect *means* — what a form spawns, what a flag does
to a hit — is code, `SkillRunner._apply` and `feature/attacks/`, and the rows
name it by field. A board is its parts and the way each faces: which feeds
which is walked, not stored. What a part looks like stays in `Style`.

The `text` in a conversation's rows is the English fallback. What is actually said is
laid over it from `localization/<lang>/dialogue/<id>.json`, by node name —
words only, never where a line leads. Scenes are still files,
`data/scenes/<id>.json`, and work the same way, by beat.

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

## Where does it go?

| Change | File |
|---|---|
| New skill component | a row in `data/db/parts/parts.sql` — its category, heat, cells, ports and what it does to a flow, as effects — and a number on the end of `codes` there, or no board carrying it can be shared; then `data/db/build.sh`. A new *kind* of effect, form or trigger is code: `SkillRunner._apply`, `Payload`, `feature/attacks/`. Its colour, glyph and icon in `graphics/style.gd` |
| The share code — what it carries, how long it is | `circuit/board_code.gd`; the sheet that shows it, and spells its refusals, `graphics/ui/share_code_panel.gd` |
| New monster | `feature/actors/monsters.gd`; its attack, a board in `data/db/boards/monsters.sql`; its sprite and colour in `graphics/style.gd` |
| How the player looks — plate, cape, glow | `graphics/assets/sprites/player/player.skin.png`, and nothing else: every pose beside it is painted in the colours of a map that names its pixels, and takes theirs from it. See that folder's README and `graphics/skin/` |
| A new pose for the player | a strip beside the skin, painted in the map's colours; how it plays, `SkinnedCharacter.ANIMS`; when, `PlayerView._animate` |
| New NPC or dialogue | a file in `data/db/dialogue/`, then `data/db/build.sh` — see `data/db/README.md`; no code. New *kinds* of direction: a column in `data/db/schema.sql`, read in `story/view/dialogue_box.gd` (emotion, portrait), `story/view/npc_view.gd` (camera) or `app/audio/audio_cues.gd` (sound) |
| Content better kept as rows than as a file | a table in `data/db/schema.sql`, read through `Db` (`app/db.gd`) |
| A board the game ships with — a weapon's own attack, a monster's, a starter skill | `data/db/boards/`, then `data/db/build.sh`; the weapon or the monster names it by id |
| The player's movement — its states, what each does, which can follow which, and when | `data/db/machines/player.sql`, then `data/db/build.sh`. A new action for a step to take, or a new sense for a condition to read, `_setup_fsm` in `feature/actors/player.gd` |
| A new directed scene, or a new staging direction | a file in `data/scenes/` — see its README; no code. A new direction is a case in `story/rules/cutscene.gd` and, if it shows, `story/view/cutscene_view.gd` |
| How a conversation behaves — range, reveal speed, who is held still | `story/rules/npc.gd`. How it reads on screen, `story/view/dialogue_box.gd` |
| Someone who talks free, and what they notice | a file in `data/db/dialogue/` of `rules`, `criteria` and `changes` — see **Free talk** in `data/db/README.md`; no code. A new kind of moment to notice, a row of `events` in `data/db/schema.sql` naming the cue. How free talk is picked and paced, `story/rules/free_talk.gd`; how the bubble looks, `story/view/speech_bubble.gd` |
| What anyone actually says, on any screen, in any language | `localization/<lang>/` — see its README. A new language is a folder and an entry in `LANGUAGES` in `app/loc.gd` |
| What an emotion looks like | `EMOTIONS` in `graphics/style.gd` |
| Retune damage, room generation | `feature/` |
| Retune a part — its heat, what it adds or multiplies, how long it slows the fight | `data/db/parts/parts.sql`, then `data/db/build.sh` |
| Retune a board's timing — ticks, cooldowns, a pulse's life | `circuit/skill_runner.gd` |
| The dragon test's tower — where the guards stand, where the stairwells are | `LAYOUT` in `feature/world/dragon_tower.gd`; how it is lit and dressed, `graphics/views/tower_view.gd` |
| Retune shake, sparks, hitstop *feel* | `graphics/cue_visuals.gd` — except hitstop and dilation, see below |
| HUD layout, editor look — where a thing sits, not what it says | `graphics/ui/` |
| The resolution the world is drawn at | `graphics/pixel_camera.gd` (the size comes from `Sprites.PIXEL_SCALE`) |
| A new sound | `app/audio/audio_cues.gd` |
| What a moment says on screen — WINDED, a boss's second form | `hud.fx` in `localization/`, spelled in `graphics/cue_visuals.gd`; the rule sends the id |
| A setting on both settings pages — a volume, the language, the screen | `graphics/ui/settings_rows.gd` for the game's, `graphics/ui/video_rows.gd` for the machine's; the title and the pause menu both ask for the rows |
| A new thing a press of `interact` can use in a world | that world's `use_nearby()`, see `feature/world/world.gd`; the shell asks and names nothing |
| What the forge costs, and that a skill sits in one slot at a time | `feature/core/game_state.gd` (`FORGE_COST`, `FORGE_INPUTS`, `assign_skill`); the counter only asks |
| A control on the on-screen console — where it sits, whether it is a key or a stick, what it says | `CONTROLS` in `mobile/view/touch_pad.gd`, and its word in `controls.pad` in `localization/`. What pressing it does to the game is `mobile/input/touch.gd`, which sends the action a keyboard would and is the only thing that knows a finger from a key |
| Where a player may move a console button, and what is kept of it | `mobile/view/touch_layout_editor.gd`; the arrangement itself, `TouchPad.layout` in `mobile/view/touch_pad.gd` |
| A new screen | `app/game.gd`, plus its Control in `graphics/ui/` |

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
| `Db` | app | the content database, `data/enigami.db` — the conversations, the state machines, the parts and the boards the game ships with, as tables — read-only |
| `Cues` | app | the seam |
| `Audio`, `AudioCues` | app | the synthesised sound bank, and what each cue sounds like |
| `Pointer` | app | where the hand is pointing, at the speed the setting asks, and whether the system's arrow is hidden under it |
| `Video` | app | whether the window takes the whole display, and whether an impact may move the camera |
| `Arena` | feature | the node live world objects are parented to |
| `TimeCtl` | feature | hitstop and dilation |
| `GameState` | feature | the profile, the stash, the raid in progress |
| `Sprites` | graphics | the atlas, sliced |
| `Fx` | graphics | shake, sparks, floating numbers |
| `Views` | graphics | attaches views to gameplay nodes |
| `CueVisuals` | graphics | what each cue looks like |

`story/`, `circuit/` and `mobile/` add none. Story's nodes are spawned by
whatever stages them — `app/game.gd` for the intro, `Sandbox` for the bench —
and their views are attached by `Views` like any other. The circuit is classes
the rules make instances of. The console's input is a static class, `Touch`,
and its picture is built by `app/game.gd`. Keep it that way: an autoload is the
one thing a module's branch cannot add without touching `project.godot`.

`project.godot` is the one file any branch may need to touch — adding an
autoload, an input action or a collision layer. Its autoload block is grouped
by module so two additions rarely collide.
