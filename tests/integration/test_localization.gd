extends GutTest
## М7: переключение языка в рантайме через Settings.

var _saved_locale: String


func before_each() -> void:
	_saved_locale = Settings.get_value(&"locale")


func after_each() -> void:
	Settings.set_value(&"locale", _saved_locale)


func test_switching_locale_changes_translations() -> void:
	Settings.set_value(&"locale", "en")
	assert_eq(TranslationServer.get_locale(), "en")
	assert_eq(tr("HELLO_KRAKEN"), "Hello, Kraken")
	Settings.set_value(&"locale", "ru")
	assert_eq(TranslationServer.get_locale(), "ru")
	assert_eq(tr("HELLO_KRAKEN"), "Привет, Кракен")


func test_switching_locale_emits_event() -> void:
	Settings.set_value(&"locale", "en")
	watch_signals(Events)
	Settings.set_value(&"locale", "ru")
	assert_signal_emitted_with_parameters(Events, "locale_changed", ["ru"])


func test_labels_retranslate_at_runtime() -> void:
	Settings.set_value(&"locale", "en")
	var label: Label = add_child_autofree(Label.new())
	label.text = "LANG_EN"
	var title: Label = add_child_autofree(Label.new())
	title.text = "FONT_TEST_TITLE"
	await wait_process_frames(1)
	Settings.set_value(&"locale", "ru")
	await wait_process_frames(1)
	assert_eq(title.get_text(), "FONT_TEST_TITLE", "ключ хранится, перевод — при отрисовке")
	assert_eq(title.atr("FONT_TEST_TITLE"), "Шрифт и языки")


func test_font_test_scene_builds_in_both_languages() -> void:
	for locale in ["ru", "en"]:
		Settings.set_value(&"locale", locale)
		var screen: Control = add_child_autofree(load("res://scenes/font_test.tscn").instantiate())
		await wait_process_frames(1)
		assert_gt(screen.get_child_count(), 0, locale)
