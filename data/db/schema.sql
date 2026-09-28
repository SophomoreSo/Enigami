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
INSERT INTO meta (key, value) VALUES ('schema_version', '2');

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
-- its shape lives here: the states, and the graph of ways out of each. What a
-- state *does* each frame and what it takes for a way out to be *open* are
-- code — the owner hands `Machine` its actions and its conditions by name,
-- and a row names one of each. A name no owner has is reported by
-- `Machine.build` and fails tests/feature/machine_test.

CREATE TABLE machines (
	id    TEXT PRIMARY KEY CHECK (id <> ''),
	start TEXT NOT NULL,   -- the state it begins in
	FOREIGN KEY (id, start) REFERENCES states (machine_id, id) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE states (
	machine_id TEXT NOT NULL REFERENCES machines (id) ON DELETE CASCADE,
	id         TEXT NOT NULL CHECK (id <> ''),
	label      TEXT NOT NULL CHECK (label <> ''),    -- what `state_name()` reports; the debug log and the tests read it
	action     TEXT NOT NULL CHECK (action <> ''),   -- what the owner does each frame in it, by the owner's name for it
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
	condition   TEXT NOT NULL CHECK (condition <> ''),   -- whether the way is open, by the owner's name for it
	probability REAL NOT NULL DEFAULT 1.0 CHECK (probability > 0.0 AND probability <= 1.0),
	PRIMARY KEY (machine_id, from_id, position, to_id),
	FOREIGN KEY (machine_id, from_id) REFERENCES states (machine_id, id) ON DELETE CASCADE,
	FOREIGN KEY (machine_id, to_id) REFERENCES states (machine_id, id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
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
