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
	(33, 'ZAP'),
	(34, 'INVERT'), (35, 'STUN'),
	(36, 'POSSESS'),
	(37, 'AUTO_AIM'),
	(38, 'HEALTH_DRAIN'),
	(39, 'WATER');

-- WIRE and BEND carried a flow one cell and did nothing else to it, which
-- every part already does: any part takes flow on any side and sends it where
-- it points. INPUT was where a flow started; a board's root is that now, the
-- weapon's own part (`SkillBoard.root`). OUTPUT was where a flow became an
-- attack; the middle of the board's right edge is that now
-- (`SkillBoard.way_out`). A board that still has any of them reads with the
-- part left out and its cell left empty, and one that ended on an OUTPUT is
-- slid along to where its flow used to end (`SkillBoard.slide_onto_way_out`).
--
-- DASH lunged the caster along the aim as the attack went off. The player has
-- a dash of their own on a key now, and SWIFT STRIKE is the lunge a board
-- makes, so it was a third way to do one thing.
--
-- SPLIT and TEE forked a flow in two. A board has one way out, so what a fork
-- made was walked round to it, and a ring with a TEE in it sent an attack out
-- on every lap. A trigger does that job: its branch goes round the ring and
-- each lap is one more follow-up. With no fork, a cast is one attack.
--
-- REVERSE turned a bolt round to come back at the caster a moment after it
-- left, and did nothing to any other form.
INSERT INTO retired_parts (id) VALUES ('WIRE'), ('BEND'), ('INPUT'), ('OUTPUT'), ('DASH'),
	('SPLIT'), ('TEE'), ('REVERSE');

-- DASHSLASH_AUTO, SWIFT STRIKE+, was SWIFT STRIKE with AUTO-AIM built into it:
-- it lunged at the nearest enemy and through. AUTO-AIM is a part now, and does
-- that for any form, so SWIFT STRIKE+ is SWIFT STRIKE wherever it was — a
-- board, a stash, a drop — and AUTO-AIM is placed beside it. It keeps its own
-- number, since SWIFT STRIKE has one already; a code that says 8 reads as
-- SWIFT STRIKE through the rename (`BoardCode.decode`).
INSERT INTO renamed_parts (old_id, new_id) VALUES ('AREA', 'EXPLODE'), ('DASHSLASH_AUTO', 'DASHSLASH');


-- ---- form: what the attack is ------------------------------------------------
-- A form is only as good as the attack that draws it: feature/attacks/ spawns
-- each by its id, and `Weapons.finalize` weighs it. A weapon's own form is the
-- root of its graph, so every cast off it starts as that form; a form placed
-- after it makes the flow that instead.

INSERT INTO parts (id, name, category, heat, cells, tag, description) VALUES
	('PROJECTILE', 'PROJECTILE', 'form', 0.6, 1, 'ranged', 'Fires a bolt along the aim direction. The standard ranged form.'),
	('SLASH', 'SLASH', 'form', 0.5, 1, 'melee', 'An instant short arc at the aim direction. Fast, but reach is short.'),
	('EXPLODE', 'EXPLODE', 'form', 1.2, 2, 'area', 'Damages everything inside a burst radius. Uses two board cells.'),
	('DASHSLASH', 'SWIFT STRIKE', 'form', 1.0, 2, 'melee', 'Lunges along the aim direction, cutting everything on the path. Uses two cells.'),
	('ZAP', 'ZAP', 'form', 0.7, 1, 'ranged', 'A beam to where the cursor points, striking the instant it is cast. Stops at the first wall, and at the first enemy unless PIERCE carries it on.');

INSERT INTO ports (part_id, side) VALUES
	('PROJECTILE', 'E'), ('SLASH', 'E'), ('EXPLODE', 'E'), ('DASHSLASH', 'E'),
	('ZAP', 'E');

