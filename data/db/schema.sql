-- The tables in data/enigami.db.
--
-- Read by `Db` (app/db.gd), read-only, and never written by the game. Built
-- into data/enigami.db by build.sh here, together with every .sql in the
-- folders beside this file, inside one transaction with foreign keys on. How
-- to write a conversation into these tables is in README.md here; this file
-- is the contract the code reads against.
--
-- Two conventions the loader leans on, stated once:
--
--   * A column declared JSON holds a JSON document as text, and comes out of
--     `Db.records` parsed — an object, a list, a string — exactly as the same
--     value read out of a JSON file did; text that is not JSON comes out as
--     the text. That is how a line's `camera` reaches the picture as the
--     dictionary it expects, or as the word "reset".
--   * A NULL is a key that is not there. `Db.records` leaves it out, so a
--     line with no `sfx` has no `sfx`, rather than one that is null.

CREATE TABLE meta (
	key   TEXT PRIMARY KEY,
	value TEXT NOT NULL
);
-- `Db.SCHEMA_VERSION` in app/db.gd is the same number: bump both when a
-- change is one older code could not read. build.sh adds `source_hash`.
INSERT INTO meta (key, value) VALUES ('schema_version', '4');

-- How a portrait and the letters behave while a line is said: the ids
-- `Style.EMOTIONS` (graphics/style.gd) draws. A line naming one not here
-- fails the build, where a JSON file would quietly have read as neutral.
CREATE TABLE emotions (
	id TEXT PRIMARY KEY
);
INSERT INTO emotions (id) VALUES
	('neutral'), ('happy'), ('sad'), ('angry'), ('surprised'), ('thinking'), ('scared');

-- The register of the blip under the typing: the keys of `VOICE_PITCH` in
-- app/audio/audio_cues.gd, and `none` for no blip at all.
CREATE TABLE voices (
	id TEXT PRIMARY KEY
);
INSERT INTO voices (id) VALUES ('low'), ('mid'), ('high'), ('none');

-- Everyone with something to say. One conversation each, opening on `start`.
--
-- The `line_` columns are what their lines say when a line does not say it
-- itself: `Dialogue` fills a line's missing `voice` from `line_voice`, and so
-- on for every column with that prefix — add one, and it is a default too.
CREATE TABLE characters (
	id           TEXT PRIMARY KEY CHECK (id <> '' AND id = upper(id)),
	name         TEXT NOT NULL CHECK (name <> ''),     -- on the tab when they speak
	sprite       TEXT NOT NULL CHECK (sprite <> ''),   -- their character in the atlas, in the world and on the portrait
	player_name  TEXT,                                 -- on the tab when the player speaks; NULL reads hud.dialogue.player
	start        TEXT NOT NULL,                        -- the line a conversation opens on
	line_speaker TEXT NOT NULL DEFAULT 'npc' CHECK (line_speaker IN ('npc', 'player')),
	line_emotion TEXT NOT NULL DEFAULT 'neutral' REFERENCES emotions (id),
	line_voice   TEXT NOT NULL DEFAULT 'low' REFERENCES voices (id),
	line_speed   INTEGER NOT NULL DEFAULT 45 CHECK (line_speed >= 1),   -- letters per second
	-- Checked when the build commits, since the line comes after the character.
	FOREIGN KEY (id, start) REFERENCES nodes (character_id, id) DEFERRABLE INITIALLY DEFERRED
);

-- The lines: the tree itself. Where a line leads is `next`, or the answers
-- in `choices` when it is a question; neither, and the conversation ends on
-- the press after it.
--
-- The rules read `text`, `next`, `speaker`, `name` and `speed`. Every other
-- column is for the picture and the sound bank, and reaches them as it is,
-- by column name: a new kind of direction is a column here and a reader
-- there, with nothing to change in between.
CREATE TABLE nodes (
	character_id TEXT NOT NULL REFERENCES characters (id) ON DELETE CASCADE,
	id           TEXT NOT NULL CHECK (id <> ''),
	text         TEXT NOT NULL CHECK (text <> ''),
	speaker      TEXT CHECK (speaker IN ('npc', 'player')),   -- NULL: the character's line_speaker
	name         TEXT,                                        -- overrides the name on the tab for this line
	speed        INTEGER CHECK (speed >= 1),                  -- letters per second; NULL: line_speed
	emotion      TEXT REFERENCES emotions (id),               -- NULL: line_emotion
	sprite       TEXT,                                        -- swaps the portrait for this line
	camera       JSON CHECK (camera IS NULL OR camera = 'reset' OR json_valid(camera)),
	                                                          -- {"focus", "zoom", "shake", "time"}, or reset
	sfx          TEXT,                                        -- a sound from the bank in app/audio/audio.gd, as the line starts
	voice        TEXT REFERENCES voices (id),                 -- NULL: line_voice
	next         TEXT,                                        -- the line a press moves on to; NULL ends, unless there are choices
	PRIMARY KEY (character_id, id),
	FOREIGN KEY (character_id, next) REFERENCES nodes (character_id, id) DEFERRABLE INITIALLY DEFERRED
);

