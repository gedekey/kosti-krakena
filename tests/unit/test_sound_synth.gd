extends GutTest
## М12: процедурные звуки и музыка-заглушки. Детерминизм, диапазон, без хвоста тишины,
## бесшовные петли, где ищутся файлы (сгенерированные автором — первыми).

const RATE := SoundBalance.SAMPLE_RATE


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_every_cue_renders_normalized_short_sound() -> void:
	for cue in SfxSynth.CUES:
		var buf := SfxSynth.render(cue, _rng(7))
		assert_gt(buf.size(), int(0.02 * RATE), "%s: не пустой" % cue)
		assert_lt(buf.size(), 4 * RATE, "%s: короткий" % cue)
		assert_almost_eq(SfxSynth.peak_of(buf), SoundBalance.SFX_PEAK, 0.001, "%s: пик" % cue)
		assert_eq(buf[buf.size() - 1], 0.0, "%s: гаснет в ноль, без щелчка" % cue)
		# Нет хвоста тишины: в последних 50 мс ещё что-то звучит.
		var tail := buf.slice(maxi(0, buf.size() - int(0.05 * RATE)))
		assert_gt(SfxSynth.peak_of(tail), SoundBalance.SILENCE * 0.5,
				"%s: без тишины в конце" % cue)


func test_render_is_deterministic_per_seed() -> void:
	for cue in [&"dice_shake", &"whisper_abyss", &"cup_slam"]:
		assert_eq(SfxSynth.render(cue, _rng(3)), SfxSynth.render(cue, _rng(3)),
				"%s: тот же seed" % cue)
		assert_ne(SfxSynth.render(cue, _rng(3)), SfxSynth.render(cue, _rng(4)),
				"%s: другой seed" % cue)


func test_unknown_cue_is_empty() -> void:
	assert_eq(SfxSynth.render(&"nope", _rng(1)).size(), 0)
	assert_eq(MusicSynth.render(&"nope", _rng(1)).size(), 0)


func test_stream_is_16_bit_mono() -> void:
	var buf := SfxSynth.render(&"ui_click", _rng(1))
	var stream := SfxSynth.to_stream(buf)
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_false(stream.stereo)
	assert_eq(stream.mix_rate, RATE)
	assert_eq(stream.data.size(), buf.size() * 2)
	assert_almost_eq(stream.data.decode_s16(2) / 32767.0, buf[1], 0.0001)


func test_fold_loop_joins_end_to_start() -> void:
	# Линейный рост: после склейки конец петли переходит в начало без скачка.
	var n := 100
	var buf := PackedFloat32Array()
	for i in n + 20:
		buf.append(float(i) / n)
	var out := MusicSynth.fold_loop(buf, n)
	assert_eq(out.size(), n)
	assert_almost_eq(out[0], 1.0, 0.001, "начало = продолжение конца")
	assert_almost_eq(out[n - 1], 0.99, 0.001)


func test_music_loop_is_seamless_and_stings_are_not_looped() -> void:
	var buf := MusicSynth.render(&"madness_layer", _rng(5))
	assert_eq(buf.size(), int(MusicSynth.LENGTHS[&"madness_layer"] * RATE), "точная длина петли")
	assert_almost_eq(SfxSynth.peak_of(buf), SoundBalance.MUSIC_PEAK, 0.001)
	var max_step := 0.0
	for i in range(1, buf.size()):
		max_step = maxf(max_step, absf(buf[i] - buf[i - 1]))
	assert_lt(absf(buf[0] - buf[buf.size() - 1]), max_step * 1.5, "шов не громче обычного шага")
	assert_true(MusicSynth.is_looped(&"tavern_ambient"))
	assert_true(MusicSynth.is_looped(&"main_menu"))
	assert_false(MusicSynth.is_looped(&"victory"))
	assert_false(MusicSynth.is_looped(&"defeat"))


func test_catalog_prefers_generated_assets() -> void:
	var none := func(_p: String) -> bool: return false
	assert_eq(SoundCatalog.sfx_path(&"cup_slam", none), "res://audio/sfx/cup_slam.wav")
	assert_eq(SoundCatalog.music_path(&"victory", none), "res://audio/music/victory.wav")
	var has_ogg := func(p: String) -> bool: return p == "res://assets/generated/sfx/cup_slam.ogg"
	assert_eq(SoundCatalog.sfx_path(&"cup_slam", has_ogg), "res://assets/generated/sfx/cup_slam.ogg")
	var has_music := func(p: String) -> bool: return p.ends_with("music/tavern_ambient.wav")
	assert_eq(SoundCatalog.music_path(&"tavern_ambient", has_music),
			"res://assets/generated/music/tavern_ambient.wav")


func test_every_sound_is_built_and_has_volume() -> void:
	for cue in SoundCatalog.cues():
		var path := "res://audio/sfx/%s.wav" % cue
		assert_true(ResourceLoader.exists(path), "%s собран (tools/build_sfx.ps1)" % path)
		assert_true(SoundBalance.CUE_DB.has(cue), "%s: громкость в SoundBalance" % cue)
	for track in SoundCatalog.TRACKS:
		var path := "res://audio/music/%s.wav" % track
		assert_true(ResourceLoader.exists(path), "%s собран" % path)
		assert_true(MusicSynth.LENGTHS.has(track))
