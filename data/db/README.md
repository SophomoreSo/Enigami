# The content database

`data/enigami.db` is what the game reads and never writes, kept as tables:
the conversations and the player's state machine, today, and whatever else is
better kept as rows than as a file tomorrow. The game reaches it through `Db`
(`app/db.gd`), and it is built from the SQL in this folder:

```
data/
├── enigami.db        the build — committed, shipped, read by the game. Never edited by hand.
└── db/
    ├── schema.sql    the tables: the contract the code reads against
    ├── build.sh      rebuilds enigami.db from everything here
    ├── dialogue/     the conversations, one file per character, named after their id in lower case
    │   └── sage.sql
    └── machines/     the state machines, one file each
        └── player.sql
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
| `sprite` | Their character in the sprite atlas — in the world and on the portrait. |
| `player_name` | The name on the tab when the player speaks. Leave it out for `You`. |
| `start` | The line a conversation opens on. |
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
| `sprite` | atlas character | Swaps the portrait for this line, e.g. `knight_f`. |
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
`pickup` `place` `erase` `ui` `deny` `extract` `parry` `boss` `voice`. An unknown
id plays nothing and warns in the output.

## Translating

Only the words leave this folder: what is said, the names on the tab and the
answers to a question are laid over these rows from
`localization/<lang>/dialogue/<id>.json`, by the line's `id`. The `text` here
is the English fallback, and `tests/shared/loc_test` fails if the two drift.
See `localization/README.md`.

## A state machine

The player's movement is a state machine, and its **shape** is three tables:
`machines` (the id and the state it starts in), `states` and `transitions`.
What a state *does* each frame and what it takes for a way out to be *open*
stay code: the owner hands `Machine.build` its actions and its conditions by
name, and a row names one of each. A name the owner does not have is a
`fault` on the machine, reported by the player and failed by
`tests/feature/machine_test.tscn`.

```sql
INSERT INTO machines (id, start) VALUES ('player', 'idle');

INSERT INTO states (machine_id, id, label, action) VALUES
	('player', 'idle', 'Idle', 'idle'),
	('player', 'dash', 'Dash', 'dash');

-- Out of idle, asked in order: the first open way is taken.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'idle', 0, 'dash', 'dashing');
```

| Table · column | Meaning |
|---|---|
| `states.label` | What `state_name()` reports — the debug log and the tests read it. |
| `states.action` | What the owner does each frame in this state, by the owner's name for it. |
| `transitions.position` | The order the ways out of a state are asked in. The first whose condition holds is taken. |
| `transitions.condition` | Whether this way is open, by the owner's name for it. |
| `transitions.probability` | Rows sharing a `from_id` and a `position` are one way out that **splits** between their `to_id`s by this, and add up to 1. One row, and the way is certain. The rows of a split name the same condition; the build refuses ones that do not. |

The player's six states can each reach every other, so `player.sql` is
thirty rows; close a way by deleting its row, and open a split by adding
rows at the same position. `Player._setup_fsm` is where its actions and
conditions are named.

## Reading it from code

```gdscript
Db.rows("SELECT id, name FROM characters ORDER BY id")        # raw rows, NULL as null
Db.records("nodes", "character_id = ?", ["SAGE"], "rowid")     # content: NULL left out, JSON columns parsed
Db.meta("schema_version")
```

`Dialogue` (`story/rules/dialogue.gd`) reads the conversations into the shape
`Npc` plays, and `Machine` (`feature/core/machine.gd`) builds a state machine
into the `FSMNode`s its owner runs; nothing else needs to know either came
from a table. `Dialogue.reload()` picks up a rebuilt file without a restart.

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
