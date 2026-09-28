-- The player's movement machine (feature/actors/player.gd).
--
-- Six states, and every one can reach every other: a dash can end in the air
-- or on the ground, a wall kick can go straight up, a ledge drops into a fall
-- from a standstill. The ways out of a state are tried in order; the player's
-- conditions are exclusive — at most one holds on any frame — so the order
-- only says which is asked first. Close a way by deleting its row. The
-- actions and the conditions are named in `Player._setup_fsm`.

INSERT INTO machines (id, start) VALUES ('player', 'idle');

INSERT INTO states (machine_id, id, label, action) VALUES
	('player', 'idle',       'Idle',      'idle'),
	('player', 'run',        'Run',       'run'),
	('player', 'rise',       'Rise',      'air'),
	('player', 'fall',       'Fall',      'air'),
	('player', 'wall_slide', 'WallSlide', 'wall_slide'),
	('player', 'dash',       'Dash',      'dash');

-- Out of idle.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'idle', 0, 'dash',       'dashing'),
	('player', 'idle', 1, 'wall_slide', 'wall_sliding'),
	('player', 'idle', 2, 'run',        'running'),
	('player', 'idle', 3, 'rise',       'rising'),
	('player', 'idle', 4, 'fall',       'falling');

-- Out of run.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'run', 0, 'dash',       'dashing'),
	('player', 'run', 1, 'wall_slide', 'wall_sliding'),
	('player', 'run', 2, 'idle',       'standing'),
	('player', 'run', 3, 'rise',       'rising'),
	('player', 'run', 4, 'fall',       'falling');

-- Out of rise.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'rise', 0, 'dash',       'dashing'),
	('player', 'rise', 1, 'wall_slide', 'wall_sliding'),
	('player', 'rise', 2, 'run',        'running'),
	('player', 'rise', 3, 'idle',       'standing'),
	('player', 'rise', 4, 'fall',       'falling');

-- Out of fall.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'fall', 0, 'dash',       'dashing'),
	('player', 'fall', 1, 'wall_slide', 'wall_sliding'),
	('player', 'fall', 2, 'run',        'running'),
	('player', 'fall', 3, 'idle',       'standing'),
	('player', 'fall', 4, 'rise',       'rising');

-- Out of a wall slide.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'wall_slide', 0, 'dash', 'dashing'),
	('player', 'wall_slide', 1, 'run',  'running'),
	('player', 'wall_slide', 2, 'idle', 'standing'),
	('player', 'wall_slide', 3, 'rise', 'rising'),
	('player', 'wall_slide', 4, 'fall', 'falling');

-- Out of a dash.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'dash', 0, 'wall_slide', 'wall_sliding'),
	('player', 'dash', 1, 'run',        'running'),
	('player', 'dash', 2, 'idle',       'standing'),
	('player', 'dash', 3, 'rise',       'rising'),
	('player', 'dash', 4, 'fall',       'falling');
