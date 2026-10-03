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

-- One to three cables a room, three to five cells long.
INSERT INTO hangings (rope, fewest, most, shortest, longest) VALUES
	('cable', 1, 3, 3, 5);
