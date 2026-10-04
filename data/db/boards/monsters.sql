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
	('crawler'), ('sentry'), ('lobber'), ('hopper'), ('drifter'), ('warden'), ('arbiter'), ('arbiter_phase2'),
	('gunman');

INSERT INTO board_parts (board_id, x, y, part, facing, root) VALUES
	('crawler', 6, 2, 'SLASH', 'E', 1),

	('sentry', 6, 2, 'PROJECTILE', 'E', 1),

	('lobber', 5, 2, 'PROJECTILE', 'E', 1), ('lobber', 6, 2, 'DAMAGE', 'E', 0),

	('hopper', 6, 2, 'EXPLODE', 'E', 1),

	('drifter', 5, 2, 'PROJECTILE', 'E', 1), ('drifter', 6, 2, 'HOMING', 'E', 0),

	-- A frost bolt, three times over.
	('warden', 4, 2, 'PROJECTILE', 'E', 1), ('warden', 5, 2, 'ICE', 'E', 0),
	('warden', 6, 2, 'DUPLICATE', 'E', 0),

	('arbiter', 4, 2, 'PROJECTILE', 'E', 1), ('arbiter', 5, 2, 'FIRE', 'E', 0),
	('arbiter', 6, 2, 'DUPLICATE', 'E', 0),

	-- An explosion whose every hit sends a bolt, three times over. The ON HIT's
	-- branch drops to the row below, and the DUPLICATE turns it back up into
	-- the explosion's line to leave the way it does.
	('arbiter_phase2', 3, 2, 'EXPLODE', 'E', 1), ('arbiter_phase2', 4, 2, 'ON_HIT', 'E', 0),
	('arbiter_phase2', 5, 2, 'DELAY', 'E', 0), ('arbiter_phase2', 6, 2, 'DELAY', 'E', 0),
	('arbiter_phase2', 4, 3, 'PROJECTILE', 'E', 0), ('arbiter_phase2', 5, 3, 'DUPLICATE', 'N', 0),

	-- The Jean Grey test's rifle: one bolt, which the Gunman's kind makes
	-- heavy and quick (feature/actors/monsters.gd).
	('gunman', 6, 2, 'PROJECTILE', 'E', 1);
