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
INSERT INTO meta (key, value) VALUES ('schema_version', '3');

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

-- Everyone with something to say: a conversation in the box, opening on
-- `start`, free talk in `rules` further down, or both.
--
-- The `line_` columns are what their lines say when a line does not say it
-- itself: `Dialogue` fills a line's missing `voice` from `line_voice`, and so
-- on for every column with that prefix — add one, and it is a default too.
CREATE TABLE characters (
	id           TEXT PRIMARY KEY CHECK (id <> '' AND id = upper(id)),
	name         TEXT NOT NULL CHECK (name <> ''),     -- on the tab when they speak
	sprite       TEXT NOT NULL CHECK (sprite <> ''),   -- their character in the atlas, in the world and on the portrait
	player_name  TEXT,                                 -- on the tab when the player speaks; NULL reads hud.dialogue.player
	start        TEXT,                                 -- the line a conversation in the box opens on; NULL: they only talk free
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

-- A line in the box belongs to somebody the box opens on. A character with no
-- `start` only talks free, and a line in the box for them is one that nothing
-- will ever reach.
CREATE TRIGGER nodes_need_a_start
BEFORE INSERT ON nodes
WHEN (SELECT start FROM characters WHERE id = NEW.character_id) IS NULL
BEGIN
	SELECT RAISE(ABORT, 'a line in the box for somebody the box never opens on');
END;

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

-- ---- free talk ----------------------------------------------------------------
--
-- The other way a character talks: free, in a bubble over whoever is
-- speaking, while the player goes on playing. Nobody is held still, a line
-- moves on by itself once it has had time to be read, and nothing follows a
-- tree. Every line is a rule: the event it answers, the criteria the facts
-- must meet for it, and the changes it makes to them once it has been said.
-- Of the rules an event could get, the one with the most criteria that all
-- hold is said — the most specific thing there is to say. It is aarthificial's
-- Typewriter (Legacy devlog #23), after Elan Ruskin's dynamic dialog for
-- Valve. `FreeTalk` (story/rules/free_talk.gd) plays it; how to write it is in
-- README.md here.

-- What the characters know: whole numbers by name, 0 until something sets
-- them. `scope` is how long one is kept —
--
--   save   with the profile, for good (`GameState.memory`)
--   visit  until the player leaves the world they are in
--   game   what the game counts for itself, read off the profile each time it
--          is asked (`GameState.facts`); a line may ask about one and never
--          change it
--
-- Every event and every rule is a fact too, declared by the triggers below:
-- how many times the event has been raised, or the line said — an event
-- under its own name, a rule as `<CHARACTER>.<rule>`. A name means one thing,
-- so a fact that shares one with an event fails the build.
CREATE TABLE facts (
	id    TEXT PRIMARY KEY CHECK (id <> ''),
	scope TEXT NOT NULL CHECK (scope IN ('save', 'visit', 'game'))
);
-- The keys of `GameState.facts()` (feature/core/game_state.gd), and
-- tests/story/free_talk_test fails on one that is not.
INSERT INTO facts (id, scope) VALUES
	('raids', 'game'), ('escapes', 'game'), ('deaths', 'game'), ('kills', 'game'),
	('best_haul', 'game'), ('scrap', 'game'), ('kit_waiting', 'game');

-- What a line can answer. An event with a `cue` is a moment the game already
-- announces (app/cues.gd), heard by every free talker the player is in
-- earshot of: that cue, whenever it carries everything `match` says. An event
-- with none is raised by the game — the three below, by name — or by a line
-- that `triggers` it.
CREATE TABLE events (
	id    TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	cue   TEXT CHECK (cue <> ''),
	match JSON CHECK (match IS NULL OR (json_valid(match) AND json_type(match) = 'object')),
	CHECK (match IS NULL OR cue IS NOT NULL)
);

CREATE TRIGGER events_are_facts
AFTER INSERT ON events
BEGIN
	INSERT INTO facts (id, scope) VALUES (NEW.id, 'save');
END;

-- talk: a press of interact beside them while nothing is being said.
-- near: the player coming into earshot.
-- leave: the player going out of it, halfway through talk they started.
INSERT INTO events (id) VALUES ('talk'), ('near'), ('leave');

-- The moments a free talker notices. Each is a cue `feature/` sends, and
-- tests/story/free_talk_test fails on one it does not. When a cue is more
-- than one of these, the one that matches more of it is answered first.
INSERT INTO events (id, cue, match) VALUES
	('jump',        'jump',    '{"kind": "ground"}'),
	('double_jump', 'jump',    '{"kind": "air"}'),
	('wall_kick',   'jump',    '{"kind": "wall"}'),
	('dash',        'dash',    NULL),
	('winded',      'refused', '{"kind": "stamina"}'),
	('parry',       'parry',   NULL),
	('strike',      'hit',     '{"target_team": 1}'),
	('kill',        'hit',     '{"target_team": 1, "killed": true}'),
	('hurt',        'hurt',    '{"team": 0}');

-- The lines. `speaker` says whose head the bubble is over; the columns shared
-- with `nodes` mean what they mean there, and fall back on the character's
-- `line_` defaults the same way.
CREATE TABLE rules (
	character_id TEXT NOT NULL REFERENCES characters (id) ON DELETE CASCADE,
	id           TEXT NOT NULL CHECK (id <> ''),
	listens      TEXT REFERENCES events (id),                 -- the event it answers; NULL: said only as another's `next`
	once         INTEGER NOT NULL DEFAULT 0 CHECK (once IN (0, 1)),   -- 1: never said twice
	text         TEXT NOT NULL CHECK (text <> ''),
	speaker      TEXT CHECK (speaker IN ('npc', 'player')),   -- NULL: the character's line_speaker
	speed        INTEGER CHECK (speed >= 1),                  -- letters per second; NULL: line_speed
	emotion      TEXT REFERENCES emotions (id),               -- NULL: line_emotion
	sfx          TEXT,                                        -- a sound from the bank in app/audio/audio.gd, as the line starts
	voice        TEXT REFERENCES voices (id),                 -- NULL: line_voice
	hold         REAL CHECK (hold >= 0),                      -- seconds it stays up once it is out; NULL: long enough to read
	next         TEXT,                                        -- said after it, whatever the facts
	triggers     TEXT REFERENCES events (id),                 -- raised after it: whatever answers best is said next
	PRIMARY KEY (character_id, id),
	FOREIGN KEY (character_id, next) REFERENCES rules (character_id, id) DEFERRABLE INITIALLY DEFERRED,
	CHECK (next IS NULL OR triggers IS NULL)
);

CREATE TRIGGER rules_are_facts
AFTER INSERT ON rules
BEGIN
	INSERT INTO facts (id, scope) VALUES (NEW.character_id || '.' || NEW.id, 'save');
END;

-- What the facts must be for a rule to be said: every row of it at once.
CREATE TABLE criteria (
	character_id TEXT NOT NULL,
	rule_id      TEXT NOT NULL,
	fact         TEXT NOT NULL REFERENCES facts (id) DEFERRABLE INITIALLY DEFERRED,
	op           TEXT NOT NULL DEFAULT '=' CHECK (op IN ('=', '<>', '<', '<=', '>', '>=')),
	value        INTEGER NOT NULL CHECK (typeof(value) = 'integer'),
	FOREIGN KEY (character_id, rule_id) REFERENCES rules (character_id, id) ON DELETE CASCADE
);

-- What a rule does to the facts once it has been said: `set` one to the
-- value, or `add` the value to it — a negative one takes away.
CREATE TABLE changes (
	character_id TEXT NOT NULL,
	rule_id      TEXT NOT NULL,
	fact         TEXT NOT NULL REFERENCES facts (id) DEFERRABLE INITIALLY DEFERRED,
	op           TEXT NOT NULL DEFAULT 'set' CHECK (op IN ('set', 'add')),
	value        INTEGER NOT NULL CHECK (typeof(value) = 'integer'),
	FOREIGN KEY (character_id, rule_id) REFERENCES rules (character_id, id) ON DELETE CASCADE
);

-- What the game counts, it counts: a line may ask, and never change it.
CREATE TRIGGER changes_leave_game_facts_alone
BEFORE INSERT ON changes
WHEN (SELECT scope FROM facts WHERE id = NEW.fact) = 'game'
BEGIN
	SELECT RAISE(ABORT, 'a line cannot change a fact the game counts for itself');
END;

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
