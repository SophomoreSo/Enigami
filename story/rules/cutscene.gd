class_name Cutscene
extends Node2D

## Plays a directed scene out of `data/scenes/<id>.json` — the prologue, and
## anything else that wants to move people about and be read a line at a time.
## The format is in `data/scenes/README.md`; `CutsceneScript` reads the file.
##
## What happens here is the sequencing and the staging: whose turn it is to
## speak, how far the line has typed, who is walking where, and when a beat is
## done with. What any of it looks or sounds like is not decided here.
## Directions this module has no use for — `anim`, `sfx`, `camera`, `fade` — go
## out untouched on the `scene_direction` cue for the picture and the sound bank
## to answer, which is what lets a writer add a new kind of direction without a
## line changing in `feature/`.
##
## Nothing is drawn here: `story/view/cutscene_view.gd` shows the stage and
## the narration, and `story/view/cutscene_actor_view.gd` shows the cast.

signal finished()
## A beat started. The index is into `beats`, so a view can tell a new beat from
## a re-read of the same one.
signal beat_started(index: int)

## Letters a second when a beat does not say.
const REVEAL_RATE := 34.0
## Letters that make no sound while typing, so a voice does not click on spaces.
const QUIET := " .,!?;:'\"-…()"
## How wide the stage is, for the floor under it.
const STAGE_WIDTH := 2400.0

var scene_id: String = "intro"
## The whole file, kept for the picture to read its own keys out of, exactly as
## an `Npc` keeps its dialogue file. The rules take `floor`, `marks`, `cast` and
## `beats` out of it below and never look at the rest.
var data: Dictionary = {}
## Everyone in the scene, by their name in the file.
var cast: Dictionary = {}
var marks: Dictionary = {}
var beats: Array = []
var floor_y: float = CutsceneScript.DEFAULT_FLOOR

## Which beat is playing, -1 before the first and beats.size() once it is over.
var index: int = -1
## How much of the current beat's line has been typed.
var revealed: float = 0.0
var done: bool = false

## Cast members the beat running now told to walk, so the beat knows when they
## have all arrived.
var _moving: Array[CutsceneActor] = []
## Seconds the beat running now is still waiting out — a `wait` direction, or
## the beat's own `hold`.
var _wait_left: float = 0.0
var _floor: StaticBody2D

func _ready() -> void:
	Arena.register(self)
	var def := CutsceneScript.scene(scene_id)
	data = def
	if def.is_empty():
		# A missing file must not strand the player on a black screen with
		# nothing to press: the scene is simply over.
		_finish()
		return
	floor_y = float(def.get("floor", CutsceneScript.DEFAULT_FLOOR))
	marks = def.get("marks", {})
	beats = def.get("beats", [])
	_build_floor()
	_build_cast(def.get("cast", {}))
	# The stage is standing but no beat has run yet. A view is attached as this
	# node enters the tree — before this `_ready` — so it has not had a chance
	# to frame anything, and the first beat is very often a camera direction.
	# Saying so here gives it that chance before the scene starts.
	Cues.emit_cue(&"scene_staged", {"scene": scene_id, "floor": floor_y, "marks": marks})
	_next_beat()

## --- the stage --------------------------------------------------------------

func _build_floor() -> void:
	_floor = StaticBody2D.new()
	_floor.collision_layer = 1
	_floor.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(STAGE_WIDTH, 200.0)
	shape.shape = rect
	shape.position = Vector2(0.0, floor_y + 100.0)
	_floor.add_child(shape)
	add_child(_floor)

func _build_cast(entries: Dictionary) -> void:
	for who in entries:
		var entry = entries[who]
		if not entry is Dictionary:
			continue
		var a := CutsceneActor.new()
		a.setup(String(who), entry)
		# On no collision layer of their own: the cast walk through each other
		# and stand on the floor, and nothing in the world can touch them.
		a.collision_layer = 0
		a.collision_mask = 1
		add_child(a)
		cast[String(who)] = a
		if entry.has("at"):
			a.place_at(_place(entry["at"]))
		else:
			# Cast but not yet on: an `enter` direction walks them in.
			a.on_stage = false
			a.place_at(Vector2(0.0, floor_y))

func _place(value) -> Vector2:
	return CutsceneScript.resolve_place(value, marks, floor_y)

## --- running ----------------------------------------------------------------

func _process(delta: float) -> void:
	if done:
		return
	if _wait_left > 0.0:
		_wait_left = maxf(0.0, _wait_left - delta)
	_type(delta)
	# A beat with a line waits to be read; one without is over as soon as its
	# directions are, so a scene can move somebody without asking for a press.
	if _directions_done() and line() == "":
		_next_beat()

func _type(delta: float) -> void:
	var text := line()
	if text == "" or line_finished():
		return
	var before := int(revealed)
	revealed = minf(revealed + reveal_rate() * delta, float(text.length()))
	for i in range(before, int(revealed)):
		if i % 2 == 0 and not QUIET.contains(text[i]):
			Cues.emit_cue(&"scene_letter", {"scene": scene_id, "beat": beat(), "index": i})
			break

