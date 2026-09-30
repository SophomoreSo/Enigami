-- Each weapon's own graph, as a new profile gets it: the weapon's own part on
-- the root cell, and an OUTPUT to fire it. The root is the weapon's and stays;
-- everything a player builds on after it is theirs. A weapon names its graph
-- as `board` and its root part as `root` (feature/core/weapons.gd), and
-- tests/feature/boards_test holds the two to each other. Named in the code,
-- after the weapon, in the language being played.

INSERT INTO boards (id) VALUES ('sword'), ('gun'), ('rock');

INSERT INTO board_parts (board_id, x, y, part) VALUES
	-- DASHSLASH covers two cells, so the OUTPUT waits past both.
	('sword', 0, 2, 'DASHSLASH'), ('sword', 2, 2, 'OUTPUT'),
	('gun', 0, 2, 'PROJECTILE'), ('gun', 1, 2, 'OUTPUT'),
	('rock', 0, 2, 'PROJECTILE'), ('rock', 1, 2, 'OUTPUT');
