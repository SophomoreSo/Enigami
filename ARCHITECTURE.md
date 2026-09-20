# Three modules

The project is split so that **a change to what the game does**, **a change to
how the game looks** and **a change to what the game tells** are edits to three
disjoint sets of files. Three branches working in parallel — one per module —
can then be merged without any of them touching another's lines.

```
feature/     the rules. What happens, and when.
graphics/    the picture. What that looks like.
story/       the telling. Who speaks, what is staged, and how that reads.
app/         the shell they sit in: the seam, the screen flow, the sound bank.
tests/       feature/ · graphics/ · story/ · shared/, the same split

data/          conversations and scenes, as files. Content the modules read.
localization/  every word the game says, one folder per language.
```

`story/` is a whole subsystem rather than one side of one — a conversation has
both a shape and a look — so it carries the same seam inside itself:

```
story/rules/  the conversation and the staging. What is said, and what follows.
story/view/   the box, the portraits, the camera. What that looks like.
```

That is why it is a module and not a folder in each of the other two: everything
about a conversation is in one place, and a branch writing one opens no file the
other two branches touch.

## The rule

**A picture may read the rules it draws. A rule may never mention its picture.**

One rule, applied twice — once between the modules, once inside `story/`:

```
graphics/     may read  feature/
story/rules/  may read  feature/
story/view/   may read  story/rules/ · graphics/ · feature/
feature/      reads none of them
```

Nothing in `feature/` or `story/rules/` draws, names a colour, loads a sprite,
plays a sound, or holds a reference to a screen. There is a standing check for
this: delete the four graphics autoloads (`Sprites`, `Fx`, `Views`,
`CueVisuals`) from `project.godot` and every test under `tests/feature` **and
`tests/story`** still passes — raids run, hits resolve, boards fire,
conversations run to their last line, nothing is drawn. Run it whenever the
split starts to feel theoretical.

`story/view/` reads `graphics/` the way any screen does — `UiKit`, `PixelDraw`,
`Style`, `Sprites`, `Fx` — and adds nothing to it. Back the other way there is
exactly one line, `Views` handing an unrecognised node to `StoryViews`. That is
a hand-off and not a dependency on the telling: `graphics/` names that one entry
point and nothing else — no story node, no story view, nothing a conversation
does — so what the box looks like and what the HUD looks like are still never
the same edit.

