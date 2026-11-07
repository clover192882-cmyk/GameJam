extends Node

const MIX_RATE := 22050

const FILE_SOUNDS := {
	"balloon_pop": ["res://assets/audio/balloon_pop.ogg"],
	"balloon_inflate": ["res://assets/audio/balloon_inflate.ogg"],
	"dart_throw": ["res://assets/audio/dart_throw.wav", "res://assets/audio/dart_throw_alt.wav"],
	"dart_hit": ["res://assets/audio/dart_hit_wood.wav", "res://assets/audio/dart_hit_wood_alt.wav"],
}
const FILE_VOLUME_DB := {"balloon_pop": 2.0, "balloon_inflate": -8.0, "dart_throw": -2.0, "dart_hit": -3.0}
const MUSIC_PATH := "res://assets/audio/carnival_music.ogg"
const POOL_SIZE := 6

var _sounds := {}
var _drone: AudioStreamPlayer
var _music: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _sfx: AudioStreamPlayer
var _eerie: AudioStreamPlayer
var _timer: Timer


func _ready() -> void:
	_sounds["chime"] = _tone([880.0, 1320.0], 0.45, 0.35, 6.0, 0.0)
	_sounds["buzz"] = _tone([110.0, 117.0], 0.35, 0.4, 3.0, 0.1)
	_sounds["unlock"] = _tone([523.0, 659.0, 784.0], 0.6, 0.3, 3.0, 0.0)
	_sounds["pop"] = _tone([300.0], 0.12, 0.6, 30.0, 0.9)
	_sounds["thud"] = _tone([90.0], 0.2, 0.5, 14.0, 0.2)
	_sounds["shot"] = _tone([200.0], 0.15, 0.6, 22.0, 0.7)
	_sounds["splash"] = _tone([500.0], 0.5, 0.35, 5.0, 0.95)
	_sounds["gunshot"] = _gunshot()
	_sounds["quack"] = _quack()
	_sounds["reload"] = _reload_sound()
	_sounds["qte_hit"] = _tone([1040.0, 1560.0], 0.12, 0.4, 24.0, 0.0)
	_sounds["tear"] = _tone([260.0], 0.4, 0.5, 8.0, 0.85)
	_sounds["eerie"] = _tone([73.0, 77.5, 110.0], 3.5, 0.35, 0.6, 0.05)

	_drone = AudioStreamPlayer.new()
	_drone.stream = _loop(_tone([55.0, 55.7, 82.4], 4.0, 0.25, 0.0, 0.03))
	_drone.volume_db = -22.0
	add_child(_drone)
	_drone.play()

	var music: AudioStreamOggVorbis = load(MUSIC_PATH)
	music.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = music
	_music.volume_db = -17.0
	_music.pitch_scale = 0.62
	add_child(_music)
	_music.play()

	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	_eerie = AudioStreamPlayer.new()
	_eerie.volume_db = -10.0
	add_child(_eerie)

	_music.bus = "Music"
	_drone.bus = "Music"
	_eerie.bus = "SFX"
	_sfx.bus = "SFX"
	for p in _pool:
		p.bus = "SFX"

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_eerie_timer)
	add_child(_timer)
	_timer.start(randf_range(15.0, 30.0))

	PointManager.points_changed.connect(_on_points_changed)
	StallManager.stall_unlocked.connect(func(_id): play("unlock"))
	PointManager.game_over.connect(func():
		_drone.stop()
		_music.stop())


func play(sound: String) -> void:
	if FILE_SOUNDS.has(sound):
		_play_file(sound)
		return
	if sound == "gunshot" or sound == "quack":
		_play_pooled(_sounds[sound], 0.0 if sound == "gunshot" else -2.0, 0.04 if sound == "gunshot" else 0.12)
		return
	if sound == "qte_hit" or sound == "tear" or sound == "splash":
		_play_pooled(_sounds[sound], 0.0, 0.06)
		return
	if sound == "reload":
		_play_pooled(_sounds[sound], -2.0, 0.02)
		return
	if not _sounds.has(sound):
		return
	_sfx.stream = _sounds[sound]
	_sfx.play()


