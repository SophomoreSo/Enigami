-- The board the dragon test's tower is built around (feature/world/dragon_test.gd):
-- a DASHSLASH+ whose ON HIT walks three OVERCLOCKs back round into it. Every
-- lap the cast has life for is one more lunge at the nearest guard still
-- standing. Named in the code.

INSERT INTO boards (id) VALUES ('dragon');

INSERT INTO board_parts (board_id, x, y, part, facing) VALUES
	('dragon', 0, 2, 'INPUT', 'E'),
	('dragon', 1, 2, 'DASHSLASH_AUTO', 'E'),
	('dragon', 3, 2, 'ON_HIT', 'E'),
	('dragon', 4, 2, 'OUTPUT', 'E'),
	('dragon', 3, 3, 'OVERCLOCK', 'W'),
	('dragon', 2, 3, 'OVERCLOCK', 'W'),
	('dragon', 1, 3, 'OVERCLOCK', 'N');
