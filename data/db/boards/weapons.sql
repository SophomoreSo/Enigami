-- Each weapon's own attack, on its own button and outside the loadout: a
-- weapon names one of these as its `innate` (feature/core/weapons.gd), and a
-- new profile's library opens with the sword's and the gun's. Named in the
-- code, after the weapon, in the language being played.

INSERT INTO boards (id) VALUES ('slash'), ('bolt'), ('lob');

INSERT INTO board_parts (board_id, x, y, part) VALUES
	('slash', 0, 2, 'INPUT'), ('slash', 1, 2, 'SLASH'), ('slash', 2, 2, 'OUTPUT'),
	('bolt', 0, 2, 'INPUT'), ('bolt', 1, 2, 'PROJECTILE'), ('bolt', 2, 2, 'OUTPUT'),
	('lob', 0, 2, 'INPUT'), ('lob', 1, 2, 'PROJECTILE'), ('lob', 2, 2, 'DAMAGE'), ('lob', 3, 2, 'OUTPUT');
