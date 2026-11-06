class_name MusicSynth
extends RefCounted
## Музыка-заглушки (М12), пока автор не сгенерировал свою по ART_PROMPTS.md §3.
##
## Чистая логика: render(track, rng) → сэмплы. Петли (LOOPED) бесшовные: рендерим с запасом
## SoundBalance.LOOP_FOLD и склеиваем хвост с началом. Стинги — без петли.

const RATE := SoundBalance.SAMPLE_RATE
const Wave := SfxSynth.Wave

## Длины треков (секунды). Петли короткие — это заглушки.
const LENGTHS := {
	&"main_menu": 16.0,
	&"tavern_ambient": 24.0,
	&"madness_layer": 12.0,
	&"victory": 3.5,
	&"defeat": 4.5,
}
const LOOPED: Array[StringName] = [&"main_menu", &"tavern_ambient", &"madness_layer"]

## Ля минор: аккорды по 4 с (Am | F | G | E — E тянет обратно к Am).
const MENU_CHORDS := [[57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 56, 59]]
## Ритм мелодии в долях секунды на такт (сумма — 4 с).
const MENU_RHYTHM := [0.75, 0.25, 0.5, 0.5, 0.75, 0.25, 1.0]
const PENTATONIC := [57, 60, 62, 64, 67, 69, 72]


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
		&"tavern_ambient": _tavern(b, rng, length)
		&"madness_layer": _madness(b, rng, length)
		&"victory": _victory(b, rng)
		&"defeat": _defeat(b, rng)
	if looped:
		b = fold_loop(b, int(length * RATE))
	return SfxSynth.finish(b, SoundBalance.MUSIC_PEAK, not looped)