INSERT INTO effects (part_id, position, field, op, value) VALUES
	('PROJECTILE', 0, 'form', 'set', 'PROJECTILE'),
	('SLASH', 0, 'form', 'set', 'SLASH'),
	('EXPLODE', 0, 'form', 'set', 'EXPLODE'),
	('DASHSLASH', 0, 'form', 'set', 'DASHSLASH'),
	('ZAP', 0, 'form', 'set', 'ZAP');


-- ---- element ----------------------------------------------------------------

-- WATER is the third, and what it does is change the other two: a wet enemy
-- freezes under ICE and is only dried by FIRE (`Actor.afflict`).
INSERT INTO parts (id, name, category, heat, description) VALUES
	('FIRE', 'FIRE', 'element', 0.4, 'Adds flame. Struck enemies burn for damage over time; a wet one is only dried.'),
	('ICE', 'ICE', 'element', 0.4, 'Adds frost. Struck enemies are slowed; a wet one freezes solid for a moment.'),
	('WATER', 'WATER', 'element', 0.4, 'Soaks what it strikes. A wet enemy freezes solid under ICE, and FIRE only dries it; water puts a burning enemy out.');

INSERT INTO ports (part_id, side) VALUES ('FIRE', 'E'), ('ICE', 'E'), ('WATER', 'E');

INSERT INTO effects (part_id, position, field, op, value) VALUES
	('FIRE', 0, 'elements', 'include', 'FIRE'),
	('ICE', 0, 'elements', 'include', 'ICE'),
	('WATER', 0, 'elements', 'include', 'WATER');


-- ---- stat ---------------------------------------------------------------------

-- `stack_limit` is how many of a part one flow can stack; a part without one
-- stacks for as long as the board has room. SIZE stops at three, which is an
-- attack four times the size. SPEED stops at four, and the fourth is the one
-- that matters: a bolt whose SPEED is at its limit flies at laser speed
-- (`Projectile.LASER_SPEED`). RANGE stops at three, which carries the gun's
-- bolt further than a room is wide — the most range there is to have.
INSERT INTO parts (id, name, category, heat, stack_limit, description) VALUES
	('DAMAGE', 'DAMAGE +', 'stat', 0.3, NULL, 'Raises damage, and each one stacked raises it by more than the last. Stable and simple, but interacts with little else.'),
	('SIZE', 'SIZE x', 'stat', 0.4, 3, 'Scales the attack by 1.6. Melee arcs widen and reach further. Stacks up to 3.'),
	('SPEED', 'SPEED x', 'stat', 0.35, 4, 'Bolts leave 1.5x faster. They also carry further before they fade, and are harder to dodge. A beam reaches a little further too. Does nothing to a flow with neither. Stacks up to 4, and at 4 a bolt flies at laser speed.'),
	('RANGE', 'RANGE x', 'stat', 0.35, 3, 'Bolts carry 1.75x as far before they fade, and a beam reaches 1.75x as far. Does nothing to a flow with neither. Stacks up to 3, which is the most range there is.'),
	('SHATTER', 'SHATTER', 'stat', 0.45, NULL, 'Breaks the frost on an enemy slowed by it: the hit lands far harder, and the enemy thaws. Each one stacked breaks harder still. Worth nothing on its own — pair it with ICE, or with a board that lands twice.');

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
--
-- DAMAGE grows with the stack (`per_stack`): one adds 8, as it always has, and
-- every one after it adds 4 more than the one before — 8, 12, 16 — so three are
-- worth 36 where three used to be worth 24. It grows by adding, not by
-- multiplying, on purpose: a charged ring walks a flow through the same part
-- lap after lap, and a multiply there doubles every few laps.
INSERT INTO effects (part_id, position, field, op, value, per_stack) VALUES
	('DAMAGE', 0, 'damage', 'add', 8, 4);

