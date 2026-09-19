class_name Payload
extends RefCounted

## The value that travels along a skill flow. Every component mutates it; the
## OUTPUT turns whatever arrives into a real effect in the world.

var damage: float = 10.0
var size: float = 1.0
var speed: float = 1.0
var form: String = ""              ## "", PROJECTILE, SLASH, AREA, DASHSLASH, DASHSLASH_AUTO
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
var shatter: bool = false          ## far harder on an enemy frost has slowed
var mana_drain: bool = false       ## every connection pays the caster back
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
	p.form = form
	p.elements = elements.duplicate()
	p.pierce = pierce
	p.homing = homing
	p.reverse = reverse
	p.dash = dash
	p.blink = blink
	p.pull = pull
	p.shatter = shatter
	p.mana_drain = mana_drain
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

func summary() -> String:
	var parts: Array[String] = []
	parts.append(Components.name_for(form) if form != "" else Loc.t("editor.payload.no_form"))
	parts.append(Loc.t("editor.payload.damage", [damage]))
	if size != 1.0:
		parts.append(Loc.t("editor.payload.size", [size]))
	if duplicates > 1:
		parts.append(Loc.t("editor.payload.duplicates", [duplicates]))
	for e in elements:
		parts.append(Components.name_for(e).to_lower())
	if pierce > 0:
		parts.append(Loc.t("editor.payload.pierce", [pierce]))
	if homing:
		parts.append(Loc.t("editor.payload.homing"))
	if reverse:
		parts.append(Loc.t("editor.payload.reverse"))
	if dash:
		parts.append(Loc.t("editor.payload.dash"))
	if blink:
		parts.append(Loc.t("editor.payload.blink"))
	if pull:
		parts.append(Loc.t("editor.payload.pull"))
	if shatter:
		parts.append(Loc.t("editor.payload.shatter", [Attacks.SHATTER_MUL]))
	if mana_drain:
		parts.append(Loc.t("editor.payload.mana_drain", [Attacks.MANA_PER_HIT]))
	return Loc.t("editor.payload.separator").join(parts)