## Бесшовная петля длиной n: последние сэмплы после n плавно вливаются в начало.
static func fold_loop(buf: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var tail := buf.size() - n
	for i in tail:
		var k := float(i) / tail
		buf[i] = buf[i] * k + buf[n + i] * (1.0 - k)
	buf.resize(n)
	return buf


# --- Треки --------------------------------------------------------------------------

## Меню: грустная «шанти» — аккордеон аккордами и скрипка.
static func _main_menu(b: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var bar := 4.0
	for i in MENU_CHORDS.size() + 1:      # +1 такт уходит в склейку петли
		var chord: Array = MENU_CHORDS[i % MENU_CHORDS.size()]
		var t0 := i * bar
		_reed(b, t0, bar + 0.3, SfxSynth.midi_hz(chord[0] - 12), 0.18)
		for n: int in chord:
			# Аккордеон «дышит»: два меха на такт.
			_reed(b, t0, bar * 0.5 + 0.1, SfxSynth.midi_hz(n), 0.07)
			_reed(b, t0 + bar * 0.5, bar * 0.5 + 0.1, SfxSynth.midi_hz(n), 0.06)
		var t := t0
		for d: float in MENU_RHYTHM:
			var note: int = chord[rng.randi_range(0, chord.size() - 1)] + 12
			if rng.randf() < 0.3:
				note = PENTATONIC[rng.randi_range(0, PENTATONIC.size() - 1)] + 12
			SfxSynth.voice(b, t, d * 0.95, SfxSynth.midi_hz(note), SfxSynth.midi_hz(note),
					0.16, 0.04, 0.12, Wave.TRIANGLE, 5.5, 0.004)
			t += d


## Таверна: низкий гул, редкие «виолончельные» ноты, щипки и скрип дерева.
static func _tavern(b: PackedFloat32Array, rng: RandomNumberGenerator, length: float) -> void:
	var total := b.size() / float(RATE)
	SfxSynth.voice(b, 0.0, total, 55.0, 55.0, 0.22, 0.01, 0.01, Wave.TRIANGLE)
	SfxSynth.voice(b, 0.0, total, 82.41, 82.41, 0.1, 0.01, 0.01, Wave.TRIANGLE)
	var cello := [45, 41, 48, 40]
	var step := length / cello.size()
	for i in cello.size() + 1:
		var f := SfxSynth.midi_hz(cello[i % cello.size()])
		SfxSynth.voice(b, i * step, step + 1.0, f, f, 0.14, 1.5, 2.0, Wave.SAW, 4.5, 0.003)
		SfxSynth.voice(b, i * step, step + 1.0, f, f, 0.12, 1.5, 2.0, Wave.TRIANGLE)
	var t := rng.randf_range(0.3, 1.0)
	while t < length:
		var f := SfxSynth.midi_hz(PENTATONIC[rng.randi_range(0, PENTATONIC.size() - 1)])
		SfxSynth.tone(b, t, 1.2, f, f, rng.randf_range(0.06, 0.12), 0.004, 0.35, Wave.TRIANGLE)
		t += rng.randf_range(0.8, 2.2)
	for k in 3:
		_creak(b, rng, rng.randf_range(0.5, length - 1.0))


## Безумие: биения, тритон, «хор» и шёпот задом наперёд.
static func _madness(b: PackedFloat32Array, rng: RandomNumberGenerator, length: float) -> void:
	var total := b.size() / float(RATE)
	for f in [110.0, 110.7, 155.56, 156.3]:
		SfxSynth.voice(b, 0.0, total, f, f, 0.12, 0.01, 0.01, Wave.TRIANGLE)
	SfxSynth.voice(b, 0.0, total, 52.0, 52.0, 0.25, 0.01, 0.01)
	for f in [220.0, 233.08, 329.63]:
		SfxSynth.voice(b, 0.0, total, f, f, 0.05, 0.01, 0.01, Wave.TRIANGLE, 0.3, 0.01)
	for k in 8:
		# «Обратный» шёпот: нарастает и обрывается.
		var dur := rng.randf_range(0.5, 0.9)
		SfxSynth.noise(b, rng, rng.randf_range(0.0, length - dur), dur, 0.12, dur, 10.0,
				1500.0, 3500.0)


static func _victory(b: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var notes := [[67, 0.0, 0.15], [72, 0.15, 0.15], [76, 0.3, 0.15], [79, 0.45, 0.6]]
	for n: Array in notes:
		_brass(b, n[1], n[2], SfxSynth.midi_hz(n[0]), 0.2)
	for n in [72, 76, 79, 84]:
		_brass(b, 1.1, 2.2, SfxSynth.midi_hz(n), 0.12)
	for t in [0.0, 0.45, 1.1]:
		SfxSynth.thump(b, rng, t, 0.6, 110.0, 55.0, 0.08)
		SfxSynth.noise(b, rng, t, 0.2, 0.25, 0.0, 0.06, 1500.0, 6000.0)


static func _defeat(b: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var horn := [[45, 0.0, 1.3], [41, 1.2, 1.3], [40, 2.4, 2.0]]
	for n: Array in horn:
		var f := SfxSynth.midi_hz(n[0])
		SfxSynth.voice(b, n[1], n[2], f, f, 0.18, 0.15, 0.8, Wave.SAW, 4.0, 0.003)
		SfxSynth.voice(b, n[1], n[2], f * 0.5, f * 0.5, 0.25, 0.15, 0.8, Wave.TRIANGLE)
	SfxSynth.voice(b, 0.0, 4.4, SfxSynth.midi_hz(57), SfxSynth.midi_hz(52), 0.12, 0.3, 1.2,
			Wave.TRIANGLE, 5.0, 0.005)
	SfxSynth.noise(b, rng, 0.0, 4.4, 0.4, 1.0, 3.0, 20.0, 200.0)


# --- Инструменты --------------------------------------------------------------------

## «Язычок» аккордеона: два чуть расстроенных треугольника и немного меандра.
static func _reed(b: PackedFloat32Array, t: float, dur: float, f: float, amp: float) -> void:
	SfxSynth.voice(b, t, dur, f, f, amp, 0.08, 0.15, Wave.TRIANGLE)
	SfxSynth.voice(b, t, dur, f * 1.004, f * 1.004, amp * 0.7, 0.08, 0.15, Wave.TRIANGLE)
	SfxSynth.voice(b, t, dur, f, f, amp * 0.2, 0.08, 0.15, Wave.SQUARE)


static func _brass(b: PackedFloat32Array, t: float, dur: float, f: float, amp: float) -> void:
	SfxSynth.voice(b, t, dur, f, f, amp, 0.02, dur * 0.4, Wave.SQUARE, 5.0, 0.003)
	SfxSynth.voice(b, t, dur, f, f, amp * 1.5, 0.02, dur * 0.4, Wave.TRIANGLE)


## Скрип дерева: частые мелкие щелчки.
static func _creak(b: PackedFloat32Array, rng: RandomNumberGenerator, t: float) -> void:
	var count := rng.randi_range(18, 30)
	var gap := rng.randf_range(0.012, 0.02)
	for k in count:
		var env := sin(PI * float(k) / count)
		SfxSynth.noise(b, rng, t + k * gap * rng.randf_range(0.9, 1.1), 0.006, 0.12 * env, 0.0,
				0.002, 300.0, 1200.0)
