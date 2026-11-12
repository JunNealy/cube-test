extends Node

# Procedural audio generator using native AudioStreamWAV for zero-latency, click-free SFX.

var sfx_pool: Array[AudioStreamPlayer] = []
var max_pool_size: int = 12

var wav_squish: AudioStreamWAV
var wav_gulp: AudioStreamWAV
var wav_digest_done: AudioStreamWAV
var wav_enraged: AudioStreamWAV
var wav_panic: AudioStreamWAV
var wav_hurt: AudioStreamWAV
var wav_bounce: AudioStreamWAV
var wav_buff: AudioStreamWAV
var wav_game_over: AudioStreamWAV

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Create pool of players
	for i in range(max_pool_size):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)
	
	_generate_all_sounds()

func _get_player() -> AudioStreamPlayer:
	for p in sfx_pool:
		if not p.playing:
			return p
	# Steal first player if all busy
	return sfx_pool[0]

func play(stream: AudioStreamWAV, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not stream:
		return
	var p = _get_player()
	p.stream = stream
	p.pitch_scale = pitch_scale + randf_range(-0.06, 0.06)
	p.volume_db = volume_db
	p.play()

func play_squish() -> void:
	play(wav_squish, randf_range(0.9, 1.15), -4.0)

func play_gulp() -> void:
	play(wav_gulp, 1.0, 1.0)

func play_digest_done() -> void:
	play(wav_digest_done, 1.0, 2.0)

func play_enraged() -> void:
	play(wav_enraged, 1.0, 0.0)

func play_panic() -> void:
	play(wav_panic, 1.0, -2.0)

func play_hurt() -> void:
	play(wav_hurt, 1.0, 3.0)

func play_bounce() -> void:
	play(wav_bounce, 1.0, 2.0)

func play_buff() -> void:
	play(wav_buff, 1.0, 1.0)

func play_game_over() -> void:
	play(wav_game_over, 1.0, 2.0)

func _generate_all_sounds() -> void:
	wav_squish = _make_squish()
	wav_gulp = _make_gulp()
	wav_digest_done = _make_digest_done()
	wav_enraged = _make_enraged()
	wav_panic = _make_panic()
	wav_hurt = _make_hurt()
	wav_bounce = _make_bounce()
	wav_buff = _make_buff()
	wav_game_over = _make_game_over()

func _create_wav(samples: int, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	var data = PackedByteArray()
	data.resize(samples * 2)
	wav.data = data
	return wav

# 1. Squish: pitch sliding sine with quick squishy decay and slight harmonic
func _make_squish() -> AudioStreamWAV:
	var rate = 22050
	var dur = 0.18
	var count = int(rate * dur)
	var wav = _create_wav(count, rate)
	var data = wav.data
	for i in range(count):
		var t = float(i) / rate
		var freq = lerpf(380.0, 120.0, t / dur)
		var env = (1.0 - (t / dur)) * (1.0 - exp(-t * 80.0))
		var wave = sin(t * freq * TAU) + 0.3 * sin(t * freq * 2.3 * TAU)
		var val = int(clampf(wave * env * 18000.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, val)
	wav.data = data
	return wav

# 2. Gulp: deep downward frequency sweep with bubbling resonance
func _make_gulp() -> AudioStreamWAV:
	var rate = 22050
	var dur = 0.35
	var count = int(rate * dur)
	var wav = _create_wav(count, rate)
	var data = wav.data
	for i in range(count):
		var t = float(i) / rate
		var prog = t / dur
		var freq = lerpf(450.0, 90.0, pow(prog, 0.6))
		# Bubble modulation
		var mod = sin(t * 35.0 * TAU) * 30.0
		var env = sin(prog * PI) * (1.0 - prog * 0.4)
		var wave = sin(t * (freq + mod) * TAU) + 0.4 * sin(t * (freq * 0.5) * TAU)
		var val = int(clampf(wave * env * 22000.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, val)
	wav.data = data
	return wav

# 3. Digest Done: bright sparkly chime + bubbly pop
func _make_digest_done() -> AudioStreamWAV:
	var rate = 22050
	var dur = 0.45
	var count = int(rate * dur)
	var wav = _create_wav(count, rate)
	var data = wav.data
	var notes = [523.25, 659.25, 783.99, 1046.50] # C5, E5, G5, C6
	for i in range(count):
		var t = float(i) / rate
		var sum = 0.0
		for n_idx in range(notes.size()):
			var note_time = t - (n_idx * 0.07)
			if note_time > 0.0:
				var note_env = exp(-note_time * 9.0)
				sum += sin(note_time * notes[n_idx] * TAU) * note_env
		# Add a subtle bubbly bass pop
		var pop_env = exp(-t * 20.0)
		sum += sin(t * 180.0 * TAU) * pop_env * 0.6
		var val = int(clampf(sum * 14000.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, val)
	wav.data = data
	return wav

# 4. Enraged: dissonant sharp alert stinger
func _make_enraged() -> AudioStreamWAV:
	var rate = 22050
	var dur = 0.3
	var count = int(rate * dur)
	var wav = _create_wav(count, rate)
	var data = wav.data
	for i in range(count):
		var t = float(i) / rate
		var env = exp(-t * 7.0)
		# Dissonant tritone chord: A4 (440) + Eb5 (622)
		var wave = sin(t * 440.0 * TAU) + sin(t * 622.0 * TAU) + 0.3 * (fposmod(t * 220.0, 1.0) - 0.5)
		var val = int(clampf(wave * env * 16000.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, val)
	wav.data = data
	return wav

# 5. Panic: trembling high pitch wobble
func _make_panic() -> AudioStreamWAV:
	var rate = 22050
	var dur = 0.35
	var count = int(rate * dur)
	var wav = _create_wav(count, rate)
	var data = wav.data
	for i in range(count):
		var t = float(i) / rate
		var env = (1.0 - t / dur)
		var tremolo = sin(t * 24.0 * TAU) * 80.0
		var wave = sin(t * (750.0 + tremolo) * TAU)
		var val = int(clampf(wave * env * 15000.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, val)
	wav.data = data
	return wav

# 6. Hurt: heavy crunchy impact
func _make_hurt() -> AudioStreamWAV:
	var rate = 22050
	var dur = 0.28
	var count = int(rate * dur)
	var wav = _create_wav(count, rate)
	var data = wav.data
	for i in range(count):
		var t = float(i) / rate
		var env = exp(-t * 12.0)
		# Low thud + white noise burst
		var noise = randf_range(-1.0, 1.0) * exp(-t * 20.0)
		var thud = sin(t * 90.0 * TAU) * env
		var wave = thud * 0.7 + noise * 0.5
		var val = int(clampf(wave * 24000.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, val)
	wav.data = data
	return wav

# 7. Bounce: metallic clang (when hitting knight without gauntlets)
func _make_bounce() -> AudioStreamWAV:
	var rate = 22050
	var dur = 0.35
	var count = int(rate * dur)
	var wav = _create_wav(count, rate)
	var data = wav.data
	for i in range(count):
		var t = float(i) / rate
		var env = exp(-t * 10.0)
		# Metallic inharmonic frequencies
		var wave = sin(t * 880.0 * TAU) * 0.6 + sin(t * 1240.0 * TAU) * 0.4 + sin(t * 1790.0 * TAU) * 0.3
		var val = int(clampf(wave * env * 22000.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, val)
	wav.data = data
	return wav

# 8. Buff pickup: triumphant ascending arpeggio
func _make_buff() -> AudioStreamWAV:
	var rate = 22050
	var dur = 0.4
	var count = int(rate * dur)
	var wav = _create_wav(count, rate)
	var data = wav.data
	var notes = [440.0, 554.37, 659.25, 880.0] # A Major: A4, C#5, E5, A5
	for i in range(count):
		var t = float(i) / rate
		var sum = 0.0
		for n_idx in range(notes.size()):
			var note_time = t - (n_idx * 0.08)
			if note_time > 0.0:
				var note_env = exp(-note_time * 8.0)
				sum += sin(note_time * notes[n_idx] * TAU) * note_env
		var val = int(clampf(sum * 15000.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, val)
	wav.data = data
	return wav

# 9. Game Over: descending sad minor tones
func _make_game_over() -> AudioStreamWAV:
	var rate = 22050
	var dur = 0.8
	var count = int(rate * dur)
	var wav = _create_wav(count, rate)
	var data = wav.data
	var notes = [392.0, 349.23, 311.13, 261.63] # G4, F4, Eb4, C4
	for i in range(count):
		var t = float(i) / rate
		var sum = 0.0
		for n_idx in range(notes.size()):
			var note_time = t - (n_idx * 0.16)
			if note_time > 0.0:
				var note_env = exp(-note_time * 4.5)
				sum += sin(note_time * notes[n_idx] * TAU) * note_env
		var val = int(clampf(sum * 16000.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, val)
	wav.data = data
	return wav
