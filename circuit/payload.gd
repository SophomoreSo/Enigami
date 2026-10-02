class_name Payload
extends RefCounted

## The value that travels along a skill flow. Every component mutates it; the
## OUTPUT turns whatever arrives into a real effect in the world.

## How far a bolt carries before it fades, in pixels. A room is 40 cells of 32
## across, so the standard reach is a quarter of one: you fight inside a part of
## the room rather than across the whole of it, and closing the distance is most
## of what a ranged build spends its time doing. Every weapon scales it
## (`Weapons.finalize`), SPEED extends it, and a monster's shot is given the
## reach its own attack range needs (`Enemy._make_runner`).
##
## It is a property of the shot rather than a constant on the bolt because that
## is where the answer differs: a gun outranges a thrown rock, and a Sentry
## outranges both or it could never hit anything from where it sits.
const BASE_RANGE := 320.0

var damage: float = 10.0
var size: float = 1.0
var speed: float = 1.0
var range_px: float = BASE_RANGE
var form: String = ""              ## "", PROJECTILE, SLASH, EXPLODE, DASHSLASH, DASHSLASH_AUTO, ZAP
var elements: Array[String] = []   ## FIRE / ICE
var pierce: int = 0                ## extra targets an attack passes through
var homing: bool = false
var reverse: bool = false
var dash: bool = false             ## lunge along aim before the attack lands
var blink: bool = false            ## teleport behind nearest enemy
## Drags nearby enemies into the impact instead of knocking the struck one back.
## Not to be confused with a thrown weapon's `gravity_shots`, which arcs the
## bolt: that one is a property of the weapon and rides in the spawn context.
var pull: bool = false
var knockback: bool = false        ## the struck enemy is thrown on along the attack
var shatter: bool = false          ## far harder on an enemy frost has slowed
var mana_drain: bool = false       ## every connection pays the caster back
var stun: float = 0.0              ## seconds the struck enemy stands stunned
## What an INVERT makes of the part before it (the `inversions` rows), each
## landing on the struck enemy once the hit has: health given back, every burn,
## chill and stun it was carrying ended — though not what this same hit brings
## it — the enemies round the impact driven off rather than gathered (GRAVITY's
## opposite), the struck one hauled back the way the attack came rather than
## thrown on (KNOCKBACK's).
var heal: float = 0.0
var cleanse: bool = false
var repel: bool = false
var hook: bool = false
var duplicates: int = 1
var heat: float = 0.0              ## accumulated while travelling; feeds cycle cooldown
var branch: String = ""            ## "", "ON_HIT", "ON_KILL", "ON_PARRY"
## Set on an attack spawned as a trigger's follow-up. The chain it belongs to is
## one blow, so its links do not each stop the clock like a blow of their own.
var follow_up: bool = false

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
	p.reverse = reverse
	p.dash = dash
	p.blink = blink
	p.pull = pull
	p.knockback = knockback
	p.shatter = shatter
	p.mana_drain = mana_drain
	p.stun = stun
	p.heal = heal
	p.cleanse = cleanse
	p.repel = repel
	p.hook = hook
	p.duplicates = duplicates
	p.heat = heat
	p.branch = branch
	p.follow_up = follow_up
	p.on_hit = on_hit
	p.on_kill = on_kill
	p.on_parry = on_parry
	return p

func has_element(e: String) -> bool:
	return elements.has(e)

## Does this payload do anything at all when it reaches an OUTPUT?
func is_productive() -> bool:
	return form != "" or dash or blink
