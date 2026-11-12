extends GutTest
## М23: экраны кампании — главное меню, выбор портрета и вступление, карта и карточка
## уровня, сцены с Хобом, стол кампании (модификаторы, ранг не меняется, итог матча),
## финал и «Конец», «Заново». Всё в пределах экрана на обоих языках.

const CampaignScene := preload("res://scenes/campaign.tscn")
const TableScene := preload("res://scenes/table.tscn")
const MainMenu := preload("res://scenes/main_menu.tscn")
const Phase := MatchController.Phase
const Mode := RankTracker.Mode


func before_each() -> void:
	MatchSetup.pending = null
	ScreenNav.history.clear()
	for flag in HintPanel.TOPICS:
		Stats.set_flag(flag)
	Campaign.reset()
	Ranks.reset()


func after_each() -> void:
	get_tree().paused = false
	MatchSetup.pending = null
	Campaign.reset()
	Ranks.reset()
	Stats.reset()
	Stats.clear_flags()
	Achievements.reset()
	Settings.reset_to_defaults()


func _esc() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	return e


func _screen() -> Control:
	return add_child_autofree(CampaignScene.instantiate())


## Кампания начата, вступление показано, пройдены уровни до passed включительно.
func _started(passed := 0) -> void:
	Campaign.start_new(&"player2")
	Campaign.mark_intro_seen()
	for n in range(1, passed + 1):
		Campaign.progress.record_win(n)


func _table(level: int) -> Control:
	Rng.set_master_seed(level * 11)
	MatchSetup.pending = MatchSetup.for_campaign(CampaignLevels.get_level(level), &"player2")
	return add_child_autofree(TableScene.instantiate())


# --- Главное меню -----------------------------------------------------------------

func test_main_menu_opens_campaign_and_shows_finished_mark() -> void:
	var menu: Control = add_child_autofree(MainMenu.instantiate())
	assert_false(menu.campaign_mark.visible)
	menu.campaign_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.CAMPAIGN)
	Campaign.progress.ever_finished = true
	var menu2: Control = add_child_autofree(MainMenu.instantiate())
	assert_true(menu2.campaign_mark.visible, "кампания пройдена — отметка")


# --- Первый вход: портрет и вступление ------------------------------------------------

func test_first_visit_picks_portrait_then_plays_intro() -> void:
	var s := _screen()
	assert_true(s.picker.visible, "сначала выбор портрета")
	s.picker.step(2)
	s.picker.ok_button.pressed.emit()
	assert_true(Campaign.progress.started)
	assert_eq(Campaign.progress.portrait, Sprites.PLAYER_PORTRAITS[2])
	assert_true(s.slides.is_playing(), "вступление")
	assert_eq(s.slides.current_slide(), &"intro_1")
	for i in SlideShow.INTRO.size():
		s.slides.advance()        # допечатать
		s.slides.advance()        # дальше
	assert_false(s.slides.is_playing())
	assert_true(Campaign.progress.intro_seen)


func test_intro_can_be_skipped_and_replayed() -> void:
	var s := _screen()
	s.picker.ok_button.pressed.emit()
	s.slides.skip_button.pressed.emit()
	assert_false(s.slides.is_playing())
	s.intro_button.pressed.emit()
	assert_true(s.slides.is_playing())
	s._unhandled_input(_esc())
	assert_false(s.slides.is_playing(), "Esc пропускает слайды")


# --- Карта и карточка ----------------------------------------------------------------

func test_map_shows_progress_and_card_locks_levels() -> void:
	_started(2)
	var s := _screen()
	assert_false(s.picker.visible)
	assert_eq(s.selected(), 3, "выбран самый дальний открытый уровень")
	assert_false(s.map.points[3].disabled)
	assert_true(s.map.points[4].disabled)
	assert_eq(s.card.level_number(), 3)
	assert_false(s.card.play_button.disabled)
	assert_string_contains(s.card.modifier_description(), str(CampaignBalance.EVIL_EYE_DICE))
	s.map.points[1].pressed.emit()
	assert_eq(s.card.level_number(), 1, "пройденный уровень можно открыть")
	assert_true(s.card._done_label.visible)
	s.select(5)
	assert_true(s.card.play_button.disabled, "закрытый уровень не сыграть")


