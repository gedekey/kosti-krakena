extends GutTest
## М17: меню паузы стола (Esc), экран и уведомления достижений, полный экран и
## разрешение окна в настройках.

const TableScene := preload("res://scenes/table.tscn")
const AchievementsScene := preload("res://scenes/achievements.tscn")
const MainMenu := preload("res://scenes/main_menu.tscn")
const SettingsScene := preload("res://scenes/settings.tscn")


var _saved_locale: String


func before_each() -> void:
	_saved_locale = Settings.get_value(&"locale")
	MatchSetup.pending = null
	ScreenNav.history.clear()
	for flag in HintPanel.TOPICS:
		Stats.set_flag(flag)
	Achievements.reset()


func after_each() -> void:
	get_tree().paused = false
	Settings.set_value(&"locale", _saved_locale)
	Stats.clear_flags()
	Stats.reset()
	Achievements.reset()
	Settings.reset_keys([&"fullscreen", &"window_scale"])
	MatchSetup.pending = null


func _esc() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	return e


func _table(seed_value := 3) -> Control:
	Rng.set_master_seed(seed_value)
	return add_child_autofree(TableScene.instantiate())


# --- Пауза -----------------------------------------------------------------------

func test_escape_opens_pause_and_escape_resumes() -> void:
	var table := _table()
	assert_false(table.is_paused())
	table._unhandled_input(_esc())
	assert_true(table.is_paused(), "меню паузы открыто")
	assert_true(get_tree().paused, "дерево на паузе")
	assert_true(table._pause.surrender_button.visible, "в матче можно сдаться")
	table._pause._unhandled_input(_esc())
	assert_false(table.is_paused())
	assert_false(get_tree().paused)


func test_resume_button_continues() -> void:
	var table := _table()
	table.open_pause()
	table._pause.resume_button.pressed.emit()
	assert_false(table.is_paused())
	assert_false(get_tree().paused)


func test_escape_closes_open_menu_before_pausing() -> void:
	var table := _table()
	table._accuse_menu.open("x", [] as Array[ChoicePanel.Choice])
	table._unhandled_input(_esc())
	assert_false(table._accuse_menu.visible, "Esc закрыл меню обвинения")
	assert_false(table.is_paused(), "пауза не открылась")


func test_surrender_shows_defeat_without_win() -> void:
	var table := _table()
	table.open_pause()
	table._pause.surrender_button.pressed.emit()
	assert_false(get_tree().paused)
	assert_true(table._end_panel.visible, "экран поражения")
	assert_false(table._end_panel.is_won())
	assert_false(table._end_panel.spectate_button.visible, "досматривать нечего")
	assert_eq(Stats.get_count(&"matches_won"), 0)
	assert_eq(Achievements.unlocked_count(), 0)
	assert_lt(table._auto_delay(), 0.0, "боты больше не ходят")
	table.open_pause()
	assert_false(table._pause.surrender_button.visible, "второй раз не сдаться")
	table.resume()
	table._end_panel.rematch_button.pressed.emit()
	assert_false(table._end_panel.visible, "реванш начинает новый матч")
	assert_eq(Stats.get_count(&"matches_played"), 2)


func test_quit_goes_to_menu_and_unpauses() -> void:
	var table := _table()
	table.open_pause()
	table._pause.quit_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.MAIN_MENU)
	assert_false(get_tree().paused)


func test_no_surrender_in_tutorial() -> void:
	MatchSetup.pending = MatchSetup.for_tutorial()
	var table: Control = add_child_autofree(TableScene.instantiate())
	table.open_pause()
	assert_false(table._pause.surrender_button.visible)
	assert_true(table._pause.quit_button.visible)
	table.resume()


func test_leaving_table_while_paused_unpauses() -> void:
	var table := _table()
	table.open_pause()
	remove_child(table)
	assert_false(get_tree().paused)
	table.free()


# --- Уведомления о достижениях ---------------------------------------------------

func test_toast_shows_unlocks_in_order() -> void:
	var table := _table()
	var toast: AchievementToast = table._toast
	assert_eq(toast.shown_key(), "")
	toast.push(Achievement.Id.FIRST_WIN)
	toast.push(Achievement.Id.HUNTER)
	assert_eq(toast.shown_key(), Achievement.name_key(Achievement.Id.FIRST_WIN))
	toast._next()
	assert_eq(toast.shown_key(), Achievement.name_key(Achievement.Id.HUNTER))
	toast._next()
	assert_eq(toast.shown_key(), "")


