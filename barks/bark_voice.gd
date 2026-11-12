class_name BarkVoice
extends RefCounted
## «Бормотание» реплик (М24, DESIGN.md §8д): короткие слоги с тембром персонажа.
##
## Тембр — параметр персонажа (высота, форма волны, дрожь голоса, хрип, длина слога).
## Слоги синтезируются процедурно (как SFX М12): render_syllable(character, rng) → сэмплы.
## Без нод; RNG — переданный (одинаковый seed → тот же слог).

## Тембр: hz — высота, wave — SfxSynth.Wave, vib — частота дрожи (Гц) и её глубина,
## breath — доля шума (хрип / шёпот), dur — длина слога (сек), spread — разброс высоты
## между слогами (полутоны).
const TIMBRES := {
	&"scholar": {"hz": 170.0, "wave": SfxSynth.Wave.TRIANGLE, "vib": [5.0, 0.01], "breath": 0.05, "dur": 0.08, "spread": 2.0},
	&"occultist": {"hz": 140.0, "wave": SfxSynth.Wave.SAW, "vib": [7.0, 0.04], "breath": 0.15, "dur": 0.09, "spread": 4.0},
	&"sailor": {"hz": 115.0, "wave": SfxSynth.Wave.SQUARE, "vib": [0.0, 0.0], "breath": 0.1, "dur": 0.07, "spread": 3.0},
	&"witch": {"hz": 270.0, "wave": SfxSynth.Wave.TRIANGLE, "vib": [9.0, 0.05], "breath": 0.1, "dur": 0.08, "spread": 5.0},
	&"plague_cultist": {"hz": 150.0, "wave": SfxSynth.Wave.SAW, "vib": [4.0, 0.03], "breath": 0.35, "dur": 0.08, "spread": 6.0},
	&"drowned": {"hz": 85.0, "wave": SfxSynth.Wave.SINE, "vib": [24.0, 0.12], "breath": 0.2, "dur": 0.11, "spread": 2.0},
	&"deep_one": {"hz": 65.0, "wave": SfxSynth.Wave.SAW, "vib": [3.0, 0.03], "breath": 0.2, "dur": 0.12, "spread": 1.5},
	&"ulits": {"hz": 125.0, "wave": SfxSynth.Wave.SINE, "vib": [2.0, 0.02], "breath": 0.05, "dur": 0.16, "spread": 1.0},
	&"ichthyander": {"hz": 210.0, "wave": SfxSynth.Wave.SQUARE, "vib": [14.0, 0.06], "breath": 0.1, "dur": 0.06, "spread": 4.0},
	&"omen": {"hz": 330.0, "wave": SfxSynth.Wave.SINE, "vib": [6.0, 0.02], "breath": 0.6, "dur": 0.09, "spread": 2.0},
	&"craber": {"hz": 185.0, "wave": SfxSynth.Wave.SQUARE, "vib": [0.0, 0.0], "breath": 0.25, "dur": 0.045, "spread": 3.0},
	&"horror_master": {"hz": 100.0, "wave": SfxSynth.Wave.TRIANGLE, "vib": [0.0, 0.0], "breath": 0.05, "dur": 0.1, "spread": 1.0},
	## Старый Хоб — для сцен кампании (М23).
	&"hob": {"hz": 90.0, "wave": SfxSynth.Wave.SINE, "vib": [3.0, 0.02], "breath": 0.15, "dur": 0.11, "spread": 2.0},
}
const DEFAULT_TIMBRE := {"hz": 150.0, "wave": SfxSynth.Wave.TRIANGLE, "vib": [0.0, 0.0], "breath": 0.1, "dur": 0.08, "spread": 3.0}

## Пик слога после нормализации: бормотание тише остальных звуков.
const PEAK := 0.45
## Сколько разных слогов у персонажа (чередуются случайно).
const SYLLABLES := 4
## Не чаще одного слога за столько секунд печати.
const SYLLABLE_GAP := 0.07


static func timbre(character: StringName) -> Dictionary:
	return TIMBRES.get(character, DEFAULT_TIMBRE)


## Один слог: нота с подъёмом-спадом высоты, второй гармоникой и хрипом.
static func render_syllable(character: StringName, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var t := timbre(character)
	var dur: float = t["dur"] * rng.randf_range(0.85, 1.2)
	var hz: float = t["hz"] * pow(2.0, rng.randf_range(-t["spread"], t["spread"]) / 12.0)
	var glide := rng.randf_range(0.9, 1.1)
	var vib: Array = t["vib"]
	var buf := SfxSynth.empty(dur + 0.02)
	SfxSynth.voice(buf, 0.0, dur, hz, hz * glide, 0.8, 0.008, dur * 0.4, t["wave"],
			vib[0], vib[1])
	SfxSynth.voice(buf, 0.0, dur, hz * 2.0, hz * 2.0 * glide, 0.25, 0.01, dur * 0.5,
			SfxSynth.Wave.SINE, vib[0], vib[1])
	if t["breath"] > 0.0:
		SfxSynth.noise(buf, rng, 0.0, dur, 0.8 * t["breath"], 0.005, dur * 0.6,
				hz * 2.0, minf(hz * 16.0, 7000.0))
	return SfxSynth.finish(buf, PEAK)


## Буква начинает слог (гласная RU / EN) — на ней звучит бормотание.
static func is_syllable(ch: String) -> bool:
	return "aeiouyаеёиоуыэюя".contains(ch.to_lower())
