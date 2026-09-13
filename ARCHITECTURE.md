# Two modules

The project is split so that **a change to what the game does** and **a change
to how the game looks** are edits to two disjoint sets of files. Two branches
working in parallel — one per module — can then be merged without either one
touching the other's lines.

```
feature/     the rules. What happens, and when.
graphics/    the picture. What that looks like.
app/         the shell both sit in: the seam, the screen flow, the sound bank.
tests/       feature/ · graphics/ · shared/, the same split
```

## The rule

**`graphics/` may read `feature/`. `feature/` may never mention `graphics/`.**

Nothing in `feature/` draws, names a colour, loads a sprite, plays a sound, or
holds a reference to a screen. There is a standing check for this: delete the
four graphics autoloads (`Sprites`, `Fx`, `Views`, `CueVisuals`) from
`project.godot` and every test under `tests/feature` still passes — raids run,
hits resolve, boards fire, nothing is drawn. Run it whenever the split starts
to feel theoretical.

The shell in `app/` is the one place allowed to know both: `app/game.gd` is the
composition root, and builds screens out of `graphics/` to drive `feature/`.

## How the two halves talk

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

To give something a view, add a case to `Views.view_script_for`.

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

### Dialogue files — content both halves read

Conversations are data, not a fourth mechanism: `data/dialogue/<id>.json`, one
file per character, format in `data/dialogue/README.md`. Each half reads only
its own keys from a line:

| Keys | Read by |
|---|---|
| `text` `next` `choices` `speaker` `name` `speed` | `feature/actors/dialogue.gd` and `npc.gd` — the conversation itself |
| `emotion` `sprite` | `graphics/ui/dialogue_box.gd`, polling the NPC's current line |
| `camera` | `graphics/views/npc_view.gd`, through `Fx.direct` / `Fx.release` |
| `sfx` `voice` | `app/audio/audio_cues.gd`, from the `talk` and `talk_letter` cues, which carry the line |

`feature/` passes the rest through untouched and never names a key it does not
use, so the rule above still holds: a new kind of direction is a new key in the
files and a handler on the presentation side.

## Where does it go?

| Change | File |
|---|---|
| New skill component | `feature/core/components.gd` + its rule in `skill_runner.gd`; its colour, glyph and icon in `graphics/style.gd` |
| New monster | `feature/actors/monsters.gd`; its sprite and colour in `graphics/style.gd` |
| New NPC or dialogue | a file in `data/dialogue/` — see its README; no code. New *kinds* of direction: `graphics/ui/dialogue_box.gd` (emotion, portrait), `graphics/views/npc_view.gd` (camera), `app/audio/audio_cues.gd` (sound) |
| What an emotion looks like | `EMOTIONS` in `graphics/style.gd` |
| Retune damage, cooldowns, room generation | `feature/` |
| Retune shake, sparks, hitstop *feel* | `graphics/cue_visuals.gd` — except hitstop and dilation, see below |
| HUD layout, editor look, menu copy | `graphics/ui/` |
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
| `Cues` | app | the seam |
| `Audio`, `AudioCues` | app | the synthesised sound bank, and what each cue sounds like |
| `Arena` | feature | the node live world objects are parented to |
| `TimeCtl` | feature | hitstop and dilation |
| `GameState` | feature | the profile, the stash, the raid in progress |
| `Sprites` | graphics | the atlas, sliced |
| `Fx` | graphics | shake, sparks, floating numbers |
| `Views` | graphics | attaches views to gameplay nodes |
| `CueVisuals` | graphics | what each cue looks like |

`project.godot` is the one file both branches may need to touch — adding an
autoload, an input action or a collision layer. Its autoload block is grouped
by module so two additions rarely collide.
