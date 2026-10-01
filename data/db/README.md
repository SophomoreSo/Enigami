# The content database

`data/enigami.db` is what the game reads and never writes, kept as tables:
the conversations, the player's state machine, the parts a skill board is
built from, the boards the game ships with, the menus, the lines that hang
in the rooms and what grows on their floors, today, and whatever else is
better kept as rows than as a file tomorrow. The game reaches it through `Db`
(`app/db.gd`), and it is built from the SQL in this folder:

```
data/
├── enigami.db        the build — committed, shipped, read by the game. Never edited by hand.
└── db/
    ├── schema.sql    the tables: the contract the code reads against
    ├── build.sh      rebuilds enigami.db from everything here
    ├── boards/       the boards the game ships with, a file for each who uses them
    │   ├── weapons.sql      each weapon's graph, as a new profile gets it
    │   ├── monsters.sql     every monster's
    │   └── dragon_test.sql  the dragon test's tower's
    ├── dialogue/     the conversations, one file per character, named after their id in lower case
    │   ├── sage.sql         in the box
    │   └── apprentice.sql   free
    ├── machines/     the state machines, one file each
    │   └── player.sql
    ├── menus/        the menus, and what is on each
    │   └── menus.sql
    ├── ropes/        the lines that hang in the rooms, and what a room hangs of each
    │   └── ropes.sql
    ├── foliage/      what grows on the rooms' floors, and how much of each a room grows
    │   └── foliage.sql
    └── parts/        every part a board is built from, and its number in a shared code
        └── parts.sql
```

Edit the `.sql`, run `data/db/build.sh`, commit both. The build refuses a
line that leads to a line that does not exist, an emotion nobody draws, a
voice nobody has and a line with nothing to say — the mistakes that would
otherwise show up as a conversation cut short in front of a player — and
`tests/story/dialogue_test.tscn` fails if the database is older than the SQL
beside it, or the SQLite extension does not load. Run it after an edit.

Text *and* a built file, rather than one or the other: the `.sql` is what a
review reads and a merge resolves, a line at a time, and the `.db` is what a
build ships and a fresh checkout plays, with nothing to install. Any SQLite
tool can open `enigami.db` to look around; write to the `.sql`.

`build.sh` needs the `sqlite3` command line. macOS has it; Linux has it as a
package (`apt install sqlite3`); Windows from <https://sqlite.org/download.html>.

## A character

One row in `characters`, and one conversation, opening on `start`.

```sql
INSERT INTO characters (id, name, sprite, player_name, start,
		line_speaker, line_emotion, line_voice, line_speed)
	VALUES ('SAGE', 'Old Tinker', 'wizzard_m', 'Knight', 'hello',
		'npc', 'neutral', 'low', 45);
```

| Column | Meaning |
|---|---|
| `id` | The character's id, upper case. The NPC set up as `SAGE` reads these rows. |
| `name` | The name on the tab when they speak. |
| `sprite` | Their character — one from the sprite atlas, or the game's own `player` — in the world and on the portrait. |
| `player_name` | The name on the tab when the player speaks. Leave it out for `You`. |
| `start` | The line a conversation in the box opens on. Leave it out for someone who only talks free — see **Free talk**. |
| `line_speaker` `line_emotion` `line_voice` `line_speed` | What their lines say when a line does not say it itself. Left out, they are `npc`, `neutral`, `low` and `45`. |

Any column named `line_<key>` is the default for `<key>` on every line, so a
default a writer adds to the table is one the game fills without a change to
the code.

## A line

One row in `nodes`. Name only the columns the line sets; the rest are NULL,
which the game reads as *not there* — the character's `line_` default where
there is one, nothing where there is not.

```sql
INSERT INTO nodes (character_id, id, text, emotion, sfx, camera, next) VALUES
	('SAGE', 'hello', 'Ah, a new face. Nothing you break in here stays broken.',
		'happy', 'pickup', '{"focus": "both", "zoom": 1.5, "time": 0.6}', 'ask');
```

