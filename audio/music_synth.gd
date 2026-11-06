class_name MusicSynth
extends RefCounted
## Музыка-заглушки (М12, переписана в М15), пока автор не положил свою по ART_PROMPTS.md §3.
##
## М15: прежние треки держались на непрерывных гулах (55/82 Гц, пила с вибрато, биения
## 110/110,7 Гц) — на слух «жужжание». Теперь только щипковые струны (модель Карплуса —
## Стронга), мягкая «флейта» синусом, колокольчики и паузы; всё в лёгком эхе таверны.
## Ни одного тона, который звучит дольше нескольких секунд.
##
## Чистая логика: render(track, rng) → сэмплы. Петли (LOOPED) бесшовные: рендерим с запасом
## SoundBalance.LOOP_FOLD и склеиваем хвост с началом. Стинги — без петли.

const RATE := SoundBalance.SAMPLE_RATE
const Wave := SfxSynth.Wave

## Длины треков (секунды): целое число тактов.
const LENGTHS := {
	&"main_menu": 24.0,
	&"tavern_ambient": 32.0,
	&"madness_layer": 16.0,
	&"victory": 3.5,
	&"defeat": 4.5,
}
const LOOPED: Array[StringName] = [&"main_menu", &"tavern_ambient", &"madness_layer"]

## Такт, с. Темп спокойный: восьмая — 0,5 с.
const BAR := 4.0
## Эхо таверны: задержка, с; доля громкости каждого повтора; число повторов.
const ECHO_DELAY := 0.27
const ECHO_GAIN := 0.28
const ECHO_TAPS := 3

## Меню — ля минор: Am | F | C | G | Am | E (по такту).
const MENU_CHORDS := [[57, 60, 64], [53, 57, 60], [48, 55, 60], [55, 59, 62], [57, 60, 64],
		[52, 56, 59]]
## Порядок нот аккорда в арпеджио (индексы; 3 — верхняя нота октавой выше нижней).
const ARPEGGIO := [0, 1, 2, 3, 2, 1, 2, 1]
## Мелодия «флейты» — натуральный минор ля.
const MINOR_SCALE := [69, 71, 72, 74, 76, 77, 79, 81]
## Таверна — ре минор: Dm | Am | B♭ | A, дважды.
const TAVERN_CHORDS := [[50, 53, 57], [45, 52, 57], [46, 50, 53], [45, 49, 52]]
const PENTATONIC := [62, 65, 67, 69, 72, 74]
## Безумие: колокольчики «мимо» лада (целотонный ряд и тритон).
const MADNESS_NOTES := [72, 74, 76, 78, 80, 82]


static func is_looped(track: StringName) -> bool:
	return track in LOOPED


static func render(track: StringName, rng: RandomNumberGenerator) -> PackedFloat32Array:
	if not LENGTHS.has(track):
		return PackedFloat32Array()
	var length: float = LENGTHS[track]
	var looped := is_looped(track)
	var b := SfxSynth.empty(length + (SoundBalance.LOOP_FOLD if looped else 0.0))
	match track:
		&"main_menu": _main_menu(b, rng)
		&"tavern_ambient": _tavern(b, rng)
		&"madness_layer": _madness(b, rng, length)
		&"victory": _victory(b, rng)
		&"defeat": _defeat(b, rng)
	echo(b, ECHO_DELAY, ECHO_GAIN, ECHO_TAPS)
	if looped:
		b = fold_loop(b, int(length * RATE))
	remove_dc(b)
	return SfxSynth.finish(b, SoundBalance.MUSIC_PEAK, not looped)


## Убрать постоянную составляющую (шумовой импульс струны несимметричен).
static func remove_dc(buf: PackedFloat32Array) -> void:
	if buf.is_empty():
		return
	var mean := 0.0
	for s in buf:
		mean += s
	mean /= buf.size()
	for i in buf.size():
		buf[i] -= mean