func _next_beat() -> void:
	index += 1
	revealed = 0.0
	_moving.clear()
	_wait_left = 0.0
	if index >= beats.size():
		_finish()
		return
	var b := beat()
	_wait_left = maxf(float(b.get("hold", 0.0)), 0.0)
	for d in b.get("do", []):
		if d is Dictionary:
			_direct(d)
	if line() != "":
		Cues.emit_cue(&"scene_line", {"scene": scene_id, "beat": b})
	beat_started.emit(index)

## Carries out one direction. The ones that move something are done here; every
## other one is announced and left to whoever draws or plays it.
func _direct(d: Dictionary) -> void:
	if d.has("move"):
		var who := _who(d["move"])
		if who != null:
			who.on_stage = true
			who.walk_to(_place(d.get("to", null)).x, float(d.get("speed", CutsceneActor.WALK_SPEED)))
			_moving.append(who)
		return
	if d.has("place"):
		var who := _who(d["place"])
		if who != null:
			who.on_stage = true
			who.place_at(_place(d.get("at", null)))
		return
	if d.has("enter"):
		var who := _who(d["enter"])
		if who != null:
			who.on_stage = true
			who.place_at(_place(d.get("at", null)))
			if d.has("to"):
				who.walk_to(_place(d["to"]).x, float(d.get("speed", CutsceneActor.WALK_SPEED)))
				_moving.append(who)
		return
	if d.has("exit"):
		var who := _who(d["exit"])
		if who != null:
			who.stop()
			who.on_stage = false
		return
	if d.has("face"):
		var who := _who(d["face"])
		if who != null:
			who.face(-1 if String(d.get("dir", "right")) == "left" else 1)
		return
	if d.has("wait"):
		_wait_left = maxf(_wait_left, float(d["wait"]))
		return
	# Nothing here moves: it belongs to the picture or the sound bank.
	var extra := {"scene": scene_id, "direction": d}
	if d.has("anim"):
		var who := _who(d["anim"])
		if who != null:
			# Held on the cast member rather than sent as a moment, because it
			# is state: the view reads it every frame until something else is
			# asked for. The cue still goes out for anything else listening.
			who.forced_anim = String(d.get("play", ""))
			extra["who"] = who.cast_id
			Cues.at(&"scene_direction", who.global_position, extra)
			return
	Cues.emit_cue(&"scene_direction", extra)

func _who(value) -> CutsceneActor:
	var a = cast.get(String(value), null)
	return a if a is CutsceneActor else null

func _directions_done() -> bool:
	if _wait_left > 0.0:
		return false
	for a in _moving:
		if is_instance_valid(a) and a.walking():
			return false
	return true

## --- what a press does ------------------------------------------------------

## One press: finish the typing if it is still running, otherwise cut short
## whatever the beat is still doing and move on. A press always makes something
## happen, so a scene can never be sat in front of waiting.
func press() -> void:
	if done:
		return
	if line() != "" and not line_finished():
		revealed = float(line().length())
		return
	for a in _moving:
		if is_instance_valid(a):
			a.finish_walk()
	_wait_left = 0.0
	_next_beat()

## Out of the whole scene, however far through it is.
func skip() -> void:
	if done:
		return
	index = beats.size()
	_finish()

func _finish() -> void:
	if done:
		return
	done = true
	Cues.emit_cue(&"scene_finished", {"scene": scene_id})
	finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	if event.is_action_pressed("ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		press()
		get_viewport().set_input_as_handled()

## --- what the picture reads -------------------------------------------------

## Where a name in the file points: a cast member, a mark, or a pair of numbers
## written out. The picture needs this as much as the staging does — a `camera`
## direction names a place exactly the way a `move` does — so it is public.
func point_of(value) -> Vector2:
	var a := _who(value)
	if a != null:
		return a.global_position
	return _place(value)

func beat() -> Dictionary:
	if index < 0 or index >= beats.size():
		return {}
	var b = beats[index]
	return b if b is Dictionary else {}

## The whole line of the beat running now, typed or not.
func line() -> String:
	return String(beat().get("text", ""))

## The part of it typed so far.
func visible_text() -> String:
	return line().left(int(revealed))

func line_finished() -> bool:
	return int(revealed) >= line().length()

func reveal_rate() -> float:
	return maxf(float(beat().get("speed", REVEAL_RATE)), 1.0)

## Who is speaking this beat, or "" when it is narration with nobody behind it.
func speaker() -> String:
	return String(beat().get("say", ""))

## The name on the tab, which a beat may set itself.
func speaker_name() -> String:
	if beat().has("name"):
		return String(beat()["name"])
	var a := _who(speaker())
	if a == null:
		return ""
	return String(a.cast.get("name", a.cast_id))

## Whether the scene is waiting on a press rather than on something finishing.
func waiting_for_press() -> bool:
	return not done and line() != "" and _directions_done()
