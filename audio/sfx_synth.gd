class_name SfxSynth
extends RefCounted
## Процедурные звуки (М12): кубики, чашки, удары по столу, колокольчики, шёпот.
##
## Чистая логика без нод: render(cue, rng) → сэмплы (моно, float −1…1, SoundBalance.SAMPLE_RATE),
## to_stream(...) → AudioStreamWAV. RNG — только переданный (одинаковый seed → тот же звук).
## Собирается в WAV скриптом tools/build_sfx.gd. Примитивы (tone, voice, noise) нужны и MusicSynth.

enum Wave { SINE, TRIANGLE, SAW, SQUARE }

const RATE := SoundBalance.SAMPLE_RATE

## Все звуки, которые умеет синтезатор (имена совпадают с ART_PROMPTS.md §4, где они там есть).
const CUES: Array[StringName] = [
	&"ui_click", &"dice_shake", &"dice_roll", &"cup_slam", &"cup_lift", &"cup_close", &"bid",
	&"your_turn", &"liar_call", &"calza_call", &"die_lost", &"die_gained", &"eliminated",
	&"trick", &"whisper_abyss", &"cheat_fail", &"evidence", &"accuse", &"madness_onset",
	&"madness_other", &"palifico",
]


## Сэмплы звука cue, нормализованные, без хвоста тишины. Пусто — нет такого звука.
static func render(cue: StringName, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	match cue:
		&"ui_click": buf = _ui_click(rng)
		&"dice_shake": buf = _dice_shake(rng)
		&"dice_roll": buf = _dice_roll(rng)
		&"cup_slam": buf = _cup_slam(rng)
		&"cup_lift": buf = _cup_lift(rng)
		&"cup_close": buf = _cup_close(rng)
		&"bid": buf = _bid(rng)
		&"your_turn": buf = _your_turn(rng)
		&"liar_call": buf = _liar_call(rng)
		&"calza_call": buf = _calza_call(rng)
		&"die_lost": buf = _die_lost(rng)
		&"die_gained": buf = _die_gained(rng)
		&"eliminated": buf = _eliminated(rng)
		&"trick": buf = _trick(rng)
		&"whisper_abyss": buf = _whisper_abyss(rng)
		&"cheat_fail": buf = _cheat_fail(rng)
		&"evidence": buf = _evidence(rng)
		&"accuse": buf = _accuse(rng)
		&"madness_onset": buf = _madness_onset(rng)
		&"madness_other": buf = _madness_other(rng)
		&"palifico": buf = _palifico(rng)
		_:
			return buf
	return finish(buf, SoundBalance.SFX_PEAK)


# --- Вывод ----------------------------------------------------------------------------

## Нормализовать к пику, обрезать тихий хвост и мягко его погасить.
static func finish(buf: PackedFloat32Array, peak: float, trim := true) -> PackedFloat32Array:
	var m := peak_of(buf)
	if m <= 0.0:
		return buf
	var g := peak / m
	if trim:
		var end := buf.size()
		while end > 1 and absf(buf[end - 1]) * g < SoundBalance.SILENCE:
			end -= 1
		buf.resize(end)
		var fade := mini(int(SoundBalance.FADE_OUT * RATE), end)
		for i in fade:
			buf[end - 1 - i] *= float(i) / fade
	for i in buf.size():
		buf[i] *= g
	return buf


static func peak_of(buf: PackedFloat32Array) -> float:
	var m := 0.0
	for s in buf:
		m = maxf(m, absf(s))
	return m


static func to_stream(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(round(clampf(buf[i], -1.0, 1.0) * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream


static func empty(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * RATE))
	buf.fill(0.0)
	return buf


static func midi_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


# --- Примитивы -------------------------------------------------------------------------

## Удар: тон со скольжением f0 → f1, атакой и экспоненциальным затуханием.
static func tone(buf: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float,
		amp: float, attack: float, decay: float, wave := Wave.SINE) -> void:
	var start := int(t0 * RATE)
	var n := mini(int(dur * RATE), buf.size() - start)
	var tail := maxf(n * 0.05, 1.0)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase = fmod(phase + lerpf(f0, f1, float(i) / n) / RATE, 1.0)
		var env := exp(-t / decay) * minf((n - i) / tail, 1.0)
		if attack > 0.0:
			env *= minf(t / attack, 1.0)
		buf[start + i] += amp * env * wave_at(wave, phase)


## Ровная нота: атака, держится, спад в конце. Вибрато — доля частоты.
static func voice(buf: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float,
		amp: float, attack: float, release: float, wave := Wave.TRIANGLE,
		vib_hz := 0.0, vib_depth := 0.0) -> void:
	var start := int(t0 * RATE)
	var n := mini(int(dur * RATE), buf.size() - start)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, float(i) / n)
		if vib_hz > 0.0:
			f *= 1.0 + vib_depth * sin(TAU * vib_hz * t)
		phase = fmod(phase + f / RATE, 1.0)
		var env := minf(t / maxf(attack, 0.001), 1.0) * minf((dur - t) / maxf(release, 0.001), 1.0)
		buf[start + i] += amp * env * wave_at(wave, phase)


## Шум в полосе lo…hi (hi скользит к hi_end) с атакой и затуханием. Однополюсные фильтры —
## устойчивы при любой частоте.
static func noise(buf: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, dur: float,
		amp: float, attack: float, decay: float, lo: float, hi: float, hi_end := -1.0) -> void:
	if hi_end < 0.0:
		hi_end = hi
	var start := int(t0 * RATE)
	var n := mini(int(dur * RATE), buf.size() - start)
	var tail := maxf(n * 0.05, 1.0)
	var a_lo := _pole(lo)
	var lp1 := 0.0
	var lp2 := 0.0
	var hp_state := 0.0
	for i in n:
		var t := float(i) / RATE
		var a_hi := _pole(lerpf(hi, hi_end, float(i) / n))
		var x := rng.randf_range(-1.0, 1.0)
		lp1 += a_hi * (x - lp1)
		lp2 += a_hi * (lp1 - lp2)
		hp_state += a_lo * (lp2 - hp_state)
		var env := exp(-t / decay) * minf((n - i) / tail, 1.0)
		if attack > 0.0:
			env *= minf(t / attack, 1.0)
		buf[start + i] += amp * env * (lp2 - hp_state) * 2.0


## Костяной кубик о дерево (muffled — внутри чашки, глуше).
static func clack(buf: PackedFloat32Array, rng: RandomNumberGenerator, t: float, amp: float,
		muffled := false) -> void:
	var f := rng.randf_range(700.0, 1300.0) if muffled else rng.randf_range(1400.0, 2600.0)
	var decay := 0.014 if muffled else 0.009
	tone(buf, t, 0.05, f, f * 0.97, amp, 0.0003, decay)
	tone(buf, t, 0.04, f * 1.53, f * 1.5, amp * 0.5, 0.0003, decay * 0.6)
	noise(buf, rng, t, 0.012, amp * 0.6, 0.0, 0.003, 300.0 if muffled else 1500.0,
			2500.0 if muffled else 6000.0)


## Глухой удар по дереву (кулак, чашка, барабан).
static func thump(buf: PackedFloat32Array, rng: RandomNumberGenerator, t: float, amp: float,
		f0: float, f1: float, decay: float) -> void:
	tone(buf, t, decay * 5.0, f0, f1, amp, 0.001, decay)
	noise(buf, rng, t, decay * 2.5, amp * 0.7, 0.0005, decay * 0.4, 40.0, 900.0, 300.0)


## Колокольчик: неровные обертоны, у каждого своё затухание.
static func bell(buf: PackedFloat32Array, t: float, f: float, amp: float, decay: float) -> void:
	var partials := [[1.0, 1.0, 1.0], [2.0, 0.4, 0.55], [2.76, 0.3, 0.4], [5.4, 0.1, 0.2]]
	for p: Array in partials:
		tone(buf, t, decay * 4.0, f * p[0], f * p[0], amp * p[1], 0.002, decay * p[2])


static func wave_at(wave: Wave, phase: float) -> float:
	match wave:
		Wave.TRIANGLE:
			return 4.0 * absf(phase - 0.5) - 1.0
		Wave.SAW:
			return 2.0 * phase - 1.0
		Wave.SQUARE:
			return 1.0 if phase < 0.5 else -1.0
	return sin(TAU * phase)


static func _pole(hz: float) -> float:
	return 1.0 - exp(-TAU * clampf(hz, 1.0, RATE * 0.45) / RATE)


# --- Рецепты --------------------------------------------------------------------------

static func _ui_click(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(0.06)
	tone(b, 0.0, 0.04, 1100.0, 800.0, 0.6, 0.0005, 0.008, Wave.TRIANGLE)
	noise(b, rng, 0.0, 0.02, 0.4, 0.0, 0.004, 800.0, 4000.0)
	return b


static func _dice_shake(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(0.6)
	var span := 0.45
	for k in 22:
		var t := rng.randf_range(0.0, span)
		clack(b, rng, t, sqrt(sin(PI * t / span)) * rng.randf_range(0.3, 0.7), true)
	noise(b, rng, 0.0, 0.5, 0.25, 0.05, 0.4, 60.0, 500.0)
	return b


static func _dice_roll(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(0.8)
	var t := 0.0
	var gap := 0.09
	for k in 9:
		clack(b, rng, t, 0.8 * pow(0.85, k))
		if rng.randf() < 0.5:
			clack(b, rng, t + rng.randf_range(0.01, 0.03), 0.3 * pow(0.85, k))
		t += gap * rng.randf_range(0.6, 1.2)
		gap *= 0.85
	return b


static func _cup_slam(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(0.4)
	thump(b, rng, 0.0, 1.0, 130.0, 55.0, 0.06)
	tone(b, 0.0, 0.15, 240.0, 220.0, 0.3, 0.001, 0.03, Wave.TRIANGLE)
	for k in 4:
		clack(b, rng, 0.01 + rng.randf_range(0.0, 0.08), 0.25, true)
	return b


static func _cup_lift(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(0.35)
	tone(b, 0.0, 0.03, 600.0, 500.0, 0.25, 0.0005, 0.01, Wave.TRIANGLE)
	noise(b, rng, 0.0, 0.3, 0.45, 0.08, 0.12, 300.0, 2200.0, 1200.0)
	return b


static func _cup_close(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(0.25)
	thump(b, rng, 0.0, 0.7, 180.0, 90.0, 0.04)
	for k in 2:
		clack(b, rng, 0.01 + rng.randf_range(0.0, 0.04), 0.2, true)
	return b


static func _bid(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(0.25)
	tone(b, 0.0, 0.15, 420.0, 380.0, 0.6, 0.0005, 0.03, Wave.TRIANGLE)
	tone(b, 0.0, 0.12, 1050.0, 1000.0, 0.15, 0.0005, 0.02)
	clack(b, rng, 0.04, 0.4)
	return b


static func _your_turn(_rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(0.9)
	bell(b, 0.0, 784.0, 0.6, 0.3)
	return b


static func _liar_call(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(0.6)
	thump(b, rng, 0.0, 1.0, 95.0, 45.0, 0.09)
	for k in 6:
		clack(b, rng, rng.randf_range(0.03, 0.25), 0.35)
	return b


static func _calza_call(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(0.9)
	tone(b, 0.0, 0.15, 400.0, 380.0, 0.6, 0.0005, 0.03, Wave.TRIANGLE)
	bell(b, 0.03, 988.0, 0.45, 0.25)
	bell(b, 0.1, 1319.0, 0.35, 0.25)
	clack(b, rng, 0.0, 0.3)
	return b


static func _die_lost(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(0.55)
	tone(b, 0.0, 0.5, 330.0, 140.0, 0.6, 0.002, 0.15, Wave.TRIANGLE)
	thump(b, rng, 0.0, 0.6, 110.0, 60.0, 0.05)
	noise(b, rng, 0.0, 0.25, 0.3, 0.02, 0.08, 200.0, 1500.0)
	return b


static func _die_gained(_rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(0.8)
	for i in 3:
		bell(b, i * 0.08, [523.0, 659.0, 784.0][i], 0.4, 0.2)
	return b


static func _eliminated(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(1.8)
	for i in 3:
		bell(b, i * 0.25, [392.0, 330.0, 262.0][i], 0.45, 0.45)
	tone(b, 0.0, 1.6, 65.0, 55.0, 0.5, 0.05, 0.6)
	noise(b, rng, 0.0, 1.0, 0.15, 0.2, 0.4, 40.0, 300.0)
	return b


static func _trick(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(0.4)
	noise(b, rng, 0.0, 0.35, 0.6, 0.12, 0.1, 400.0, 1200.0, 5000.0)
	tone(b, 0.12, 0.2, 1568.0, 1568.0, 0.1, 0.002, 0.05)
	return b


static func _whisper_abyss(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(2.0)
	tone(b, 0.0, 2.0, 55.0, 48.0, 0.35, 0.4, 1.5, Wave.TRIANGLE)
	for k in 5:
		noise(b, rng, rng.randf_range(0.0, 1.5), rng.randf_range(0.2, 0.4), 0.5, 0.06, 0.12,
				1200.0, 4000.0, 2500.0)
	for k in 10:
		var f := rng.randf_range(250.0, 500.0)
		tone(b, rng.randf_range(0.0, 1.8), 0.05, f, f * 2.2, 0.35, 0.002, 0.02)
	return b


static func _cheat_fail(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(1.0)
	for f in [196.0, 207.65, 277.18]:
		tone(b, 0.0, 0.8, f, f * 0.98, 0.22, 0.005, 0.25, Wave.SAW)
	thump(b, rng, 0.0, 0.6, 90.0, 50.0, 0.06)
	noise(b, rng, 0.08, 0.6, 0.4, 0.15, 0.25, 500.0, 2500.0)
	return b


static func _evidence(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(0.5)
	for k in 8:
		clack(b, rng, k * 0.05 + rng.randf_range(0.0, 0.02), 0.3, true)
	tone(b, 0.0, 0.45, 70.0, 70.0, 0.2, 0.05, 0.2, Wave.TRIANGLE)
	return b


static func _accuse(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(1.1)
	thump(b, rng, 0.0, 1.0, 75.0, 45.0, 0.2)
	noise(b, rng, 0.1, 1.0, 0.25, 0.3, 0.4, 300.0, 1400.0)
	for k in 3:
		noise(b, rng, rng.randf_range(0.2, 0.7), 0.25, 0.2, 0.05, 0.1, 1500.0, 4000.0)
	return b


static func _madness_onset(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(3.0)
	for d in [1.0, 1.007, 1.5, 1.51, 0.5]:
		voice(b, 0.0, 2.4, 80.0 * d, 240.0 * d, 0.2, 2.2, 0.05, Wave.TRIANGLE)
	noise(b, rng, 0.0, 2.4, 0.35, 2.2, 3.0, 200.0, 800.0, 4000.0)
	thump(b, rng, 2.45, 1.0, 60.0, 40.0, 0.07)
	thump(b, rng, 2.7, 0.8, 60.0, 40.0, 0.07)
	return b


static func _madness_other(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(1.2)
	voice(b, 0.0, 1.1, 300.0, 180.0, 0.3, 0.1, 0.4, Wave.TRIANGLE)
	voice(b, 0.0, 1.1, 317.0, 170.0, 0.3, 0.1, 0.4, Wave.TRIANGLE)
	noise(b, rng, 0.1, 0.8, 0.3, 0.2, 0.3, 1200.0, 3500.0)
	return b


static func _palifico(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := empty(1.6)
	var partials := [[1.0, 1.0, 1.2], [2.4, 0.5, 0.7], [3.9, 0.35, 0.4], [5.3, 0.2, 0.25]]
	for p: Array in partials:
		tone(b, 0.0, 1.6, 98.0 * p[0], 98.0 * p[0], p[1], 0.003, p[2])
	noise(b, rng, 0.0, 0.1, 0.4, 0.0, 0.02, 200.0, 3000.0)
	return b
