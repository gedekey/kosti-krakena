extends GutTest
## Дымовой тест отладочного экрана: матч играется кнопками до победы.

const Scene := preload("res://scenes/debug_match.tscn")


func test_full_match_through_buttons() -> void:
	Rng.set_master_seed(2026)
	var screen: Control = add_child_autofree(Scene.instantiate())
	screen._on_new_match()
	var mc: MatchController = screen._controller
	var steps := 0
	while mc.phase != MatchController.Phase.MATCH_OVER and steps < 5000:
		steps += 1
		if not screen._roll_button.disabled:
			screen._roll_button.pressed.emit()
		elif not screen._next_button.disabled:
			screen._next_button.pressed.emit()
		elif mc.is_waiting_for_human():
			# Человек: «Ложь!», если можно, иначе минимальная ставка (подставляется экраном).
			var dudo_ok: bool = not screen._dudo_button.disabled
			if dudo_ok and (steps % 3 == 0 or screen._bid_button.disabled):
				screen._dudo_button.pressed.emit()
			else:
				assert_false(screen._bid_button.disabled, "минимальная ставка должна быть доступна")
				screen._bid_button.pressed.emit()
		else:
			screen._on_bot_timer()
	assert_eq(mc.phase, MatchController.Phase.MATCH_OVER)
	assert_string_contains(screen._log.get_parsed_text(), tr("DEBUG_LOG_WINNER").left(5))


## Довести матч до хода человека (боты ходят, раунды листаются).
func _until_human_turn(screen: Control, mc: MatchController) -> void:
	var steps := 0
	while not mc.is_waiting_for_human() and steps < 500:
		steps += 1
		if not screen._roll_button.disabled:
			screen._roll_button.pressed.emit()
		elif not screen._next_button.disabled:
			screen._next_button.pressed.emit()
		else:
			screen._on_bot_timer()


func _select_cheat(screen: Control, kind: Cheat.Kind) -> void:
	screen._cheat_option.select(screen._cheat_option.get_item_index(kind))
	screen._refresh()


func test_tricks_and_accusation_through_buttons() -> void:
	Rng.set_master_seed(7)
	var screen: Control = add_child_autofree(Scene.instantiate())
	screen._risk_option.select(1)  # без провалов
	screen._on_new_match()
	var mc: MatchController = screen._controller
	assert_eq(mc.cheats.risk_mode, CheatState.RiskMode.NEVER_FAIL)
	assert_eq(mc.phase, MatchController.Phase.ROLL)

	# Фаза броска: «Утяжелённая кость».
	_select_cheat(screen, Cheat.Kind.LOADED_DIE)
	screen._cheat_face_spin.value = 6
	assert_false(screen._cheat_button.disabled)
	screen._cheat_button.pressed.emit()
	assert_eq(mc.cheats.sanity[0], 7)
	assert_true(screen._cheat_button.disabled, "одна за бросок")
	screen._roll_button.pressed.emit()
	assert_eq(mc.hand_of(0)[MatchController.LOADED_DIE_INDEX], 6)

	# Свой ход: «Подглядеть» у соседа, второй трюк недоступен.
	_until_human_turn(screen, mc)
	_select_cheat(screen, Cheat.Kind.PEEK)
	assert_false(screen._cheat_target_option.disabled)
	assert_true(mc.view_for(0).neighbors().has(screen._cheat_target_option.get_selected_id()))
	watch_signals(mc)
	screen._cheat_button.pressed.emit()
	assert_signal_emitted(mc, "cheat_resolved")
	_select_cheat(screen, Cheat.Kind.ABYSS_WHISPER)
	assert_true(screen._cheat_button.disabled, "1 трюк за ход")

	# «Обвинить»: боты М4 честны — обвинение ложное.
	var target: int = screen._accuse_option.get_selected_id()
	var dice_before := mc.dice_counts[0]
	assert_false(screen._accuse_button.disabled)
	screen._accuse_button.pressed.emit()
	assert_signal_emitted_with_parameters(mc, "accusation_made", [0, target, false])
	assert_eq(mc.dice_counts[0], dice_before - 1)
	assert_eq(mc.phase, MatchController.Phase.ROUND_END)
	assert_string_contains(screen._log.get_parsed_text(), "[")  # журнал раунда выведен


func test_madness_hallucinations_visible_through_buttons() -> void:
	Rng.set_master_seed(11)
	var screen: Control = add_child_autofree(Scene.instantiate())
	screen._on_new_match()
	var mc: MatchController = screen._controller
	assert_true(screen._cup_button.disabled, "до броска чашка недоступна")
	_until_human_turn(screen, mc)
	mc.perception.chance = 1.0
	assert_false(screen._go_mad_button.disabled)
	screen._go_mad_button.pressed.emit()
	assert_true(mc.cheats.is_mad(0))
	assert_true(screen._go_mad_button.disabled)
	var truth_marker: String = tr("DEBUG_TRUTH").left(5)
	assert_string_contains(screen._dice_label.text, truth_marker)

	# Закрыть / открыть чашку несколько раз — хотя бы раз глаза соврут.
	var lied := false
	for t in 10:
		screen._cup_button.pressed.emit()
		assert_false(mc.view_for(0).cup_open)
		assert_string_contains(screen._dice_label.text, tr("DEBUG_CUP_CLOSED"))
		screen._cup_button.pressed.emit()
		assert_true(mc.view_for(0).cup_open)
		lied = lied or not mc.lying_dice(0).is_empty()
	assert_true(lied)
	assert_ne(mc.view_for(0).own_dice, mc.hand_of(0))
