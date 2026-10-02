-- The parts a skill board is built from (circuit/components.gd), in the order
-- the palette shows them — which is also the order the loot pool draws from.
--
-- A part is its numbers and what it does to a flow. `heat` is added to the
-- cooldown of every cast that passes through it; `cells` is its footprint and
-- its cost in ticks, so time on a board is distance on it. Its ports are the
-- sides a flow leaves it by, as it faces east. Its effects are what it does
-- to the payload a flow carries, as the flow enters it. The `name` and
-- `description` are the English, laid under localization/<lang>/parts.json
-- the way a line's text is laid under its translation.
--
-- What a part looks like — its colour, glyph and icon — is graphics/style.gd's,
-- keyed by the same id, and a part added here draws in its category's colour
-- until somebody gives it a look of its own. A part added here needs a number
-- in `codes`, or no board carrying it can be shared.
--
-- Where a flow starts and where it becomes an attack are not parts of their
-- own. They are the board's: its root, and its way out in the middle of its
-- right edge (circuit/skill_board.gd).

INSERT INTO categories (id) VALUES
	('form'), ('element'), ('stat'), ('behavior'), ('flow'), ('trigger');

-- Every number a part has ever had in a shared code, in order. **Only ever
-- add to the end.** A code written today has to mean the same board next
-- year, so a number is a part's for good: INPUT, OUTPUT, WIRE and BEND keep
-- theirs though they are gone, and EXPLODE has the number it had when it was
-- called AREA. A code has six bits for it, so the last number there can be
-- is 63.
INSERT INTO codes (code, id) VALUES
	(0, 'INPUT'), (1, 'OUTPUT'), (2, 'WIRE'), (3, 'BEND'),
	(4, 'PROJECTILE'), (5, 'SLASH'), (6, 'EXPLODE'), (7, 'DASHSLASH'), (8, 'DASHSLASH_AUTO'),
	(9, 'FIRE'), (10, 'ICE'), (11, 'DAMAGE'), (12, 'SIZE'), (13, 'SPEED'),
	(14, 'PIERCE'), (15, 'DASH'), (16, 'BLINK'), (17, 'HOMING'), (18, 'REVERSE'),
	(19, 'SPLIT'), (20, 'TEE'), (21, 'DUPLICATE'), (22, 'OVERCLOCK'), (23, 'DELAY'), (24, 'TIME_DILATION'),
	(25, 'ON_HIT'), (26, 'ON_KILL'), (27, 'ON_PARRY'),
	(28, 'SHATTER'), (29, 'GRAVITY'), (30, 'MANA_DRAIN'),
	(31, 'RANGE'),
	(32, 'KNOCKBACK'),
	(33, 'ZAP');

-- WIRE and BEND carried a flow one cell and did nothing else to it, which
-- every part already does: any part takes flow on any side and sends it where
-- it points. INPUT was where a flow started; a board's root is that now, the
-- weapon's own part (`SkillBoard.root`). OUTPUT was where a flow became an
-- attack; the middle of the board's right edge is that now
-- (`SkillBoard.way_out`). A board that still has any of them reads with the
-- part left out and its cell left empty, and one that ended on an OUTPUT is
-- slid along to where its flow used to end (`SkillBoard.slide_onto_way_out`).
INSERT INTO retired_parts (id) VALUES ('WIRE'), ('BEND'), ('INPUT'), ('OUTPUT');

INSERT INTO renamed_parts (old_id, new_id) VALUES ('AREA', 'EXPLODE');


-- ---- form: what the attack is ------------------------------------------------
-- A form is only as good as the attack that draws it: feature/attacks/ spawns
-- each by its id, and `Weapons.finalize` weighs it. A weapon's own form is the
-- root of its graph, so every cast off it starts as that form; a form placed
-- after it makes the flow that instead.

INSERT INTO parts (id, name, category, heat, cells, tag, description) VALUES
	('PROJECTILE', 'PROJECTILE', 'form', 0.6, 1, 'ranged', 'Fires a bolt along the aim direction. The standard ranged form.'),
	('SLASH', 'SLASH', 'form', 0.5, 1, 'melee', 'An instant short arc at the aim direction. Fast, but reach is short.'),
	('EXPLODE', 'EXPLODE', 'form', 1.2, 2, 'area', 'Damages everything inside a burst radius. Uses two board cells.'),
	('DASHSLASH', 'DASHSLASH', 'form', 1.0, 2, 'melee', 'Lunges along the aim direction, cutting everything on the path. Uses two cells.'),
	('DASHSLASH_AUTO', 'DASHSLASH+', 'form', 1.4, 2, 'melee', 'Seeks the nearest visible enemy and blinks through it, cutting the path. Uses two cells.'),
	('ZAP', 'ZAP', 'form', 0.7, 1, 'ranged', 'A beam to where the cursor points, striking the instant it is cast. Stops at the first wall, and at the first enemy unless PIERCE carries it on.');

