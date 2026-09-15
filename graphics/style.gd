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

## What each category is called where the editor groups the palette by it. The
## ids are the rules' own; the wording on screen is ours.
const CAT_NAME := {
	Components.CAT_STRUCT: "STRUCTURE",
	Components.CAT_FORM: "FORM",
	Components.CAT_ELEMENT: "ELEMENT",
	Components.CAT_STAT: "STAT",
	Components.CAT_BEHAVIOR: "BEHAVIOR",
	Components.CAT_FLOW: "FLOW",
	Components.CAT_TRIGGER: "TRIGGER",
}

## Per-part overrides. `glyph` is what a dropped part draws (the editor draws
## the part's `COMPONENT_ICON`); `color` is only given where a part should not
## wear its category's colour.
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

## A category added on the feature branch reads as its own id until it is named
## here, like every other lookup in this file.
static func category_name(cat: String) -> String:
	return String(CAT_NAME.get(cat, cat.to_upper()))

static func component_color(id: String) -> Color:
	var look: Dictionary = COMPONENT.get(id, {})
	if look.has("color"):
		return look["color"]
	return category_color(String(Components.get_def(id).get("cat", Components.CAT_STRUCT)))

static func component_glyph(id: String) -> String:
	return String(COMPONENT.get(id, {}).get("glyph", "?"))

## Every part again, as a picture seven pixels square, for the pixel look: the
## pixel face has almost none of the symbols `glyph` uses. One string per row,
## `#` for a pixel, drawn a `UiKit.PIXEL` block each. A part without one draws
## ICON_FALLBACK.
const COMPONENT_ICON := {
	"INPUT": [
		"..#....",
		"..##...",
		"..###..",
		"..####.",
		"..###..",
		"..##...",
		"..#....",
	],
	"OUTPUT": [
		"..###..",
		".#...#.",
		"#.....#",
		"#..#..#",
		"#.....#",
		".#...#.",
		"..###..",
	],
	"WIRE": [
		".......",
		".......",
		".......",
		"#######",
		".......",
		".......",
		".......",
	],
	"BEND": [
		"...#...",
		"...#...",
		"...#...",
		"...####",
		".......",
		".......",
		".......",
	],

	"PROJECTILE": [
		".......",
		"....#..",
		".....#.",
		"#######",
		".....#.",
		"....#..",
		".......",
	],
	"SLASH": [
		"......#",
		".....#.",
		"....#..",
		"...#...",
		"..#....",
		".#.....",
		"#......",
	],
	"AREA": [
		"..###..",
		".#...#.",
		"#.###.#",
		"#.#.#.#",
		"#.###.#",
		".#...#.",
		"..###..",
	],
	"DASHSLASH": [
		".......",
		"#..#...",
		".#..#..",
		"..#..#.",
		".#..#..",
		"#..#...",
		".......",
	],
	"DASHSLASH_AUTO": [
		".....#.",
		"....###",
		"#.#..#.",
		".#.#...",
		"..#.#..",
		".#.#...",
		"#.#....",
	],

	"FIRE": [
		"...#...",
		"..##...",
		"..###.#",
		".#####.",
		"##.####",
		"#...##.",
		".####..",
	],
	"ICE": [
		"...#...",
		".#.#.#.",
		"..###..",
		"#######",
		"..###..",
		".#.#.#.",
		"...#...",
	],

	"DAMAGE": [
		".......",
		"...#...",
		"...#...",
		".#####.",
		"...#...",
		"...#...",
		".......",
	],
	"SIZE": [
		"....###",
		".....##",
		"....#.#",
		"...#...",
		"#.#....",
		"##.....",
		"###....",
	],
	"SPEED": [
		".......",
		"#...#..",
		"##..##.",
		"###.###",
		"##..##.",
		"#...#..",
		".......",
	],

	"PIERCE": [
		"..#....",
		"..#.#..",
		"..#..#.",
		"#######",
		"..#..#.",
		"..#.#..",
		"..#....",
	],
	"DASH": [
		".......",
		"##.##..",
		".##.##.",
		"..##.##",
		".##.##.",
		"##.##..",
		".......",
	],
	"BLINK": [
		"...#...",
		"...#...",
		"..###..",
		"#######",
		"..###..",
		"...#...",
		"...#...",
	],
	"HOMING": [
		"...#...",
		"..#.#..",
		".#.#.#.",
		"#.###.#",
		".#.#.#.",
		"..#.#..",
		"...#...",
	],
	"REVERSE": [
		"#####..",
		".....#.",
		"......#",
		"......#",
		".#...#.",
		"#####..",
		".#.....",
	],

	"SPLIT": [
		"#.....#",
		".#...#.",
		"..#.#..",
		"...#...",
		"...#...",
		"...#...",
		"...#...",
	],
	"TEE": [
		".......",
		".......",
		".......",
		"#######",
		"...#...",
		"...#...",
		"...#...",
	],
	"DUPLICATE": [
		".......",
		".......",
		".......",
		"#..#..#",
		".......",
		".......",
		".......",
	],
	"OVERCLOCK": [
		"....##.",
		"...##..",
		"..##...",
		".#####.",
		"...##..",
		"..##...",
		".##....",
	],
	"DELAY": [
		"#######",
		".#...#.",
		"..#.#..",
		"...#...",
		"..#.#..",
		".#.#.#.",
		"#######",
	],
	"TIME_DILATION": [
		"..###..",
		".#.#.#.",
		"#..#..#",
		"#..##.#",
		"#.....#",
		".#...#.",
		"..###..",
	],

	"ON_HIT": [
		"...#...",
		"...#...",
		"...#...",
		"...#...",
		"...#...",
		".......",
		"...#...",
	],
	"ON_KILL": [
		".#####.",
		"#######",
		"#..#..#",
		"#######",
		".##.##.",
		".#####.",
		".#.#.#.",
	],
	"ON_PARRY": [
		"#######",
		"#.....#",
		"#.....#",
		"#.....#",
		".#...#.",
		"..#.#..",
		"...#...",
	],
}