## Бесшовная петля длиной n: последние сэмплы после n плавно вливаются в начало.
static func fold_loop(buf: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var tail := buf.size() - n
	for i in tail:
		var k := float(i) / tail
		buf[i] = buf[i] * k + buf[n + i] * (1.0 - k)
	buf.resize(n)
	return buf


## Эхо: taps затухающих повторов через delay секунд.
static func echo(buf: PackedFloat32Array, delay: float, gain: float, taps: int) -> void:
	var d := int(delay * RATE)
	var src := buf.duplicate()
	for k in range(1, taps + 1):
		var g := pow(gain, k)
		for i in range(d * k, buf.size()):
			buf[i] += src[i - d * k] * g


# --- Треки --------------------------------------------------------------------------

## Меню: лютня перебирает аккорды, бас на сильные доли, редкая флейта с паузами.
static func _main_menu(b: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	for i in MENU_CHORDS.size() + 1:      # +1 такт уходит в склейку петли
		var chord: Array = MENU_CHORDS[i % MENU_CHORDS.size()]
		var t0 := i * BAR
		pluck(b, rng, t0, SfxSynth.midi_hz(chord[0] - 12), 0.32, 2.6, 0.35)
		pluck(b, rng, t0 + BAR * 0.5, SfxSynth.midi_hz(chord[0] - 12), 0.2, 2.0, 0.35)
		for k in ARPEGGIO.size():
			var idx: int = ARPEGGIO[k]
			var note: int = chord[0] + 12 if idx == 3 else chord[idx]
			var amp := 0.2 if k == 0 else 0.13
			pluck(b, rng, t0 + k * BAR / ARPEGGIO.size(), SfxSynth.midi_hz(note), amp, 1.6, 0.6)
		# Флейта — через такт, короткая фраза из 2–3 нот и тишина.
		if i % 2 == 1:
			var t := t0 + 0.5
			for n in rng.randi_range(2, 3):
				var note: int = MINOR_SCALE[rng.randi_range(0, MINOR_SCALE.size() - 1)]
				var dur: float = [0.5, 1.0, 1.0][rng.randi_range(0, 2)]
				_flute(b, t, dur, SfxSynth.midi_hz(note), 0.07)
				t += dur


## Таверна: тихий перебор гитары раз в полтакта, бас, редкие высокие ноты и скрип дерева.
static func _tavern(b: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var length: float = LENGTHS[&"tavern_ambient"]
	var bars := int(length / BAR)
	for i in bars + 1:
		var chord: Array = TAVERN_CHORDS[i % TAVERN_CHORDS.size()]
		var t0 := i * BAR
		pluck(b, rng, t0, SfxSynth.midi_hz(chord[0] - 12), 0.28, 3.0, 0.3)
		_strum(b, rng, t0 + 0.02, chord, 0.11)
		_strum(b, rng, t0 + BAR * 0.5, chord, 0.07)
		if rng.randf() < 0.6:
			var f := SfxSynth.midi_hz(PENTATONIC[rng.randi_range(0, PENTATONIC.size() - 1)] + 12)
			pluck(b, rng, t0 + rng.randf_range(1.0, 3.5), f, 0.06, 1.4, 0.5)
	for k in 2:
		_creak(b, rng, rng.randf_range(0.5, length - 1.0))


## Безумие (слой поверх таверны): редкие расстроенные колокольчики и шёпот, без гула.
static func _madness(b: PackedFloat32Array, rng: RandomNumberGenerator, length: float) -> void:
	var t := rng.randf_range(0.2, 0.8)
	while t < length:
		var f := SfxSynth.midi_hz(MADNESS_NOTES[rng.randi_range(0, MADNESS_NOTES.size() - 1)])
		# Чуть «мимо» ноты — как расстроенная музыкальная шкатулка.
		SfxSynth.bell(b, t, f * rng.randf_range(0.985, 1.015), 0.09, 0.5)
		t += rng.randf_range(1.2, 2.6)
	for k in 5:
		# «Обратный» шёпот: нарастает и обрывается.
		var dur := rng.randf_range(0.5, 0.9)
		SfxSynth.noise(b, rng, rng.randf_range(0.0, length - dur), dur, 0.05, dur, 10.0,
				1500.0, 3500.0)
	# Низкий щипок раз в такт — сердцебиение.
	for i in int(length / BAR) + 1:
		pluck(b, rng, i * BAR, SfxSynth.midi_hz(42), 0.18, 1.2, 0.25)
		pluck(b, rng, i * BAR + 0.35, SfxSynth.midi_hz(42), 0.12, 1.0, 0.25)


static func _victory(b: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var run := [60, 64, 67, 72, 76, 79]
	for k in run.size():
		pluck(b, rng, k * 0.11, SfxSynth.midi_hz(run[k]), 0.22, 1.8, 0.7)
	for n in [72, 76, 79, 84]:
		pluck(b, rng, 0.9, SfxSynth.midi_hz(n), 0.16, 2.4, 0.6)
	SfxSynth.bell(b, 0.9, SfxSynth.midi_hz(84), 0.12, 0.6)
	pluck(b, rng, 0.9, SfxSynth.midi_hz(48), 0.3, 2.4, 0.3)


static func _defeat(b: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var notes := [[57, 0.0], [53, 0.9], [52, 1.8], [45, 2.7]]
	for n: Array in notes:
		pluck(b, rng, n[1], SfxSynth.midi_hz(n[0]), 0.22, 2.2, 0.4)
		pluck(b, rng, n[1], SfxSynth.midi_hz(n[0] - 12), 0.18, 2.2, 0.3)
	SfxSynth.bell(b, 2.7, SfxSynth.midi_hz(45), 0.1, 0.9)


# --- Инструменты --------------------------------------------------------------------

## Щипок струны (Карплус — Стронг): шумовой импульс в линии задержки с усреднением.
## decay — за сколько секунд звук стихает примерно в 1000 раз; brightness 0..1 — яркость
## атаки (меньше — мягче, «нейлон»).
static func pluck(b: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, f: float,
		amp: float, decay: float, brightness: float) -> void:
	var start := int(t0 * RATE)
	var n := mini(int(decay * RATE), b.size() - start)
	if n <= 0:
		return
	var period := maxi(2, int(round(RATE / f)))
	var line := PackedFloat32Array()
	line.resize(period)
	var lp := 0.0
	for i in period:
		lp += brightness * (rng.randf_range(-1.0, 1.0) - lp)
		line[i] = lp
	# Потеря за проход по струне — чтобы стихнуть за decay (−60 дБ).
	var loss := pow(0.001, float(period) / (decay * RATE))
	var tail := maxf(n * 0.1, 1.0)
	var idx := 0
	for i in n:
		var cur := line[idx]
		var nxt := line[(idx + 1) % period]
		line[idx] = (cur + nxt) * 0.5 * loss
		b[start + i] += amp * cur * minf((n - i) / tail, 1.0)
		idx = (idx + 1) % period


## Перебор аккорда снизу вверх.
static func _strum(b: PackedFloat32Array, rng: RandomNumberGenerator, t: float, chord: Array,
		amp: float) -> void:
	for k in chord.size():
		pluck(b, rng, t + k * 0.035, SfxSynth.midi_hz(chord[k]), amp, 2.2, 0.45)


## Мягкая флейта: синус с плавной атакой и лёгким вибрато (без расстройки — без биений).
static func _flute(b: PackedFloat32Array, t: float, dur: float, f: float, amp: float) -> void:
	SfxSynth.voice(b, t, dur, f, f, amp, 0.12, 0.3, Wave.SINE, 4.5, 0.004)
	SfxSynth.voice(b, t, dur, f * 2.0, f * 2.0, amp * 0.12, 0.12, 0.3, Wave.SINE, 4.5, 0.004)


## Скрип дерева: частые мелкие щелчки.
static func _creak(b: PackedFloat32Array, rng: RandomNumberGenerator, t: float) -> void:
	var count := rng.randi_range(18, 30)
	var gap := rng.randf_range(0.012, 0.02)
	for k in count:
		var env := sin(PI * float(k) / count)
		SfxSynth.noise(b, rng, t + k * gap * rng.randf_range(0.9, 1.1), 0.006, 0.08 * env, 0.0,
				0.002, 300.0, 1200.0)
