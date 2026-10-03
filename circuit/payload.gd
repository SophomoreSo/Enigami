class_name Payload
extends RefCounted

## The value that travels along a skill flow. Every component mutates it, and
## whatever leaves the board by its way out becomes a real effect in the world.

## How far a bolt carries before it fades, in pixels. A room is 40 cells of 32
## across, so the standard reach is an eighth of one — five cells: you fight
## inside a part of the room rather than across the whole of it, and closing the
## distance is most of what a ranged build spends its time doing. Every weapon scales it
## (`Weapons.finalize`), SPEED extends it, and a monster's shot is given the
## reach its own attack range needs (`Enemy._make_runner`).
##
## It is a property of the shot rather than a constant on the bolt because that
## is where the answer differs: a gun outranges a thrown rock, and a Sentry
## outranges both or it could never hit anything from where it sits.
const BASE_RANGE := 160.0

var damage: float = 10.0
var size: float = 1.0
var speed: float = 1.0
var range_px: float = BASE_RANGE
var form: String = ""              ## "", PROJECTILE, SLASH, EXPLODE, DASHSLASH, DASHSLASH_AUTO, ZAP
var elements: Array[String] = []   ## FIRE / ICE
var pierce: int = 0                ## extra targets an attack passes through
## The behaviours below are counts, not flags: 0 is without, and every part of
## the kind the flow passes adds one, so a board that stacks them does the same
## thing harder — a tighter turn, a stronger drag, a longer throw.
var homing: int = 0                ## tracks the nearest enemy, and finds its way round walls
var blink: bool = false            ## teleport behind nearest enemy
## Drags nearby enemies into the impact instead of knocking the struck one back.
## Not to be confused with a thrown weapon's `gravity_shots`, which arcs the
## bolt: that one is a property of the weapon and rides in the spawn context.
var pull: int = 0
var knockback: int = 0             ## the struck enemy is thrown on along the attack
var shatter: int = 0               ## breaks the frost on a slowed enemy, for far more damage
var mana_drain: int = 0            ## every connection pays the caster back
var stun: float = 0.0              ## seconds the struck enemy stands stunned
## Seconds the player's hands go into the monster struck (`Player.possess`).
var possess: float = 0.0
## What an INVERT makes of the part before it (the `inversions` rows), each
## landing on the struck enemy once the hit has: health given back, every burn,
## chill and stun it was carrying ended — though not what this same hit brings
## it — the enemies round the impact driven off rather than gathered (GRAVITY's
## opposite), the struck one hauled back the way the attack came rather than
## thrown on (KNOCKBACK's).
var heal: float = 0.0
var cleanse: bool = false
var repel: int = 0
var hook: int = 0
var duplicates: int = 1
var heat: float = 0.0              ## accumulated while travelling; feeds cycle cooldown
var branch: String = ""            ## "", "ON_HIT", "ON_KILL", "ON_PARRY"
## Set on an attack spawned as a trigger's follow-up. The chain it belongs to is
## one blow, so its links do not each stop the clock like a blow of their own.
var follow_up: bool = false

## How many times each part has done its work on this flow, by id: what a
## part's `stack_limit` is counted against (`SkillRunner._apply`), and how
## anything asks whether a part has been stacked to its limit (`at_limit`).
var stacks: Dictionary = {}

## Trigger payloads resolved from branch flows, attached at fire time.
var on_hit: Payload = null
var on_kill: Payload = null
var on_parry: Payload = null

func clone() -> Payload:
	var p := Payload.new()
	p.damage = damage
	p.size = size
	p.speed = speed
	p.range_px = range_px
	p.form = form
	p.elements = elements.duplicate()
	p.pierce = pierce
	p.homing = homing
	p.blink = blink
	p.pull = pull
	p.knockback = knockback
	p.shatter = shatter
	p.mana_drain = mana_drain
	p.stun = stun
	p.possess = possess
	p.heal = heal
	p.cleanse = cleanse
	p.repel = repel
	p.hook = hook
	p.duplicates = duplicates
	p.heat = heat
	p.branch = branch
	p.follow_up = follow_up
	p.stacks = stacks.duplicate()
	p.on_hit = on_hit
	p.on_kill = on_kill
	p.on_parry = on_parry
	return p

func has_element(e: String) -> bool:
	return elements.has(e)

## How many of part `id` this flow has been through that did their work.
func stack(id: String) -> int:
	return int(stacks.get(id, 0))

## Whether part `id` has a limit and this flow has reached it.
func at_limit(id: String) -> bool:
	var limit := Components.limit_of(id)
	return limit > 0 and stack(id) >= limit

## Does this payload do anything at all when it leaves the board?
func is_productive() -> bool:
	return form != "" or blink