The shell in `app/` is the one place allowed to know all three: `app/game.gd` is
the composition root, and builds screens out of `graphics/` and `story/view/` to
drive `feature/` and `story/rules/`.

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
# feature/                                  # graphics/
Components.name_for(id)                     Loc.t("hud.map.title")
Loc.t("hud.extract.needs_scrap", [20, 4])   Loc.t("menu.title.start")
```

It sits in `app/` for the same reason `Cues` does. The rules name a part, a
monster and a facility; the picture names a button and a heading; neither
should have to reach into the other to find out how that word is spelled today.
The format, and how a translation falls back while it is half-written, are in
`localization/README.md`.

The English still in `Components.DEFS`, `Weapons.DEFS`, `Monsters.DEFS`,
`GameState.FACILITY_INFO`, `Controls.ACTIONS`, `Raid.TUTORIAL_STEPS` and the
`text` in `data/` is the **fallback** under all of it, so a part added on the
feature branch is named on screen before anybody translates it — the same way
a part with no glyph yet draws in its category's colour.
`tests/shared/loc_test` compares the two and fails if they drift.

Silkscreen is Latin-only, so a language whose writing it does not carry brings
a face of its own, in its own folder — Korean ships 둥근모꼴, a 16-pixel bitmap
face. That makes two pixel grids on one screen: Latin on `UiKit.PIXEL`'s two,
Hangul on one, both whole pixels. `Loc.pixel_grid()` is where that number
lives, and the pixel tests ask it before holding a screen to a grid. See **The
face** in that README.

### Dialogue files — content the modules read

Conversations are data, not a fourth mechanism: `data/dialogue/<id>.json`, one
file per character, format in `data/dialogue/README.md`. Each side reads only
its own keys from a line:

| Keys | Read by |
|---|---|
| `text` `next` `choices` `speaker` `name` `speed` | `story/rules/dialogue.gd` and `npc.gd` — the conversation itself |
| `emotion` `sprite` | `story/view/dialogue_box.gd`, polling the NPC's current line |
| `camera` | `story/view/npc_view.gd`, through `Fx.direct` / `Fx.release` |
| `sfx` `voice` | `app/audio/audio_cues.gd`, from the `talk` and `talk_letter` cues, which carry the line |

Three of those four rows are inside `story/` now. That is the point of the
module: a new kind of direction — a key nobody reads yet — is written, read and
drawn without leaving it, and `app/audio/` stays the one outside hand, because
sound belongs to the shell wherever it is asked for.

The `text` in those files is the English fallback. What is actually said is
laid over it from `localization/<lang>/dialogue/<id>.json`, by node name —
words only, never where a line leads. Scenes work the same way, by beat.

`story/rules/` passes the rest through untouched and never names a key it does
not use, so the rule above still holds: a new kind of direction is a new key in
the files and a handler on the presentation side.

## Where does it go?

| Change | File |
|---|---|
| New skill component | `feature/core/components.gd` + its rule in `skill_runner.gd`; a number on the end of `CODE_IDS` in `board_code.gd`, or no board carrying it can be shared; its colour, glyph and icon in `graphics/style.gd` |
| The share code — what it carries, how long it is | `feature/core/board_code.gd`; the sheet that shows it, `graphics/ui/share_code_panel.gd` |
| New monster | `feature/actors/monsters.gd`; its sprite and colour in `graphics/style.gd` |
| New NPC or dialogue | a file in `data/dialogue/` — see its README; no code. New *kinds* of direction: `story/view/dialogue_box.gd` (emotion, portrait), `story/view/npc_view.gd` (camera), `app/audio/audio_cues.gd` (sound) |
| A new directed scene, or a new staging direction | a file in `data/scenes/` — see its README; no code. A new direction is a case in `story/rules/cutscene.gd` and, if it shows, `story/view/cutscene_view.gd` |
| How a conversation behaves — range, reveal speed, who is held still | `story/rules/npc.gd`. How it reads on screen, `story/view/dialogue_box.gd` |
| What anyone actually says, on any screen, in any language | `localization/<lang>/` — see its README. A new language is a folder and an entry in `LANGUAGES` in `app/loc.gd` |
| What an emotion looks like | `EMOTIONS` in `graphics/style.gd` |
| Retune damage, cooldowns, room generation | `feature/` |
| The dragon test's tower — where the guards stand, where the stairwells are | `LAYOUT` in `feature/world/dragon_tower.gd`; how it is lit and dressed, `graphics/views/tower_view.gd` |
| Retune shake, sparks, hitstop *feel* | `graphics/cue_visuals.gd` — except hitstop and dilation, see below |
| HUD layout, editor look — where a thing sits, not what it says | `graphics/ui/` |
| The resolution the world is drawn at | `graphics/pixel_camera.gd` (the size comes from `Sprites.PIXEL_SCALE`) |
| A new sound | `app/audio/audio_cues.gd` |
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
| `Cues` | app | the seam |
| `Audio`, `AudioCues` | app | the synthesised sound bank, and what each cue sounds like |
| `Arena` | feature | the node live world objects are parented to |
| `TimeCtl` | feature | hitstop and dilation |
| `GameState` | feature | the profile, the stash, the raid in progress |
| `Sprites` | graphics | the atlas, sliced |
| `Fx` | graphics | shake, sparks, floating numbers |
| `Views` | graphics | attaches views to gameplay nodes |
| `CueVisuals` | graphics | what each cue looks like |

`story/` adds none. Its nodes are spawned by whatever stages them — `app/game.gd`
for the intro, `Sandbox` for the bench — and their views are attached by `Views`
like any other, so the module needs no global of its own. Keep it that way: an
autoload is the one thing a third branch cannot add without touching
`project.godot`.

`project.godot` is the one file any branch may need to touch — adding an
autoload, an input action or a collision layer. Its autoload block is grouped
by module so two additions rarely collide.