func test_play_shows_hob_then_starts_campaign_table() -> void:
	_started()
	Settings.set_value(&"palifico", false)
	Settings.set_value(&"calza", false)
	var s := _screen()
	s.card.play_button.pressed.emit()
	assert_true(s.hob.is_playing())
	var level := CampaignLevels.get_level(1)
	assert_eq(s.hob.current_key(), level.before_keys[0])
	assert_eq(s.hob.current_speaker(), &"hob")
	for i in level.before_keys.size():
		s.hob.advance()
		s.hob.advance()
	assert_false(s.hob.is_playing())
	assert_eq(ScreenNav.last(), ScreenNav.TABLE)
	var setup := MatchSetup.pending
	assert_eq(setup.campaign_level.number, 1)
	assert_eq(setup.opponents, [&"sailor"] as Array[StringName])
	assert_eq(setup.player_portrait, &"player2")
	assert_true(setup.palifico and setup.calza, "Palifico и Calza всегда включены")
	assert_eq(setup.bark_story, "L1")


func test_change_portrait_and_restart_with_confirmation() -> void:
	_started(3)
	Campaign.progress.ever_finished = true
	var s := _screen()
	s.portrait_button.pressed.emit()
	assert_true(s.picker.visible)
	s.picker.step(1)
	s.picker.ok_button.pressed.emit()
	assert_eq(Campaign.progress.portrait, &"player3")
	assert_eq(Campaign.progress.completed_count(), 3, "смена портрета прогресс не трогает")
	s.restart_button.pressed.emit()
	assert_true(s.confirm.visible, "сначала подтверждение")
	s.confirm.buttons()[1].pressed.emit()
	assert_eq(Campaign.progress.completed_count(), 3, "«Отмена»")
	s.restart_button.pressed.emit()
	s.confirm.buttons()[0].pressed.emit()
	assert_true(s.picker.visible)
	s.picker.ok_button.pressed.emit()
	assert_eq(Campaign.progress.completed_count(), 0, "кампания заново")
	assert_true(Campaign.progress.ever_finished, "отметка о прохождении остаётся")
	assert_true(s.slides.is_playing(), "снова вступление")


func test_esc_goes_to_main_menu() -> void:
	_started()
	var s := _screen()
	s._unhandled_input(_esc())
	assert_eq(ScreenNav.last(), ScreenNav.MAIN_MENU)


# --- Стол кампании -----------------------------------------------------------------

func test_campaign_table_skips_rank_and_counts_campaign() -> void:
	_started()
	var t := _table(1)
	assert_false(Ranks.is_counting(), "ранг не меняется")
	assert_true(Campaign.is_counting())
	assert_eq(Campaign.tracker.level(), 1)
	assert_eq(t._background.modulate, CampaignLevels.get_level(1).background_tint)
	assert_true(t._controller.options.palifico_enabled and t._controller.options.calza_enabled)


func test_surrender_is_defeat_without_rank_change() -> void:
	_started()
	var t := _table(1)
	var glory := Ranks.glory(Mode.SINGLE)
	t.open_pause()
	t._pause.surrender_button.pressed.emit()
	assert_false(Campaign.progress.flawless, "поражение на уровне")
	assert_eq(Ranks.glory(Mode.SINGLE), glory)
	var panel: MatchEndPanel = t._end_panel
	assert_true(panel.rematch_button.visible)
	assert_eq(panel.rematch_button.text, "CAMP_RETRY")
	assert_eq(panel.menu_button.text, "CAMP_TO_MAP")
	assert_false(panel.rank_badge.is_visible_in_tree())
	panel.menu_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.CAMPAIGN)


func test_victory_goes_to_hob_scene_and_opens_next_level() -> void:
	_started()
	var t := _table(1)
	var mc: MatchController = t._controller
	mc.dice_counts[1] = 1
	mc._finish_round(1, -1)            # Моряк выбыл — победа игрока
	assert_eq(mc.phase, Phase.MATCH_OVER)
	t._result_panel.press_continue()
	var panel: MatchEndPanel = t._end_panel
	assert_true(panel.is_won())
	assert_false(panel.rematch_button.visible)
	assert_eq(panel.menu_button.text, "CAMP_CONTINUE")
	assert_true(Campaign.progress.is_completed(1))
	assert_true(Campaign.progress.is_unlocked(2))
	panel.menu_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.CAMPAIGN)
	var s := _screen()
	assert_true(s.hob.is_playing(), "после победы — сцена с Хобом")
	assert_eq(s.hob.current_key(), CampaignLevels.get_level(1).after_keys[0])
	s.hob.skip_button.pressed.emit()
	assert_eq(s.selected(), 2, "на карте — следующий уровень")
	assert_true(Achievements.is_unlocked(Achievement.Id.CLEAN_CONSCIENCE), "без трюков")


