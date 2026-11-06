extends GutTest
## Правила Перудо — DESIGN.md §2.

const NOT_ALLOWED := PerudoRules.NOT_ALLOWED


func _rules(palifico := false) -> RoundRules:
	return RoundRules.new(palifico)


# --- Константы ---------------------------------------------------------------

func test_start_and_max_dice_are_five() -> void:
	assert_eq(PerudoRules.START_DICE, 5)
	assert_eq(PerudoRules.MAX_DICE, 5)


# --- Бросок ------------------------------------------------------------------

func test_roll_returns_requested_count_in_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var dice := PerudoRules.roll_dice(50, rng)
	assert_eq(dice.size(), 50)
	for d in dice:
		assert_between(d, 1, 6)


func test_roll_is_deterministic_by_seed() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	assert_eq(PerudoRules.roll_dice(5, a), PerudoRules.roll_dice(5, b))


func test_roll_zero_dice() -> void:
	var rng := RandomNumberGenerator.new()
	assert_eq(PerudoRules.roll_dice(0, rng).size(), 0)


func test_roll_uses_all_faces() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for d in PerudoRules.roll_dice(300, rng):
		seen[d] = true
	assert_eq(seen.size(), 6)


# --- Подсчёт -----------------------------------------------------------------

func test_count_with_wild_ones() -> void:
	var dice: Array[int] = [1, 3, 3, 5, 1]
	assert_eq(PerudoRules.count_face(dice, 3, true), 4, "две тройки + две единицы")
	assert_eq(PerudoRules.count_face(dice, 6, true), 2, "только единицы")


func test_count_without_wild_ones() -> void:
	var dice: Array[int] = [1, 3, 3, 5, 1]
	assert_eq(PerudoRules.count_face(dice, 3, false), 2)


func test_count_ones_counts_only_ones() -> void:
	var dice: Array[int] = [1, 3, 3, 5, 1]
	assert_eq(PerudoRules.count_face(dice, 1, true), 2)
	assert_eq(PerudoRules.count_face(dice, 1, false), 2)


func test_count_on_table_sums_all_hands() -> void:
	var hands := [[1, 2, 2], [2, 6], [], [1, 1, 4, 2, 5]]
	assert_eq(PerudoRules.count_on_table(hands, 2, true), 7)
	assert_eq(PerudoRules.count_on_table(hands, 2, false), 4)


func test_round_rules_wild_ones() -> void:
	assert_true(_rules(false).ones_wild())
	assert_false(_rules(true).ones_wild(), "в Palifico единицы — не джокеры")


# --- Первая ставка ----------------------------------------------------------

func test_first_bid_any_quantity_on_non_ones() -> void:
	for face in range(2, 7):
		assert_eq(PerudoRules.min_quantity_for_face(null, face, _rules()), 1)
	assert_true(PerudoRules.is_valid_bid(null, Bid.new(1, 2), _rules()))
	assert_true(PerudoRules.is_valid_bid(null, Bid.new(7, 6), _rules()))


func test_first_bid_cannot_be_ones() -> void:
	assert_eq(PerudoRules.min_quantity_for_face(null, 1, _rules()), NOT_ALLOWED)
	assert_false(PerudoRules.is_valid_bid(null, Bid.new(3, 1), _rules()))


func test_first_bid_can_be_ones_in_palifico() -> void:
	assert_eq(PerudoRules.min_quantity_for_face(null, 1, _rules(true)), 1)
	assert_true(PerudoRules.is_valid_bid(null, Bid.new(1, 1), _rules(true)))


func test_malformed_bid_is_invalid() -> void:
	assert_false(PerudoRules.is_valid_bid(null, Bid.new(0, 3), _rules()))
	assert_false(PerudoRules.is_valid_bid(null, Bid.new(2, 7), _rules()))
	assert_false(PerudoRules.is_valid_bid(Bid.new(2, 3), Bid.new(3, 0), _rules()))


# --- Повышение (обычный раунд) ----------------------------------------------

