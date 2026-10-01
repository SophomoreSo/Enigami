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
INSERT INTO meta (key, value) VALUES ('schema_version', '9');

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
--
-- Where a flow starts is not a part: every board is rooted at one cell
-- (`SkillBoard.ROOT`, the left edge of the middle row), and whatever part
-- stands there — a weapon's own DASHSLASH, a monster's SLASH — is the source
-- of every cycle. INPUT, which used to be that, is retired and keeps its
-- number.

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
	tag         TEXT CHECK (tag IN ('ranged', 'melee', 'area', 'mobility', 'trigger')),   -- what it makes a board, for a weapon to accept
	description TEXT NOT NULL CHECK (description <> ''),             -- the English, too
	FOREIGN KEY (id) REFERENCES codes (id) DEFERRABLE INITIALLY DEFERRED
);

-- The sides a part's flow leaves by, as the part faces east, in the order the
-- flows leave. A part takes flow on every other side — inputs are never
-- declared — so rotation decides where a flow goes, never where it may come
-- from; the root takes flow like any other part, so a ring may run back
-- through it. A `branch` is a trigger's second way out, and carries its
-- payload. A part with no ports is where a flow ends.
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

-- The boards the game ships with: each weapon's own graph as a new profile
-- gets it, every monster's, the dragon test's. What a player builds onto a
-- weapon's graph is theirs, and lives in the save. Which part feeds which is
-- not written down: the parts' ports and the way each faces already say it,
-- and `SkillBoard.trace` walks it. Every board has a part on its root cell,
-- (0, 2), where its flow starts; feature/core/boards.gd refuses one without.
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

-- ---- menus -----------------------------------------------------------------
--
-- The menus a screen is made of: the title's, the save slots behind its
-- START, its SETTINGS and the two pages behind them, and PAUSED. A menu is
-- its name — the heading over it, and what a button opening it says — and
-- its items, in `position` order, each one thing: the menu it `opens`, or an
-- act of the screen that shows it, by the item's id. The screen keeps only
-- the acts, handed to `Menus` (graphics/ui/menus.gd) by name the way the
-- player hands `Machine` its actions, and lays the items out: one that is a
-- way out of the menu (`exit`) sits pinned at its foot. What an item looks
-- like — its colour, the mark over a tile — is the screen's, keyed by the
-- item's id, the way a part's look is `Style`'s.
--
-- The English here is the fallback under localization/<lang>/menu.json, by
-- id: `menu.<menu>.heading` for a name, `menu.<menu>.<item>` for an item's
-- text. tests/shared/loc_test fails if the two drift.

CREATE TABLE menus (
	id   TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	name TEXT CHECK (name <> '')   -- the heading over it; NULL for one with none, the title's, which the seal heads
);

CREATE TABLE menu_items (
	menu_id  TEXT NOT NULL REFERENCES menus (id) ON DELETE CASCADE,
	id       TEXT NOT NULL CHECK (id <> ''),
	position INTEGER NOT NULL CHECK (position >= 0),
	text     TEXT CHECK (text <> ''),      -- what it says; NULL: the name of the menu it opens
	opens    TEXT REFERENCES menus (id),   -- the menu it leads to; NULL: an act of the screen's, by the item's id
	exit     INTEGER NOT NULL DEFAULT 0 CHECK (exit IN (0, 1)),   -- 1: a way out of the menu, gathered at its foot
	PRIMARY KEY (menu_id, id),
	UNIQUE (menu_id, position),
	CHECK (text IS NOT NULL OR opens IS NOT NULL)
);

-- An item with no text of its own says the name of the menu it opens, so
-- that menu has to have one — and to be written before it, since this asks
-- as the item goes in.
CREATE TRIGGER menu_items_say_something
BEFORE INSERT ON menu_items
WHEN NEW.text IS NULL AND (SELECT name FROM menus WHERE id = NEW.opens) IS NULL
BEGIN
	SELECT RAISE(ABORT, 'an item with no text of its own opens a menu with no name');
END;

-- ---- lines that hang -------------------------------------------------------
--
-- The lines that hang in the rooms — cables today; chains, vines and wires
-- when somebody writes them — as `Rope` (graphics/rope.gd) moves them. A
-- kind of line is the numbers the simulation shares along one: how far apart
-- its nodes are, how firmly it keeps the angles it was hung with, how fast
-- its motion dies, how hard the world pulls on it, and how much of a passing
-- body's speed it takes. What keeps a line steady whatever these say — the
-- most a node moves in a step, the slowest body that moves it — stays code,
-- and so does the look: a kind's colours are graphics/style.gd's, by the
-- same id, and a kind with none yet hangs in a cable's.