func test_final_level_plays_finale_and_end_screen() -> void:
	_started(5)
	var t := _table(6)
	var mc: MatchController = t._controller
	mc.dice_counts[1] = 1
	mc._finish_round(1, -1)
	assert_true(Campaign.progress.is_finished())
	assert_true(Achievements.is_unlocked(Achievement.Id.LEAVE_ISLAND))
	assert_true(Achievements.is_unlocked(Achievement.Id.NO_RETREAT))
	var s := _screen()
	assert_true(s.hob.is_playing())
	assert_eq(s.hob.current_speaker(), &"deep_one", "Хоб сбросил облик")
	s.hob.skip()
	assert_true(s.slides.is_playing(), "финал")
	assert_eq(s.slides.current_slide(), &"finale_1")
	s.slides.skip()
	assert_true(s.end_view.visible, "экран «Конец»")
	(s.end_view.get_meta(&"button") as Button).pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.MAIN_MENU)


func test_lair_table_shows_six_dice_and_tide() -> void:
	_started(5)
	var t := _table(6)
	var mc: MatchController = t._controller
	assert_eq(mc.dice_counts[1], CampaignBalance.LAIR_BOSS_DICE)
	assert_eq(t._seats[1]._dice_label.text, "×%d" % CampaignBalance.LAIR_BOSS_DICE)
	assert_false(t._tide_label.visible)
	mc.dice_counts[1] = CampaignBalance.TIDE_BOSS_DICE
	mc._finish_round(0, 0)
	t._result_panel.press_continue()
	var tide := mc.round_rules.tide()
	assert_true(tide in CampaignBalance.TIDE_FACES)
	assert_true(t._tide_label.visible)
	assert_eq(t._tide_label.text, tr("TABLE_TIDE") % tide)


func test_evil_eye_marks_own_die() -> void:
	_started(2)
	var t := _table(3)
	t._roll_button.pressed.emit()
	var view: PlayerView = t._session.view_for(0)
	assert_eq(view.watched_dice.size(), 1)
	if not view.cup_open:
		t._own.cup_pressed.emit()
	assert_eq(t._own.watched_marks(), view.watched_dice, "метка глаза на кубике")


func test_scarce_sanity_shows_fewer_pips() -> void:
	_started(3)
	var t := _table(4)
	var shown := 0
	for pip: TextureRect in t._own._sanity_pips:
		if pip.visible:
			shown += 1
	assert_eq(shown, CampaignBalance.SCARCE_SANITY)


func test_dead_hand_message_on_table() -> void:
	_started(4)
	var t := _table(5)
	var mc: MatchController = t._controller
	mc.dice_counts[1] = 1
	mc._finish_round(1, -1)
	assert_eq(mc.dice_counts[1], CampaignBalance.DEAD_HAND_DICE)
	var found := false
	for child in t._messages.get_children():
		if child is TermLabel and (child as TermLabel).plain_text().contains(tr("BOT_DROWNED")):
			found = true
	assert_true(found, "сообщение о возвращении Утопленника")
	assert_true(t._seats[1]._cup.visible, "чашка снова на месте")


func test_plain_match_after_campaign_counts_rank_again() -> void:
	_started()
	_table(1)
	MatchSetup.pending = MatchSetup.from_settings()
	add_child_autofree(TableScene.instantiate())
	assert_true(Ranks.is_counting())
	assert_false(Campaign.is_counting())


# --- Раскладка ----------------------------------------------------------------------

func test_campaign_screens_fit_in_both_languages() -> void:
	_started(5)
	for locale in ["ru", "en"]:
		Settings.set_value(&"locale", locale)
		var s := _screen()
		for n in range(1, CampaignBalance.LEVEL_COUNT + 1):
			s.select(n)
			await wait_process_frames(1)
			_assert_inside(s, "уровень %d %s" % [n, locale])
			var card_rect: Rect2 = s.card.get_global_rect()
			assert_true(card_rect.size.y <= CampaignLayout.CARD_RECT.size.y + 0.5,
					"карточка %d не раздулась: %s %s" % [n, card_rect, locale])
		s.hob.play(HobScene.lines_for(CampaignLevels.get_level(5), false))
		s.hob._text.finish()
		await wait_process_frames(1)
		_assert_inside(s, "Хоб " + locale)
		s.hob.skip()
		s.slides.play(SlideShow.INTRO)
		s.slides._text.finish()
		await wait_process_frames(1)
		_assert_inside(s, "слайды " + locale)
		s.slides.skip()
		s.queue_free()


func _assert_inside(root: Control, what: String) -> void:
	for c in root.find_children("*", "Control", true, false):
		var ctrl := c as Control
		if ctrl.is_visible_in_tree() and ctrl.size.x > 0:
			var r := ctrl.get_global_rect()
			assert_true(r.position.x >= 0 and r.end.x <= MenuLayout.SCREEN.x + 0.5
					and r.position.y >= 0 and r.end.y <= MenuLayout.SCREEN.y + 0.5,
					"%s в пределах экрана: %s %s" % [ctrl.name, r, what])
