extends Node

## All sound is synthesised at boot, so the project carries no audio assets.
## Each cue is a short PCM buffer built from an envelope plus a waveform.

const RATE := 22050

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _next_player := 0

var sfx_volume: float = 0.7
var music_volume: float = 0.35

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_library()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)
	_music_player.stream = _make_music()
	_apply_volumes()

## Release the streaming buffers on the way out, so shutdown is clean.
func _exit_tree() -> void:
	_music_player.stop()
	_music_player.stream = null
	for p in _players:
		p.stop()
		p.stream = null
	_sfx.clear()

func _apply_volumes() -> void:
	_music_player.volume_db = linear_to_db(maxf(music_volume, 0.0001))
	for p in _players:
		p.volume_db = linear_to_db(maxf(sfx_volume, 0.0001))

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()

func play(id: String, pitch: float = 1.0) -> void:
	if not _sfx.has(id) or sfx_volume <= 0.001:
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _sfx[id]
	p.pitch_scale = clampf(pitch * randf_range(0.96, 1.05), 0.3, 3.0)
	p.play()

func play_music() -> void:
	if not _music_player.playing and music_volume > 0.001:
		_music_player.play()

func stop_music() -> void:
	_music_player.stop()

## --- synthesis --------------------------------------------------------------
func _build_library() -> void:
	_sfx["shoot"] = _tone(620.0, 240.0, 0.12, "square", 0.35, 0.10)
	_sfx["slash"] = _noise(0.14, 0.5, 0.55)
	_sfx["hit"] = _tone(300.0, 120.0, 0.09, "square", 0.4, 0.35)
	_sfx["explode"] = _noise(0.36, 0.25, 0.15)
	_sfx["jump"] = _tone(320.0, 640.0, 0.10, "tri", 0.3, 0.0)
	_sfx["dash"] = _noise(0.16, 0.4, 0.8)
	_sfx["hurt"] = _tone(220.0, 90.0, 0.22, "saw", 0.45, 0.2)
	_sfx["death"] = _tone(180.0, 40.0, 0.6, "saw", 0.5, 0.3)
	_sfx["pickup"] = _tone(700.0, 1150.0, 0.11, "tri", 0.35, 0.0)
	_sfx["place"] = _tone(480.0, 520.0, 0.05, "tri", 0.3, 0.0)
	_sfx["erase"] = _tone(340.0, 220.0, 0.06, "tri", 0.3, 0.0)
	_sfx["ui"] = _tone(880.0, 880.0, 0.035, "tri", 0.22, 0.0)
	_sfx["deny"] = _tone(200.0, 160.0, 0.13, "square", 0.3, 0.2)
	_sfx["extract"] = _tone(420.0, 880.0, 0.5, "tri", 0.4, 0.0)
	_sfx["parry"] = _tone(1200.0, 700.0, 0.18, "tri", 0.5, 0.0)
	_sfx["boss"] = _tone(90.0, 60.0, 0.8, "saw", 0.6, 0.4)

func _wave(kind: String, phase: float) -> float:
	match kind:
		"square":
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"saw":
			return fmod(phase, 1.0) * 2.0 - 1.0
		"tri":
			var t := fmod(phase, 1.0)
			return (t * 4.0 - 1.0) if t < 0.5 else (3.0 - t * 4.0)
		_:
			return sin(phase * TAU)

func _tone(f0: float, f1: float, dur: float, kind: String, amp: float, noise_mix: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f: float = lerpf(f0, f1, t * t)
		phase += f / float(RATE)
		var env: float = pow(1.0 - t, 1.6)
		var s: float = _wave(kind, phase) * (1.0 - noise_mix) + randf_range(-1.0, 1.0) * noise_mix
		var v := int(clampf(s * env * amp, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	return _wav(data)

func _noise(dur: float, amp: float, brightness: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var last := 0.0
	for i in n:
		var t := float(i) / float(n)
		var raw := randf_range(-1.0, 1.0)
		last = lerpf(last, raw, clampf(brightness, 0.05, 1.0))
		var env: float = pow(1.0 - t, 2.2)
		var v := int(clampf(last * env * amp, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	return _wav(data)

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s

## A slow minor arpeggio over a drone. Eight bars, looped.
func _make_music() -> AudioStreamWAV:
	var bar := 1.6
	var bars := 8
	var n := int(bar * bars * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var scale := [220.0, 261.63, 329.63, 392.0, 440.0, 523.25]
	var drone_phase := 0.0
	var lead_phase := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var step := int(t / 0.4) % scale.size()
		var bar_idx := int(t / bar) % bars
		var lead_f: float = scale[(step + bar_idx) % scale.size()]
		var drone_f: float = 110.0 if bar_idx < 4 else 98.0
		drone_phase += drone_f / float(RATE)
		lead_phase += lead_f / float(RATE)
		var note_t := fmod(t, 0.4) / 0.4
		var lead_env: float = pow(1.0 - note_t, 2.0) * 0.22
		var s := _wave("tri", lead_phase) * lead_env
		s += _wave("tri", drone_phase) * 0.10
		s += sin(drone_phase * TAU * 0.5) * 0.06
		var v := int(clampf(s, -1.0, 1.0) * 28000.0)
		data.encode_s16(i * 2, v)
	var stream := _wav(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = n
	return stream
