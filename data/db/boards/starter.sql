-- The skills a new profile's library opens with, beside the sword's and the
-- gun's own attacks (`GameState._new_profile`): a step out of trouble, and a
-- beam to try the gun's range with. Each becomes the player's the moment it
-- is theirs: a copy goes into the save, under this name.

INSERT INTO boards (id, name) VALUES ('blink_step', 'Blink Step'), ('zap', 'Zap');

INSERT INTO board_parts (board_id, x, y, part) VALUES
	('blink_step', 0, 2, 'INPUT'), ('blink_step', 1, 2, 'BLINK'), ('blink_step', 2, 2, 'OUTPUT'),
	('zap', 0, 2, 'INPUT'), ('zap', 1, 2, 'ZAP'), ('zap', 2, 2, 'OUTPUT');
