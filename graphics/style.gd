class_name Style
extends RefCounted

## What everything in the game looks like, in one place.
##
## The rules tables next door — `Components`, `Monsters`, `Weapons` — carry
## numbers and behaviour and nothing else. Every colour, glyph and atlas
## character the game draws them with is here, keyed by the id the rules use.
##
## Every lookup falls back rather than failing, so a part or a monster added on
## the feature branch draws with a sane default until the graphics branch gives
## it a look. Nothing here may be read by `feature/`.

## --- components -------------------------------------------------------------
const CAT_COLOR := {
	Components.CAT_STRUCT: Color(0.55, 0.58, 0.66),
	Components.CAT_FORM: Color(0.98, 0.78, 0.26),
	Components.CAT_ELEMENT: Color(0.95, 0.42, 0.32),
	Components.CAT_STAT: Color(0.45, 0.85, 0.62),
	Components.CAT_BEHAVIOR: Color(0.42, 0.72, 0.98),
	Components.CAT_FLOW: Color(0.75, 0.52, 0.95),
	Components.CAT_TRIGGER: Color(0.98, 0.55, 0.78),
}

## Per-part overrides. `glyph` is what the editor and a dropped part draw;
## `color` is only given where a part should not wear its category's colour.
const COMPONENT := {
	"INPUT": {"glyph": "▶"},
	"OUTPUT": {"glyph": "◉"},
	"WIRE": {"glyph": "─"},
	"BEND": {"glyph": "└"},

	"PROJECTILE": {"glyph": "→"},
	"SLASH": {"glyph": "/"},
	"AREA": {"glyph": "◎"},
	"DASHSLASH": {"glyph": "»"},
	"DASHSLASH_AUTO": {"glyph": "»*"},

	"FIRE": {"glyph": "🔥"},
	"ICE": {"glyph": "❄", "color": Color(0.45, 0.8, 0.98)},

	"DAMAGE": {"glyph": "+"},
	"SIZE": {"glyph": "⤢"},
	"SPEED": {"glyph": "⏩"},

	"PIERCE": {"glyph": "⇢"},
	"DASH": {"glyph": "≫"},
	"BLINK": {"glyph": "✦"},
	"HOMING": {"glyph": "◈"},
	"REVERSE": {"glyph": "↺"},

	"SPLIT": {"glyph": "Y"},
	"TEE": {"glyph": "┬"},
	"DUPLICATE": {"glyph": "⋯"},
	"OVERCLOCK": {"glyph": "⚡"},
	"DELAY": {"glyph": "⏳"},
	"TIME_DILATION": {"glyph": "◷"},

	"ON_HIT": {"glyph": "!"},
	"ON_KILL": {"glyph": "☠"},
	"ON_PARRY": {"glyph": "⊓"},
}

const FALLBACK := Color(0.55, 0.58, 0.66)

static func category_color(cat: String) -> Color:
	return CAT_COLOR.get(cat, FALLBACK)

static func component_color(id: String) -> Color:
	var look: Dictionary = COMPONENT.get(id, {})
	if look.has("color"):
		return look["color"]
	return category_color(String(Components.get_def(id).get("cat", Components.CAT_STRUCT)))

static func component_glyph(id: String) -> String:
	return String(COMPONENT.get(id, {}).get("glyph", "?"))

## The flow colour the editor writes its notes in.
static func flow_color() -> Color:
	return category_color(Components.CAT_FLOW)

## --- elements ---------------------------------------------------------------
const NEUTRAL_ATTACK := Color(0.98, 0.85, 0.4)
const ELEMENT_COLOR := {
	"FIRE": Color(1.0, 0.5, 0.22),
	"ICE": Color(0.5, 0.85, 1.0),
}

## What an attack carrying this payload is drawn in. First element wins, so a
## flow's colour tracks the first thing that was added to it.
static func element_color(p: Payload) -> Color:
	if p == null:
		return NEUTRAL_ATTACK
	for e in p.elements:
		if ELEMENT_COLOR.has(e):
			return ELEMENT_COLOR[e]
	return NEUTRAL_ATTACK

## --- weapons ----------------------------------------------------------------
## `art` names the weapon tile in the atlas. Every weapon tile points up.
const WEAPON := {
	"SWORD": {"color": Color(0.85, 0.9, 1.0), "art": "weapon_regular_sword"},
	"GUN": {"color": Color(0.6, 0.95, 0.85), "art": "weapon_bow_2"},
	"ROCK": {"color": Color(0.95, 0.82, 0.55), "art": "weapon_mace"},
}

static func weapon_color(id: String) -> Color:
	return WEAPON.get(id, {}).get("color", Color(0.85, 0.9, 1.0))

static func weapon_art(id: String) -> String:
	return String(WEAPON.get(id, {}).get("art", "weapon_regular_sword"))

## --- the player -------------------------------------------------------------
## Teal plate, which already matches the cyan the player was drawn in.
const PLAYER_ART := "knight_m"
const PLAYER_COLOR := Color(0.65, 0.9, 1.0)

