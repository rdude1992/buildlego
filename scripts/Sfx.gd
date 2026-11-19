class_name Sfx
extends Node
## Sound effects synthesised at startup, so the game ships with no audio files.
## Also triggers short phone vibrations.

const RATE := 22050

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["click"] = _wav(_click())
	_streams["thud"] = _wav(_thud())
	_streams["rip"] = _wav(_rip())
	_streams["tape"] = _wav(_tape())
	_streams["spill"] = _wav(_spill())
	_streams["fanfare"] = _wav(_fanfare())
	_streams["tap"] = _wav(_tap())


func play(sfx_name: String, volume_db := 0.0, vary := true) -> void:
	if not _streams.has(sfx_name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sfx_name]
	p.volume_db = volume_db
	p.pitch_scale = _rng.randf_range(0.92, 1.08) if vary else 1.0
	p.play()


static func buzz(ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# --- synthesis ----------------------------------------------------------------

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Plastic-on-plastic snap: two sharp ticks with a bright resonance.
func _click() -> PackedFloat32Array:
	var b := _buf(0.09)
	for i in b.size():
		var t := float(i) / RATE
		var v := _rng.randf_range(-1, 1) * exp(-t * 140.0) * 0.5
		v += sin(TAU * 3200.0 * t) * exp(-t * 90.0) * 0.35
		var t2 := t - 0.014
		if t2 > 0:
			v += _rng.randf_range(-1, 1) * exp(-t2 * 160.0) * 0.45
			v += sin(TAU * 2400.0 * t2) * exp(-t2 * 70.0) * 0.3
		b[i] = v
	return b


func _thud() -> PackedFloat32Array:
	var b := _buf(0.22)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * (140.0 - 60.0 * t) * t) * exp(-t * 18.0) * 0.8 + _rng.randf_range(-1, 1) * exp(-t * 60.0) * 0.15
	return b


func _tap() -> PackedFloat32Array:
	var b := _buf(0.05)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 1100.0 * t) * exp(-t * 90.0) * 0.4
	return b


## Plastic bag tearing: crackly low-passed noise with random bursts.
func _rip() -> PackedFloat32Array:
	var b := _buf(0.5)
	var lp := 0.0
	var burst := 1.0
	for i in b.size():
		var t := float(i) / RATE
		if i % 400 == 0:
			burst = _rng.randf_range(0.3, 1.0)
		lp = lerpf(lp, _rng.randf_range(-1, 1), 0.35)
		var env := minf(t * 30.0, 1.0) * exp(-t * 4.0)
		b[i] = lp * env * burst * 0.9
	return b


## Tape being cut: a rising scratchy sweep.
func _tape() -> PackedFloat32Array:
	var b := _buf(0.4)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lerpf(lp, _rng.randf_range(-1, 1), 0.15 + t * 1.5)
		b[i] = lp * sin(PI * t / 0.4) * 0.7
	return b


## Pieces tumbling onto the table: many small random clicks.
func _spill() -> PackedFloat32Array:
	var b := _buf(0.8)
	for k in 26:
		var start := int(pow(_rng.randf(), 1.6) * 0.65 * RATE)
		var f := _rng.randf_range(1800.0, 4200.0)
		var amp := _rng.randf_range(0.15, 0.45) * (1.0 - float(start) / b.size())
		for j in int(0.03 * RATE):
			if start + j >= b.size():
				break
			var t := float(j) / RATE
			b[start + j] += (sin(TAU * f * t) * 0.6 + _rng.randf_range(-1, 1) * 0.4) * exp(-t * 180.0) * amp
	return b


## Short happy arpeggio for a finished set.
func _fanfare() -> PackedFloat32Array:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var lens := [0.12, 0.12, 0.12, 0.5]
	var b := _buf(0.9)
	var at := 0
	for n in notes.size():
		var f: float = notes[n]
		var len_s: float = lens[n]
		for j in int(len_s * RATE):
			if at + j >= b.size():
				break
			var t := float(j) / RATE
			var env := minf(t * 80.0, 1.0) * exp(-t * (3.0 if n == 3 else 9.0))
			b[at + j] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t) + 0.15 * sin(TAU * f * 3.0 * t)) * env * 0.35
		at += int(len_s * RATE * (1.0 if n == 3 else 0.9))
	return b