func test_raise_same_face_needs_more() -> void:
	var prev := Bid.new(3, 4)
	assert_false(PerudoRules.is_valid_bid(prev, Bid.new(3, 4), _rules()))
	assert_true(PerudoRules.is_valid_bid(prev, Bid.new(4, 4), _rules()))


func test_raise_higher_face_same_quantity() -> void:
	var prev := Bid.new(3, 4)
	assert_true(PerudoRules.is_valid_bid(prev, Bid.new(3, 5), _rules()))
	assert_true(PerudoRules.is_valid_bid(prev, Bid.new(3, 6), _rules()))


func test_raise_lower_face_needs_more_quantity() -> void:
	var prev := Bid.new(3, 4)
	assert_false(PerudoRules.is_valid_bid(prev, Bid.new(3, 2), _rules()))
	assert_true(PerudoRules.is_valid_bid(prev, Bid.new(4, 2), _rules()))


func test_lower_quantity_is_invalid() -> void:
	assert_false(PerudoRules.is_valid_bid(Bid.new(3, 4), Bid.new(2, 6), _rules()))


func test_min_quantity_for_each_face_after_regular_bid() -> void:
	var prev := Bid.new(5, 4)
	assert_eq(PerudoRules.min_quantity_for_face(prev, 2, _rules()), 6)
	assert_eq(PerudoRules.min_quantity_for_face(prev, 4, _rules()), 6)
	assert_eq(PerudoRules.min_quantity_for_face(prev, 5, _rules()), 5)
	assert_eq(PerudoRules.min_quantity_for_face(prev, 6, _rules()), 5)


# --- Пако ---------------------------------------------------------------------

func test_switch_to_ones_halves_rounding_up() -> void:
	assert_eq(PerudoRules.min_quantity_for_face(Bid.new(5, 4), 1, _rules()), 3)
	assert_eq(PerudoRules.min_quantity_for_face(Bid.new(6, 4), 1, _rules()), 3)
	assert_eq(PerudoRules.min_quantity_for_face(Bid.new(1, 6), 1, _rules()), 1)
	assert_true(PerudoRules.is_valid_bid(Bid.new(5, 4), Bid.new(3, 1), _rules()))
	assert_false(PerudoRules.is_valid_bid(Bid.new(5, 4), Bid.new(2, 1), _rules()))


func test_ones_to_ones_needs_more() -> void:
	var prev := Bid.new(3, 1)
	assert_eq(PerudoRules.min_quantity_for_face(prev, 1, _rules()), 4)
	assert_false(PerudoRules.is_valid_bid(prev, Bid.new(3, 1), _rules()))
	assert_true(PerudoRules.is_valid_bid(prev, Bid.new(4, 1), _rules()))


func test_switch_from_ones_doubles_plus_one() -> void:
	var prev := Bid.new(3, 1)
	for face in range(2, 7):
		assert_eq(PerudoRules.min_quantity_for_face(prev, face, _rules()), 7)
	assert_false(PerudoRules.is_valid_bid(prev, Bid.new(6, 6), _rules()))
	assert_true(PerudoRules.is_valid_bid(prev, Bid.new(7, 2), _rules()))


# --- Palifico ----------------------------------------------------------------

func test_palifico_face_is_fixed() -> void:
	var prev := Bid.new(2, 3)
	assert_eq(PerudoRules.min_quantity_for_face(prev, 3, _rules(true)), 3)
	for face in [1, 2, 4, 5, 6]:
		assert_eq(PerudoRules.min_quantity_for_face(prev, face, _rules(true)), NOT_ALLOWED,
				"грань %d запрещена" % face)
	assert_false(PerudoRules.is_valid_bid(prev, Bid.new(2, 4), _rules(true)))
	assert_false(PerudoRules.is_valid_bid(prev, Bid.new(5, 1), _rules(true)))
	assert_true(PerudoRules.is_valid_bid(prev, Bid.new(3, 3), _rules(true)))


func test_palifico_ones_face_is_fixed_too() -> void:
	var prev := Bid.new(1, 1)
	assert_eq(PerudoRules.min_quantity_for_face(prev, 1, _rules(true)), 2)
	assert_eq(PerudoRules.min_quantity_for_face(prev, 5, _rules(true)), NOT_ALLOWED)