## --- monsters ---------------------------------------------------------------
## `art` names the character in the shared atlas, chosen so the sprite reads as
## the AI: the only winged sprite is the only flyer, the legless caster is the
## turret. `color` is what a death burst throws, so it tracks the sprite's
## palette. `tint` multiplies the sprite when the art has to say something the
## pack does not — the Warden is an ice caster wearing a green ogre.
const MONSTER := {
	"CRAWLER": {"art": "imp", "color": Color(0.95, 0.42, 0.42)},
	"SENTRY": {"art": "necromancer", "color": Color(0.72, 0.32, 0.62)},
	"LOBBER": {"art": "orc_shaman", "color": Color(0.6, 0.8, 0.45)},
	"HOPPER": {"art": "masked_orc", "color": Color(0.82, 0.8, 0.86)},
	"DRIFTER": {"art": "angel", "color": Color(0.5, 0.85, 0.95)},
	"WARDEN": {"art": "ogre", "color": Color(0.45, 0.65, 0.98), "tint": Color(0.66, 0.82, 1.1)},
	"DUMMY": {"art": "skelet", "color": Color(0.6, 0.62, 0.68)},
	"ARBITER": {"art": "big_demon", "color": Color(0.98, 0.35, 0.55)},
}

const MONSTER_FALLBACK := {"art": "imp", "color": Color(0.85, 0.55, 0.55)}

static func monster_art(kind: String) -> String:
	return String(MONSTER.get(kind, MONSTER_FALLBACK)["art"])

static func monster_color(kind: String) -> Color:
	return MONSTER.get(kind, MONSTER_FALLBACK)["color"]

static func monster_tint(kind: String) -> Color:
	return MONSTER.get(kind, {}).get("tint", Color.WHITE)

## The Arbiter's second form recolours the whole silhouette.
const BOSS_PHASE2_TINT := Color(1.35, 0.7, 0.55)
const BOSS_PHASE2_COLOR := Color(1.0, 0.5, 0.3)

## A ring in this colour marks a monster carrying that modifier.
const MODIFIER_COLOR := {
	"swift": Color(0.6, 1.0, 0.8),
	"armored": Color(0.75, 0.75, 0.85),
	"volatile": Color(1.0, 0.6, 0.3),
	"glacial": Color(0.6, 0.9, 1.0),
}

static func modifier_color(id: String) -> Color:
	return MODIFIER_COLOR.get(id, Color(0.85, 0.85, 0.9))

const ELITE_RING := Color(1, 0.9, 0.5, 0.7)
const AGGRO_DOT := Color(1, 0.4, 0.4, 0.9)
const HEALTH_BAR := Color(0.95, 0.35, 0.35)

## --- NPCs -------------------------------------------------------------------
## `art` names the character in the shared atlas, like a monster's — picked from
## the ones no monster wears, so a bystander is never mistaken for a threat.
const NPC := {
	"SAGE": {"art": "wizzard_m"},
}

static func npc_art(id: String) -> String:
	return String(NPC.get(id, NPC["SAGE"])["art"])

## The speech bubble is paper and ink, so it reads as someone talking rather
## than as another panel of the HUD.
const SPEECH_FILL := Color(0.95, 0.94, 0.88)
const SPEECH_EDGE := Color(0.1, 0.12, 0.16)
const SPEECH_TEXT := Color(0.1, 0.11, 0.14)
const SPEECH_NAME := Color(0.42, 0.33, 0.62)
const SPEECH_PROMPT_FILL := Color(0.05, 0.06, 0.08, 0.8)
const SPEECH_PROMPT_TEXT := Color(0.86, 0.9, 0.96)
## Answers not yet picked are faded ink; the highlighted one sits on a wash.
const SPEECH_CHOICE := Color(0.36, 0.37, 0.42)
const SPEECH_CHOICE_FILL := Color(0.42, 0.33, 0.62, 0.16)
const SPEECH_HINT := Color(0.5, 0.5, 0.55)

## --- the world --------------------------------------------------------------
const ROOM_BG := Color(0.075, 0.085, 0.11)
const ROOM_GRID := Color(1, 1, 1, 0.022)
const REGION_TINT := [
	Color(0.18, 0.21, 0.27),
	Color(0.20, 0.26, 0.34),
	Color(0.28, 0.22, 0.32),
	Color(0.32, 0.26, 0.20),
]

static func region_tint(region: int) -> Color:
	return REGION_TINT[clampi(region, 0, REGION_TINT.size() - 1)]

const HAZARD := Color(0.9, 0.35, 0.4)
const DOOR_FILL := Color(0.4, 0.75, 0.95, 0.18)
const DOOR_EDGE := Color(0.45, 0.8, 1.0, 0.75)
const EXIT_OPEN := Color(0.45, 0.95, 0.7)
const EXIT_SEALED := Color(0.85, 0.5, 0.5)

## --- loot -------------------------------------------------------------------
const SCRAP := Color(0.95, 0.85, 0.45)

static func loot_color(component_id: String, scrap: int) -> Color:
	if scrap > 0:
		return SCRAP
	return component_color(component_id)

static func pickup_color(p: Pickup) -> Color:
	return loot_color(p.component_id, p.scrap_amount)

## --- refusals ---------------------------------------------------------------
## A press that does nothing has to say why. The tone says which kind of "no"
## it was: the weapon will not carry this, or the body has nothing left.
const REFUSE_COLOR := {
	"weapon": Color(1.0, 0.55, 0.5),
	"stamina": Color(0.95, 0.7, 0.35),
}

static func refuse_color(kind: String) -> Color:
	return REFUSE_COLOR.get(kind, Color(1.0, 0.6, 0.55))

const PARRY := Color(1, 0.95, 0.6)
const JUMP_DUST := Color(0.7, 0.85, 1.0)
const WALL_DUST := Color(0.6, 0.7, 0.8)
const BLINK_TRAIL := Color(0.6, 0.8, 1.0)
const TRAVEL_DUST := Color(0.5, 0.8, 1.0)
const EXTRACT_SPARK := Color(0.6, 1.0, 0.8)
const BOSS_RING := Color(1, 0.4, 0.4)
const BOSS_TEXT := Color(1, 0.6, 0.6)