INSERT INTO effects (part_id, position, field, op, value) VALUES
	('SIZE', 0, 'size', 'multiply', 1.6),
	('SPEED', 0, 'speed', 'multiply', 1.5),
	('SPEED', 1, 'range_px', 'multiply', 1.2),
	('RANGE', 0, 'range_px', 'multiply', 1.75),
	('SHATTER', 0, 'shatter', 'add', 1);


-- ---- behavior -------------------------------------------------------------------

-- Every one of these stacks: each is a count on the payload, and what reads it
-- (feature/attacks/) does more for a higher one. BLINK is the exception — one
-- teleport is all a cast has in it — so its limit is 1.
INSERT INTO parts (id, name, category, heat, tag, stack_limit, description) VALUES
	('PIERCE', 'PIERCE', 'behavior', 0.5, NULL, NULL, 'The attack passes through one enemy and carries on to the next. Each one stacked is one more enemy it passes through.'),
	('BLINK', 'BLINK', 'behavior', 0.7, 'mobility', 1, 'Teleports behind the nearest visible enemy. Works alone; if nothing is in sight the flow simply continues. A cast blinks once: more than one does nothing more.'),
	('HOMING', 'HOMING', 'behavior', 0.6, NULL, NULL, 'Tracks the nearest enemy. Bolts curve and find their way round walls; melee forms re-aim themselves. Each one stacked turns a bolt tighter, so it holds a winding path it would otherwise fly wide of.'),
	('GRAVITY', 'GRAVITY', 'behavior', 0.7, NULL, NULL, 'The enemy struck is not knocked back but pinned, and every other enemy nearby is dragged onto it. Gathers a room into one place for whatever comes next. Each one stacked drags harder.'),
	('KNOCKBACK', 'KNOCKBACK', 'behavior', 0.5, NULL, NULL, 'Hits throw the enemy back the way the attack was going. Buys room, but can put it out of reach. Each one stacked throws harder.'),
	('MANA_DRAIN', 'MANA DRAIN', 'behavior', 0.5, NULL, NULL, 'Every enemy this attack connects with gives mana back to the caster. What pays for the next charge is landing hits, not waiting. Each one stacked drains more.'),
	('HEALTH_DRAIN', 'HEALTH DRAIN', 'behavior', 0.6, NULL, NULL, 'Every enemy this attack hurts gives health back to the caster: a fifth of the damage dealt, and a fifth more for each one stacked. What keeps you standing is landing hits.'),
	('STUN', 'STUN', 'behavior', 0.6, NULL, NULL, 'Struck enemies are stunned: for a moment they stand where they are and cannot attack. Each one stacked holds them longer. Once it wears off, an enemy shrugs off the next stun for a while.'),
	('POSSESS', 'POSSESS', 'behavior', 0.9, NULL, NULL, 'Takes over the monster struck for 5 seconds, unharmed, longer for each one stacked. Your keys move it; it fights with its own attack, or your weapon once it takes it from your body, left behind and still hunted. Bosses resist it.'),
	('AUTO_AIM', 'AUTO-AIM', 'behavior', 0.4, NULL, NULL, 'Aims the attack at the nearest enemy, wherever you point: bolts and beams go straight at it, as far as they reach, a swing turns to it, and SWIFT STRIKE lunges all the way to it and through. Each one stacked looks further for one.');

INSERT INTO ports (part_id, side) VALUES
	('PIERCE', 'E'), ('BLINK', 'E'), ('HOMING', 'E'),
	('GRAVITY', 'E'), ('KNOCKBACK', 'E'), ('MANA_DRAIN', 'E'), ('HEALTH_DRAIN', 'E'),
	('STUN', 'E'), ('POSSESS', 'E'), ('AUTO_AIM', 'E');

