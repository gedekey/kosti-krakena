extends GutTest
## М13: обучающий матч мышью на столе, подсказки при первом использовании, предложение
## обучения в главном меню, экран «Правила». Всё в пределах 640×360 на обоих языках.

const TableScene := preload("res://scenes/table.tscn")
const MainMenu := preload("res://scenes/main_menu.tscn")
const RulesScene := preload("res://scenes/rules.tscn")
const Cmd := TutorialStep.Command
const SCREEN := Vector2(640, 360)

var _saved_locale: String


func before_each() -> void:
	_saved_locale = Settings.get_value(&"locale")
	Stats.reset()
	Stats.clear_flags()
	ScreenNav.history.clear()
	MatchSetup.pending = null


func after_each() -> void:
	Settings.set_value(&"locale", _saved_locale)
	Stats.reset()
	Stats.clear_flags()
	Stats.recording = true
	MatchSetup.pending = null


func _tutorial() -> Control:
	Rng.set_master_seed(13)
	MatchSetup.pending = MatchSetup.for_tutorial()
	return add_child_autofree(TableScene.instantiate())


func _table(seed_value: int) -> Control:
	Rng.set_master_seed(seed_value)
	var setup := MatchSetup.from_settings()
	setup.opponents = [&"scholar", &"witch"]
	MatchSetup.pending = setup
	return add_child_autofree(TableScene.instantiate())


func _until_human_turn(screen: Control) -> void:
	var mc: MatchController = screen._controller
	var steps := 0
	while not mc.is_waiting_for_human() and steps < 500:
		steps += 1
		if screen._result_panel.visible:
			screen._result_panel.press_continue()
		elif screen._roll_button.visible:
			screen._roll_button.pressed.emit()
		else:
			screen._on_timer()


## Сделать мышью то, что просит шаг (или подождать Моряка).
func _tutorial_step(screen: Control) -> void:
	var d: TutorialDirector = screen._director
	if screen._result_panel.visible:
		screen._result_panel.press_continue()
		return
	if not d.is_ready():
		screen._on_timer()
		return
	match d.step().command:
		Cmd.ROLL:
			screen._roll_button.pressed.emit()
		Cmd.BID:
			assert_false(screen._bid_button.disabled, "ставка из шага подставлена")
			screen._bid_button.pressed.emit()
		Cmd.LIAR:
			screen._liar_button.pressed.emit()
		Cmd.TRICK:
			screen._tricks_button.pressed.emit()
			var menu: TrickMenu = screen._trick_menu
			assert_true(menu.visible)
			menu.picked.emit(Cheat.Kind.PEEK)
			if menu.step() == TrickMenu.Step.NEIGHBOR:
				menu.picked.emit(TutorialScript.SAILOR_ID)
			assert_eq(menu.step(), TrickMenu.Step.DIE)
			menu.picked.emit(0)
		Cmd.ACCUSE:
			screen._accuse_button.pressed.emit()
			assert_true(screen._accuse_menu.visible)
			screen._accuse_menu.buttons()[0].pressed.emit()


# --- Обучающий матч ------------------------------------------------------------------

func test_tutorial_plays_through_with_mouse() -> void:
	var screen := _tutorial()
	var d: TutorialDirector = screen._director
	var coach: TutorialCoach = screen._coach
	var mc: MatchController = screen._controller
	assert_not_null(d, "стол в режиме обучения")
	assert_eq(mc.player_count(), 2, "1×1")
	assert_eq((mc.agent(1) as BotAgent).personality.id, &"sailor")
	assert_true(coach.visible)
	assert_false(Stats.recording, "обучение не в статистике")
	var guard := 0
	while not coach.is_finish_shown() and guard < 200:
		guard += 1
		if d.is_ready() and not screen._result_panel.visible:
			assert_eq(coach.coach_text(), d.step().coach_key, "тренер говорит текст шага")
		_tutorial_step(screen)
	assert_true(coach.is_finish_shown(), "итог обучения")
	assert_true(d.is_finished())
	assert_true(Stats.has_flag(Stats.FLAG_TUTORIAL_DONE))
	assert_eq(Stats.get_count(&"matches_played"), 0, "обучение не считается матчем")
	assert_eq(Stats.get_count(&"cheaters_caught"), 0)
	assert_false(screen._result_panel.visible)
	coach.play_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.OPPONENTS)
	coach.rules_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.RULES)
	coach.menu_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.MAIN_MENU)
	screen.free()
	assert_true(Stats.recording, "после ухода со стола статистика снова ведётся")


