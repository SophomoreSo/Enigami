-- Every monster's attack, on the same boards the player builds — which is what
-- makes a drop legible: a kill yields a part the monster was seen using. A
-- monster names its board as `board` (feature/actors/monsters.gd), and the
-- Arbiter the one it turns to at half health as `board_phase2`. Named in the
-- code, after the monster. The Test Dummy and the dragon test's Grunts have
-- none, and attack with nothing.
--
-- Laid out like every board: the monster's own form is the root (`root` 1),
-- where the flow starts, and the chain runs from it into the middle of the
-- right edge, (6, 2), which is where its flow leaves as the attack.

INSERT INTO boards (id) VALUES
	('crawler'), ('sentry'), ('lobber'), ('hopper'), ('drifter'), ('warden'), ('arbiter'), ('arbiter_phase2');

INSERT INTO board_parts (board_id, x, y, part, facing, root) VALUES
	('crawler', 6, 2, 'SLASH', 'E', 1),

	('sentry', 6, 2, 'PROJECTILE', 'E', 1),

	('lobber', 5, 2, 'PROJECTILE', 'E', 1), ('lobber', 6, 2, 'DAMAGE', 'E', 0),

	-- EXPLODE covers two cells, so it starts a cell further in.
	('hopper', 5, 2, 'EXPLODE', 'E', 1),

	('drifter', 5, 2, 'PROJECTILE', 'E', 1), ('drifter', 6, 2, 'HOMING', 'E', 0),

	-- A frost bolt split two ways. A board has one way out, so each half is
	-- walked back to it — one round over and one round under, on DELAYs, which
	-- turn a flow and do nothing else to it — and the same distance each, so
	-- the two bolts still leave together.
	('warden', 3, 2, 'PROJECTILE', 'E', 1), ('warden', 4, 2, 'ICE', 'E', 0),
	('warden', 5, 2, 'SPLIT', 'E', 0),
	('warden', 5, 1, 'DELAY', 'E', 0), ('warden', 6, 1, 'DELAY', 'S', 0),
	('warden', 5, 3, 'DELAY', 'E', 0), ('warden', 6, 3, 'DELAY', 'N', 0),
	('warden', 6, 2, 'DELAY', 'E', 0),

	('arbiter', 4, 2, 'PROJECTILE', 'E', 1), ('arbiter', 5, 2, 'FIRE', 'E', 0),
	('arbiter', 6, 2, 'DUPLICATE', 'E', 0),

	-- An explosion whose every hit sends a bolt, split into two. The ON HIT's
	-- branch drops to the row below, and both halves of the bolt come back up
	-- into the explosion's line to leave the way it does: one straight up out
	-- of the SPLIT, the other round the corner under it.
	('arbiter_phase2', 2, 2, 'EXPLODE', 'E', 1), ('arbiter_phase2', 4, 2, 'ON_HIT', 'E', 0),
	('arbiter_phase2', 5, 2, 'DELAY', 'E', 0), ('arbiter_phase2', 6, 2, 'DELAY', 'E', 0),
	('arbiter_phase2', 4, 3, 'PROJECTILE', 'E', 0), ('arbiter_phase2', 5, 3, 'SPLIT', 'E', 0),
	('arbiter_phase2', 5, 4, 'DELAY', 'E', 0), ('arbiter_phase2', 6, 4, 'DELAY', 'N', 0),
	('arbiter_phase2', 6, 3, 'DELAY', 'N', 0);
