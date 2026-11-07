extends GutTest
## М11: главное меню, выбор соперников, настройки, статистика. Переходы — через ScreenNav
## (в тестах сцена не меняется, переходы пишутся в history).

const MainMenu := preload("res://scenes/main_menu.tscn")
const Opponents := preload("res://scenes/opponents.tscn")
const SettingsScene := preload("res://scenes/settings.tscn")
const StatsScene := preload("res://scenes/stats.tscn")
const TableScene := preload("res://scenes/table.tscn")
const AchievementsScene := preload("res://scenes/achievements.tscn")

var _saved_locale: String


func before_each() -> void:
	_saved_locale = Settings.get_value(&"locale")
	Settings.reset_keys([&"music_volume", &"sfx_volume", &"bot_speed", &"palifico", &"calza",
			&"show_dice_counts", &"player_portrait", &"opponents_random", &"opponent_count", &"opponents"])
	Stats.reset()
	ScreenNav.history.clear()
	MatchSetup.pending = null


func after_each() -> void:
	Settings.set_value(&"locale", _saved_locale)
	Settings.reset_to_defaults()
	Stats.reset()
	MatchSetup.pending = null


func _screen(scene: PackedScene) -> Control:
	return add_child_autofree(scene.instantiate())


func _esc() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	return e


# --- Главное меню ------------------------------------------------------------------

func test_main_scene_is_main_menu() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), ScreenNav.MAIN_MENU)


func test_main_menu_buttons_navigate() -> void:
	var menu := _screen(MainMenu)
	menu.play_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.OPPONENTS)
	menu.stats_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.STATS)
	menu.settings_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.SETTINGS)
	assert_true(menu.quit_button.visible, "на ПК выход есть")
	menu.quit_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.QUIT)


func test_main_menu_escape_does_nothing() -> void:
	var menu := _screen(MainMenu)
	menu._unhandled_input(_esc())
	assert_eq(ScreenNav.history.size(), 0)


func test_table_menu_button_returns_to_main_menu() -> void:
	Rng.set_master_seed(5)
	var table := _screen(TableScene)
	table._end_panel.menu_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.MAIN_MENU)


func test_scene_paths_exist() -> void:
	for path in [ScreenNav.MAIN_MENU, ScreenNav.OPPONENTS, ScreenNav.SETTINGS, ScreenNav.STATS,
			ScreenNav.TABLE, ScreenNav.ACHIEVEMENTS]:
		assert_true(ResourceLoader.exists(path), path)


# --- Выбор соперников --------------------------------------------------------------

func test_random_mode_by_default_starts_three_random_opponents() -> void:
	var s := _screen(Opponents)
	assert_true(s.is_random())
	assert_eq(s.cards.size(), BotRoster.PATHS.size())
	for card: OpponentCard in s.cards:
		assert_true(card.disabled, "в случайном режиме карточки не нажимаются")
	s.start_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.TABLE)
	var setup := MatchSetup.pending
	assert_not_null(setup)
	assert_true(setup.opponents.is_empty(), "соперников выберет стол")
	assert_eq(setup.opponent_count, MatchSetup.DEFAULT_OPPONENTS)


func test_random_count_is_limited_to_1_5() -> void:
	var s := _screen(Opponents)
	for i in 10:
		s.count_stepper.left_arrow.pressed.emit()
	assert_eq(s.opponent_count(), 1)
	assert_true(s.count_stepper.left_arrow.disabled)
	for i in 10:
		s.count_stepper.right_arrow.pressed.emit()
	assert_eq(s.opponent_count(), 5)
	assert_true(s.count_stepper.right_arrow.disabled)
	s.start()
	assert_eq(MatchSetup.pending.opponent_count, 5)


func test_manual_pick_keeps_order_and_limit() -> void:
	var s := _screen(Opponents)
	s.manual_button.pressed.emit()
	assert_false(s.is_random())
	assert_true(s.start_button.disabled, "никого не выбрано")
	assert_false(s.count_stepper.visible)
	# Выбираем всех по очереди с конца: в стол попадут первые пять выбранных.
	for i in range(s.cards.size() - 1, -1, -1):
		var card: OpponentCard = s.cards[i]
		if not card.disabled:
			card.pressed.emit()
	assert_eq(s.picked().size(), 5)
	var expected: Array[StringName] = []
	for i in range(s.cards.size() - 1, s.cards.size() - 6, -1):
		expected.append(s.cards[i].personality.id)
	assert_eq(s.picked(), expected)
	assert_true(s.cards[0].disabled and s.cards[1].disabled, "больше пяти не выбрать")
	assert_eq(s.cards[s.cards.size() - 1].order(), 1)
	# Снять выбор — номера сдвигаются.
	s.cards[s.cards.size() - 1].pressed.emit()
	assert_eq(s.picked().size(), 4)
	assert_eq(s.cards[s.cards.size() - 2].order(), 1)
	assert_false(s.cards[0].disabled)
	s.start_button.pressed.emit()
	var setup := MatchSetup.pending
	assert_eq(setup.opponents, s.picked())