| Column | Values | Meaning |
|---|---|---|
| `id` | a name | The line's name: what `next`, an answer and a translation call it. |
| `text` | string | What is said. Required. Double a quote to write one: `'won''t'`. |
| `next` | a line's `id` | The line a press moves on to. Leave it out to end the conversation — unless the line has answers. |
| `speaker` | `npc` · `player` | Who says it. The NPC's portrait sits on the left, the player's on the right. |
| `name` | string | Overrides the name on the tab for this line. |
| `speed` | letters per second | How fast it types. |
| `emotion` | see below | How the portrait and the letters behave. |
| `sprite` | a character | Swaps the portrait for this line, e.g. `knight_f`. |
| `camera` | JSON, or `reset` | Where the camera goes, see below. |
| `sfx` | sound id | Played once as the line starts. |
| `voice` | `low` · `mid` · `high` · `none` | The blip that plays along with the typing. |

The rules read `text`, `next`, `speaker`, `name` and `speed`. Every other
column is handed to the picture and the sound bank as it is, by name — so a
new kind of direction is a column in `schema.sql`, a value here, and a reader
in `story/view/` or `app/audio/`, with nothing to change in the rules.
Declare a column `JSON` and it arrives parsed, the way `camera` does.

## A question

A line whose answers are rows in `choices`, in `position` order. Where each
one leads is its own `next`; leave it out and that answer ends the
conversation. A question's own `next` is never used — the build accepts it,
and `dialogue_test` points it out.

```sql
INSERT INTO nodes (character_id, id, text, emotion) VALUES
	('SAGE', 'ask', 'What would you like to know?', 'thinking');
INSERT INTO choices (character_id, node_id, position, text, next) VALUES
	('SAGE', 'ask', 0, 'How do skills work?', 'circuits'),
	('SAGE', 'ask', 1, 'Who are you?', 'who'),
	('SAGE', 'ask', 2, 'Nothing. Bye.', NULL);
```

### Emotions

| `emotion` | Portrait | Letters |
|---|---|---|
| `neutral` | hops while talking | still |
| `happy` | bigger hop, sparkles | gentle ripple |
| `sad` | cooled, still, a falling tear | still |
| `angry` | reddened, trembling, a vein | tremble |
| `surprised` | a big hop, an `!` | still |
| `thinking` | still, `...` | still |
| `scared` | pale, trembling, sweat | small tremble |

The list is the `emotions` table in `schema.sql`, which mirrors `EMOTIONS`
in `graphics/style.gd`; a line naming one not in it fails the build. A new
emotion is a row there and a treatment in `Style`.

A character can also have a face per emotion: if the atlas holds
`<sprite>_<emotion>_idle_anim_f0` — say `wizzard_m_angry_idle_anim_f0` — that
line's portrait uses it instead of the plain sprite.

### Camera

```sql
'{"focus": "npc", "zoom": 1.5, "shake": 6, "time": 0.4}'
```

| Key | Values | Meaning |
|---|---|---|
| `focus` | `npc` · `player` · `both` | What to centre on. Default `both`. |
| `zoom` | 1 or more | How far in, against the screen's own zoom. Default 1. |
| `shake` | pixels | A shake as the line starts. On its own it leaves the camera where it is. |
| `time` | seconds | How long the move takes. 0 cuts. Default 0.4. |

A line without a `camera` leaves the camera where the last line put it.
`'reset'` eases it back to the screen's own framing, and so does the
conversation ending. The camera never shows past the edges the screen itself
frames.

### Sounds

Every sound is synthesised, so `sfx` names one from the bank in
`app/audio/audio.gd`: `shoot` `slash` `hit` `explode` `jump` `dash` `hurt` `death`
`pickup` `place` `erase` `ui` `deny` `extract` `parry` `boss` `voice` `zap`. An unknown
id plays nothing and warns in the output.

## Free talk

