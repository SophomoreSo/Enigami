class_name StoryMaker
extends World

## The story maker: a conversation written a line at a time — who says it, and
## what — set on a map made in the map creator (`Maps`), and played on the
## spot in one of three ways (`Mode`):
##
##   FREE     the player goes on playing, and the character talks free: each
##            line in a bubble over whoever says it, moving on by itself once
##            it has been read (`FreeTalk`). A press up close starts it, or
##            hurries it along.
##   FROZEN   the player walks up and presses to talk, is walked the last
##            step over and held still, and the conversation runs in the box,
##            a press a line (`Npc`, in the box).
##   NOVEL    nobody plays. The two of them stand facing each other on the
##            map, and the story is read like a scene, a press a line, in the
##            panel along the foot of the screen (`Cutscene`).
##
## Two things happen here, one at a time. A story is **written**: `add_line`
## and its kin change it, and SAVE keeps it as a file (`Stories`). Or it is
## **played**: the map is stood up — empty, with no monster at its post, no
## box and nothing to dig, since a conversation has nobody to fight — and the
## story is set going on it whichever way `mode` says, with a body in it for
## the player where there is one to play. Leaving play goes back to the desk,
## with the story as it was.
##
## A line is `speaker` — `npc` or `player` — and `text`, and carries whatever
## else it was given on to the picture and the sound bank, in the box and
## free, the way a row of the conversation tables does: an `emotion`, a
## `camera`, a `sprite`. A novel takes a line's `speed` and `voice`. What is
## played is the lines with something in them; a line with nothing in it yet
## is kept on the desk and never said.
##
## The story on the desk is kept while the game runs: left for the title and
## come back to, it is as it was left, saved or not.
##
## Nothing here draws. `story/view/story_maker_view.gd` attaches itself to
## this node; the desk the story is written at is `story/view/story_desk.gd`.

signal exit_requested()
## The story went from being written to being played, or back.
signal playing_changed(on: bool)

## The ways a story is played.
enum Mode { FREE, FROZEN, NOVEL }
## Each by the id the file writes it as, in `Mode`'s order.
const MODE_IDS := ["free", "frozen", "novel"]
## Who says a line.
const NPC := "npc"
const PLAYER := "player"
## The id the character goes by while the story is played: what a free line
## said is counted under (`Facts.line`).
const CHARACTER := "STORY"
## The game's own character, as a scene file names it: what the player is
## drawn as in a novel.
const PLAYER_SPRITE := "player"
## What a new story's character is called and looks like, what they call the
## player — the bench's own, to start from — and how it plays.
const NEW_NAME := "Old Tinker"
const NEW_SPRITE := "wizzard_m"
const NEW_PLAYER_NAME := "Knight"
const NEW_MODE := Mode.FROZEN
## How far along the floor from the player's start the character stands, in
## cells, for a story that says nowhere (`spot`): in sight, and out of talking
## range, so a walk over is the first thing that happens.
const APART := 4
## Seconds a novel takes to come up out of black, and how far in its camera
## stands: close enough that the two of them are the picture, as the intro
## is framed, with the floor they stand on just over the panel.
const FADE := 0.6
const NOVEL_ZOOM := 1.5
## What a line says when it does not say: what a line in the database would.
const LINE_SPEED := 45
const LINE_EMOTION := "neutral"
const LINE_VOICE := "low"

## The story on the desk from one visit to the next — see `_exit_tree`.
static var _kept: Dictionary = {}

## The name the story was last saved or opened under, or "" for one that never was.
var story_id: String = ""
## The map it is set on, by id (`Maps`); "" for whichever there is.
var map_id: String = ""
var mode: int = NEW_MODE
var npc_name: String = NEW_NAME
var sprite: String = NEW_SPRITE
var player_name: String = NEW_PLAYER_NAME
## The cell of the map the character stands in, or (-1, -1) for along the
## floor from the player's start.
var spot := Vector2i(-1, -1)
## The lines, in order: each its `speaker` and its `text`, and whatever else
## it was given.
var lines: Array = []
## Whether the story has changed since it was last saved or opened.
var unsaved: bool = false

