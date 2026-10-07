# Stories

Conversations written in the story maker (title → **STORY MAKER**), one file
each: `first_meeting.json` is the story `first_meeting`. SAVE writes them here
when the game is run from the project — the editor, or `godot --path` — and
what is here is committed and ships with the game. An exported game cannot
write into itself: it keeps the stories written on that machine under
`user://stories/`, and reads these as the ones it came with. `Stories`
(`story/rules/stories.gd`) is what knows where.

`first_meeting` is the Old Tinker met in the Moonlit Grove, to play and to
start from.

## The file

```json
{
	"map": "moonlit_grove",
	"mode": "frozen",
	"name": "Old Tinker",
	"sprite": "wizzard_m",
	"player_name": "Knight",
	"spot": [12, 19],
	"lines": [
		{"speaker": "npc", "text": "So the seal let somebody through after all."},
		{"speaker": "player", "text": "Through? I walked in the front."},
		"Mind the lanterns; they swing."
	]
}
```

| Key | Meaning |
|---|---|
| `map` | The map it is set on, by id — one made in the map creator (`data/maps/`). Leave it out, or name one that is not there, and it is played on whichever map there is. |
| `mode` | How it is played: `free`, `frozen` or `novel` — see below. Default `frozen`. |
| `name` | The character's name, on the tab when they speak. |
| `sprite` | What they look like: one from the sprite atlas — `wizzard_m`, `knight_f`, `elf_m`… — or the game's own, `player`. |
| `player_name` | The name on the tab when the player speaks. |
| `spot` | The cell of the map the character stands in, `[x, y]`. Leave it out and they stand along the floor from the player's start. |
| `lines` | The story, said top to bottom. |

A line is who says it — `speaker`, `npc` or `player` — and `text`, what is
said. A bare string is the character's own line. Whatever else a line carries
goes with it as a row of the conversation tables would — an `emotion`, a
`camera`, a `sprite`, a `voice`, an `sfx` — read in the box and free by the
picture and the sound bank the way a line in `data/db/dialogue/` is
(`data/db/README.md`, **A line**). A novel reads a line's `speed` and
`voice`. A line with nothing in it is kept and never said.

## The three ways

| `mode` | What happens |
|---|---|
| `free` | The player goes on playing. The character talks free: a press up close starts the story, and each line comes out in a bubble over whoever says it, moving on by itself once it has been read. |
| `frozen` | The player walks up and presses to talk, is walked the last step over and held still, and the story runs in the box at the top of the screen, a press a line. |
| `novel` | Nobody plays. The two of them stand facing each other on the map, and the story is read like a scene, a press a line, in the panel along the foot of the screen. `Esc` skips it. |

The map is stood up empty whichever way: no monster at its post, no box,
nothing to dig. The story is told the same way in all three — the lines, in
order — so a story written for one reads the same in the others.

`tests/story/story_maker_test.tscn` checks every file here the way the dialogue
files are checked: a way of playing that is none, a line said by nobody, a
line that is not one, nothing to say. Run it after an edit by hand.

## Exporting

These are plain files, not resources: an export preset needs `data/*.json`
in its non-resource include filter — which takes this folder in with the
scenes — or the stories will be missing from the build.
