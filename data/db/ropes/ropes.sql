-- The lines that hang in the rooms, and what a room hangs of each. See "A
-- rope" in README.md. The numbers are `Rope`'s (graphics/rope.gd): change
-- one here and rebuild, and every line of that kind in the game moves that
-- way. A new kind is a row here, a row of `hangings` for the rooms to hang
-- it, and its colours in graphics/style.gd.
INSERT INTO ropes (id, segment, stiffness, damping, gravity, give, push_most) VALUES
	('cable', 12, 3, 0.8, 900, 0.35, 220);

-- One to three cables a room, three to five cells long.
INSERT INTO hangings (rope, fewest, most, shortest, longest) VALUES
	('cable', 1, 3, 3, 5);