var playing: bool = false
## The map stood up while the story is played, and who is in it: the player's
## body and the character, FREE or FROZEN; the scene, a NOVEL.
var room: MadeRoom = null
var player: Player = null
var npc: Npc = null
var scene: Cutscene = null
## weapon id -> the graph the body carries: a copy of the profile's, as on the bench.
var graphs: Dictionary = {}

func _ready() -> void:
	Arena.register(self)
	Cues.emit_cue(&"music_start")
	# Copies only: nothing played here reaches the hideout.
	for w in Weapons.ids():
		graphs[w] = GameState.weapon_board(String(w)).duplicate_board()
	if _kept.is_empty():
		new_story()
	else:
		_take(_kept)
		story_id = String(_kept.get("id", ""))
		unsaved = bool(_kept.get("unsaved", false))

## What is on the desk is kept for the next visit, whatever way this one ends.
func _exit_tree() -> void:
	_kept = story()
	_kept["id"] = story_id
	_kept["unsaved"] = unsaved

## Forgets the story kept from the last visit, so the next starts on a new one.
static func forget() -> void:
	_kept = {}

## --- the story --------------------------------------------------------------

## A story nobody has written anything in: no lines, the bench's own character,
## set on whichever map there is, played in the box.
func new_story() -> void:
	story_id = ""
	map_id = ""
	mode = NEW_MODE
	npc_name = NEW_NAME
	sprite = NEW_SPRITE
	player_name = NEW_PLAYER_NAME
	spot = Vector2i(-1, -1)
	lines = []
	unsaved = false

func line_count() -> int:
	return lines.size()

## Line `i` as it stands, or nothing for one there is not.
func line(i: int) -> Dictionary:
	return lines[i] if i >= 0 and i < lines.size() else {}

func text_of(i: int) -> String:
	return String(line(i).get("text", ""))

func speaker_of(i: int) -> String:
	return String(line(i).get("speaker", NPC))

## Puts a line in after line `after` — at the end, left out — and says where it
## went. Whose it is, when `speaker` does not say: the other's from the line
## before it, and the character's for the first, so a conversation written
## straight down goes turn and turn about.
func add_line(text: String = "", speaker: String = "", after: int = -1) -> int:
	var at := lines.size() if after < 0 or after >= lines.size() else after + 1
	if speaker != NPC and speaker != PLAYER:
		speaker = NPC if at == 0 else (PLAYER if speaker_of(at - 1) == NPC else NPC)
	lines.insert(at, {"speaker": speaker, "text": text})
	unsaved = true
	return at

## Changes what line `i` says. Whether there was such a line.
func set_text(i: int, text: String) -> bool:
	if i < 0 or i >= lines.size():
		return false
	if text_of(i) != text:
		(lines[i] as Dictionary)["text"] = text
		unsaved = true
	return true

func set_speaker(i: int, speaker: String) -> bool:
	if i < 0 or i >= lines.size() or (speaker != NPC and speaker != PLAYER):
		return false
	if speaker_of(i) != speaker:
		(lines[i] as Dictionary)["speaker"] = speaker
		unsaved = true
	return true

## Gives line `i` to the other of the two.
func toggle_speaker(i: int) -> bool:
	return set_speaker(i, PLAYER if speaker_of(i) == NPC else NPC)

func remove_line(i: int) -> bool:
	if i < 0 or i >= lines.size():
		return false
	lines.remove_at(i)
	unsaved = true
	return true

## Moves line `i` up (`by` -1) or down (1) one place. Not off either end.
func move_line(i: int, by: int) -> bool:
	var to := i + by
	if i < 0 or i >= lines.size() or to < 0 or to >= lines.size() or by == 0:
		return false
	var moved = lines[i]
	lines.remove_at(i)
	lines.insert(to, moved)
	unsaved = true
	return true

## The lines that are said: the ones with something in them, in order.
func said() -> Array:
	return lines.filter(func(l: Dictionary) -> bool: return String(l.get("text", "")).strip_edges() != "")

func set_mode(m: int) -> void:
	m = clampi(m, 0, MODE_IDS.size() - 1)
	if m != mode:
		mode = m
		unsaved = true