# Recorded sounds go through a small pool so a throw, a pop and a landing can overlap, with slight pitch variation.
func _play_file(sound: String) -> void:
	var options: Array = FILE_SOUNDS[sound]
	var player: AudioStreamPlayer = _pool[0]
	for p in _pool:
		if not p.playing:
			player = p
			break
	player.stream = load(options[randi() % options.size()])
	player.volume_db = FILE_VOLUME_DB.get(sound, 0.0)
	player.pitch_scale = randf_range(0.93, 1.08)
	player.play()


func _play_pooled(stream: AudioStream, volume_db: float, pitch_jitter: float) -> void:
	var player: AudioStreamPlayer = _pool[0]
	for p in _pool:
		if not p.playing:
			player = p
			break
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	player.play()


# Sharp noise crack over a low thump, decaying fast.
func _gunshot() -> AudioStreamWAV:
	var count := int(MIX_RATE * 0.45)
	var data := PackedByteArray()
	data.resize(count * 2)
	var low := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		var crack := randf_range(-1.0, 1.0) * exp(-38.0 * t)
		low = lerpf(low, randf_range(-1.0, 1.0), 0.12)
		var boom := low * 2.2 * exp(-9.0 * t)
		var thump := sin(TAU * (140.0 - 90.0 * minf(t * 4.0, 1.0)) * t) * exp(-14.0 * t)
		var s := (crack * 0.8 + boom * 0.7 + thump * 0.6) * minf(t / 0.002, 1.0)
		data.encode_s16(i * 2, int(clampf(s * 0.85, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav


# Three metallic clicks: magazine out, slide rack, and lock-in, spread across one second.
func _reload_sound() -> AudioStreamWAV:
	var count := int(MIX_RATE * 1.0)
	var data := PackedByteArray()
	data.resize(count * 2)
	var clicks := [[0.02, 1.0, 1700.0], [0.38, 0.7, 900.0], [0.82, 1.0, 1300.0]]
	for i in count:
		var t := float(i) / MIX_RATE
		var s := 0.0
		for c in clicks:
			var dt: float = t - c[0]
			if dt < 0.0 or dt > 0.12:
				continue
			var env := exp(-70.0 * dt) * minf(dt / 0.001, 1.0)
			s += (sin(TAU * c[2] * dt) * 0.6 + randf_range(-1.0, 1.0) * 0.5) * env * c[1]
		data.encode_s16(i * 2, int(clampf(s * 0.6, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav


# Two nasal, buzzy "quack" syllables: a falling pitch sweep with harmonics and a bit of rasp.
func _quack() -> AudioStreamWAV:
	var count := int(MIX_RATE * 0.5)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		var local := fposmod(t, 0.22)
		var syllable := t < 0.44
		var env := 0.0
		if syllable:
			env = minf(local / 0.012, 1.0) * exp(-7.0 * local)
		var freq := (560.0 if t < 0.22 else 500.0) * (1.0 - 0.38 * minf(local / 0.2, 1.0))
		phase += TAU * freq / MIX_RATE
		var s := sin(phase) + 0.6 * sin(phase * 2.0) + 0.45 * sin(phase * 3.0) + 0.3 * sin(phase * 5.0)
		s = lerpf(s / 2.3, randf_range(-1.0, 1.0), 0.12)
		data.encode_s16(i * 2, int(clampf(s * env * 0.7, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav


func _on_points_changed(_points: int, delta: int) -> void:
	if delta > 0:
		play("chime")
	elif delta < 0 and not PointManager.is_game_over:
		play("buzz")


func _on_eerie_timer() -> void:
	if not PointManager.is_game_over:
		_eerie.stream = _sounds["eerie"]
		_eerie.pitch_scale = randf_range(0.7, 1.2)
		_eerie.play()
	_timer.start(randf_range(20.0, 40.0))


func _loop(stream: AudioStreamWAV) -> AudioStreamWAV:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	return stream


# Sum of sines plus noise, with an exponential decay; decay 0 gives a steady loop-friendly tone.
func _tone(freqs: Array, seconds: float, volume: float, decay: float, noise: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / MIX_RATE
		var s := 0.0
		for f in freqs:
			s += sin(TAU * f * t)
		s /= freqs.size()
		s = lerpf(s, randf_range(-1.0, 1.0), noise)
		var env := exp(-decay * t) if decay > 0.0 else 1.0
		var attack := minf(t / 0.01, 1.0)
		data.encode_s16(i * 2, int(clampf(s * env * attack * volume, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav
