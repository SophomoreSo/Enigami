class_name Components
extends RefCounted

## Static definition table for every skill-board component.
##
## A component occupies one (or two) grid cells and declares its OUTPUT ports in
## LOCAL space. Rotation `r` turns a local direction `d` into world direction
## `(d + r) % 4`. Direction indices: 0=East 1=South 2=West 3=North.
##
## A part costs one tick per cell it occupies, so `cells` is its tick cost too:
## time on the board is distance on the board, and what a cycle costs can be
## counted off the grid instead of looked up part by part.
##
## Inputs are not declared. A part takes flow on any edge that is not one of its
## own outputs, so the arrows drawn on the board describe its behaviour
## completely: rotation decides where a flow goes, never where it may come from.
## (INPUT is the exception — it is the source, so nothing feeds into it.)

const E := 0
const S := 1
const W := 2
const N := 3

const DIR_VEC := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

# Categories are used for palette grouping and for weapon compatibility tags.
# What each one looks like is `Style.CAT_COLOR`, over in the graphics module.
const CAT_STRUCT := "struct"
const CAT_FORM := "form"
const CAT_ELEMENT := "element"
const CAT_STAT := "stat"
const CAT_BEHAVIOR := "behavior"
const CAT_FLOW := "flow"
const CAT_TRIGGER := "trigger"

