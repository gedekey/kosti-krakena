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
