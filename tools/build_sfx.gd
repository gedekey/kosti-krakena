extends SceneTree
## Сборка процедурных звуков и музыки-заглушек (М12): SfxSynth / MusicSynth → WAV
## в audio/sfx/<звук>.wav и audio/music/<трек>.wav. Seed каждого файла — от его имени,
## так что пересборка даёт те же файлы.
##
##   godot --headless --path . -s res://tools/build_sfx.gd [-- --only=<имя>]
## Обёртка с импортом — tools/build_sfx.ps1.


func _init() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SoundCatalog.SFX_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SoundCatalog.MUSIC_DIR))
	var ok := true
	for cue in SoundCatalog.cues():
		if only == "" or only == String(cue):
			ok = _write(SfxSynth.render(cue, _rng(cue)), SoundCatalog.SFX_DIR, cue) and ok
	for track in SoundCatalog.TRACKS:
		if only == "" or only == String(track):
			ok = _write(MusicSynth.render(track, _rng(track)), SoundCatalog.MUSIC_DIR, track) and ok
	quit(0 if ok else 1)


static func _rng(name: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(name))
	return rng


func _write(samples: PackedFloat32Array, dir: String, name: StringName) -> bool:
	if samples.is_empty():
		push_error("Пустой звук: %s" % name)
		return false
	var path := ProjectSettings.globalize_path(dir.path_join("%s.wav" % name))
	var err := SfxSynth.to_stream(samples).save_to_wav(path)
	if err != OK:
		push_error("Не записан %s: %s" % [path, error_string(err)])
		return false
	print("%s: %.2f с" % [name, samples.size() / float(SoundBalance.SAMPLE_RATE)])
	return true