## id -> definition. Fields:
##   name, cat, heat, cells (1 or 2), inp (local input dirs),
##   outs (local output dirs),
##   payload_out (local dir of a trigger's secondary branch, -1 if none),
##   acts_on_entry (the part does its work on the way in; see below), desc
##
## Behaviour only. The colour and glyph a part is drawn with are in
## `graphics/style.gd`, keyed by the same id, and a part added here draws in
## its category's colour until someone gives it a glyph of its own.
const DEFS := {
	"INPUT": {
		"name": "INPUT", "cat": CAT_STRUCT, "heat": 0.0, "cells": 1,
		"outs": [E], "payload_out": -1, "source": true,
		"desc": "Flow origin. Starts the next pulse once the previous one has resolved.",
	},
	"OUTPUT": {
		"name": "OUTPUT", "cat": CAT_STRUCT, "heat": 0.0, "cells": 1,
		"outs": [], "payload_out": -1,
		"desc": "Converts the assembled flow into a real effect. A flow with no attack form produces no attack.",
	},
	"WIRE": {
		"name": "WIRE", "cat": CAT_STRUCT, "heat": 0.0, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Carries the flow straight through. Costs one tick.",
	},
	"BEND": {
		"name": "BEND", "cat": CAT_STRUCT, "heat": 0.0, "cells": 1,
		"outs": [S], "payload_out": -1,
		"desc": "Turns the flow ninety degrees. Costs one tick.",
	},

	"PROJECTILE": {
		"name": "PROJECTILE", "cat": CAT_FORM, "heat": 0.6, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Fires a bolt along the aim direction. The standard ranged form.",
	},
	"SLASH": {
		"name": "SLASH", "cat": CAT_FORM, "heat": 0.5, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "An instant short arc at the aim direction. Fast, but reach is short.",
	},
	"AREA": {
		"name": "AREA", "cat": CAT_FORM, "heat": 1.2, "cells": 2,
		"outs": [E], "payload_out": -1,
		"desc": "Damages everything inside a burst radius. Uses two board cells.",
	},
	"DASHSLASH": {
		"name": "DASHSLASH", "cat": CAT_FORM, "heat": 1.0, "cells": 2,
		"outs": [E], "payload_out": -1,
		"desc": "Lunges along the aim direction, cutting everything on the path. Uses two cells.",
	},
	"DASHSLASH_AUTO": {
		"name": "DASHSLASH+", "cat": CAT_FORM, "heat": 1.4, "cells": 2,
		"outs": [E], "payload_out": -1,
		"desc": "Seeks the nearest visible enemy and blinks through it, cutting the path. Uses two cells.",
	},

	"FIRE": {
		"name": "FIRE", "cat": CAT_ELEMENT, "heat": 0.4, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Adds flame. Struck enemies burn for damage over time.",
	},
	"ICE": {
		"name": "ICE", "cat": CAT_ELEMENT, "heat": 0.4, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Adds frost. Struck enemies are slowed.",
	},

	"DAMAGE": {
		"name": "DAMAGE +", "cat": CAT_STAT, "heat": 0.3, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Raises damage. Stable and simple, but interacts with little else.",
	},
	"SIZE": {
		"name": "SIZE x", "cat": CAT_STAT, "heat": 0.4, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Scales the attack by 1.6. Melee arcs widen and reach further.",
	},
	"SPEED": {
		"name": "SPEED x", "cat": CAT_STAT, "heat": 0.35, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Bolts leave 1.5x faster. They also carry further before they fade, and are harder to dodge. Does nothing to a flow with no bolt in it.",
	},

	"SHATTER": {
		"name": "SHATTER", "cat": CAT_STAT, "heat": 0.45, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Hits an enemy already slowed by frost far harder. Worth nothing on its own — pair it with ICE, or with a board that lands twice.",
	},

	"PIERCE": {
		"name": "PIERCE", "cat": CAT_BEHAVIOR, "heat": 0.5, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "The attack continues through targets instead of stopping on the first.",
	},
	"DASH": {
		"name": "DASH", "cat": CAT_BEHAVIOR, "heat": 0.5, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Lunges a short distance along the aim. Chains with melee forms into a moving arc.",
	},
	"BLINK": {
		"name": "BLINK", "cat": CAT_BEHAVIOR, "heat": 0.7, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Teleports behind the nearest visible enemy. Works alone; if nothing is in sight the flow simply continues.",
	},
	"HOMING": {
		"name": "HOMING", "cat": CAT_BEHAVIOR, "heat": 0.6, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Tracks the nearest enemy. Bolts curve; melee forms re-aim themselves.",
	},
	"REVERSE": {
		"name": "REVERSE", "cat": CAT_BEHAVIOR, "heat": 0.4, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Flips travel direction. Bolts return to you; other forms invert in their own way.",
	},

	"GRAVITY": {
		"name": "GRAVITY", "cat": CAT_BEHAVIOR, "heat": 0.7, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "The enemy struck is not knocked back but pinned, and every other enemy nearby is dragged onto it. Gathers a room into one place for whatever comes next.",
	},
	"MANA_DRAIN": {
		"name": "MANA DRAIN", "cat": CAT_BEHAVIOR, "heat": 0.5, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Every enemy this attack connects with gives mana back to the caster. What pays for the next charge is landing hits, not waiting.",
	},

	"SPLIT": {
		"name": "SPLIT", "cat": CAT_FLOW, "heat": 0.4, "cells": 1,
		"outs": [N, S], "payload_out": -1,
		"desc": "Divides one flow into two. Each branch carries half the damage.",
	},
	"TEE": {
		"name": "TEE", "cat": CAT_FLOW, "heat": 0.5, "cells": 1,
		"outs": [E, S], "payload_out": -1,
		"desc": "Keeps the main flow and grows one branch sideways. Both carry full damage.",
	},
	"DUPLICATE": {
		"name": "DUPLICATE x3", "cat": CAT_FLOW, "heat": 3.0, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Produces the same result three times at full damage. Generates a lot of heat.",
	},
	"OVERCLOCK": {
		"name": "OVERCLOCK", "cat": CAT_FLOW, "heat": 0.0, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "Runs the whole board on a faster clock, at the price of a settling delay between cycles. Each one adds less speed than the last while the delay grows faster, so a few pay off and a wall of them does not.",
	},
	"DELAY": {
		"name": "DELAY", "cat": CAT_FLOW, "heat": 0.0, "cells": 1,
		"outs": [E], "payload_out": -1,
		"desc": "One cell of waiting, like every other cell. Stagger a branch against another by giving it further to walk.",
	},
	"TIME_DILATION": {
		"name": "TIME DILATION", "cat": CAT_FLOW, "heat": 2.0, "cells": 1,
		"outs": [E], "payload_out": -1, "acts_on_entry": true,
		"desc": "Slows the world and the board alike. Not a speed buff — a change in the pace of the fight.",
	},

	"ON_HIT": {
		"name": "ON HIT", "cat": CAT_TRIGGER, "heat": 0.6, "cells": 1,
		"outs": [E], "payload_out": S,
		"desc": "Runs the branch flow as a payload when this skill connects.",
	},
	"ON_KILL": {
		"name": "ON KILL", "cat": CAT_TRIGGER, "heat": 0.6, "cells": 1,
		"outs": [E], "payload_out": S,
		"desc": "Runs the branch flow as a payload only when this skill kills.",
	},
	"ON_PARRY": {
		"name": "ON PARRY", "cat": CAT_TRIGGER, "heat": 0.8, "cells": 1,
		"outs": [E], "payload_out": S, "acts_on_entry": true,
		"desc": "Opens a brief guard window as the flow passes. Absorbing a hit there runs the branch flow.",
	},
}

## Parts that are structural: always available, never consumed as loot.
const STRUCTURAL := ["INPUT", "OUTPUT", "WIRE", "BEND"]