## The mode by its id in the file. Whether it was one.
func set_mode_id(id: String) -> bool:
	var m := MODE_IDS.find(id)
	if m < 0:
		return false
	set_mode(m)
	return true

func mode_id() -> String:
	return MODE_IDS[mode]

func set_map(id: String) -> void:
	if id != map_id:
		map_id = id
		unsaved = true

func set_npc_name(called: String) -> void:
	if called != npc_name:
		npc_name = called
		unsaved = true

func set_sprite(art: String) -> void:
	if art != sprite:
		sprite = art
		unsaved = true

func set_player_name(called: String) -> void:
	if called != player_name:
		player_name = called
		unsaved = true

func set_spot(cell: Vector2i) -> void:
	if cell != spot:
		spot = cell
		unsaved = true

## The map the story would be played on: its own, where that is kept, else the
## first there is; "" with none kept anywhere.
func map_to_play() -> String:
	if map_id != "" and Maps.exists(map_id):
		return map_id
	var ids := Maps.ids()
	return String(ids[0]) if not ids.is_empty() else ""

## --- keeping ----------------------------------------------------------------

## The story as a file has it: what SAVE writes, and what `_take` reads.
func story() -> Dictionary:
	var out := {"map": map_id, "mode": mode_id(), "name": npc_name, "sprite": sprite,
		"player_name": player_name, "lines": lines.duplicate(true)}
	if spot.x >= 0 and spot.y >= 0:
		out["spot"] = [spot.x, spot.y]
	return out

## Puts a story as a file has it on the desk, squared off: a mode that is not
## one is the new story's, a line's speaker one of the two, a line written as
## a bare string the character's own.
func _take(s: Dictionary) -> void:
	map_id = String(s.get("map", ""))
	mode = maxi(MODE_IDS.find(String(s.get("mode", MODE_IDS[NEW_MODE]))), 0) \
		if MODE_IDS.has(String(s.get("mode", MODE_IDS[NEW_MODE]))) else NEW_MODE
	npc_name = String(s.get("name", NEW_NAME))
	sprite = String(s.get("sprite", NEW_SPRITE))
	player_name = String(s.get("player_name", NEW_PLAYER_NAME))
	spot = Vector2i(-1, -1)
	var at = s.get("spot", null)
	if at is Array and (at as Array).size() == 2:
		spot = Vector2i(int(at[0]), int(at[1]))
	lines = []
	var given = s.get("lines", [])
	for l in (given if given is Array else []):
		if l is Dictionary:
			var kept: Dictionary = (l as Dictionary).duplicate(true)
			kept["text"] = String(kept.get("text", ""))
			kept["speaker"] = PLAYER if String(kept.get("speaker", NPC)) == PLAYER else NPC
			lines.append(kept)
		elif l is String:
			lines.append({"speaker": NPC, "text": String(l)})

## Keeps the story as `called` (`Stories.save`). "" once it is kept, and
## otherwise why it was not, as an id for the desk to spell: `name` for a
## name with nothing in it to file a story under, `write` for a file that
## could not be written.
func save_as(called: String) -> String:
	var id := Stories.id_for(called)
	if id == "":
		return "name"
	if Stories.save(id, story()) != OK:
		return "write"
	story_id = id
	unsaved = false
	return ""

## Puts the story `id` on the desk in place of the one there. Whether there
## was such a story.
func open(id: String) -> bool:
	var found := Stories.load_story(id)
	if found.is_empty():
		return false
	_take(found)
	story_id = id
	unsaved = false
	return true

## Mistakes in the story that would otherwise show up as one that plays
## wrong, phrased the way `Dialogue.problems` phrases them.
func problems() -> Array:
	return problems_in(story())

