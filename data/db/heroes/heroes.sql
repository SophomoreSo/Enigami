-- The heroes: who the player can play as. See "A hero" in README.md.
--
-- A row a hero, in the order they stand on the bench's screen, drawn as a
-- character of the atlas, in a colour of their own. Their names are
-- `hud.heroes.name.<id>` in localization/. What each can do is to come.

INSERT INTO heroes (id, place, sprite, color) VALUES
	('dren_repus', 1, 'doc', '#5ce0ff'),
	('legna_dennis', 2, 'angel', '#ffd36b'),
	('reniart_lamina', 3, 'elf_m', '#7bf28a'),
	('sett_eragic', 4, 'wizzard_m', '#d98cff');
