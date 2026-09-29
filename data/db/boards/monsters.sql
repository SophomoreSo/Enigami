-- Every monster's attack, on the same boards the player builds — which is what
-- makes a drop legible: a kill yields a part the monster was seen using. A
-- monster names its board as `board` (feature/actors/monsters.gd), and the
-- Arbiter the one it turns to at half health as `board_phase2`. Named in the
-- code, after the monster. The Test Dummy and the dragon test's Grunts have
-- none, and attack with nothing.

INSERT INTO boards (id) VALUES
	('crawler'), ('sentry'), ('lobber'), ('hopper'), ('drifter'), ('warden'), ('arbiter'), ('arbiter_phase2');

INSERT INTO board_parts (board_id, x, y, part, facing) VALUES
	('crawler', 0, 2, 'INPUT', 'E'), ('crawler', 1, 2, 'SLASH', 'E'), ('crawler', 2, 2, 'OUTPUT', 'E'),

	('sentry', 0, 2, 'INPUT', 'E'), ('sentry', 1, 2, 'PROJECTILE', 'E'), ('sentry', 2, 2, 'OUTPUT', 'E'),

	('lobber', 0, 2, 'INPUT', 'E'), ('lobber', 1, 2, 'PROJECTILE', 'E'), ('lobber', 2, 2, 'DAMAGE', 'E'),
	('lobber', 3, 2, 'OUTPUT', 'E'),

	-- EXPLODE covers two cells, so the OUTPUT waits past both.
	('hopper', 0, 2, 'INPUT', 'E'), ('hopper', 1, 2, 'EXPLODE', 'E'), ('hopper', 3, 2, 'OUTPUT', 'E'),

	('drifter', 0, 2, 'INPUT', 'E'), ('drifter', 1, 2, 'PROJECTILE', 'E'), ('drifter', 2, 2, 'HOMING', 'E'),
	('drifter', 3, 2, 'OUTPUT', 'E'),

	-- A frost bolt split two ways, an OUTPUT on each.
	('warden', 0, 2, 'INPUT', 'E'), ('warden', 1, 2, 'PROJECTILE', 'E'), ('warden', 2, 2, 'ICE', 'E'),
	('warden', 3, 2, 'SPLIT', 'E'), ('warden', 3, 1, 'OUTPUT', 'E'), ('warden', 3, 3, 'OUTPUT', 'E'),

	('arbiter', 0, 2, 'INPUT', 'E'), ('arbiter', 1, 2, 'PROJECTILE', 'E'), ('arbiter', 2, 2, 'FIRE', 'E'),
	('arbiter', 3, 2, 'DUPLICATE', 'E'), ('arbiter', 4, 2, 'OUTPUT', 'E'),

	-- An explosion whose every hit sends a bolt south, split into two.
	('arbiter_phase2', 0, 2, 'INPUT', 'E'), ('arbiter_phase2', 1, 2, 'EXPLODE', 'E'),
	('arbiter_phase2', 3, 2, 'ON_HIT', 'E'), ('arbiter_phase2', 4, 2, 'OUTPUT', 'E'),
	('arbiter_phase2', 3, 3, 'PROJECTILE', 'S'), ('arbiter_phase2', 3, 4, 'SPLIT', 'S'),
	('arbiter_phase2', 2, 4, 'OUTPUT', 'E'), ('arbiter_phase2', 4, 4, 'OUTPUT', 'E');