## The same check against a story as a file has it — so the checker can be put
## in front of a broken one without a broken file having to live in the
## project: a mode that is none of the three, a line said by nobody, a line
## that is not one, and nothing to say at all.
static func problems_in(s: Dictionary) -> Array:
	var found: Array = []
	var m := String(s.get("mode", MODE_IDS[NEW_MODE]))
	if not MODE_IDS.has(m):
		found.append("mode '%s' is none of %s" % [m, ", ".join(MODE_IDS)])
	var given = s.get("lines", [])
	if not given is Array:
		return found + ["lines is not a list"]
	var says := 0
	for i in (given as Array).size():
		var l = given[i]
		var at := "line %d" % (i + 1)
		if l is String:
			says += 1 if String(l).strip_edges() != "" else 0
			continue
		if not l is Dictionary:
			found.append("%s is not a line" % at)
			continue
		var who := String(l.get("speaker", NPC))
		if who != NPC and who != PLAYER:
			found.append("%s is said by '%s', who is neither %s nor %s" % [at, who, NPC, PLAYER])
		if String(l.get("text", "")).strip_edges() != "":
			says += 1
	if says == 0:
		found.append("no lines")
	return found

## --- what is played ---------------------------------------------------------

## The character, as `Dialogue.character` would read one out of the database
## and an `Npc` takes one (`Npc.setup_with`): the lines said, in the box as
## `nodes` each leading to the next from `start`, and free as `rules`, the
## first answering a press and each leading to the next, so the story is told
## the same way whichever way it is played.
func character() -> Dictionary:
	var nodes := {}
	var rules := {}
	var says := said()
	for i in says.size():
		var id := str(i + 1)
		var node := _as_row(says[i], id)
		if i + 1 < says.size():
			node["next"] = str(i + 2)
		nodes[id] = node
		var rule := node.duplicate()
		rule["once"] = 0
		if i == 0:
			rule["listens"] = FreeTalk.TALK
		rules[id] = rule
	var def := {"id": CHARACTER, "name": npc_name, "sprite": sprite, "player_name": player_name,
		"nodes": nodes, "rules": rules}
	if not says.is_empty():
		def["start"] = "1"
	return def

## A line as a row of the conversation tables: what it says and who says it,
## saying what a line in the database would where it does not say itself, and
## whatever else it was given carried through.
func _as_row(l: Dictionary, id: String) -> Dictionary:
	var row := l.duplicate(true)
	row["id"] = id
	row["text"] = String(l.get("text", "")).strip_edges()
	row["speaker"] = PLAYER if String(l.get("speaker", NPC)) == PLAYER else NPC
	if not row.has("speed"):
		row["speed"] = LINE_SPEED
	if not row.has("emotion"):
		row["emotion"] = LINE_EMOTION
	if not row.has("voice"):
		row["voice"] = LINE_VOICE
	return row

## The story as a directed scene (`Cutscene.handed`), for a NOVEL: the
## character standing at `npc_at` and the player at `player_at` on the floor
## at `floor_y`, facing each other with the camera in close on them, and a
## beat a line — the first bringing the picture up out of black.
func scene_script(npc_at: Vector2, player_at: Vector2, floor_y: float) -> Dictionary:
	var beats: Array = []
	var says := said()
	for i in says.size():
		var row := _as_row(says[i], str(i + 1))
		var beat := {"say": row["speaker"], "text": row["text"], "speed": row["speed"], "voice": row["voice"]}
		if i == 0:
			beat["do"] = [{"fade": "in", "time": FADE}]
		beats.append(beat)
	var npc_left := npc_at.x < player_at.x
	return {
		"floor": floor_y,
		"camera": {"zoom": NOVEL_ZOOM},
		"marks": {NPC: [npc_at.x, npc_at.y], PLAYER: [player_at.x, player_at.y]},
		"cast": {
			NPC: {"name": npc_name, "sprite": sprite, "at": NPC, "facing": "right" if npc_left else "left"},
			PLAYER: {"name": player_name, "sprite": PLAYER_SPRITE, "at": PLAYER,
				"facing": "left" if npc_left else "right"},
		},
		"beats": beats,
	}

## --- playing ----------------------------------------------------------------

## Stands the map up and sets the story going on it. "" once it is, and
## otherwise why not, as an id for the desk to spell: `empty` for a story with
## nothing in it to say, `map` for no map to play it on.
func play() -> String:
	if playing:
		return ""
	if said().is_empty():
		return "empty"
	var stage := Maps.load_room(map_to_play())
	if stage == null:
		return "map"
	playing = true
	_stand(stage)
	playing_changed.emit(true)
	return ""

