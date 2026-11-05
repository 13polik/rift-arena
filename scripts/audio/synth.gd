class_name Synth
extends RefCounted
## Tiny offline synthesizer: builds all original SFX and music at startup as AudioStreamWAV (no audio files needed).
## Every sound is a recipe of oscillators + noise + envelopes, so they are 100% original and weigh 0 KB in the build.

const RATE := 22050


static func _to_wav(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Adds an oscillator with a frequency sweep and an attack/decay envelope.
## wave: 0 sine, 1 square, 2 saw, 3 triangle, 4 noise
static func _osc(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, wave: int, vol: float, attack := 0.005, decay_pow := 1.5) -> PackedFloat32Array:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += f / RATE
		var p := fmod(phase, 1.0)
		var v := 0.0
		match wave:
			0: v = sin(p * TAU)
			1: v = 1.0 if p < 0.5 else -1.0
			2: v = p * 2.0 - 1.0
			3: v = 4.0 * absf(p - 0.5) - 1.0
			4:
				# filtered noise: f acts as a crude low-pass cutoff (Hz)
				var a := clampf(f / RATE * 6.0, 0.01, 1.0)
				lp += (randf() * 2.0 - 1.0 - lp) * a
				v = lp * 1.6
		var env := minf(1.0, float(i) / maxf(1.0, attack * RATE)) * pow(1.0 - t, decay_pow)
		b[idx] += v * env * vol
	return b  # packed arrays are copy-on-write, so the caller re-assigns the result


static func _note(semi: int) -> float:
	return 440.0 * pow(2.0, (semi - 9) / 12.0) # semi 0 = C4


static func sfx(name: StringName) -> AudioStreamWAV:
	var b: PackedFloat32Array
	match name:
		&"step_light":
			b = _buf(0.08); b = _osc(b, 0, 0.08, 900, 300, 4, 0.35, 0.002, 3.0)
		&"step_heavy":
			b = _buf(0.16); b = _osc(b, 0, 0.16, 400, 90, 4, 0.6, 0.002, 2.0); b = _osc(b, 0, 0.12, 90, 50, 0, 0.5, 0.002, 2.0)
		&"zap":
			b = _buf(0.14); b = _osc(b, 0, 0.14, 1800, 500, 1, 0.22, 0.001, 2.0); b = _osc(b, 0, 0.06, 4000, 2000, 4, 0.25, 0.001, 2.0)
		&"blink":
			b = _buf(0.32); b = _osc(b, 0, 0.3, 300, 2400, 0, 0.35, 0.01, 1.2); b = _osc(b, 0.02, 0.28, 1200, 6000, 4, 0.18, 0.01, 1.5)
		&"super_volt":
			b = _buf(1.1); b = _osc(b, 0, 0.35, 200, 1600, 2, 0.25, 0.02, 0.5); b = _osc(b, 0.3, 0.8, 120, 35, 0, 0.9, 0.002, 1.4)
			b = _osc(b, 0.3, 0.7, 3000, 200, 4, 0.7, 0.002, 1.6)
		&"hammer":
			b = _buf(0.3); b = _osc(b, 0, 0.12, 600, 1800, 4, 0.25, 0.03, 0.8); b = _osc(b, 0.1, 0.2, 140, 50, 0, 0.8, 0.002, 2.0)
			b = _osc(b, 0.1, 0.15, 2500, 400, 4, 0.4, 0.001, 2.5)
		&"charge":
			b = _buf(0.5); b = _osc(b, 0, 0.5, 60, 140, 2, 0.35, 0.02, 0.7); b = _osc(b, 0, 0.5, 300, 1200, 4, 0.3, 0.02, 0.9)
		&"super_brute":
			b = _buf(1.4); b = _osc(b, 0, 0.4, 80, 160, 2, 0.3, 0.05, 0.3); b = _osc(b, 0.4, 1.0, 90, 28, 0, 1.0, 0.002, 1.2)
			b = _osc(b, 0.4, 1.0, 1800, 120, 4, 0.9, 0.002, 1.3); b = _osc(b, 0.55, 0.8, 700, 100, 4, 0.4, 0.05, 1.0)
		&"dart":
			b = _buf(0.12); b = _osc(b, 0, 0.1, 1400, 2600, 3, 0.25, 0.002, 1.8); b = _osc(b, 0.04, 0.08, 2200, 3200, 0, 0.15, 0.002, 2.0)
		&"stasis":
			b = _buf(0.7)
			for k in 6:
				b = _osc(b, k * 0.08, 0.3, 500 - k * 40, 300 - k * 30, 3, 0.18, 0.01, 1.2)
			b = _osc(b, 0, 0.7, 1500, 400, 4, 0.15, 0.05, 1.0)
		&"super_nyx":
			b = _buf(1.2)
			var ch := [0, 4, 7, 12, 16]
			for k in ch.size():
				b = _osc(b, k * 0.07, 0.9, _note(ch[k] + 12), _note(ch[k] + 12), 0, 0.2, 0.01, 1.5)
				b = _osc(b, k * 0.07, 0.9, _note(ch[k] + 24), _note(ch[k] + 24), 3, 0.06, 0.01, 2.0)
		&"hit":
			b = _buf(0.12); b = _osc(b, 0, 0.1, 3000, 600, 4, 0.55, 0.001, 2.5); b = _osc(b, 0, 0.08, 300, 120, 1, 0.25, 0.001, 3.0)
		&"hit_heavy":
			b = _buf(0.25); b = _osc(b, 0, 0.22, 2500, 200, 4, 0.8, 0.001, 2.0); b = _osc(b, 0, 0.2, 160, 45, 0, 0.8, 0.001, 2.0)
		&"elim":
			b = _buf(0.9); b = _osc(b, 0, 0.5, 900, 120, 2, 0.3, 0.005, 1.0); b = _osc(b, 0.05, 0.8, 120, 30, 0, 0.8, 0.002, 1.5)
			b = _osc(b, 0.05, 0.6, 2000, 150, 4, 0.5, 0.002, 1.5)
		&"respawn":
			b = _buf(0.7)
			for k in 4:
				b = _osc(b, k * 0.09, 0.4, _note([0, 7, 12, 19][k] + 12), _note([0, 7, 12, 19][k] + 12), 3, 0.22, 0.005, 1.5)
		&"pickup":
			b = _buf(0.18); b = _osc(b, 0, 0.08, _note(19), _note(19), 1, 0.15, 0.002, 1.5); b = _osc(b, 0.06, 0.12, _note(24), _note(24), 1, 0.15, 0.002, 1.5)
		&"deposit":
			b = _buf(0.45); b = _osc(b, 0, 0.25, _note(12), _note(12), 3, 0.3, 0.002, 1.2); b = _osc(b, 0.1, 0.35, _note(19), _note(19), 3, 0.3, 0.002, 1.2)
			b = _osc(b, 0.1, 0.3, 4000, 1500, 4, 0.1, 0.01, 1.5)
		&"score_enemy":
			b = _buf(0.4); b = _osc(b, 0, 0.3, _note(7), _note(7), 1, 0.12, 0.002, 1.2); b = _osc(b, 0.12, 0.28, _note(3), _note(3), 1, 0.12, 0.002, 1.2)
		&"click":
			b = _buf(0.06); b = _osc(b, 0, 0.05, 1800, 1200, 3, 0.35, 0.001, 3.0)
		&"countdown":
			b = _buf(0.2); b = _osc(b, 0, 0.18, _note(12), _note(12), 1, 0.18, 0.002, 1.5)
		&"go":
			b = _buf(0.5); b = _osc(b, 0, 0.45, _note(24), _note(24), 1, 0.2, 0.002, 1.2); b = _osc(b, 0, 0.45, _note(19), _note(19), 2, 0.12, 0.002, 1.2)
		&"victory":
			b = _buf(2.2)
			var mel := [[0, 0.0], [4, 0.15], [7, 0.3], [12, 0.45], [7, 0.75], [12, 0.9], [16, 1.05]]
			for m in mel:
				b = _osc(b, m[1], 0.6 if m[1] < 1.0 else 1.1, _note(m[0] + 12), _note(m[0] + 12), 1, 0.13, 0.005, 1.0)
				b = _osc(b, m[1], 0.6, _note(m[0]), _note(m[0]), 3, 0.15, 0.005, 1.0)
		&"defeat":
			b = _buf(2.0)
			var mel2 := [[7, 0.0], [5, 0.35], [3, 0.7], [0, 1.05]]
			for m in mel2:
				b = _osc(b, m[1], 0.8, _note(m[0]), _note(m[0]), 3, 0.25, 0.01, 1.0)
				b = _osc(b, m[1], 0.8, _note(m[0] - 12), _note(m[0] - 12), 0, 0.2, 0.01, 1.0)
		_:
			b = _buf(0.05)
	return _to_wav(b)


## Procedural music loops. style: menu | battle
static func music(style: StringName) -> AudioStreamWAV:
	var bpm := 98.0 if style == &"menu" else 132.0
	var beat := 60.0 / bpm
	var bars := 8
	var b := _buf(beat * 4.0 * bars)
	# chord roots per bar (original progression)
	var prog := [0, -3, -7, -5, 0, -3, 5, 7] if style == &"battle" else [0, -4, -7, -2, 0, -4, -9, -5]
	for bar in bars:
		var root: int = prog[bar]
		var t0 := bar * beat * 4.0
		if style == &"menu":
			for k in 3: # soft pad
				var semi: int = root + [0, 4, 7][k]
				b = _osc(b, t0, beat * 4.0, _note(semi), _note(semi), 3, 0.05, 0.4, 0.6)
			for s in 8: # gentle arpeggio
				var semi2: int = root + [0, 7, 12, 16, 19, 16, 12, 7][s] + 12
				b = _osc(b, t0 + s * beat * 0.5, beat * 0.45, _note(semi2), _note(semi2), 0, 0.07, 0.005, 1.6)
			b = _osc(b, t0, beat * 2.0, _note(root - 24), _note(root - 24), 0, 0.16, 0.01, 0.8)
		else:
			for s in 8: # driving bass
				var semi3: int = root - 24 + (12 if s % 4 == 3 else 0)
				b = _osc(b, t0 + s * beat * 0.5, beat * 0.42, _note(semi3), _note(semi3), 2, 0.13, 0.003, 1.2)
			for s in 4: # kick + snare + hats
				b = _osc(b, t0 + s * beat, 0.18, 150, 40, 0, 0.45, 0.001, 2.0)
				if s % 2 == 1:
					b = _osc(b, t0 + s * beat, 0.15, 3500, 900, 4, 0.22, 0.001, 2.2)
				b = _osc(b, t0 + s * beat + beat * 0.5, 0.05, 9000, 6000, 4, 0.08, 0.001, 3.0)
			var lead := [12, 16, 19, 16, 12, 19, 24, 19] if bar % 2 == 0 else [24, 19, 16, 19, 12, 16, 19, 16]
			for s in 8:
				var semi4: int = root + lead[s]
				b = _osc(b, t0 + s * beat * 0.5, beat * 0.4, _note(semi4), _note(semi4), 1, 0.035, 0.005, 1.4)
	return _to_wav(b, true)