INSERT INTO ports (part_id, side) VALUES
	('PROJECTILE', 'E'), ('SLASH', 'E'), ('EXPLODE', 'E'), ('DASHSLASH', 'E'), ('DASHSLASH_AUTO', 'E'),
	('ZAP', 'E');

INSERT INTO effects (part_id, position, field, op, value) VALUES
	('PROJECTILE', 0, 'form', 'set', 'PROJECTILE'),
	('SLASH', 0, 'form', 'set', 'SLASH'),
	('EXPLODE', 0, 'form', 'set', 'EXPLODE'),
	('DASHSLASH', 0, 'form', 'set', 'DASHSLASH'),
	('DASHSLASH_AUTO', 0, 'form', 'set', 'DASHSLASH_AUTO'),
	('ZAP', 0, 'form', 'set', 'ZAP');


-- ---- element ----------------------------------------------------------------

INSERT INTO parts (id, name, category, heat, description) VALUES
	('FIRE', 'FIRE', 'element', 0.4, 'Adds flame. Struck enemies burn for damage over time.'),
	('ICE', 'ICE', 'element', 0.4, 'Adds frost. Struck enemies are slowed.');

INSERT INTO ports (part_id, side) VALUES ('FIRE', 'E'), ('ICE', 'E');

INSERT INTO effects (part_id, position, field, op, value) VALUES
	('FIRE', 0, 'elements', 'include', 'FIRE'),
	('ICE', 0, 'elements', 'include', 'ICE');


-- ---- stat ---------------------------------------------------------------------

INSERT INTO parts (id, name, category, heat, description) VALUES
	('DAMAGE', 'DAMAGE +', 'stat', 0.3, 'Raises damage. Stable and simple, but interacts with little else.'),
	('SIZE', 'SIZE x', 'stat', 0.4, 'Scales the attack by 1.6. Melee arcs widen and reach further.'),
	('SPEED', 'SPEED x', 'stat', 0.35, 'Bolts leave 1.5x faster. They also carry further before they fade, and are harder to dodge. A beam reaches a little further too. Does nothing to a flow with neither.'),
	('RANGE', 'RANGE x', 'stat', 0.35, 'Bolts carry 1.75x as far before they fade, and a beam reaches 1.75x as far. Does nothing to a flow with neither.'),
	('SHATTER', 'SHATTER', 'stat', 0.45, 'Hits an enemy already slowed by frost far harder. Worth nothing on its own — pair it with ICE, or with a board that lands twice.');

INSERT INTO ports (part_id, side) VALUES
	('DAMAGE', 'E'), ('SIZE', 'E'), ('SPEED', 'E'), ('RANGE', 'E'), ('SHATTER', 'E');

-- SPEED's reach is gentler than the speed it buys, because range is the thing
-- being spent there: the part is worth taking for the speed, and the extra
-- reach is what keeps a fast bolt from running out of range before it
-- arrives — which is what the part has always said it does. RANGE is worth
-- more reach than SPEED throws in, because reach is all it buys: it does
-- nothing to how hard or how fast a bolt arrives, so it has to be the answer
-- when the thing you cannot do is reach. Their descriptions say 1.5x, 1.6
-- and 1.75x; change one, change the other.
INSERT INTO effects (part_id, position, field, op, value) VALUES
	('DAMAGE', 0, 'damage', 'add', 8),
	('SIZE', 0, 'size', 'multiply', 1.6),
	('SPEED', 0, 'speed', 'multiply', 1.5),
	('SPEED', 1, 'range_px', 'multiply', 1.2),
	('RANGE', 0, 'range_px', 'multiply', 1.75),
	('SHATTER', 0, 'shatter', 'set', 'true');


-- ---- behavior -------------------------------------------------------------------

INSERT INTO parts (id, name, category, heat, tag, description) VALUES
	('PIERCE', 'PIERCE', 'behavior', 0.5, NULL, 'The attack continues through targets instead of stopping on the first.'),
	('DASH', 'DASH', 'behavior', 0.5, 'mobility', 'Lunges a short distance along the aim. Chains with melee forms into a moving arc.'),
	('BLINK', 'BLINK', 'behavior', 0.7, 'mobility', 'Teleports behind the nearest visible enemy. Works alone; if nothing is in sight the flow simply continues.'),
	('HOMING', 'HOMING', 'behavior', 0.6, NULL, 'Tracks the nearest enemy. Bolts curve; melee forms re-aim themselves.'),
	('REVERSE', 'REVERSE', 'behavior', 0.4, NULL, 'Flips travel direction. Bolts return to you; other forms invert in their own way.'),
	('GRAVITY', 'GRAVITY', 'behavior', 0.7, NULL, 'The enemy struck is not knocked back but pinned, and every other enemy nearby is dragged onto it. Gathers a room into one place for whatever comes next.'),
	('KNOCKBACK', 'KNOCKBACK', 'behavior', 0.5, NULL, 'Hits throw the enemy back the way the attack was going. Buys room, but can put it out of reach.'),
	('MANA_DRAIN', 'MANA DRAIN', 'behavior', 0.5, NULL, 'Every enemy this attack connects with gives mana back to the caster. What pays for the next charge is landing hits, not waiting.');