## Back to the desk: the map and everyone on it goes, and the story is as it was.
func stop() -> void:
	if not playing:
		return
	_strike()
	playing = false
	# A scene makes itself the world while it runs; this is the world again.
	Arena.register(self)
	playing_changed.emit(false)

## Whether a novel is being read: a scene is up, and not over.
func reading() -> bool:
	return playing and scene != null and is_instance_valid(scene) and not scene.done

func _stand(stage: MadeRoom) -> void:
	room = stage
	if mode != Mode.NOVEL:
		player = Player.new()
		player.collision_layer = 2
		player.collision_mask = 1
		add_child(player)
		_arm()
		room.player = player
	add_child(room)
	room.build(Vector2i.ZERO, _empty_record(room), {}, 0)
	var start := room.spawn_point()
	var post := _post(room, start)
	if mode == Mode.NOVEL:
		scene = Cutscene.new()
		scene.scene_id = "story"
		scene.own_floor = false
		scene.handed = scene_script(post, start, post.y + Npc.BODY.y * 0.5)
		scene.finished.connect(stop)
		add_child(scene)
		return
	player.room = room
	player.global_position = start
	player.velocity = Vector2.ZERO
	npc = Npc.new()
	npc.setup_with(character())
	npc.mode = Npc.Mode.FREE if mode == Mode.FREE else Npc.Mode.FREEZE
	npc.collision_layer = 0
	npc.collision_mask = 1
	npc.position = post
	add_child(npc)

## The map's record with nothing in it to fight or find: a conversation's
## stage, not a raid's room.
static func _empty_record(stage: MadeRoom) -> Dictionary:
	var rec := stage.record()
	rec["enemies"] = []
	rec["loot"] = []
	rec["digs"] = []
	rec.erase("box")
	return rec

## Where the character stands: in the cell the story says, where the map has
## room to stand in it; otherwise on the floor APART cells along from the
## player's start — to the right where there is floor, else to the left, and
## as far as the floor goes; and with no floor to either side, on the start.
func _post(stage: MadeRoom, start: Vector2) -> Vector2:
	var half := Npc.BODY.y * 0.5
	if _standable(stage, spot):
		return stage.stand_point(spot, half)
	var from := Vector2i(int(floor(start.x / Room.CELL)), int(floor(start.y / Room.CELL)))
	for side: int in [1, -1]:
		var found := Vector2i(-1, -1)
		var c := from
		for i in APART:
			c.x += side
			if not _standable(stage, c):
				break
			found = c
		if found.x >= 0:
			return stage.stand_point(found, half)
	return start

## Room to stand in cell `c`: open, with headroom, and floor under it.
static func _standable(stage: MadeRoom, c: Vector2i) -> bool:
	if c.x < 0 or c.y < 1 or c.x >= stage.cols or c.y >= stage.rows - 1:
		return false
	return not stage.is_solid(c.x, c.y) and not stage.is_solid(c.x, c.y - 1) and stage.is_solid(c.x, c.y + 1)

## A kit's worth off the rack, as the bench hands one out.
func _arm() -> void:
	var ids := Weapons.ids()
	var kit: Array = []
	var boards: Array = []
	for k in mini(Player.MAX_WEAPONS, ids.size()):
		kit.append(ids[k])
		boards.append(graphs[String(kit[k])])
	player.setup_kit(kit, boards, 0)

func _strike() -> void:
	Attacks.clear_in_flight(self)
	for n: Node in [player, npc, scene, room]:
		if n == null or not is_instance_valid(n):
			continue
		if n is Player:
			# Out of the hunt now rather than at the end of the frame.
			n.remove_from_group("player")
		# Nothing being struck gets another turn (`Raid._enter_room`).
		n.process_mode = Node.PROCESS_MODE_DISABLED
		n.queue_free()
	player = null
	npc = null
	scene = null
	room = null

## The character in talking range, with something to say.
func use_nearby() -> bool:
	return npc != null and is_instance_valid(npc) and npc.answers_press()

func leave() -> void:
	exit_requested.emit()
