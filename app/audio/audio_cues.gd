extends Node

## What every gameplay cue sounds like.
##
## The mirror of `graphics/cue_visuals.gd`, and deliberately separate from it:
## sound and picture answer to the same moments but neither has to know the
## other exists, and a silent build is a build with this autoload removed.

func _ready() -> void:
	Cues.fired.connect(_on_cue)

func _on_cue(name: StringName, d: Dictionary) -> void:
	match name:
		&"music_start":
			Audio.play_music()
		&"attack":
			match String(d.get("form", "")):
				"PROJECTILE": Audio.play("shoot")
				"SLASH": Audio.play("slash")
		&"area_blast":
			Audio.play("explode")
		&"lunge_cut", &"lunge", &"dash":
			Audio.play("dash")
		&"blink":
			Audio.play("dash", 1.3)
		&"hit":
			Audio.play("hit", 1.0 + randf_range(-0.12, 0.12))
		&"death":
			Audio.play("death", 1.0 + randf_range(-0.1, 0.1))
		&"jump":
			Audio.play("jump", JUMP_PITCH.get(String(d.get("kind", "ground")), 1.0))
		&"hurt":
			Audio.play("hurt")
		&"parry":
			Audio.play("parry")
		&"refused":
			Audio.play("deny", 0.85 if String(d.get("kind", "")) == "stamina" else 1.0)
		&"pickup":
			Audio.play("pickup")
		&"boss_phase":
			Audio.play("boss")
		&"extract_done":
			Audio.play("extract")
		&"ui":
			Audio.play("ui", UI_PITCH.get(String(d.get("kind", "")), 1.0))
		&"talk":
			_line_sound(d.get("line", {}))
		&"talk_letter":
			_voice(d.get("line", {}))

## The sound a dialogue line names for its start (`sfx`).
func _line_sound(line: Dictionary) -> void:
	var id := String(line.get("sfx", ""))
	if id == "":
		return
	if not Audio.has(id):
		push_warning("Dialogue asks for sound '%s', which is not in the bank" % id)
		return
	Audio.play(id)

## The blip under a line's typing, in the register its `voice` names. "none", or
## a register this does not know, is silent.
func _voice(line: Dictionary) -> void:
	var voice := String(line.get("voice", "mid"))
	if VOICE_PITCH.has(voice):
		Audio.play("voice", VOICE_PITCH[voice])

## A higher hop sounds higher. The wall kick and the air jump are both
## recoveries, so they sit above the jump they came out of.
const JUMP_PITCH := {"ground": 1.0, "wall": 1.15, "air": 1.3}
const UI_PITCH := {"arm": 1.2}
const VOICE_PITCH := {"low": 0.72, "mid": 1.0, "high": 1.4}