func test_tutorial_lets_only_the_step_command() -> void:
	var screen := _tutorial()
	var d: TutorialDirector = screen._director
	assert_eq(d.step().command, Cmd.ROLL)
	assert_false(screen._roll_button.disabled)
	screen._roll_button.pressed.emit()
	assert_eq(d.step().command, Cmd.BID)
	assert_eq([screen._bid_input.quantity, screen._bid_input.face], [2, 3], "ставка шага")
	assert_false(screen._bid_button.disabled)
	assert_true(screen._liar_button.disabled, "«Ложь!» не по шагу")
	assert_true(screen._calza_button.disabled)
	assert_true(screen._tricks_button.disabled)
	assert_true(screen._accuse_button.disabled)
	screen._bid_input.shift_quantity(1)
	assert_true(screen._bid_button.disabled, "другая ставка — не по сценарию")
	screen._bid_button.pressed.emit()
	assert_eq(d.step().command, Cmd.BID, "нажатие ничего не сделало")
	screen._liar_button.pressed.emit()
	assert_eq(screen._controller.phase, MatchController.Phase.BIDDING)
	screen._bid_input.shift_quantity(-1)
	screen._bid_button.pressed.emit()
	assert_eq(d.step().command, Cmd.LIAR)
	assert_eq(screen._coach.coach_text(), "TUT_WAIT", "ходит Моряк — тренер ждёт")


func test_tutorial_trick_menu_offers_only_peek_and_no_hints() -> void:
	var screen := _tutorial()
	var d: TutorialDirector = screen._director
	var guard := 0
	while not (d.step().command == Cmd.TRICK and d.is_ready()) and guard < 200:
		guard += 1
		_tutorial_step(screen)
	assert_false(screen._tricks_button.disabled)
	assert_true(screen._bid_button.disabled, "сначала трюк")
	screen._tricks_button.pressed.emit()
	assert_false(screen._hint.visible, "в обучении подсказок нет")
	var menu: TrickMenu = screen._trick_menu
	assert_true(menu.visible)
	for i in Cheat.ALL.size():
		assert_eq(not menu.buttons()[i].disabled, Cheat.ALL[i] == Cheat.Kind.PEEK,
				"в меню доступен только «Подглядеть»: %s" % Cheat.ALL[i])


func test_tutorial_highlights_the_expected_button() -> void:
	var screen := _tutorial()
	await wait_process_frames(2)
	var coach: TutorialCoach = screen._coach
	assert_true(coach.is_highlighting(), "рамка у «Трясти чашки»")
	assert_true(coach.highlight_rect().encloses(screen._roll_button.get_global_rect()))
	screen._roll_button.pressed.emit()
	await wait_process_frames(1)
	assert_true(coach.highlight_rect().encloses(screen._bid_button.get_global_rect()))


func test_skip_marks_tutorial_done_and_goes_to_menu() -> void:
	var screen := _tutorial()
	screen._coach.skip_button.pressed.emit()
	assert_true(Stats.has_flag(Stats.FLAG_TUTORIAL_DONE))
	assert_eq(ScreenNav.last(), ScreenNav.MAIN_MENU)


func test_coach_texts_fit_in_panel() -> void:
	for locale in ["ru", "en"]:
		Settings.set_value(&"locale", locale)
		var screen := _tutorial()
		var coach: TutorialCoach = screen._coach
		for step in TutorialScript.steps():
			if step.command == Cmd.DONE:
				continue
			coach._text.text = step.coach_key
			await wait_process_frames(1)
			coach._panel.reset_size()
			assert_true(coach._panel.size.y <= TutorialLayout.COACH_RECT.size.y,
					"%s %s: %d px" % [locale, step.coach_key, coach._panel.size.y])
			assert_eq(int(coach._panel.size.x), TutorialLayout.COACH_RECT.size.x,
					"тренер не шире своего места (не заезжает на портрет Моряка)")
		screen._coach.show_finish()
		await wait_process_frames(1)
		var finish: PanelContainer = coach._finish
		finish.reset_size()
		assert_true(finish.size.y <= TutorialLayout.FINISH_RECT.size.y,
				"%s итог: %d px" % [locale, finish.size.y])
		assert_eq(int(finish.size.x), TutorialLayout.FINISH_RECT.size.x)
		screen.queue_free()


