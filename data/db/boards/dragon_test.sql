-- The board the dragon test's tower is built around (feature/world/dragon_test.gd):
-- a DASHSLASH+ at the root whose ON HIT walks three OVERCLOCKs back round into
-- it. Every lap the cast has life for is one more lunge at the nearest guard
-- still standing. The root takes flow like any other part, which is what lets
-- the ring close on it. Named in the code.

INSERT INTO boards (id) VALUES ('dragon');

INSERT INTO board_parts (board_id, x, y, part, facing) VALUES
	('dragon', 0, 2, 'DASHSLASH_AUTO', 'E'),
	('dragon', 2, 2, 'ON_HIT', 'E'),
	('dragon', 3, 2, 'OUTPUT', 'E'),
	('dragon', 2, 3, 'OVERCLOCK', 'W'),
	('dragon', 1, 3, 'OVERCLOCK', 'W'),
	('dragon', 0, 3, 'OVERCLOCK', 'N');