func test_toast_follows_autoload_unlocks() -> void:
	var table := _table()
	Achievements.tracker.madness(AchievementTracker.HUMAN_ID)
	assert_eq(table._toast.shown_key(), Achievement.name_key(Achievement.Id.INTO_ABYSS))


# --- Экран достижений ------------------------------------------------------------

func test_main_menu_opens_achievements() -> void:
	var menu: Control = add_child_autofree(MainMenu.instantiate())
	menu.achievements_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.ACHIEVEMENTS)


func test_achievements_screen_shows_state_and_progress() -> void:
	Settings.set_value(&"locale", "ru")
	Achievements.tracker.begin_match(4)
	Achievements.tracker.match_ended(AchievementTracker.HUMAN_ID)
	var s: Control = add_child_autofree(AchievementsScene.instantiate())
	assert_eq(s.cards.size(), 18)
	assert_true(s.is_shown_unlocked(Achievement.Id.FIRST_WIN))
	assert_false(s.is_shown_unlocked(Achievement.Id.HUNTER))
	assert_eq(s.count_label.text, "Открыто: 3 из 18")

	assert_string_contains(s.description_of(Achievement.Id.VETERAN), "(1/10)")
	assert_string_contains(s.description_of(Achievement.Id.HUNTER), "5")
	s._unhandled_input(_esc())
	assert_eq(ScreenNav.last(), ScreenNav.MAIN_MENU)


func test_achievements_screen_fits_in_both_languages() -> void:
	for locale in ["ru", "en"]:
		Settings.set_value(&"locale", locale)
		var s: Control = add_child_autofree(AchievementsScene.instantiate())
		await wait_process_frames(1)
		for id: Achievement.Id in s.cards:
			var card: Control = s.cards[id]
			var r := card.get_global_rect()
			assert_true(r.size.x <= MenuLayout.ACH_CELL_SIZE.x + 0.5
					and r.size.y <= MenuLayout.ACH_CELL_SIZE.y + 0.5,
					"карточка %s не раздулась: %s %s" % [Achievement.save_name(id), r, locale])
			assert_true(r.end.y <= MenuLayout.BACK_RECT.position.y,
					"над кнопкой «Назад»: %s %s" % [r, locale])
		s.queue_free()


# --- Полный экран и разрешение ---------------------------------------------------

func test_window_scale_is_sanitized() -> void:
	assert_eq(Settings.sanitize(&"window_scale", 0), Settings.WINDOW_SCALE_MIN)
	assert_eq(Settings.sanitize(&"window_scale", 99), Settings.WINDOW_SCALE_MAX)
	assert_eq(Settings.sanitize(&"window_scale", 3.0), 3)
	assert_eq(Settings.sanitize(&"window_scale", "3"), null)
	assert_eq(Settings.sanitize(&"fullscreen", 1), null)


func test_scales_fitting_screen() -> void:
	assert_eq(Settings.scales_fitting(Vector2i(1920, 1040)), [1, 2] as Array[int],
			"1920×1080 с панелью задач — окно до 1280×720")
	assert_eq(Settings.scales_fitting(Vector2i(2560, 1400)), [1, 2, 3] as Array[int])
	assert_eq(Settings.scales_fitting(Vector2i(600, 300)), [1] as Array[int], "1 есть всегда")
	assert_eq(Settings.scales_fitting(Vector2i.ZERO).size(), Settings.WINDOW_SCALE_FALLBACK)
	assert_eq(Settings.resolution_text(3), "1920×1080")


func test_settings_screen_display_rows() -> void:
	var s: Control = add_child_autofree(SettingsScene.instantiate())
	assert_true(s.fullscreen.visible, "на ПК есть строка полного экрана")
	assert_eq(s.resolution.value_text(), "1280×720")
	s.resolution.right_arrow.pressed.emit()
	assert_eq(Settings.get_value(&"window_scale"), 3)
	assert_eq(s.resolution.value_text(), "1920×1080")
	assert_true(s.resolution.right_arrow.disabled, "больше не влезает (headless — до ×3)")
	s.resolution.left_arrow.pressed.emit()
	assert_eq(Settings.get_value(&"window_scale"), 2)
	s.fullscreen.right_arrow.pressed.emit()
	assert_true(Settings.get_value(&"fullscreen"))
	assert_eq(s.fullscreen.value_text(), "SETTINGS_FULLSCREEN")
	assert_true(s.resolution.left_arrow.disabled and s.resolution.right_arrow.disabled,
			"в полном экране разрешение — монитора")
	s.defaults_button.pressed.emit()
	assert_false(Settings.get_value(&"fullscreen"))
	assert_eq(Settings.get_value(&"window_scale"), 2)
