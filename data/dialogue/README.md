# Dialogue files

One file per character, named after their id in lower case: the NPC set up as
`SAGE` reads `sage.json`. Edit these to change what anyone says, how they look
saying it, where the camera goes and what it sounds like — no code involved.

`tests/story/npc_test.tscn` checks every file here for broken links, lines with
no text and a file name that does not match its id. Run it after an edit.

## The file

```json
{
	"id": "SAGE",
	"name": "Old Tinker",
	"sprite": "wizzard_m",
	"player_name": "Knight",
	"start": "hello",
	"defaults": {"speaker": "npc", "emotion": "neutral", "voice": "low", "speed": 45},
	"nodes": {
		"hello": {"text": "Ah, a new face.", "emotion": "happy", "next": "ask"},
		"ask": {"text": "What would you like to know?", "choices": [
			{"text": "Who are you?", "next": "who"},
			{"text": "Nothing. Bye.", "next": ""}
		]}
	}
}
```

| Key | Meaning |
|---|---|
| `id` | The character's id. Must match the file name. |
| `name` | The name on the tab when they speak. |
| `sprite` | Their character in the sprite atlas — in the world and on the portrait. |
| `player_name` | The name on the tab when the player speaks. Default `You`. |
| `start` | The line a conversation opens on. |
| `defaults` | Keys every line gets unless it sets them itself. Any line key can go here. |
| `nodes` | The lines, by name. |

## A line

| Key | Values | Meaning |
|---|---|---|
| `text` | string | What is said. Required. |
| `next` | line name, or `""` | The line a press moves on to. Empty or missing ends the conversation. |
| `choices` | list of `{"text", "next"}` | Makes the line a question: the answers, and where each leads. |
| `speaker` | `npc` · `player` | Who says it. The NPC's portrait sits on the left, the player's on the right. |
| `name` | string | Overrides the name on the tab for this line. |
| `speed` | letters per second | How fast it types. Default 45. |
| `emotion` | see below | How the portrait and the letters behave. |
| `sprite` | atlas character | Swaps the portrait for this line, e.g. `"knight_f"`. |
| `camera` | object, or `"reset"` | Where the camera goes, see below. |
| `sfx` | sound id | Played once as the line starts. |
| `voice` | `low` · `mid` · `high` · `none` | The blip that plays along with the typing. |

### Emotions

| `emotion` | Portrait | Letters |
|---|---|---|
| `neutral` | hops while talking | still |
| `happy` | bigger hop, sparkles | gentle ripple |
| `sad` | cooled, still, a falling tear | still |
| `angry` | reddened, trembling, a vein | tremble |
| `surprised` | a big hop, an `!` | still |
| `thinking` | still, `...` | still |
| `scared` | pale, trembling, sweat | small tremble |

An unknown emotion reads as `neutral`. The treatments live in
`graphics/style.gd` (`EMOTIONS`).

A character can also have a face per emotion: if the atlas holds
`<sprite>_<emotion>_idle_anim_f0` — say `wizzard_m_angry_idle_anim_f0` — that line's
portrait uses it instead of the plain sprite.

### Camera

```json
"camera": {"focus": "npc", "zoom": 1.5, "shake": 6, "time": 0.4}
```

| Key | Values | Meaning |
|---|---|---|
| `focus` | `npc` · `player` · `both` | What to centre on. Default `both`. |
| `zoom` | 1 or more | How far in, against the screen's own zoom. Default 1. |
| `shake` | pixels | A shake as the line starts. On its own it leaves the camera where it is. |
| `time` | seconds | How long the move takes. 0 cuts. Default 0.4. |

A line without `camera` leaves the camera where the last line put it. `"reset"`
eases it back to the screen's own framing, and so does the conversation ending.
The camera never shows past the edges the screen itself frames.

### Sounds

Every sound is synthesised, so `sfx` names one from the bank in
`app/audio/audio.gd`: `shoot` `slash` `hit` `explode` `jump` `dash` `hurt` `death`
`pickup` `place` `erase` `ui` `deny` `extract` `parry` `boss` `voice`. An unknown
id plays nothing and warns in the output.

## Exporting

These are plain files, not resources: an export preset needs `data/dialogue/*.json`
in its non-resource include filter, or the conversations will be missing from the
build.
