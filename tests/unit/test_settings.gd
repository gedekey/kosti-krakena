extends GutTest
## М11: настройки — значения, проверка, сохранение в файл и чтение обратно.

const SettingsScript := preload("res://autoload/settings.gd")
const PATH := "user://test_settings_m11.cfg"


func _settings(path := PATH) -> Node:
	var s: Node = autofree(SettingsScript.new())
	s.save_path = path
	return s


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func test_defaults() -> void:
	var s := _settings("")
	for key: StringName in SettingsScript.DEFAULTS:
		assert_eq(s.get_value(key), SettingsScript.DEFAULTS[key], String(key))


func test_values_are_sanitized() -> void:
	var s := _settings("")
	s.set_value(&"music_volume", 1.7)
	assert_eq(s.get_value(&"music_volume"), 1.0)
	s.set_value(&"sfx_volume", -3)
	assert_eq(s.get_value(&"sfx_volume"), 0.0)
	s.set_value(&"bot_speed", 100.0)
	assert_eq(s.get_value(&"bot_speed"), SettingsScript.BOT_SPEED_MAX)
	s.set_value(&"palifico", "yes")
	assert_eq(s.get_value(&"palifico"), true, "не bool — пропускаем")
	s.set_value(&"locale", "de")
	assert_eq(s.get_value(&"locale"), "", "неизвестный язык — пропускаем")
	s.set_value(&"opponent_count", 99)
	assert_eq(s.get_value(&"opponent_count"), MatchController.MAX_PLAYERS - 1)
	s.set_value(&"opponents", [&"sailor", 5, "witch"])
	assert_eq(s.get_value(&"opponents"), ["sailor", "witch"])


func test_set_value_emits_changed_once() -> void:
	var s := _settings("")
	watch_signals(s)
	s.set_value(&"calza", false)
	s.set_value(&"calza", false)
	assert_signal_emit_count(s, "changed", 1)


func test_save_and_load_round_trip() -> void:
	var a := _settings()
	a.set_value(&"music_volume", 0.3)
	a.set_value(&"bot_speed", 2.0)
	a.set_value(&"palifico", false)
	a.set_value(&"locale", "en")
	a.set_value(&"player_portrait", "player3")
	a.set_value(&"opponents_random", false)
	a.set_value(&"opponents", ["deep_one", "sailor"])
	assert_eq(a.save(), OK)
	var b := _settings()
	b.load_saved()
	assert_almost_eq(b.get_value(&"music_volume"), 0.3, 0.0001)
	assert_eq(b.get_value(&"bot_speed"), 2.0)
	assert_eq(b.get_value(&"palifico"), false)
	assert_eq(b.get_value(&"calza"), true)
	assert_eq(b.get_value(&"locale"), "en")
	assert_eq(b.get_value(&"player_portrait"), "player3")
	assert_eq(b.get_value(&"opponents_random"), false)
	assert_eq(b.get_value(&"opponents"), ["deep_one", "sailor"])
	TranslationServer.set_locale(Settings.resolve_locale())   # load_saved переключил язык


func test_broken_file_values_are_ignored() -> void:
	var file := ConfigFile.new()
	file.set_value(SettingsScript.SECTION, "music_volume", "loud")
	file.set_value(SettingsScript.SECTION, "sfx_volume", 0.5)
	file.set_value(SettingsScript.SECTION, "unknown_key", 1)
	file.save(PATH)
	var s := _settings()
	s.load_saved()
	assert_eq(s.get_value(&"music_volume"), SettingsScript.DEFAULTS[&"music_volume"])
	assert_eq(s.get_value(&"sfx_volume"), 0.5)


func test_missing_file_keeps_defaults() -> void:
	var s := _settings("user://no_such_settings_m11.cfg")
	s.load_saved()
	assert_eq(s.get_value(&"bot_speed"), 1.0)


func test_empty_path_never_writes() -> void:
	var s := _settings("")
	s.set_value(&"sfx_volume", 0.2)
	assert_eq(s.save(), OK)
	assert_false(FileAccess.file_exists(PATH))


func test_reset_keys_only_touches_given_keys() -> void:
	var s := _settings("")
	s.set_value(&"bot_speed", 3.0)
	s.set_value(&"opponents", ["witch"])
	s.reset_keys([&"bot_speed"])
	assert_eq(s.get_value(&"bot_speed"), 1.0)
	assert_eq(s.get_value(&"opponents"), ["witch"])
	s.reset_to_defaults()
	assert_eq(s.get_value(&"opponents"), [])
	assert_true(SettingsScript.DEFAULTS[&"opponents"].is_empty(), "умолчания не испорчены")


func test_global_settings_do_not_touch_disk_in_tests() -> void:
	assert_eq(Settings.save_path, "", "pre_run_script отключил сохранение")
	assert_eq(Stats.save_path, "")
	assert_true(ScreenNav.test_mode)