INSERT INTO effects (part_id, position, field, op, value) VALUES
	('PIERCE', 0, 'pierce', 'add', 1),
	('BLINK', 0, 'blink', 'set', 'true'),
	('HOMING', 0, 'homing', 'add', 1),
	('GRAVITY', 0, 'pull', 'add', 1),
	('KNOCKBACK', 0, 'knockback', 'add', 1),
	('MANA_DRAIN', 0, 'mana_drain', 'add', 1),
	('HEALTH_DRAIN', 0, 'health_drain', 'add', 1),
	('STUN', 0, 'stun', 'add', 0.8),
	('POSSESS', 0, 'possess', 'add', 5),
	('AUTO_AIM', 0, 'auto_aim', 'add', 1);


-- ---- flow ---------------------------------------------------------------------
-- OVERCLOCK does nothing to a flow: it runs the whole board on a faster clock,
-- which `SkillBoard.analyze` counts off the grid.

INSERT INTO parts (id, name, category, heat, description) VALUES
	('DUPLICATE', 'DUPLICATE x3', 'flow', 3.0, 'Produces the same result three times at full damage. Generates a lot of heat.'),
	('OVERCLOCK', 'OVERCLOCK', 'flow', 0.0, 'Runs the whole board on a faster clock, at the price of a settling delay between cycles. Each one adds less speed than the last while the delay grows faster, so a few pay off and a wall of them does not.'),
	('DELAY', 'DELAY', 'flow', 0.0, 'One cell of waiting and nothing more: it turns a flow and leaves it as it was. Steer a flow round to the way out with it, or walk a trigger''s branch round a ring and back.'),
	('TIME_DILATION', 'TIME DILATION', 'flow', 2.0, 'Slows the world and the board alike. Not a speed buff — a change in the pace of the fight.'),
	('INVERT', 'INVERT', 'flow', 0.4, 'Turns the part right before it inside out: DAMAGE heals what it strikes, FIRE, ICE and STUN cleanse it, GRAVITY pushes away, KNOCKBACK pulls in, and SIZE, SPEED and RANGE shrink. After anything else it does nothing.');

INSERT INTO ports (part_id, side) VALUES
	('DUPLICATE', 'E'), ('OVERCLOCK', 'E'), ('DELAY', 'E'), ('TIME_DILATION', 'E'),
	('INVERT', 'E');

-- INVERT does whatever the part before it has rows of `inversions` for: see
-- the foot of the file.
INSERT INTO effects (part_id, position, field, op, value) VALUES
	('DUPLICATE', 0, 'duplicates', 'multiply', 3),
	('TIME_DILATION', 0, NULL, 'dilate', 1.4),
	('INVERT', 0, NULL, 'invert', NULL);


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


-- ---- inversions: what a part does when an INVERT follows it -------------------
-- The runner puts back every field the part's effects changed, then does these
-- instead (`SkillRunner._invert`). What harms the struck enemy turns to what
-- helps it — DAMAGE's eight to a heal of eight, a burn, a chill or a stun to a
-- cleanse of all three — and what pulls pushes, what pushes pulls, and what
-- makes an attack more makes it less. A part with no rows here has no
-- opposite: an INVERT after a form or a trigger does nothing.
--
-- Each number is its effect's turned round: the heal is DAMAGE's add, and every
-- multiply here is one over the one above (1/1.6, 1/1.5, 1/1.2, 1/1.75).
-- Change one, change the other — tests/circuit/invert_test holds the
-- multiplies to it.
INSERT INTO inversions (part_id, position, field, op, value) VALUES
	('DAMAGE', 0, 'heal', 'add', 8),
	('FIRE', 0, 'cleanse', 'set', 'true'),
	('ICE', 0, 'cleanse', 'set', 'true'),
	('STUN', 0, 'cleanse', 'set', 'true'),
	('GRAVITY', 0, 'repel', 'add', 1),
	('KNOCKBACK', 0, 'hook', 'add', 1),
	('SIZE', 0, 'size', 'multiply', 0.625),
	('SPEED', 0, 'speed', 'multiply', 0.6667),
	('SPEED', 1, 'range_px', 'multiply', 0.8333),
	('RANGE', 0, 'range_px', 'multiply', 0.5714);