-- The answers to a question, in `position` order. `next` NULL ends the
-- conversation on that answer.
CREATE TABLE choices (
	character_id TEXT NOT NULL,
	node_id      TEXT NOT NULL,
	position     INTEGER NOT NULL CHECK (position >= 0),
	text         TEXT NOT NULL CHECK (text <> ''),
	next         TEXT,
	PRIMARY KEY (character_id, node_id, position),
	FOREIGN KEY (character_id, node_id) REFERENCES nodes (character_id, id) ON DELETE CASCADE,
	FOREIGN KEY (character_id, next) REFERENCES nodes (character_id, id) DEFERRABLE INITIALLY DEFERRED
);

-- ---- state machines --------------------------------------------------------
--
-- The player's movement is a state machine (feature/actors/player.gd), and
-- all of it lives here: the states, what each one does every frame, the graph
-- of ways out of each, and what opens every way. The owner keeps only the
-- words the rows are written in, and hands them to `Machine.build` by name:
-- its *actions*, which a state's steps take — each one thing the body does on
-- a frame — and its *senses*, which a condition reads. A step naming an
-- action the owner does not have, or a condition reading a sense it does not
-- have, is reported by `Machine.build` and fails tests/feature/machine_test.

CREATE TABLE machines (
	id    TEXT PRIMARY KEY CHECK (id <> ''),
	start TEXT NOT NULL,   -- the state it begins in
	FOREIGN KEY (id, start) REFERENCES states (machine_id, id) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE states (
	machine_id TEXT NOT NULL REFERENCES machines (id) ON DELETE CASCADE,
	id         TEXT NOT NULL CHECK (id <> ''),
	label      TEXT NOT NULL CHECK (label <> ''),   -- what `state_name()` reports; the debug log and the tests read it
	PRIMARY KEY (machine_id, id)
);

-- What a state does each frame: its steps, taken in `position` order, each
-- an action by the owner's name for it. A state with no steps does nothing,
-- and `Machine.problems` says so.
CREATE TABLE steps (
	machine_id TEXT NOT NULL,
	state_id   TEXT NOT NULL,
	position   INTEGER NOT NULL CHECK (position >= 0),
	action     TEXT NOT NULL CHECK (action <> ''),
	PRIMARY KEY (machine_id, state_id, position),
	FOREIGN KEY (machine_id, state_id) REFERENCES states (machine_id, id) ON DELETE CASCADE
);

-- What opens a way out: a question about the owner's senses, by name, that
-- answers true or false — `not dashing and on_floor and dir != 0`. It is read
-- as Godot's `Expression`: `and` `or` `not`, comparisons, arithmetic, a
-- sense's own fields (`velocity.y`) and the engine's functions (`abs(dir)`),
-- over the senses and nothing else.
CREATE TABLE conditions (
	machine_id TEXT NOT NULL REFERENCES machines (id) ON DELETE CASCADE,
	id         TEXT NOT NULL CHECK (id <> ''),
	expression TEXT NOT NULL CHECK (trim(expression) <> ''),
	PRIMARY KEY (machine_id, id)
);

-- The graph. The ways out of a state are tried in `position` order and the
-- first whose `condition` holds is taken. Rows sharing a `from_id` and a
-- `position` are one way out that splits between their `to_id`s by
-- `probability`, which then add up to 1; one row, and the way is certain.
CREATE TABLE transitions (
	machine_id  TEXT NOT NULL,
	from_id     TEXT NOT NULL,
	position    INTEGER NOT NULL CHECK (position >= 0),
	to_id       TEXT NOT NULL,
	condition   TEXT NOT NULL CHECK (condition <> ''),   -- whether the way is open: the id of one of the machine's conditions
	probability REAL NOT NULL DEFAULT 1.0 CHECK (probability > 0.0 AND probability <= 1.0),
	PRIMARY KEY (machine_id, from_id, position, to_id),
	FOREIGN KEY (machine_id, from_id) REFERENCES states (machine_id, id) ON DELETE CASCADE,
	FOREIGN KEY (machine_id, to_id) REFERENCES states (machine_id, id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
	FOREIGN KEY (machine_id, condition) REFERENCES conditions (machine_id, id) DEFERRABLE INITIALLY DEFERRED
);

-- One condition per way out: the rows of a split agree on when it is open.
CREATE TRIGGER transitions_one_condition_in
BEFORE INSERT ON transitions
WHEN EXISTS (SELECT 1 FROM transitions t
	WHERE t.machine_id = NEW.machine_id AND t.from_id = NEW.from_id
		AND t.position = NEW.position AND t.condition <> NEW.condition)
BEGIN
	SELECT RAISE(ABORT, 'the rows of one way out name different conditions');
END;

CREATE TRIGGER transitions_one_condition_up
BEFORE UPDATE OF machine_id, from_id, position, condition ON transitions
WHEN EXISTS (SELECT 1 FROM transitions t
	WHERE t.machine_id = NEW.machine_id AND t.from_id = NEW.from_id
		AND t.position = NEW.position AND t.condition <> NEW.condition
		AND NOT (t.to_id = NEW.to_id AND t.from_id = OLD.from_id AND t.position = OLD.position))
BEGIN
	SELECT RAISE(ABORT, 'the rows of one way out name different conditions');
END;

-- ---- parts and boards ------------------------------------------------------
--
-- The parts a skill board is built from (circuit/components.gd), and the
-- boards the game ships with (feature/core/boards.gd). A part is its numbers —
-- heat, cells, the sides its flow leaves by — and what it does to a flow as
-- the flow enters it: effects on the payload the flow carries
-- (circuit/payload.gd). What an effect *means* is code, `SkillRunner._apply`,
-- and so is what a form, a trigger or a flag does once an attack carries it.
-- What a part looks like is graphics/style.gd's, keyed by the same id.

-- The kinds of part, which the palette groups them by. `loot` 0 is a kind
-- always at hand — never dropped, sold, forged or spent from the stash — as
-- INPUT and OUTPUT are.
CREATE TABLE categories (
	id   TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	loot INTEGER NOT NULL DEFAULT 1 CHECK (loot IN (0, 1))
);

-- Every number a part has ever had in a shared code (circuit/board_code.gd).
-- A code written today has to mean the same board next year, so a number is
-- a part's for good: **only ever add to the end**. A part that is retired
-- keeps its number, and one that is renamed hands its number to its new id.
-- tests/circuit/code_test holds every number already given out to its part.
CREATE TABLE codes (
	code INTEGER PRIMARY KEY CHECK (code BETWEEN 0 AND 63),   -- six bits in a code
	id   TEXT NOT NULL UNIQUE CHECK (id <> '' AND id = upper(id))
);

-- The parts, in the order the palette shows them. Every one has a number.
CREATE TABLE parts (
	id          TEXT PRIMARY KEY CHECK (id <> '' AND id = upper(id)),
	name        TEXT NOT NULL CHECK (name <> ''),                    -- the English, under localization/<lang>/parts.json
	category    TEXT NOT NULL REFERENCES categories (id) DEFERRABLE INITIALLY DEFERRED,
	heat        REAL NOT NULL DEFAULT 0 CHECK (heat >= 0),           -- added to the cooldown of a cast that passes through
	cells       INTEGER NOT NULL DEFAULT 1 CHECK (cells IN (1, 2)),  -- its footprint, and a tick for each cell
	source      INTEGER NOT NULL DEFAULT 0 CHECK (source IN (0, 1)), -- 1: a flow starts here, and none flows in
	tag         TEXT CHECK (tag IN ('ranged', 'melee', 'area', 'mobility', 'trigger')),   -- what it makes a board, for a weapon to accept
	description TEXT NOT NULL CHECK (description <> ''),             -- the English, too
	FOREIGN KEY (id) REFERENCES codes (id) DEFERRABLE INITIALLY DEFERRED
);

-- The sides a part's flow leaves by, as the part faces east, in the order the
-- flows leave. A part takes flow on every other side — inputs are never
-- declared — so rotation decides where a flow goes, never where it may come
-- from. A `branch` is a trigger's second way out, and carries its payload. A
-- part with no ports is where a flow ends.
CREATE TABLE ports (
	part_id TEXT NOT NULL REFERENCES parts (id) ON DELETE CASCADE,
	side    TEXT NOT NULL CHECK (side IN ('E', 'S', 'W', 'N')),
	kind    TEXT NOT NULL DEFAULT 'flow' CHECK (kind IN ('flow', 'branch')),
	PRIMARY KEY (part_id, side)
);

-- One branch to a part.
CREATE UNIQUE INDEX ports_one_branch ON ports (part_id) WHERE kind = 'branch';

-- What a part does to a flow as the flow enters it, in `position` order. Most
-- change one field of the payload the flow carries:
--
--   set       the field becomes `value`
--   add       `value` is added to it
--   multiply  it is multiplied by `value`
--   toggle    a flag flips
--   include   `value` joins a list, once
--
-- and two change the fight instead, and name no field:
--
--   dilate    the world and the board slow for `value` seconds
--   guard     a guard window opens for `value` seconds; a hit absorbed in it
--             runs the part's branch
--
-- `value` is read as JSON — 8, 1.6, 'true' — and a word may go without its
-- quotes: 'FIRE'. Which fields a payload has, and what each holds, is the
-- payload's to say: `Components` holds every row to it as it reads them, and
-- tests/circuit/parts_test fails on a row that does not fit.
CREATE TABLE effects (
	part_id  TEXT NOT NULL REFERENCES parts (id) ON DELETE CASCADE,
	position INTEGER NOT NULL CHECK (position >= 0),
	field    TEXT CHECK (field <> ''),
	op       TEXT NOT NULL CHECK (op IN ('set', 'add', 'multiply', 'toggle', 'include', 'dilate', 'guard')),
	value    JSON,
	PRIMARY KEY (part_id, position),
	CHECK ((field IS NULL) = (op IN ('dilate', 'guard'))),
	CHECK ((value IS NULL) = (op = 'toggle'))
);

-- Parts the game no longer has, and the side each one sent its flow out of,
-- as it faced east. They keep their numbers, and a board saved or shared
-- while they were in still reads (`SkillBoard.drop_retired`).
CREATE TABLE retired_parts (
	id    TEXT PRIMARY KEY REFERENCES codes (id),
	sends TEXT NOT NULL CHECK (sends IN ('E', 'S', 'W', 'N'))
);

-- Parts the game still has under a new id. A board, a stash or a drop saved
-- under the old id reads back under the new one (`Components.current_id`).
CREATE TABLE renamed_parts (
	old_id TEXT PRIMARY KEY CHECK (old_id <> '' AND old_id = upper(old_id)),
	new_id TEXT NOT NULL REFERENCES parts (id) DEFERRABLE INITIALLY DEFERRED
);

-- The boards the game ships with: each weapon's own attack, every monster's,
-- a new profile's starter skill, the dragon test's. The boards a player builds
-- are theirs, and live in the save. Which part feeds which is not written
-- down: the parts' ports and the way each faces already say it, and
-- `SkillBoard.trace` walks it.
CREATE TABLE boards (
	id     TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	width  INTEGER NOT NULL DEFAULT 7 CHECK (width BETWEEN 1 AND 16),     -- the most a shared code carries
	height INTEGER NOT NULL DEFAULT 5 CHECK (height BETWEEN 1 AND 16),
	name   TEXT CHECK (name <> '')   -- what it is called when whoever builds it does not say
);

-- A part on a board: the cell it is placed in, and the way its east side
-- faces. A two-cell part covers the next cell that way too.
CREATE TABLE board_parts (
	board_id TEXT NOT NULL REFERENCES boards (id) ON DELETE CASCADE,
	x        INTEGER NOT NULL CHECK (x >= 0),
	y        INTEGER NOT NULL CHECK (y >= 0),
	part     TEXT NOT NULL REFERENCES parts (id) DEFERRABLE INITIALLY DEFERRED,
	facing   TEXT NOT NULL DEFAULT 'E' CHECK (facing IN ('E', 'S', 'W', 'N')),
	PRIMARY KEY (board_id, x, y)
);
