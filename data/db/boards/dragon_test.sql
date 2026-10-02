-- The board the dragon test's tower is built around (feature/world/dragon_test.gd):
-- a DASHSLASH+ for its root whose ON HIT walks three OVERCLOCKs back round
-- into it, while its own flow leaves the board straight ahead. Every lap the
-- cast has life for is one more lunge at the nearest guard still standing. The
-- root takes flow like any other part, which is what lets the ring close on it.
-- Named in the code.

INSERT INTO boards (id) VALUES ('dragon');

INSERT INTO board_parts (board_id, x, y, part, facing, root) VALUES
	('dragon', 4, 2, 'DASHSLASH_AUTO', 'E', 1),
	('dragon', 6, 2, 'ON_HIT', 'E', 0),
	('dragon', 6, 3, 'OVERCLOCK', 'W', 0),
	('dragon', 5, 3, 'OVERCLOCK', 'W', 0),
	('dragon', 4, 3, 'OVERCLOCK', 'N', 0);
