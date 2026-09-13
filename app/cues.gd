extends Node

## The one-way seam between the two modules.
##
## `feature/` announces moments; `graphics/` and the audio bank decide what a
## moment looks and sounds like. Gameplay code therefore never names a colour,
## a particle count or a sound file, and presentation code never reaches back
## into the rules — which is what keeps the two modules editable in parallel
## without the two edits landing in the same file.
##
## Cue names are plain StringNames and are deliberately **not** listed in one
## central table: a new cue is one `emit` on the feature side and one handler on
## the graphics side, in two files that belong to two different branches. A cue
## nobody handles is silence, never an error, so either branch can run alone.
##
## Continuous state is not a cue. A view that wants to know whether an actor is
## burning reads `actor.burn_time` every frame; cues are for the instant a thing
## happens. See ARCHITECTURE.md.

signal fired(name: StringName, data: Dictionary)

func emit_cue(name: StringName, data: Dictionary = {}) -> void:
	fired.emit(name, data)

## Sugar for the common case of "this happened over there".
func at(name: StringName, pos: Vector2, extra: Dictionary = {}) -> void:
	var d := extra.duplicate()
	d["pos"] = pos
	fired.emit(name, d)
