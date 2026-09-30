-- The menus, and what is on each: the title's, the save slots behind its
-- START, its SETTINGS and the two pages behind them, and PAUSED. See "A menu"
-- in README.md.
--
-- The menus first: an item that says the name of the menu it opens asks for
-- that name as it goes in.
INSERT INTO menus (id, name) VALUES
	('title',      NULL),                  -- the seal is its heading
	('save_slots', 'SELECT SAVE SLOT'),    -- behind START
	('settings',   'SETTINGS'),            -- nothing of its own: the way to the two pages
	('general',    'GENERAL SETTINGS'),    -- the volumes, the language, the screen; the title's and PAUSED's alike
	('controls',   'CONTROL SETTINGS'),    -- the pointer, mobile mode, the bindings; the same
	('pause',      'PAUSED');

-- The title: a column of lines, or in mobile mode a row of tiles. SETTINGS
-- says the settings' own name; START keeps its word, and leads to the slots.
INSERT INTO menu_items (menu_id, id, position, text, opens) VALUES
	('title', 'start',    0, 'START',   'save_slots'),
	('title', 'sandbox',  1, 'SANDBOX', NULL),
	('title', 'settings', 2, NULL,      'settings'),
	('title', 'quit',     3, 'QUIT',    NULL);

-- The slots themselves are rows the screen lays out from the profiles on
-- disk, one a slot; the menu holds only the way back under them.
INSERT INTO menu_items (menu_id, id, position, text, exit) VALUES
	('save_slots', 'back', 0, 'BACK', 1);

-- The settings: two doors and the way out. Each door says where it goes.
INSERT INTO menu_items (menu_id, id, position, text, opens, exit) VALUES
	('settings', 'general',  0, NULL,   'general',  0),
	('settings', 'controls', 1, NULL,   'controls', 0),
	('settings', 'back',     2, 'BACK', NULL,       1);

-- The two pages behind them carry their rows — the sliders, the switches,
-- the bindings — which are the screen's to lay out; each has only its way
-- back here. Both the title and PAUSED show them, and `back` on each is one
-- level up from wherever it was opened.
INSERT INTO menu_items (menu_id, id, position, text, exit) VALUES
	('general',  'back', 0, 'BACK', 1),
	('controls', 'back', 0, 'BACK', 1);

-- PAUSED: the same two doors, and the ways out gathered at the foot in the
-- order of what they cost — back into the game, out to the title, and last
-- the one that forfeits a raid. Which of the three ways to the title is
-- shown is the shell's: MAIN MENU everywhere but a raid, where leaving parks
-- the run and says so, and ABANDON RAID beside it.
INSERT INTO menu_items (menu_id, id, position, text, opens, exit) VALUES
	('pause', 'general',  0, NULL,                                            'general',  0),
	('pause', 'controls', 1, NULL,                                            'controls', 0),
	('pause', 'resume',   2, 'BACK TO GAME',                                  NULL,       1),
	('pause', 'title',    3, 'MAIN MENU',                                     NULL,       1),
	('pause', 'park',     4, 'MAIN MENU — the raid is kept where you left it', NULL,       1),
	('pause', 'abandon',  5, 'ABANDON RAID — forfeits the kit',               NULL,       1);