# --- Подсказки при первом использовании ----------------------------------------------

func test_first_trick_shows_hint_once() -> void:
	var screen := _table(21)
	_until_human_turn(screen)
	var hint: HintPanel = screen._hint
	screen._tricks_button.pressed.emit()
	assert_true(hint.visible, "первый раз — подсказка")
	assert_eq(hint.current_flag(), Stats.FLAG_HINT_TRICKS)
	assert_false(screen._trick_menu.visible, "меню — после подсказки")
	assert_true(Stats.has_flag(Stats.FLAG_HINT_TRICKS))
	hint.ok_button.pressed.emit()
	assert_false(hint.visible)
	assert_true(screen._trick_menu.visible, "после «Понятно» открылось меню")
	screen._trick_menu.cancel()
	screen._tricks_button.pressed.emit()
	assert_false(hint.visible, "второй раз подсказки нет")
	assert_true(screen._trick_menu.visible)


func test_first_accusation_shows_hint_once() -> void:
	var screen := _table(22)
	_until_human_turn(screen)
	var hint: HintPanel = screen._hint
	screen._accuse_button.pressed.emit()
	assert_eq(hint.current_flag(), Stats.FLAG_HINT_ACCUSE)
	assert_false(screen._accuse_menu.visible)
	hint.ok_button.pressed.emit()
	assert_true(screen._accuse_menu.visible)
	screen._accuse_menu.cancel()
	screen._accuse_button.pressed.emit()
	assert_false(hint.visible)
	assert_true(screen._accuse_menu.visible)


func test_own_madness_shows_hint_once() -> void:
	var screen := _table(23)
	_until_human_turn(screen)
	var hint: HintPanel = screen._hint
	screen._controller.debug_set_sanity(1, 0)
	assert_false(hint.visible, "Безумие бота — без подсказки")
	screen._controller.debug_set_sanity(0, 0)
	assert_eq(hint.current_flag(), Stats.FLAG_HINT_MADNESS)
	assert_true(hint._text.text.contains("%d" % roundi(MadnessBalance.HALLUCINATION_CHANCE * 100)),
			"в тексте — число из баланса")
	hint.ok_button.pressed.emit()
	assert_false(hint.visible)
	screen._on_rematch()
	_until_human_turn(screen)
	screen._controller.debug_set_sanity(0, 0)
	assert_false(hint.visible, "второй раз подсказки нет")


func test_hints_fit_in_panel() -> void:
	for locale in ["ru", "en"]:
		Settings.set_value(&"locale", locale)
		var screen := _table(24)
		var hint: HintPanel = screen._hint
		for flag in HintPanel.TOPICS:
			Stats.clear_flags()
			hint.open(flag)
			await wait_process_frames(1)
			hint._panel.reset_size()
			assert_true(hint._panel.size.y <= TutorialLayout.HINT_RECT.size.y,
					"%s %s: %d px" % [locale, flag, hint._panel.size.y])
			assert_eq(int(hint._panel.size.x), TutorialLayout.HINT_RECT.size.x)
			assert_false(hint._text.text.contains("%d"), "числа подставлены: %s" % flag)
			hint.ok_button.pressed.emit()
		screen.queue_free()


# --- Главное меню ------------------------------------------------------------------

func test_tutorial_is_offered_once_on_first_launch() -> void:
	var menu: Control = add_child_autofree(MainMenu.instantiate())
	assert_true(menu.offer.visible, "первый запуск — предложение обучения")
	assert_true(Stats.has_flag(Stats.FLAG_TUTORIAL_OFFERED))
	menu.offer.buttons()[1].pressed.emit()   # «Не сейчас»
	assert_false(menu.offer.visible)
	assert_eq(ScreenNav.history.size(), 0)
	var again: Control = add_child_autofree(MainMenu.instantiate())
	assert_false(again.offer.visible, "второй раз не предлагается")