# --- Минимальная следующая ставка ------------------------------------------

func test_lowest_first_bid() -> void:
	assert_true(PerudoRules.lowest_next_bid(null, _rules()).equals(Bid.new(1, 2)))
	assert_true(PerudoRules.lowest_next_bid(null, _rules(true)).equals(Bid.new(1, 1)))


func test_lowest_next_bid_prefers_smaller_quantity_then_face() -> void:
	# После 5x4: единицы от 3 — самая маленькая по количеству.
	assert_true(PerudoRules.lowest_next_bid(Bid.new(5, 4), _rules()).equals(Bid.new(3, 1)))
	# После 1x6: единицы от 1.
	assert_true(PerudoRules.lowest_next_bid(Bid.new(1, 6), _rules()).equals(Bid.new(1, 1)))
	# После 2x1: единицы 3 (меньше, чем 5 любой грани).
	assert_true(PerudoRules.lowest_next_bid(Bid.new(2, 1), _rules()).equals(Bid.new(3, 1)))


func test_lowest_next_bid_in_palifico() -> void:
	assert_true(PerudoRules.lowest_next_bid(Bid.new(2, 5), _rules(true)).equals(Bid.new(3, 5)))


func test_lowest_next_bid_is_always_valid() -> void:
	for pal in [false, true]:
		for q in range(1, 8):
			for f in range(1, 7):
				var prev := Bid.new(q, f)
				var lowest := PerudoRules.lowest_next_bid(prev, _rules(pal))
				assert_true(PerudoRules.is_valid_bid(prev, lowest, _rules(pal)),
						"%s -> %s, palifico=%s" % [prev, lowest, pal])


# --- Доступность действий ---------------------------------------------------

func test_dudo_needs_previous_bid() -> void:
	assert_false(PerudoRules.can_call_dudo(null))
	assert_true(PerudoRules.can_call_dudo(Bid.new(2, 3)))


func test_calza_needs_previous_bid_and_option() -> void:
	var on := RuleOptions.new()
	var off := RuleOptions.new()
	off.calza_enabled = false
	assert_false(PerudoRules.can_call_calza(null, on))
	assert_true(PerudoRules.can_call_calza(Bid.new(2, 3), on))
	assert_false(PerudoRules.can_call_calza(Bid.new(2, 3), off))


func test_options_default_to_enabled() -> void:
	var opts := RuleOptions.new()
	assert_true(opts.palifico_enabled)
	assert_true(opts.calza_enabled)


# --- «Ложь!» ------------------------------------------------------------------

const BIDDER := 0
const CHALLENGER := 1


func test_dudo_bid_holds_challenger_loses() -> void:
	var hands := [[3, 3, 1], [2, 4]]
	var r := PerudoRules.resolve_dudo(Bid.new(3, 3), BIDDER, CHALLENGER, hands, _rules())
	assert_eq(r.actual_count, 3)
	assert_true(r.bid_holds)
	assert_eq(r.player_id, CHALLENGER)
	assert_eq(r.dice_delta, -1)


func test_dudo_exceeded_bid_still_holds() -> void:
	var hands := [[3, 3, 3, 3], [3]]
	var r := PerudoRules.resolve_dudo(Bid.new(2, 3), BIDDER, CHALLENGER, hands, _rules())
	assert_true(r.bid_holds)
	assert_eq(r.player_id, CHALLENGER)


func test_dudo_bid_fails_bidder_loses() -> void:
	var hands := [[3, 2, 1], [2, 4]]
	var r := PerudoRules.resolve_dudo(Bid.new(3, 3), BIDDER, CHALLENGER, hands, _rules())
	assert_eq(r.actual_count, 2)
	assert_false(r.bid_holds)
	assert_eq(r.player_id, BIDDER)
	assert_eq(r.dice_delta, -1)