CREATE TABLE ropes (
	id        TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	segment   REAL NOT NULL DEFAULT 12 CHECK (segment >= 2),            -- pixels between nodes: finer bends more, and costs more nodes
	stiffness REAL NOT NULL DEFAULT 3 CHECK (stiffness >= 0),           -- how firmly it keeps its angles, per second: 0 a chain, 30 a rod
	damping   REAL NOT NULL DEFAULT 0.8 CHECK (damping >= 0),           -- how fast its motion dies, per second
	gravity   REAL NOT NULL DEFAULT 900,                                -- the pull on every free node, in pixels a second squared
	give      REAL NOT NULL DEFAULT 0.35 CHECK (give BETWEEN 0 AND 1),  -- the share of a passing body's speed a node takes, each frame it is covered
	push_most REAL NOT NULL DEFAULT 220 CHECK (push_most >= 0)          -- the most speed a body hands over, in pixels a second, however fast it goes
);

-- What a room hangs: of each kind of line, how many and how long, in cells
-- of the room's grid. Where each hangs is rolled by `RoomView` from the
-- room's own seed — from a solid cell with open air under it, never at the
-- room's edge or under the readout — so a room looks the same every time.
CREATE TABLE hangings (
	rope     TEXT PRIMARY KEY REFERENCES ropes (id) ON DELETE CASCADE,
	fewest   INTEGER NOT NULL DEFAULT 0 CHECK (fewest >= 0),
	most     INTEGER NOT NULL CHECK (most >= fewest),
	shortest INTEGER NOT NULL CHECK (shortest >= 1),
	longest  INTEGER NOT NULL CHECK (longest >= shortest)
);

-- ---- foliage ---------------------------------------------------------------
--
-- What grows on the rooms' floors — grass, flowers, a bush — as `Foliage`
-- (graphics/foliage.gd) draws it: aarthificial's interactive foliage, a
-- picture whose pixels sway in the wind and bend where something moving has
-- left its speed in the velocity buffer (graphics/velocity_buffer.gd). A kind
-- is how it is drawn and how it moves: which picture it is (`form`), which
-- way it gives (`sway` — `along` the ground and lower as it leans, as grass
-- and flowers do, or `any` way, as a bush does), how tall it stands, how
-- thickly, and how far a push or the wind moves its tip. How the air itself
-- springs back — how stiff, how damped, how far a push spreads — is the
-- buffer's, and shared by everything that reads it, so it stays code; and so
-- does the look: a kind's colours are graphics/style.gd's, by the same id, and
-- a kind with none yet grows in grass's.

CREATE TABLE foliage (
	id       TEXT PRIMARY KEY CHECK (id <> '' AND id = lower(id)),
	form     TEXT NOT NULL CHECK (form IN ('blades', 'flowers', 'bush')),  -- the picture: blades of grass, flowers on stems, a bush on its stems
	sway     TEXT NOT NULL CHECK (sway IN ('along', 'any')),               -- along the ground, lower as it leans; or any way at all
	shortest INTEGER NOT NULL CHECK (shortest >= 1),                       -- the shortest plant, in pixels of the picture
	tallest  INTEGER NOT NULL CHECK (tallest >= shortest),                 -- and the tallest
	density  REAL NOT NULL CHECK (density > 0 AND density <= 1),           -- the share of a patch's columns a plant stands in
	push     REAL NOT NULL CHECK (push >= 0),                              -- how far a full push moves a tip, in pixels
	wind     REAL NOT NULL CHECK (wind >= 0)                               -- how far the wind sways one, in pixels
);

-- What a room grows: of each kind, how many patches and how long each is, in
-- cells of the room's grid. Where each grows is rolled by `RoomView` from the
-- room's own seed — on a floor with open air over it, never on spikes and
-- never at the room's edge — so a room looks the same every time. Kinds are
-- drawn in the order they are written here, each over the last.
CREATE TABLE growths (
	foliage  TEXT PRIMARY KEY REFERENCES foliage (id) ON DELETE CASCADE,
	fewest   INTEGER NOT NULL DEFAULT 0 CHECK (fewest >= 0),
	most     INTEGER NOT NULL CHECK (most >= fewest),
	shortest INTEGER NOT NULL CHECK (shortest >= 1),
	longest  INTEGER NOT NULL CHECK (longest >= shortest)
);