func test_player_portrait_cycles_and_reaches_table() -> void:
	var s := _screen(Opponents)
	assert_eq(s.player_portrait(), Sprites.PLAYER_PORTRAITS[0])
	s.portrait_right.pressed.emit()
	assert_eq(s.player_portrait(), Sprites.PLAYER_PORTRAITS[1])
	s.portrait_left.pressed.emit()
	s.portrait_left.pressed.emit()
	assert_eq(s.player_portrait(), Sprites.PLAYER_PORTRAITS[Sprites.PLAYER_PORTRAITS.size() - 1])
	s.start()
	assert_eq(MatchSetup.pending.player_portrait, s.player_portrait())


func test_choice_is_remembered_between_visits() -> void:
	var s := _screen(Opponents)
	s.portrait_right.pressed.emit()
	s.manual_button.pressed.emit()
	s.cards[6].pressed.emit()
	s.cards[2].pressed.emit()
	var picked: Array[StringName] = s.picked()
	s.queue_free()
	var again := _screen(Opponents)
	assert_false(again.is_random())
	assert_eq(again.picked(), picked)
	assert_eq(again.player_portrait(), Sprites.PLAYER_PORTRAITS[1])
	assert_eq(again.cards[6].order(), 1)


func test_bad_remembered_ids_are_dropped() -> void:
	Settings.set_value(&"opponents_random", false)
	Settings.set_value(&"opponents", ["nobody", "sailor", "sailor", "witch"])
	var s := _screen(Opponents)
	assert_eq(s.picked(), [&"sailor", &"witch"] as Array[StringName])


func test_rules_from_settings_reach_table_setup() -> void:
	Settings.set_value(&"calza", false)
	var s := _screen(Opponents)
	s.start()
	assert_false(MatchSetup.pending.calza)
	assert_true(MatchSetup.pending.palifico)


func test_picked_opponents_sit_at_table_in_order() -> void:
	var s := _screen(Opponents)
	s.manual_button.pressed.emit()
	s.cards[6].pressed.emit()
	s.cards[2].pressed.emit()
	s.portrait_right.pressed.emit()
	s.start()
	Rng.set_master_seed(11)
	var table := _screen(TableScene)
	var mc: MatchController = table._controller
	assert_eq(mc.player_count(), 3)
	assert_eq((mc.agent(1) as BotAgent).personality.id, &"deep_one")
	assert_eq((mc.agent(2) as BotAgent).personality.id, &"sailor")
	assert_eq(table._setup.player_portrait, Sprites.PLAYER_PORTRAITS[1])


func test_opponents_back_goes_to_menu() -> void:
	var s := _screen(Opponents)
	s._unhandled_input(_esc())
	assert_eq(ScreenNav.last(), ScreenNav.MAIN_MENU)


# --- Настройки ---------------------------------------------------------------------

func test_settings_steppers_change_settings() -> void:
	var s := _screen(SettingsScene)
	s.music.left_arrow.pressed.emit()
	assert_almost_eq(float(Settings.get_value(&"music_volume")), 0.7, 0.001)
	assert_eq(s.music.value_text(), "70%")
	for i in 20:
		s.sfx.right_arrow.pressed.emit()
	assert_eq(Settings.get_value(&"sfx_volume"), 1.0)
	assert_true(s.sfx.right_arrow.disabled)
	for i in 20:
		s.sfx.left_arrow.pressed.emit()
	assert_eq(Settings.get_value(&"sfx_volume"), 0.0)
	assert_eq(s.sfx.value_text(), "0%")
	s.speed.right_arrow.pressed.emit()
	assert_eq(Settings.get_value(&"bot_speed"), 1.5)
	assert_eq(s.speed.value_text(), "×1.5")
	s.palifico.right_arrow.pressed.emit()
	assert_false(Settings.get_value(&"palifico"))
	assert_eq(s.palifico.value_text(), "SETTINGS_OFF")
	s.calza.left_arrow.pressed.emit()
	assert_false(Settings.get_value(&"calza"))


