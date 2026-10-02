-- The player's movement machine (feature/actors/player.gd).
--
-- All of it is here: seven states, what each does every frame, which can
-- follow which, and what opens each way. Every state can reach every other: a
-- dash can end in the air or on the ground, a wall kick can go straight up, a
-- ledge drops into a fall from a standstill or a crouch. What the player keeps
-- is the words these rows are written in — the actions a step takes and the
-- senses a condition reads — which `Player._setup_fsm` hands over by name.

INSERT INTO machines (id, start) VALUES ('player', 'idle');

INSERT INTO states (machine_id, id, label) VALUES
	('player', 'idle',       'Idle'),
	('player', 'run',        'Run'),
	('player', 'crouch',     'Crouch'),
	('player', 'rise',       'Rise'),
	('player', 'fall',       'Fall'),
	('player', 'wall_slide', 'WallSlide'),
	('player', 'dash',       'Dash');

-- What each state does every frame, in order. The actions:
--
--   brake    slows to a stop along the ground
--   run      speeds up toward the direction held, along the ground
--   steer    the same in the air, easing off when nothing is held
--   gravity  falls faster, up to the fastest fall
--   cling    a hugged wall holds the fall to a slide
--   jump     a press becomes a jump — off the ground, off a wall, or the air
--            jump — and letting go early cuts the rise short
--   dash     a press starts a dash, when the stamina and the cooldown allow
--   rush     a dash under way carries the body until its time runs out
--   duck     keeps the body low for the frame; the frame no step does, it stands
--
-- Rising and falling do the same; they are two states so the arc can be told.
-- A crouch is an idle that ducks: it stops where it is, and jumps or dashes
-- out of it like any other state on the ground.
INSERT INTO steps (machine_id, state_id, position, action) VALUES
	('player', 'idle', 0, 'brake'),
	('player', 'idle', 1, 'gravity'),
	('player', 'idle', 2, 'jump'),
	('player', 'idle', 3, 'dash'),

	('player', 'run', 0, 'run'),
	('player', 'run', 1, 'gravity'),
	('player', 'run', 2, 'jump'),
	('player', 'run', 3, 'dash'),

	('player', 'crouch', 0, 'duck'),
	('player', 'crouch', 1, 'brake'),
	('player', 'crouch', 2, 'gravity'),
	('player', 'crouch', 3, 'jump'),
	('player', 'crouch', 4, 'dash'),

	('player', 'rise', 0, 'steer'),
	('player', 'rise', 1, 'gravity'),
	('player', 'rise', 2, 'jump'),
	('player', 'rise', 3, 'dash'),

	('player', 'fall', 0, 'steer'),
	('player', 'fall', 1, 'gravity'),
	('player', 'fall', 2, 'jump'),
	('player', 'fall', 3, 'dash'),

	('player', 'wall_slide', 0, 'steer'),
	('player', 'wall_slide', 1, 'gravity'),
	('player', 'wall_slide', 2, 'cling'),
	('player', 'wall_slide', 3, 'jump'),
	('player', 'wall_slide', 4, 'dash'),

	('player', 'dash', 0, 'rush');

-- What opens each way: a question about what the player senses on the frame.
--
--   dashing   a dash is under way
--   on_floor  standing on something
--   crouch    a crouch is asked for: the down key held, or a stick pointing down
--   wall      the wall being hugged: -1 on the left, 1 on the right, 0 none
--   dir       the direction held, -1 to 1
--   velocity  in pixels a second, y down: velocity.y < 0 is going up
--
-- Exactly one of these holds on any frame, whatever the senses say, and
-- tests/feature/machine_test tries them all to be sure — so the order a
-- state's ways are asked in only says which is asked first.
INSERT INTO conditions (machine_id, id, expression) VALUES
	('player', 'dashing',      'dashing'),
	('player', 'wall_sliding', 'not dashing and not on_floor and wall != 0'),
	('player', 'crouching',    'not dashing and on_floor and crouch'),
	('player', 'running',      'not dashing and on_floor and not crouch and dir != 0'),
	('player', 'standing',     'not dashing and on_floor and not crouch and dir == 0'),
	('player', 'rising',       'not dashing and not on_floor and wall == 0 and velocity.y < 0'),
	('player', 'falling',      'not dashing and not on_floor and wall == 0 and velocity.y >= 0');

-- The ways out, asked in order: the first whose condition holds is taken.
-- Close a way by deleting its row.

-- Out of idle.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'idle', 0, 'dash',       'dashing'),
	('player', 'idle', 1, 'wall_slide', 'wall_sliding'),
	('player', 'idle', 2, 'crouch',     'crouching'),
	('player', 'idle', 3, 'run',        'running'),
	('player', 'idle', 4, 'rise',       'rising'),
	('player', 'idle', 5, 'fall',       'falling');

-- Out of run.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'run', 0, 'dash',       'dashing'),
	('player', 'run', 1, 'wall_slide', 'wall_sliding'),
	('player', 'run', 2, 'crouch',     'crouching'),
	('player', 'run', 3, 'idle',       'standing'),
	('player', 'run', 4, 'rise',       'rising'),
	('player', 'run', 5, 'fall',       'falling');

-- Out of a crouch.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'crouch', 0, 'dash',       'dashing'),
	('player', 'crouch', 1, 'wall_slide', 'wall_sliding'),
	('player', 'crouch', 2, 'run',        'running'),
	('player', 'crouch', 3, 'idle',       'standing'),
	('player', 'crouch', 4, 'rise',       'rising'),
	('player', 'crouch', 5, 'fall',       'falling');

-- Out of rise.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'rise', 0, 'dash',       'dashing'),
	('player', 'rise', 1, 'wall_slide', 'wall_sliding'),
	('player', 'rise', 2, 'crouch',     'crouching'),
	('player', 'rise', 3, 'run',        'running'),
	('player', 'rise', 4, 'idle',       'standing'),
	('player', 'rise', 5, 'fall',       'falling');

-- Out of fall.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'fall', 0, 'dash',       'dashing'),
	('player', 'fall', 1, 'wall_slide', 'wall_sliding'),
	('player', 'fall', 2, 'crouch',     'crouching'),
	('player', 'fall', 3, 'run',        'running'),
	('player', 'fall', 4, 'idle',       'standing'),
	('player', 'fall', 5, 'rise',       'rising');

-- Out of a wall slide.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'wall_slide', 0, 'dash',       'dashing'),
	('player', 'wall_slide', 1, 'crouch',     'crouching'),
	('player', 'wall_slide', 2, 'run',        'running'),
	('player', 'wall_slide', 3, 'idle',       'standing'),
	('player', 'wall_slide', 4, 'rise',       'rising'),
	('player', 'wall_slide', 5, 'fall',       'falling');

-- Out of a dash.
INSERT INTO transitions (machine_id, from_id, position, to_id, condition) VALUES
	('player', 'dash', 0, 'wall_slide', 'wall_sliding'),
	('player', 'dash', 1, 'crouch',     'crouching'),
	('player', 'dash', 2, 'run',        'running'),
	('player', 'dash', 3, 'idle',       'standing'),
	('player', 'dash', 4, 'rise',       'rising'),
	('player', 'dash', 5, 'fall',       'falling');