## Loot-able components, in the order the palette shows them.
const LOOT_POOL := [
	"PROJECTILE", "SLASH", "AREA", "DASHSLASH", "DASHSLASH_AUTO",
	"FIRE", "ICE", "DAMAGE", "SIZE", "SPEED", "SHATTER",
	"PIERCE", "DASH", "BLINK", "HOMING", "REVERSE", "GRAVITY", "MANA_DRAIN",
	"SPLIT", "TEE", "DUPLICATE", "OVERCLOCK", "DELAY", "TIME_DILATION",
	"ON_HIT", "ON_KILL", "ON_PARRY",
]

static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})

## What to call a part on screen, and what to say it does, in the language
## being played. The `name` and `desc` in DEFS above are the fallback under
## these: a part added here draws with its English name until somebody writes
## one for it, rather than drawing as its key or not at all.
static func name_for(id: String) -> String:
	return Loc.opt("parts.%s.name" % id, String(get_def(id).get("name", id)))

static func desc_for(id: String) -> String:
	return Loc.opt("parts.%s.desc" % id, String(get_def(id).get("desc", "")))

## A board's tags — `ranged`, `melee`, `trigger` — spelled for a reader. The tag
## itself stays the id the compatibility rules match on; only the label moves.
static func tag_name(tag: String) -> String:
	return Loc.opt("parts.tag.%s" % tag, tag)

## The same list, joined the way the language joins a list.
static func tag_names(tags: Array) -> String:
	var out: Array[String] = []
	for t in tags:
		out.append(tag_name(String(t)))
	return Loc.t("editor.payload.separator").join(out)

static func exists(id: String) -> bool:
	return DEFS.has(id)

static func is_structural(id: String) -> bool:
	return STRUCTURAL.has(id)

## Whether a part does its work the moment a flow enters it, rather than by
## carrying that flow on to an OUTPUT. `SkillRunner._apply` is where those two
## effects happen; the flag is declared beside the part so that a board can tell
## a loop still doing something every lap from one that only swallows the flow —
## see `SkillBoard.dead_loops`.
static func acts_on_entry(id: String) -> bool:
	return bool(get_def(id).get("acts_on_entry", false))

## Ticks a flow spends inside a component: one for every cell it covers. Read
## from the footprint rather than stored beside it, so the two cannot drift.
static func tick_cost(id: String) -> int:
	return maxi(1, int(get_def(id).get("cells", 1)))

static func rotate_dir(local_dir: int, rot: int) -> int:
	return (local_dir + rot) % 4

## The opposite direction, used when checking whether two ports face each other.
static func opposite(dir: int) -> int:
	return (dir + 2) % 4

static func dir_to_vec(dir: int) -> Vector2i:
	return DIR_VEC[dir % 4]

## World-space edges a placed component will accept flow on: everything except
## the edges it sends flow out of. Two outputs meeting head-on is the only join
## that cannot carry a flow.
static func world_inputs(id: String, rot: int) -> Array:
	var out: Array = []
	if bool(get_def(id).get("source", false)):
		return out
	var blocked := world_outputs(id, rot)
	var payload := world_payload_out(id, rot)
	for d in 4:
		if blocked.has(d) or d == payload:
			continue
		out.append(d)
	return out

## World-space main output directions of a placed component.
static func world_outputs(id: String, rot: int) -> Array:
	var out: Array = []
	for d in get_def(id).get("outs", []):
		out.append(rotate_dir(d, rot))
	return out

## World-space payload branch direction, or -1 when the component has none.
static func world_payload_out(id: String, rot: int) -> int:
	var p: int = get_def(id).get("payload_out", -1)
	if p < 0:
		return -1
	return rotate_dir(p, rot)

## Cells a component covers when placed at `origin` with `rot`.
## Two-cell components extend along their local +X axis.
static func footprint(id: String, origin: Vector2i, rot: int) -> Array:
	var cells: Array = [origin]
	if get_def(id).get("cells", 1) == 2:
		cells.append(origin + dir_to_vec(rotate_dir(E, rot)))
	return cells

## The cell a component emits from (the far cell for two-cell parts).
static func exit_cell(id: String, origin: Vector2i, rot: int) -> Vector2i:
	if get_def(id).get("cells", 1) == 2:
		return origin + dir_to_vec(rotate_dir(E, rot))
	return origin

const DIR_NAME := ["east", "south", "west", "north"]

static func dir_name(dir: int) -> String:
	return Loc.opt("parts.direction.%s" % DIR_NAME[dir % 4], DIR_NAME[dir % 4])