func test_settings_language_switches_and_wraps() -> void:
	Settings.set_value(&"locale", "ru")
	var s := _screen(SettingsScene)
	assert_eq(s.language.value_text(), "LANG_RU")
	s.language.right_arrow.pressed.emit()
	assert_eq(TranslationServer.get_locale(), "en")
	assert_eq(s.language.value_text(), "LANG_EN")
	s.language.right_arrow.pressed.emit()
	assert_eq(TranslationServer.get_locale(), "ru")


func test_settings_defaults_button_resets_only_screen_keys() -> void:
	Settings.set_value(&"bot_speed", 3.0)
	Settings.set_value(&"calza", false)
	Settings.set_value(&"opponents", ["witch"])
	var s := _screen(SettingsScene)
	s.defaults_button.pressed.emit()
	assert_eq(Settings.get_value(&"bot_speed"), 1.0)
	assert_true(Settings.get_value(&"calza"))
	assert_eq(Settings.get_value(&"opponents"), ["witch"], "выбор соперников не трогаем")


func test_settings_speed_reaches_table() -> void:
	var s := _screen(SettingsScene)
	s.speed.right_arrow.pressed.emit()
	s.speed.right_arrow.pressed.emit()
	Rng.set_master_seed(3)
	var table := _screen(TableScene)
	assert_eq(table._speed(), 2.0)


func test_volume_is_applied_to_existing_bus() -> void:
	var index := AudioServer.get_bus_index(Settings.SFX_BUS)
	var added := index < 0
	if added:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, Settings.SFX_BUS)
	Settings.set_value(&"sfx_volume", 0.5)
	assert_almost_eq(AudioServer.get_bus_volume_db(index), linear_to_db(0.5), 0.01)
	Settings.set_value(&"sfx_volume", 0.0)
	assert_true(AudioServer.is_bus_mute(index))
	if added:
		AudioServer.remove_bus(index)


# --- Статистика --------------------------------------------------------------------

func test_stats_screen_shows_counters_and_win_rate() -> void:
	Stats.increment(&"matches_played", 4)
	Stats.increment(&"matches_won", 1)
	Stats.increment(&"madness_count", 2)
	var s := _screen(StatsScene)
	assert_eq(s.value_of("STATS_MATCHES_PLAYED"), "4")
	assert_eq(s.value_of("STATS_MATCHES_WON"), "1")
	assert_eq(s.value_of("STATS_WIN_RATE"), "25%")
	assert_eq(s.value_of("STATS_MADNESS_COUNT"), "2")
	assert_eq(s.value_of("STATS_CHEATERS_CAUGHT"), "0")


func test_stats_reset_needs_confirmation() -> void:
	Stats.increment(&"matches_played", 2)
	var s := _screen(StatsScene)
	s.reset_button.pressed.emit()
	assert_true(s.confirm.visible)
	s.confirm.cancel()
	assert_eq(Stats.get_count(&"matches_played"), 2, "отмена — ничего не сбросили")
	s.reset_button.pressed.emit()
	s._unhandled_input(_esc())
	assert_false(s.confirm.visible, "Esc закрывает подтверждение")
	assert_eq(ScreenNav.history.size(), 0, "и не уходит с экрана")
	s.reset_button.pressed.emit()
	s.confirm.buttons()[0].pressed.emit()
	assert_eq(Stats.get_count(&"matches_played"), 0)
	assert_eq(s.value_of("STATS_MATCHES_PLAYED"), "0")
	s._unhandled_input(_esc())
	assert_eq(ScreenNav.last(), ScreenNav.MAIN_MENU)


func test_match_on_table_is_counted() -> void:
	Rng.set_master_seed(9)
	var table := _screen(TableScene)
	assert_eq(Stats.get_count(&"matches_played"), 1)
	table._on_rematch()
	assert_eq(Stats.get_count(&"matches_played"), 2, "реванш — новый матч")


# --- Все экраны собираются на обоих языках -------------------------------------------

func test_all_screens_build_in_both_languages() -> void:
	for locale in ["ru", "en"]:
		Settings.set_value(&"locale", locale)
		for scene: PackedScene in [MainMenu, Opponents, SettingsScene, StatsScene,
				AchievementsScene]:
			var s := _screen(scene)
			await wait_process_frames(1)
			assert_gt(s.get_child_count(), 2, "%s %s" % [scene.resource_path, locale])
			for c in s.find_children("*", "Control", true, false):
				var ctrl := c as Control
				if ctrl.is_visible_in_tree() and ctrl.size.x > 0:
					var r := ctrl.get_global_rect()
					assert_true(r.position.x >= 0 and r.end.x <= MenuLayout.SCREEN.x + 0.5
							and r.position.y >= 0 and r.end.y <= MenuLayout.SCREEN.y + 0.5,
							"%s в пределах экрана: %s %s" % [ctrl.name, r, locale])
			s.queue_free()