func test_offer_starts_tutorial() -> void:
	var menu: Control = add_child_autofree(MainMenu.instantiate())
	menu.offer.buttons()[0].pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.TABLE)
	assert_not_null(MatchSetup.pending)
	assert_true(MatchSetup.pending.tutorial)


func test_offer_closes_on_escape_and_not_shown_after_tutorial() -> void:
	var menu: Control = add_child_autofree(MainMenu.instantiate())
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	menu._unhandled_input(e)
	assert_false(menu.offer.visible)
	assert_eq(ScreenNav.history.size(), 0)
	Stats.clear_flags()
	Stats.set_flag(Stats.FLAG_TUTORIAL_DONE)
	var done: Control = add_child_autofree(MainMenu.instantiate())
	assert_false(done.offer.visible, "обучение пройдено — не предлагаем")


func test_menu_buttons_for_tutorial_and_rules() -> void:
	Stats.set_flag(Stats.FLAG_TUTORIAL_OFFERED)
	var menu: Control = add_child_autofree(MainMenu.instantiate())
	menu.rules_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.RULES)
	menu.tutorial_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.TABLE)
	assert_true(MatchSetup.pending.tutorial)


# --- Правила -------------------------------------------------------------------------

func test_rules_pages_turn_and_have_illustrations() -> void:
	var rules: Control = add_child_autofree(RulesScene.instantiate())
	assert_eq(rules.page, 0)
	assert_true(rules.prev_button.disabled)
	for i in rules.page_count():
		rules.show_page(i)
		assert_gt(rules.illustration().get_child_count(), 0, "иллюстрация на странице %d" % i)
		assert_false(rules.page_text().is_empty())
		assert_false(rules.page_text().contains("%d"), "числа подставлены, стр. %d" % i)
	assert_true(rules.next_button.disabled, "последняя страница")
	rules.prev_button.pressed.emit()
	assert_eq(rules.page, rules.page_count() - 2)
	rules.show_page(0)
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	rules._unhandled_input(right)
	assert_eq(rules.page, 1, "стрелка вправо листает")
	rules.turn(-5)
	assert_eq(rules.page, 0, "без зацикливания")


func test_rules_numbers_come_from_balance() -> void:
	var rules: Control = add_child_autofree(RulesScene.instantiate())
	rules.show_page(rules.PAGES.find(["RULES_EVIDENCE_TITLE", "RULES_EVIDENCE_TEXT"]))
	assert_true(rules.page_text().contains(
			"%d%%" % roundi(CheatBalance.FALSE_EVIDENCE_CHANCE * 100)))
	rules.show_page(rules.PAGES.find(["RULES_TRICKS_TITLE", "RULES_TRICKS_TEXT"]))
	var table: GridContainer = rules.illustration().get_child(0)
	assert_eq(table.get_child_count(), Cheat.ALL.size(), "все трюки в таблице")


func test_rules_back_goes_to_menu() -> void:
	var rules: Control = add_child_autofree(RulesScene.instantiate())
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	rules._unhandled_input(e)
	assert_eq(ScreenNav.last(), ScreenNav.MAIN_MENU)


func test_screens_fit_640x360_in_both_languages() -> void:
	for locale in ["ru", "en"]:
		Settings.set_value(&"locale", locale)
		Stats.clear_flags()
		var menu: Control = add_child_autofree(MainMenu.instantiate())
		await wait_process_frames(1)
		_assert_on_screen(menu, "меню " + locale)
		menu.queue_free()
		var rules: Control = add_child_autofree(RulesScene.instantiate())
		for i in rules.page_count():
			rules.show_page(i)
			await wait_process_frames(1)
			_assert_on_screen(rules, "правила %d %s" % [i, locale])
		rules.queue_free()
		var table := _tutorial()
		await wait_process_frames(1)
		_assert_on_screen(table, "обучение " + locale)
		table.queue_free()


func _assert_on_screen(root: Control, what: String) -> void:
	for c in root.find_children("*", "Control", true, false):
		var ctrl := c as Control
		if ctrl.is_visible_in_tree() and ctrl.size.x > 0:
			var r := ctrl.get_global_rect()
			assert_true(r.position.x >= 0 and r.end.x <= SCREEN.x + 0.5
					and r.position.y >= 0 and r.end.y <= SCREEN.y + 0.5,
					"%s: %s в пределах экрана: %s" % [what, ctrl.name, r])
