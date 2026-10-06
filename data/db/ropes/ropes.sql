-- The lines that hang in the rooms, and what a room hangs of each. See "A
-- rope" in README.md. The numbers are `Rope`'s (graphics/rope.gd): change
-- one here and rebuild, and every line of that kind in the game moves that
-- way. A new kind is a row here, a row of `hangings` for the rooms to hang
-- it, and its colours in graphics/style.gd.
--
-- A cable is carried along by whatever goes through it — it takes all of a
-- body's speed, up to 400 a second — so the whole of it swings out from its
-- anchor, and it is damped hard enough to be back at rest within a second
-- or two, hardly swinging past it. Its nodes are 24 apart, four to seven of
-- them a cable.
INSERT INTO ropes (id, segment, stiffness, damping, gravity, give, push_most) VALUES
	('cable', 24, 2, 6, 800, 1, 400);

-- A cord is what a light hangs on in the hideout — a lantern's cord in the
-- grove, a lamp's chain under the brass terrace's arches, the chain of the
-- keep's ring of candles: no room hangs one, so it has no row of `hangings`,
-- and a look of the hideout hangs its own (`HideoutScenery.cord`), in its own
-- colour. The light's weight keeps it taut, so a cord is one length from what
-- it hangs on to its light — a segment longer than any of them — and the two
-- swing from the top the way a pendulum does: with nothing keeping it to its
-- line but that weight, and hardly damped, so a lantern knocked aside goes
-- back and forth a few times before it hangs still. It takes a quarter of
-- the speed of whatever goes through it each frame, and of no more than 110
-- a second: a lantern is leaned aside by a body going through it, and let go
-- at no more than will swing the shortest cord short of level.
INSERT INTO ropes (id, segment, stiffness, damping, gravity, give, push_most) VALUES
	('cord', 400, 0, 1.2, 800, 0.25, 110);

-- A vine is what the map creator hangs in a made room where one is put
-- (graphics/views/made_room_view.gd), the length the run of it was laid: no
-- room hangs one, so it has no row of `hangings` either. It is finer than a
-- cable — a node every 16, so it bends where it is pushed rather than swinging
-- whole — looser, and less damped, so a vine walked through sways a while;
-- and it takes more than half the speed of whatever goes through it, of no
-- more than 260 a second.
INSERT INTO ropes (id, segment, stiffness, damping, gravity, give, push_most) VALUES
	('vine', 16, 1, 2.5, 800, 0.6, 260);

-- One to three cables a room, three to five cells long.
INSERT INTO hangings (rope, fewest, most, shortest, longest) VALUES
	('cable', 1, 3, 3, 5);