func test_dudo_in_palifico_ignores_jokers() -> void:
	var hands := [[3, 1, 1], [2, 1]]
	var r := PerudoRules.resolve_dudo(Bid.new(2, 3), BIDDER, CHALLENGER, hands, _rules(true))
	assert_eq(r.actual_count, 1)
	assert_eq(r.player_id, BIDDER)


# --- «Точно!» -----------------------------------------------------------------

const CALLER := 2


func test_calza_exact_gains_die() -> void:
	var hands := [[4, 1], [4, 6], [2, 2, 2]]
	var r := PerudoRules.resolve_calza(Bid.new(3, 4), CALLER, 3, hands, _rules())
	assert_eq(r.actual_count, 3)
	assert_true(r.bid_holds)
	assert_eq(r.player_id, CALLER)
	assert_eq(r.dice_delta, 1)


func test_calza_exact_at_max_dice_gains_nothing() -> void:
	var hands := [[4, 4, 4]]
	var r := PerudoRules.resolve_calza(Bid.new(3, 4), CALLER, PerudoRules.MAX_DICE, hands, _rules())
	assert_true(r.bid_holds)
	assert_eq(r.dice_delta, 0)


func test_calza_too_many_loses_die() -> void:
	var hands := [[4, 4, 4, 4]]
	var r := PerudoRules.resolve_calza(Bid.new(3, 4), CALLER, 2, hands, _rules())
	assert_false(r.bid_holds)
	assert_eq(r.player_id, CALLER)
	assert_eq(r.dice_delta, -1)


func test_calza_too_few_loses_die() -> void:
	var hands := [[4, 4]]
	var r := PerudoRules.resolve_calza(Bid.new(3, 4), CALLER, 2, hands, _rules())
	assert_false(r.bid_holds)
	assert_eq(r.dice_delta, -1)


func test_calza_in_palifico_ignores_jokers() -> void:
	var hands := [[4, 1, 1]]
	var r := PerudoRules.resolve_calza(Bid.new(3, 4), CALLER, 1, hands, _rules(true))
	assert_eq(r.actual_count, 1)
	assert_eq(r.dice_delta, -1)


# --- Palifico: когда наступает ---------------------------------------------

func test_palifico_triggers_when_first_down_to_one_die() -> void:
	var opts := RuleOptions.new()
	assert_true(PerudoRules.triggers_palifico(1, false, opts))


func test_palifico_does_not_trigger_twice() -> void:
	assert_false(PerudoRules.triggers_palifico(1, true, RuleOptions.new()))


func test_palifico_does_not_trigger_with_more_or_zero_dice() -> void:
	assert_false(PerudoRules.triggers_palifico(2, false, RuleOptions.new()))
	assert_false(PerudoRules.triggers_palifico(0, false, RuleOptions.new()))


func test_palifico_does_not_trigger_when_disabled() -> void:
	var opts := RuleOptions.new()
	opts.palifico_enabled = false
	assert_false(PerudoRules.triggers_palifico(1, false, opts))


# --- Кто начинает следующий раунд ------------------------------------------

func test_loser_starts_next_round() -> void:
	assert_eq(PerudoRules.next_round_starter([3, 2, 4], 1), 1)


func test_eliminated_loser_passes_start_clockwise() -> void:
	assert_eq(PerudoRules.next_round_starter([3, 0, 4], 1), 2)
	assert_eq(PerudoRules.next_round_starter([3, 2, 0], 2), 0, "по кругу через конец списка")
	assert_eq(PerudoRules.next_round_starter([0, 0, 0, 2], 0), 3, "пропускает выбывших")


func test_next_active_player() -> void:
	assert_eq(PerudoRules.next_active_player([2, 0, 3, 1], 0), 2)
	assert_eq(PerudoRules.next_active_player([2, 0, 3, 1], 3), 0)
	assert_eq(PerudoRules.next_active_player([0, 0, 0], 0), -1, "никого нет")


func test_winner() -> void:
	assert_eq(PerudoRules.winner([0, 3, 0]), 1)
	assert_eq(PerudoRules.winner([1, 3, 0]), -1, "ещё двое в игре")