The other way a character talks. Where the box holds the player still and
walks a tree, free talk goes on over the game: each line comes out in a
bubble over whoever says it, the player keeps moving, jumping and fighting
under it, and a line moves on by itself once it has had time to be read — a
press up close only hurries it. It is aarthificial's Typewriter, from
[Legacy devlog #23](https://www.youtube.com/watch?v=1LlF5p5Od6A), after Elan
Ruskin's dynamic dialog for Valve.

Nothing follows a fixed path. Every line is a **rule**: the **event** it
answers, the **criteria** the **facts** must meet for it, and the **changes**
it makes to them once it has been said. When an event is raised, the rules
answering it are tried from the most criteria to the fewest, and the first
whose criteria all hold is said — the most specific thing there is to say. A
tie goes to the one written first.

```sql
INSERT INTO characters (id, name, sprite) VALUES ('APPRENTICE', 'Apprentice', 'dwarf_f');

INSERT INTO rules (character_id, id, listens, once, text, next) VALUES
	('APPRENTICE', 'intro', 'talk', 1, 'Want to learn some footwork?', 'intro_reply');
INSERT INTO rules (character_id, id, text, speaker, triggers) VALUES
	('APPRENTICE', 'intro_reply', 'Sweeping sounds safer.', 'player', 'lesson');

-- Every press after the first, until it has all been taught.
INSERT INTO rules (character_id, id, listens, text, triggers) VALUES
	('APPRENTICE', 'resume', 'talk', 'Where were we? Right, footwork.', 'lesson');
INSERT INTO criteria (character_id, rule_id, fact, op, value) VALUES
	('APPRENTICE', 'resume', 'APPRENTICE.intro', '>=', 1),
	('APPRENTICE', 'resume', 'apprentice_taught', '=', 0);
```

A character with no `start` has nothing in the box and talks free when
pressed, and whoever stages a character can set which a press starts
(`Npc.mode`). What they notice they answer free either way. `dialogue/apprentice.sql` is a
whole character, commented.

| Table · column | Meaning |
|---|---|
| `rules.listens` | The event it answers. Leave it out for a line only ever reached as another's `next`. |
| `rules.once` | 1: said once and never again. A spent rule is out of the running. |
| `rules.next` | Said after it, whatever the facts. |
| `rules.triggers` | An event raised after it: whatever answers that best is said next, and nothing answering ends the talk there. Not together with `next`. |
| `rules.hold` | Seconds it stays up once it is all out. Left out, as long as it takes to read — Hangul counted by the syllable. |
| `rules.speaker` `text` `speed` `emotion` `voice` `sfx` | What they mean in `nodes`, falling back on the character's `line_` defaults the same way. |
| `criteria.fact` `op` `value` | A fact compared — `=` `<>` `<` `<=` `>` `>=` — with a whole number. Every row of a rule has to hold. |
| `changes.fact` `op` `value` | Made once the rule has been said: `set` the fact to the value, or `add` the value to it; a negative one takes away. |

A line takes a bubble of four rows at most, in every language —
`tests/shared/loc_test` fails one that runs over. Longer is a line for the box.

### Facts

Whole numbers by name, 0 until something sets them, so a rule can ask about
something before anything has happened to it. A fact is declared in `facts`
with how long it is kept:

| `scope` | Kept |
|---|---|
| `save` | With the profile, for good. A new game is somebody new to them. |
| `visit` | Until the player leaves the world they are in. |
| `game` | Not kept: read off the profile each time — `raids` `escapes` `deaths` `kills` `best_haul` `scrap` `kit_waiting`. A rule may ask about one and never change it. |

Every rule and every event is a fact as well, and needs no declaring: how
many times the line has been said — `APPRENTICE.intro` — or the event raised
— `double_jump`. That is what `once` reads, and it is how talk is **picked up
again**. A line counts only once it is all the way out, so a line the player
walked out on was never said, and the next press finds the first thing not
yet said. Nothing else remembers where a conversation got to.

### Events

| Event | Raised |
|---|---|
| `talk` | A press of interact beside them while nothing is being said. |
| `near` | The player coming into earshot — eight cells. |
| `leave` | The player going out of earshot halfway through talk they started, which cuts it off. |
| a moment | A cue the game sends (`app/cues.gd`) while the player is in earshot: `jump` `double_jump` `wall_kick` `dash` `winded` `parry` `strike` `kill` `hurt`. Counted once, however many hear it. |
| their own | Declared in the character's file — `INSERT INTO events (id) VALUES ('lesson')` — and raised by a rule's `triggers`. |

A new kind of moment is a row of `events` in `schema.sql`, naming the cue and
what it has to carry: `('double_jump', 'jump', '{"kind": "air"}')`.
`tests/story/free_talk_test` fails on one the game never sends. When one cue
is more than one event — a blow that kills is `strike` and `kill` — the one
that asks more of it is answered first.

An event that gets a rule cuts in on whatever was being said, and that goes
unsaid; an event that gets nothing leaves it alone. The prompt over a free
talker's head shows only while a press would get an answer, so once they have
nothing left to say, there is no prompt.

## Translating

Only the words leave this folder: what is said, the names on the tab and the
answers to a question are laid over these rows from
`localization/<lang>/dialogue/<id>.json`, by the line's `id` — and what a free
rule says by the rule's, under `rules`. The `text` here
is the English fallback, and `tests/shared/loc_test` fails if the two drift.
See `localization/README.md`.

## A state machine

The player's movement is a state machine, and all of it is rows, in five
tables: `machines` (the id and the state it starts in), `states`, the `steps`
each state takes every frame, the `conditions` that open a way, and the
`transitions` between states. What stays code is the words the rows are
written in, which the owner hands `Machine.build` by name: its **actions**,
each one thing the body does on a frame, and its **senses**, each one thing
it can tell about itself. A step names an action; a condition reads senses.
A name the owner does not have is a `fault` on the machine, reported by the
player and failed by `tests/feature/machine_test.tscn`.

```sql
INSERT INTO machines (id, start) VALUES ('player', 'idle');

INSERT INTO states (machine_id, id, label) VALUES
	('player', 'idle', 'Idle'),
	('player', 'dash', 'Dash');

-- What each does every frame, in order.
INSERT INTO steps (machine_id, state_id, position, action) VALUES
	('player', 'idle', 0, 'brake'),
	('player', 'idle', 1, 'gravity'),
	('player', 'idle', 2, 'jump'),
	('player', 'idle', 3, 'dash'),
	('player', 'dash', 0, 'rush');

INSERT INTO conditions (machine_id, id, expression) VALUES
	('player', 'dashing', 'dashing');

-- Out of idle, asked in order: the first open way is taken.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'idle', 0, 'dash', 'dashing');
```

| Table · column | Meaning |
|---|---|
| `states.label` | What `state_name()` reports — the debug log and the tests read it. |
| `steps.action` | One thing the state does each frame, by the owner's name for it. A state's steps are taken in `position` order; a state with none does nothing, and is a problem. |
| `conditions.expression` | When a way is open: a question about the owner's senses that answers true or false. See below. |
| `transitions.position` | The order the ways out of a state are asked in. The first whose condition holds is taken. |
| `transitions.condition` | Whether this way is open: the `id` of one of the machine's `conditions`. The build refuses one that is not written. |
| `transitions.probability` | Rows sharing a `from_id` and a `position` are one way out that **splits** between their `to_id`s by this, and add up to 1. One row, and the way is certain. The rows of a split name the same condition; the build refuses ones that do not. |

The player's six states can each reach every other, so `player.sql` is
thirty ways; close one by deleting its row, and open a split by adding rows
at the same position.

### The player's words

`Player._setup_fsm` is where these are named. A new one is a line there —
and, for an action, the method it calls.

| Action | What it does |
|---|---|
| `brake` | slows to a stop along the ground |
| `run` | speeds up toward the direction held, along the ground |
| `steer` | the same in the air, easing off when nothing is held |
| `gravity` | falls faster, up to the fastest fall |
| `cling` | a hugged wall holds the fall to a slide |
| `jump` | a press becomes a jump — off the ground, off a wall, or the air jump — and letting go early cuts the rise short |
| `dash` | a press starts a dash, when the stamina and the cooldown allow |
| `rush` | a dash under way carries the body until its time runs out |

| Sense | What it says |
|---|---|
| `dashing` | whether a dash is under way |
| `on_floor` | whether the player is standing on something |
| `wall` | the wall being hugged: `-1` on the left, `1` on the right, `0` none |
| `dir` | the direction held, `-1` to `1` |
| `velocity` | in pixels a second, y down: `velocity.y < 0` is going up |

### Conditions

A condition is read as Godot's `Expression`, over the senses and nothing
else: `and`, `or`, `not`, comparisons, arithmetic, a sense's own fields
(`velocity.y`), and the engine's functions (`abs(dir) > 0.5`). `Machine`
parses each one once, asks it once as it builds, and then asks it every time
the way it opens is tried. One that does not read, reads a name that is not
a sense, or answers anything but true or false is a fault, and the ways that
ask it are left out rather than guessed at.

```sql
INSERT INTO conditions (machine_id, id, expression) VALUES
	('player', 'running', 'not dashing and on_floor and dir != 0');
```

The player's six are exclusive and leave nothing out: on any frame exactly
one holds, so the order a state asks its ways in only says which is asked
first. `machine_test` tries them against every combination of the senses
that matters to them. A condition that overlaps another fails it; if that
is meant, the order of the ways starts to matter, and the test is where to
say so.

## A part

Every part a skill board is built from is rows in `parts/parts.sql`, in the
order the palette shows them — which is also the order the loot pool draws
from. What a part *looks* like is not here: its colour, glyph and icon are
`graphics/style.gd`'s, keyed by the same id, and a part added here draws in
its category's colour until somebody gives it a look.

There is no part for where a flow starts. Every board is rooted at one cell
(`SkillBoard.ROOT`, the left end of the middle row), and whatever part stands
there is the source of every cycle — a weapon's own attack form, a monster's.
INPUT, which used to be that, is retired and keeps its number.

```sql
INSERT INTO codes (code, id) VALUES (36, 'FROSTBOLT');

INSERT INTO parts (id, name, category, heat, tag, description) VALUES
	('FROSTBOLT', 'FROSTBOLT', 'form', 0.9, 'ranged', 'A bolt that slows what it strikes.');

INSERT INTO ports (part_id, side) VALUES ('FROSTBOLT', 'E');

INSERT INTO effects (part_id, position, field, op, value) VALUES
	('FROSTBOLT', 0, 'form', 'set', 'PROJECTILE'),
	('FROSTBOLT', 1, 'elements', 'include', 'ICE');
```

| Table · column | Meaning |
|---|---|
| `codes` | Every number a part has ever had in a shared code. **Only ever add to the end:** a code written today has to mean the same board next year. Every part needs one, or no board carrying it can be shared; `tests/circuit/code_test` holds the ones already given out. |
| `parts.name` `description` | The English, laid under `localization/<lang>/parts.json`; `loc_test` fails if the two drift. |
| `parts.category` | Which block of the palette it sits in: `struct`, `form`, `element`, `stat`, `behavior`, `flow` or `trigger`. A `struct` part is always at hand and never drops. |
| `parts.heat` | Added to the cooldown of every cast that passes through it. |
| `parts.cells` | 1 or 2: its footprint, and the ticks a flow spends in it. |
| `parts.tag` | What it makes a board — `ranged`, `melee`, `area`, `mobility`, `trigger` — for a weapon's `accepts` to match. |
| `ports` | The sides its flow leaves by, as it faces east, in the order the flows leave. It takes flow on every other side. A `branch` is a trigger's second way out, which carries its payload. A part with no ports is where a flow ends. |
| `effects` | What it does to a flow as the flow enters it, in `position` order. See below. |
| `inversions` | What it does instead when an INVERT comes straight after it — its opposite. See below. |
| `retired_parts` `renamed_parts` | Parts the game no longer has, or has under a new id, so a save or a code written before still reads. |

### Effects

An effect changes one field of the payload a flow carries
(`circuit/payload.gd`), and what the field holds decides what can be done to
it:

| `op` | Does | To a field that is |
|---|---|---|
| `set` | makes it `value` | a number, a whole number, a flag (`'true'`), a word |
| `add` | adds `value` | a number, a whole number |
| `multiply` | multiplies it by `value` | a number, a whole number (by a whole number) |
| `toggle` | flips it; no `value` | a flag |
| `include` | adds `value` to it, once | a list |
| `dilate` | slows the world and the board for `value` seconds; no field | — |
| `guard` | opens a guard window for `value` seconds, a hit absorbed in it runs the part's branch; no field | — |
| `invert` | takes back what the part the flow came from did, and does its `inversions` instead; no field, no `value` | — |

The fields are the payload's: `damage` `size` `speed` `range_px` `stun`
`heal` (numbers), `pierce` `duplicates` (whole numbers), `homing` `reverse`
`dash` `blink` `pull` `knockback` `shatter` `mana_drain` `cleanse` `repel`
`hook` (flags), `form` (a word) and `elements` (a list). `value` is read as
JSON — `8`, `1.6`, `'true'` — and a word may go without its quotes: `'FIRE'`.
A row asking for a field there is not, or for something its field cannot
take, is a fault the game reports as it reads the parts, and
`tests/circuit/parts_test.tscn` fails on it.

What an effect *means* is code, and so is anything a new one needs: a new
field is a line in `Payload` and something in `feature/attacks/` that reads
it; a new form is an attack that draws it. OVERCLOCK does nothing to a flow —
the board's clock counts it — and the triggers' ids are the moments their
branches run at.

### Opposites

INVERT turns round the part straight before it. As the flow enters INVERT,
the runner puts every field that part's effects name back to what it held
before the part, and then does the part's rows of `inversions` — rows like
its effects, but only the five ops that change a field:

```sql
INSERT INTO inversions (part_id, position, field, op, value) VALUES
	('DAMAGE', 0, 'heal', 'add', 8),          -- what it added heals the enemy struck instead
	('ICE', 0, 'cleanse', 'set', 'true'),     -- no chill: every burn, chill and stun on it ends
	('SIZE', 0, 'size', 'multiply', 0.625);   -- as much smaller as SIZE makes it bigger
```

Only that one part is turned round: FIRE, FIRE, INVERT still burns, from the
first FIRE. A part with no rows here has no opposite, and an INVERT after it —
or after a form, a trigger, SPLIT, TEE or another INVERT — does nothing.
What an opposite gives lands on the enemy the hit strikes, once the hit has
landed (`Attacks.resolve_hit`). Each number is its effect's turned round, and
`tests/circuit/invert_test.tscn` holds every multiply to one over its effect's.

## A board

The boards the game ships with — each weapon's graph as a new profile gets
it, every monster's, the dragon test's — are rows in `boards/`. What a player
builds onto a weapon's graph is theirs, and lives in the save.

```sql
INSERT INTO boards (id) VALUES ('warden');

INSERT INTO board_parts (board_id, x, y, part, facing) VALUES
	('warden', 0, 2, 'PROJECTILE', 'E'), ('warden', 1, 2, 'ICE', 'E'),
	('warden', 2, 2, 'SPLIT', 'E'), ('warden', 2, 1, 'OUTPUT', 'E'), ('warden', 2, 3, 'OUTPUT', 'E');
```

The part at `(0, 2)` is the root: the flow starts in it, and a board with
nothing there never fires. On a weapon's board it is the weapon's own attack
form, which the player cannot lift or replace; on a monster's, the monster's.

| Column | Meaning |
|---|---|
| `boards.width` `height` | The grid, 7 by 5 unless it says; 16 at most, which is what a shared code carries. |
| `boards.name` | What it is called when whoever builds it does not say. A weapon's and a monster's are named in the code, after the weapon or the monster. |
| `board_parts.x` `y` | The cell the part is placed in. A two-cell part covers the next cell the way it faces too. |
| `board_parts.facing` | Which way its east side points — `E`, `S`, `W` or `N` — which is where most parts send their flow. |

Which part feeds which is written down nowhere: the ports and the facings
already say it, and the board is walked, not stored. A weapon names its board
as `board` and its root part as `root` in `feature/core/weapons.gd`; a monster
its board as `board`, and the Arbiter's second form as `board_phase2`, in
`feature/actors/monsters.gd`. A part that does not fit where its row puts it —
off the grid, over another — is left off and reported, and
`tests/feature/boards_test.tscn` fails unless every board builds whole, has a
part on its root and reaches an OUTPUT, and every board the code asks for is
here.

## A menu

The menus a screen is made of — the title's, the save slots behind its
START, its SETTINGS and the two pages behind them, and PAUSED — are rows in
`menus/menus.sql`: a menu is its name, and its items in order. Each item is
one thing: the menu it opens, or an act of the screen that shows it, by the
item's id. What stays code is the acts, handed to `Menus`
(`graphics/ui/menus.gd`) by name, the way the player hands `Machine` its
actions: the title's `acts_for` and the shell's `_pause_acts`, each a
dictionary of what its items do. An item naming an act the screen does not
have does nothing, and says so; `tests/graphics/menus_test` fails on one.

```sql
INSERT INTO menus (id, name) VALUES
	('settings', 'SETTINGS'),
	('general',  'GENERAL SETTINGS');

INSERT INTO menu_items (menu_id, id, position, text, opens, exit) VALUES
	('settings', 'general', 0, NULL,   'general', 0),
	('settings', 'back',    1, 'BACK', NULL,      1);
```

| Table · column | Meaning |
|---|---|
| `menus.name` | The heading over the menu, and what an item opening it says. Leave it out for a menu with no heading, which is the title's — the seal heads it. |
| `menu_items.position` | The order the items are shown in. |
| `menu_items.text` | What the item says. Leave it out for a door, which says the name of the menu it opens — so GENERAL SETTINGS is written once, as that menu's name, and every door to it says it. The build refuses one with neither. |
| `menu_items.opens` | The menu it leads to. The screen knows which page each menu is, and a door to a menu it has no page for is reported, not guessed at. Written before the item, since a door with no text asks for the name as it goes in. |
| `menu_items.exit` | 1: a way out of the menu — BACK, BACK TO GAME, MAIN MENU — which the screen gathers at the foot of the page, pinned, however long the rows above it grow. |

The two pages behind the settings, `general` and `controls`, are shown by
the title and by PAUSED alike, from the same rows: each carries its own rows
— the sliders, the switches, the bindings, which are the screen's — and the
menu holds only its way back, which is one level up from wherever the page
was opened. What an item looks like — its colour, the mark over a tile in
mobile mode, how tall it stands — is the screen's, keyed by the item's id, as
a part's look is `Style`'s.

`menus.name` and `menu_items.text` are the English, laid under
`localization/<lang>/menu.json` by id — `menu.<menu>.heading` and
`menu.<menu>.<item>` — and `loc_test` fails if the two drift.

## A rope

The lines that hang in the rooms — cables today — are `Rope`
(`graphics/rope.gd`): a line of nodes, hung from a point, swaying when
somebody walks through it, drawn pixel by pixel. A **kind** of line is a
row of `ropes`, the numbers the simulation shares along one, and what a
room hangs of each kind is a row of `hangings`. Change a number in
`ropes/ropes.sql` and rebuild, and every line of that kind moves that way.

```sql
INSERT INTO ropes (id, segment, stiffness, damping, gravity, give, push_most) VALUES
	('chain', 16, 1, 0.5, 1200, 0.2, 180);

INSERT INTO hangings (rope, fewest, most, shortest, longest) VALUES
	('chain', 0, 1, 2, 4);
```

| Table · column | Meaning |
|---|---|
| `ropes.segment` | Pixels between nodes. Finer bends more smoothly, and costs more nodes. 12 is six pixels of the buffer the world is drawn into. |
| `ropes.stiffness` | How firmly the line keeps the angles it was hung with, per second: 0 is a free chain, 30 holds a bent line nearly rigid. A node's distance from its parent is kept outright whatever this says. |
| `ropes.damping` | How fast a node's motion dies, per second. Lower swings longer. |
| `ropes.gravity` | The pull on every free node, in pixels a second squared. Higher swings faster and hangs heavier. |
| `ropes.give` | The share of a passing body's speed a node takes, each frame the body covers it. |
| `ropes.push_most` | The most speed a body hands over, in pixels a second, however fast it goes. With `give`, how hard a dash swings a line. |
| `hangings.fewest` `most` | How many of the kind a room hangs. |
| `hangings.shortest` `longest` | How long each is, in cells of the room's grid, to the nearest node. |

Where a line hangs is `RoomView`'s (`graphics/views/room_view.gd`): from a
solid cell with open air under it — the ceiling, or the underside of a
ledge — never at the room's edge, never under the readout, never two close
together, rolled from the room's own seed so a room looks the same every
time. What keeps a line steady whatever its numbers say stays code, as
constants on `Rope`: the most a node moves in a step, and the slowest body
that moves it. What a kind looks like is `Style.ROPE_LOOK`
(`graphics/style.gd`), by the same id; a kind with no look yet hangs in a
cable's colours. `tests/graphics/rope_test.tscn` reads the tables, makes a
line of each kind, and tries what the schema refuses.

## Foliage

What grows on the rooms' floors — grass, flowers, a bush — is `Foliage`
(`graphics/foliage.gd`): aarthificial's interactive foliage, a picture
whose pixels sway in the wind and bend where something moving has left its
speed in the velocity buffer (`graphics/velocity_buffer.gd`). A **kind** of
foliage is a row of `foliage` — what is drawn, which way it gives, how tall
and how thick it stands, how far a push and the wind move it — and what a
room grows of each kind is a row of `growths`. Change a number in
`foliage/foliage.sql` and rebuild, and every patch of that kind is drawn and
moves that way.

```sql
INSERT INTO foliage (id, form, sway, shortest, tallest, density, push, wind) VALUES
	('fern', 'blades', 'along', 6, 14, 0.5, 8, 3);

INSERT INTO growths (foliage, fewest, most, shortest, longest) VALUES
	('fern', 0, 2, 1, 3);
```

| Table · column | Meaning |
|---|---|
| `foliage.form` | The picture: `blades` of grass, `flowers` on stems, or a `bush`. Drawn by `Foliage`, pixel by pixel; a new picture is code there. |
| `foliage.sway` | Which way it gives — the package's two shaders. `along`: back and forth along the ground, and lower at the tip the further it leans, as grass and flowers do. `any`: whichever way it is pushed, as a bush does. |
| `foliage.shortest` `tallest` | How tall a plant stands, in pixels of the picture — one is two world units. A patch of blades swells between the two and thins to the shortest at its ends. |
| `foliage.density` | The share of a patch's columns a plant stands in. A bush is one to a patch whatever this says. |
| `foliage.push` | How far, in pixels, a tip moves for a push of one in the buffer — about what a dash leaves behind it. A run leaves less than half of that. |
| `foliage.wind` | How far, in pixels, the wind sways a tip at its strongest. Most of the time it is half that or less. |
| `growths.fewest` `most` | How many patches of the kind a room grows. |
| `growths.shortest` `longest` | How long each patch is, in cells of the room's grid. |

Where a patch grows is `RoomView`'s (`graphics/views/room_view.gd`): along
the top of solid cells with open air over them — the floor and the tops of
the ledges — never on the spikes, never at the room's edge and never over a
patch of its own kind, rolled from the room's own seed so a room looks the
same every time. Kinds are drawn in the order their `growths` rows are
written, each over the last. How the air springs back once it is pushed —
how stiff it is, how damped, how far a push spreads — is the velocity
buffer's, and shared by everything that reads it, so it stays code, as
constants on `VelocityBuffer`; so does the wind's direction and the size of
a gust, in `foliage.gdshader`. What a kind looks like is
`Style.FOLIAGE_LOOK` (`graphics/style.gd`), by the same id; a kind with no
look yet grows in grass's colours. `tests/graphics/foliage_test.tscn` reads
the tables, grows a patch of each kind, and tries what the schema refuses;
`tests/graphics/velocity_test.tscn` pushes them.

## Reading it from code

```gdscript
Db.rows("SELECT id, name FROM characters ORDER BY id")        # raw rows, NULL as null
Db.records("nodes", "character_id = ?", ["SAGE"], "rowid")     # content: NULL left out, JSON columns parsed
Db.meta("schema_version")
```

`Dialogue` (`story/rules/dialogue.gd`) reads the conversations into the shape
`Npc` plays, `Machine` (`feature/core/machine.gd`) builds a state machine
into the `FSMNode`s its owner runs, `Components` (`circuit/components.gd`)
reads the parts, `Boards` (`feature/core/boards.gd`) builds a shipped board
into the `SkillBoard` the circuit runs, `Menus` (`graphics/ui/menus.gd`)
hands a screen its menus' items, in the language being played, `Rope.of`
(`graphics/rope.gd`) makes a line of a kind with its row's numbers, and
`Foliage.of` (`graphics/foliage.gd`) a patch of a kind; nothing else needs
to know any of it came from a table. `Dialogue.reload()` and `Components.reload()` pick up
a rebuilt file without a restart.

## Changing the tables

Edit `schema.sql` and rebuild. When the change is one older code could not
read, bump `schema_version` there **and** `Db.SCHEMA_VERSION` in `app/db.gd`;
`dialogue_test` holds the two numbers together.

## Exporting

`enigami.db` is a plain file, not a resource: an export preset needs
`data/*.db` in its non-resource include filter, or the build ships with
nobody to talk to. The extension's own libraries go with the platform being
exported — see `addons/godot-sqlite/README.md` for the one that has to be
fetched first.