const ICON_FALLBACK := [
	"..###..",
	".#...#.",
	".....#.",
	"....#..",
	"...#...",
	".......",
	"...#...",
]

static func component_icon(id: String) -> Array:
	return COMPONENT_ICON.get(id, ICON_FALLBACK)

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
## A character's sprite is named in their dialogue file (`sprite`). This is for a
## file that names none, or names one the atlas does not have — picked from the
## characters no monster wears, so a bystander is never mistaken for a threat.
const NPC_FALLBACK_ART := "wizzard_m"

static func npc_art(sprite: String) -> String:
	return sprite if has_character(sprite) else NPC_FALLBACK_ART

## The portrait for a line: the character's own art, unless the atlas holds a
## version of them for the line's emotion (`<art>_<emotion>_idle_anim_f0`, say
## `wizzard_m_angry`) — so giving a character a face per mood is adding tiles to
## the atlas, not code.
static func portrait_art(art: String, emotion_id: String) -> String:
	var mood := "%s_%s" % [art, emotion_id]
	return mood if emotion_id != "" and has_character(mood) else art

static func has_character(base: String) -> bool:
	return base != "" and (Sprites.has_tile("%s_idle_anim_f0" % base) or Sprites.has_tile("%s_anim_f0" % base))

## The talk prompt over an NPC's head.
const SPEECH_PROMPT_FILL := Color(0.05, 0.06, 0.08, 0.8)
const SPEECH_PROMPT_TEXT := Color(0.86, 0.9, 0.96)
## The dialogue box, after Celeste: near-black with a pale edge, so it reads as a
## voice over the scene rather than as another of the HUD's blue-grey panels.
const DIALOGUE_FILL := Color(0.03, 0.03, 0.05, 0.94)
const DIALOGUE_EDGE := Color(0.92, 0.9, 0.84)
const DIALOGUE_TEXT := Color(0.96, 0.95, 0.92)
## The name is dark on a pale tab, the box's edge colour.
const DIALOGUE_TAB := Color(0.92, 0.9, 0.84)
const DIALOGUE_NAME := Color(0.08, 0.07, 0.12)
const DIALOGUE_PORTRAIT_BG := Color(0.13, 0.11, 0.2)
## Answers not yet picked are dimmed; the marker and the arrow share one accent.
const DIALOGUE_CHOICE := Color(0.55, 0.55, 0.6)
const DIALOGUE_MARK := Color(0.72, 0.6, 0.98)
const DIALOGUE_HINT := Color(0.5, 0.5, 0.56)

## How each `emotion` a dialogue line names shows, on the portrait and in the
## letters. An emotion missing here is neutral, so a writer's typo is a calm face
## rather than an error.
##   tint    the portrait's colour
##   hop     art pixels the portrait hops while the line types (default 1)
##   shake   screen pixels the portrait trembles
##   jitter  screen pixels each letter trembles
##   wave    screen pixels the letters ripple
##   mark    the sign by the face, one of EMOTE_COLORS' keys
const EMOTIONS := {
	"neutral": {},
	"happy": {"hop": 2.0, "wave": 1.5, "mark": "sparkle"},
	"sad": {"tint": Color(0.7, 0.78, 1.0), "hop": 0.0, "mark": "drop"},
	"angry": {"tint": Color(1.0, 0.68, 0.62), "shake": 2.0, "jitter": 1.2, "mark": "vein"},
	"surprised": {"hop": 3.0, "mark": "exclaim"},
	"thinking": {"hop": 0.0, "mark": "dots"},
	"scared": {"tint": Color(0.82, 0.84, 1.0), "shake": 1.0, "jitter": 0.8, "mark": "sweat"},
}
const EMOTE_COLORS := {
	"sparkle": Color(1.0, 0.88, 0.45),
	"drop": Color(0.55, 0.75, 1.0),
	"vein": Color(1.0, 0.35, 0.35),
	"exclaim": Color(1.0, 0.95, 0.6),
	"dots": Color(0.92, 0.9, 0.84),
	"sweat": Color(0.7, 0.88, 1.0),
}

static func emotion(id: String) -> Dictionary:
	return EMOTIONS.get(id, EMOTIONS["neutral"])

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