INSERT INTO ports (part_id, side) VALUES
	('PIERCE', 'E'), ('DASH', 'E'), ('BLINK', 'E'), ('HOMING', 'E'),
	('REVERSE', 'E'), ('GRAVITY', 'E'), ('KNOCKBACK', 'E'), ('MANA_DRAIN', 'E');

INSERT INTO effects (part_id, position, field, op, value) VALUES
	('PIERCE', 0, 'pierce', 'add', 2),
	('DASH', 0, 'dash', 'set', 'true'),
	('BLINK', 0, 'blink', 'set', 'true'),
	('HOMING', 0, 'homing', 'set', 'true'),
	('REVERSE', 0, 'reverse', 'toggle', NULL),
	('GRAVITY', 0, 'pull', 'set', 'true'),
	('KNOCKBACK', 0, 'knockback', 'set', 'true'),
	('MANA_DRAIN', 0, 'mana_drain', 'set', 'true');


-- ---- flow ---------------------------------------------------------------------
-- OVERCLOCK does nothing to a flow: it runs the whole board on a faster clock,
-- which `SkillBoard.analyze` counts off the grid.

INSERT INTO parts (id, name, category, heat, description) VALUES
	('SPLIT', 'SPLIT', 'flow', 0.4, 'Divides one flow into two. Each branch carries half the damage.'),
	('TEE', 'TEE', 'flow', 0.5, 'Keeps the main flow and grows one branch sideways. Both carry full damage.'),
	('DUPLICATE', 'DUPLICATE x3', 'flow', 3.0, 'Produces the same result three times at full damage. Generates a lot of heat.'),
	('OVERCLOCK', 'OVERCLOCK', 'flow', 0.0, 'Runs the whole board on a faster clock, at the price of a settling delay between cycles. Each one adds less speed than the last while the delay grows faster, so a few pay off and a wall of them does not.'),
	('DELAY', 'DELAY', 'flow', 0.0, 'One cell of waiting and nothing more: it turns a flow and leaves it as it was. Steer a branch round to the way out with it, or stagger one against another by giving it further to walk.'),
	('TIME_DILATION', 'TIME DILATION', 'flow', 2.0, 'Slows the world and the board alike. Not a speed buff — a change in the pace of the fight.');

-- SPLIT sends north first, then south; TEE east, then south.
INSERT INTO ports (part_id, side) VALUES
	('SPLIT', 'N'), ('SPLIT', 'S'),
	('TEE', 'E'), ('TEE', 'S'),
	('DUPLICATE', 'E'), ('OVERCLOCK', 'E'), ('DELAY', 'E'), ('TIME_DILATION', 'E');

-- SPLIT halves a flow as it enters, so each of the two it sends carries half.
INSERT INTO effects (part_id, position, field, op, value) VALUES
	('SPLIT', 0, 'damage', 'multiply', 0.5),
	('DUPLICATE', 0, 'duplicates', 'multiply', 3),
	('TIME_DILATION', 0, NULL, 'dilate', 1.4);


-- ---- trigger: a second flow, run as the payload of a moment -------------------
-- Which moment is the part's id: `SkillRunner` keeps what each branch resolves
-- to under it, and a payload carries it as `on_hit`, `on_kill` or `on_parry`.

INSERT INTO parts (id, name, category, heat, tag, description) VALUES
	('ON_HIT', 'ON HIT', 'trigger', 0.6, 'trigger', 'Runs the branch flow as a payload when this skill connects.'),
	('ON_KILL', 'ON KILL', 'trigger', 0.6, 'trigger', 'Runs the branch flow as a payload only when this skill kills.'),
	('ON_PARRY', 'ON PARRY', 'trigger', 0.8, 'trigger', 'Opens a brief guard window as the flow passes. Absorbing a hit there runs the branch flow.');

INSERT INTO ports (part_id, side, kind) VALUES
	('ON_HIT', 'E', 'flow'), ('ON_HIT', 'S', 'branch'),
	('ON_KILL', 'E', 'flow'), ('ON_KILL', 'S', 'branch'),
	('ON_PARRY', 'E', 'flow'), ('ON_PARRY', 'S', 'branch');

-- The guard window is real seconds, like the overclock's settling delay and
-- for the same reason: a window counted in ticks would be shortened by a
-- faster clock. It used to be read off ON PARRY's own tick cost, which one
-- tick per cell would have cut to a third.
INSERT INTO effects (part_id, position, field, op, value) VALUES
	('ON_PARRY', 0, NULL, 'guard', 0.2);
