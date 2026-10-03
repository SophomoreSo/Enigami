class_name InputState
extends RefCounted

## One frame of what a body is asked to do, as it comes out of an
## `InputProvider`'s line: what the hands said, and whatever every system
## standing between them and the body made of it.
##
## Two kinds of thing are in it. What **lasts** — which way to walk and how
## hard, whether a button is held, where to aim — matters for its value, every
## frame. What **happens** — a jump pressed, a cast let go of — matters for the
## instant it happens: an act. Any middleware may raise an act, the hands
## included, and any may shut the gate an act has to pass, which is the
## devlog's `canJump`. A gate shut anywhere on the line drops the act at the
## end of it, whoever raised it and wherever they stand — so something further
## down may press jump for the body, and a conversation further up still keeps
## it on the ground.
##
## The acts ride on the state rather than going out as signals, which is how
## the devlog sends them, because the player reads each one at the instant of
## its frame it always has: a jump in the physics frame the body moves in, a
## cast's release in the drawn frame, before the charge starts to bleed. A
## signal would go off wherever its sender happened to be.

## --- what lasts ---------------------------------------------------------------
## Which way to walk, -1 left to 1 right, and how hard: a stick half over is half.
var move: float = 0.0
## Which way to turn without walking: -1, 1, or 0 to leave the facing alone.
var turn: int = 0
## Crouching, for as long as it is asked: down held — a key, or a stick pushed
## down past its threshold.
var crouch: bool = false
## Sprinting, for as long as it is asked: whatever way the body walks, it goes
## that way faster (`Player.SPRINT_SPEED`). A key, or the console's stick
## dragged far out of its ring.
var sprint: bool = false
## The attack button, held: the graph cast as it is, again and again.
var attack: bool = false
## The cast button, held: what charges.
var cast: bool = false
## Whether the hand is aiming at all this frame. When it is not, the weapon
## stays where it was last pointed.
var aiming: bool = false
## Which way, as a unit vector — or zero, when the pointer is on the body itself
## and says no way at all.
var aim: Vector2 = Vector2.ZERO
## Whether that is a stick's: a way rather than a place pointed at, and so
## something aim assist may bend (`AimAssist`).
var aim_by_stick: bool = false
## Where, in the world.
var aim_point: Vector2 = Vector2.ZERO
## How far an attack should go, 0 to 1 (`Player.aim_reach`).
var aim_reach: float = 1.0

## --- what happens -------------------------------------------------------------
var jump_pressed: bool = false
## Let go of early, it cuts the arc short.
var jump_released: bool = false
var dash_pressed: bool = false
## What casts a charged graph.
var cast_released: bool = false
## A weapon asked for by its slot, 0 for the first carried, or -1 for none: the
## key of the slot it is in.
var weapon_slot: int = -1
## A weapon asked for by its place next to the one in hand: 1 for the next, -1
## for the one before, 0 for neither. A wheel, a button, the console's key.
var weapon_step: int = 0

## --- what may happen ----------------------------------------------------------
## A jump, pressed or let go of.
var can_jump: bool = true
var can_dash: bool = true
## The release that casts.
var can_cast: bool = true
## Putting another weapon in hand, by its slot or by a step.
var can_switch: bool = true

## Drops every act whose gate is shut. The provider calls it once the whole line
## has had its say.
func apply_gates() -> void:
	if not can_jump:
		jump_pressed = false
		jump_released = false
	if not can_dash:
		dash_pressed = false
	if not can_cast:
		cast_released = false
	if not can_switch:
		weapon_slot = -1
		weapon_step = 0
