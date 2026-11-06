extends GutTest
## Вероятностная математика ставок (М3): BidMath и TableEstimate.

const EPS := 0.000001


func _sum(pmf: PackedFloat64Array) -> float:
	var total := 0.0
	for v in pmf:
		total += v
	return total


func _view(own: Array, counts: Array, history: Array = [], palifico := false,
		me := 0) -> PlayerView:
	var view := PlayerView.new()
	view.player_id = me
	view.own_dice.assign(own)
	view.dice_counts.assign(counts)
	view.round_rules = RoundRules.new(palifico)
	view.options = RuleOptions.new()
	for entry in history:
		view.bid_history.append(BidEntry.new(entry[0], Bid.new(entry[1], entry[2])))
	if not view.bid_history.is_empty():
		view.current_bid = view.bid_history[-1].bid
		view.current_bidder = view.bid_history[-1].player_id
	return view


# --- BidMath -------------------------------------------------------------------

func test_match_chance_counts_jokers_only_when_wild() -> void:
	assert_almost_eq(BidMath.match_chance(5, true), 1.0 / 3.0, EPS)
	assert_almost_eq(BidMath.match_chance(1, true), 1.0 / 6.0, EPS, "единицы — только единицы")
	assert_almost_eq(BidMath.match_chance(5, false), 1.0 / 6.0, EPS, "Palifico: без джокеров")


func test_binomial_known_values_and_sum() -> void:
	var pmf := BidMath.binomial(2, 0.5)
	assert_eq(pmf.size(), 3)
	assert_almost_eq(pmf[0], 0.25, EPS)
	assert_almost_eq(pmf[1], 0.5, EPS)
	assert_almost_eq(pmf[2], 0.25, EPS)
	assert_almost_eq(_sum(BidMath.binomial(25, 1.0 / 3.0)), 1.0, EPS)
	assert_eq(BidMath.binomial(0, 0.3), PackedFloat64Array([1.0]), "0 кубиков — 0 совпадений")


func test_convolution_of_binomials_is_binomial() -> void:
	var p := 1.0 / 3.0
	var conv := BidMath.convolve(BidMath.binomial(3, p), BidMath.binomial(4, p))
	var direct := BidMath.binomial(7, p)
	assert_eq(conv.size(), direct.size())
	for k in direct.size():
		assert_almost_eq(conv[k], direct[k], EPS)


func test_tail_and_exact() -> void:
	var pmf := BidMath.binomial(2, 0.5)
	assert_eq(BidMath.at_least(pmf, 0), 1.0)
	assert_eq(BidMath.at_least(pmf, -3), 1.0, "уже набрано своими — ставка точно верна")
	assert_almost_eq(BidMath.at_least(pmf, 1), 0.75, EPS)
	assert_eq(BidMath.at_least(pmf, 3), 0.0)
	assert_almost_eq(BidMath.exactly(pmf, 1), 0.5, EPS)
	assert_eq(BidMath.exactly(pmf, -1), 0.0)
	assert_eq(BidMath.exactly(pmf, 5), 0.0)
	assert_almost_eq(BidMath.expected(pmf), 1.0, EPS)


func test_mix_and_shift() -> void:
	var shifted := BidMath.shift(PackedFloat64Array([0.5, 0.5]), 1)
	assert_eq(shifted, PackedFloat64Array([0.0, 0.5, 0.5]))
	var mixed := BidMath.mix(PackedFloat64Array([1.0]), shifted, 0.5)
	assert_almost_eq(mixed[0], 0.5, EPS)
	assert_almost_eq(mixed[1], 0.25, EPS)
	assert_almost_eq(mixed[2], 0.25, EPS)


# --- TableEstimate -------------------------------------------------------------

func test_own_dice_count_with_jokers() -> void:
	var est := TableEstimate.new(_view([1, 5, 5, 3, 1], [5, 5]))
	assert_eq(est.own_count(5), 4)
	assert_eq(est.own_count(1), 2)
	assert_eq(est.p_at_least(5, 4), 1.0, "своих хватает — ставка верна наверняка")


func test_unknown_dice_follow_binomial() -> void:
	var est := TableEstimate.new(_view([2, 3, 4, 6, 6], [5, 3, 2]))
	var expected := BidMath.binomial(5, 1.0 / 3.0)
	var pmf := est.unknown_pmf(5)
	assert_eq(pmf.size(), 6, "неизвестны только 5 чужих кубиков")
	for k in expected.size():
		assert_almost_eq(pmf[k], expected[k], EPS)
	assert_almost_eq(est.p_at_least(5, 2), BidMath.at_least(expected, 2), EPS)
	assert_almost_eq(est.p_exactly(5, 1), expected[1], EPS)
	assert_almost_eq(est.expected_count(6), 2 + 5.0 / 3.0, EPS)


func test_eliminated_players_are_ignored() -> void:
	var est := TableEstimate.new(_view([2], [1, 0, 2]))
	assert_eq(est.unknown_pmf(4).size(), 3)


func test_palifico_ones_are_not_wild() -> void:
	var est := TableEstimate.new(_view([1, 1], [2, 3], [], true))
	assert_eq(est.own_count(4), 0)
	assert_almost_eq(est.p_at_least(4, 3), pow(1.0 / 6.0, 3), EPS)


func test_opponent_bids_raise_belief_only_with_reading() -> void:
	var history := [[1, 3, 4]]
	var naive := TableEstimate.new(_view([2, 3, 5, 6, 6], [5, 5], history), 0.0)
	var reader := TableEstimate.new(_view([2, 3, 5, 6, 6], [5, 5], history), 0.8)
	assert_almost_eq(naive.p_at_least(4, 3),
			BidMath.at_least(BidMath.binomial(5, 1.0 / 3.0), 3), EPS)
	assert_gt(reader.p_at_least(4, 3), naive.p_at_least(4, 3), "соперник ставил на четвёрки")
	assert_almost_eq(reader.p_at_least(3, 3), naive.p_at_least(3, 3), EPS,
			"на другие грани ставка соперника не влияет")
	assert_almost_eq(_sum(reader.unknown_pmf(4)), 1.0, EPS)


func test_own_bids_are_not_hints() -> void:
	var history := [[0, 3, 4]]
	var a := TableEstimate.new(_view([2, 3, 5, 6, 6], [5, 5], history), 1.0)
	var b := TableEstimate.new(_view([2, 3, 5, 6, 6], [5, 5]), 1.0)
	assert_almost_eq(a.p_at_least(4, 3), b.p_at_least(4, 3), EPS)


func test_ones_bid_hints_every_face_when_wild() -> void:
	var history := [[1, 2, 1]]
	var naive := TableEstimate.new(_view([2, 3, 5, 6, 6], [5, 5], history), 0.0)
	var reader := TableEstimate.new(_view([2, 3, 5, 6, 6], [5, 5], history), 1.0)
	assert_gt(reader.p_at_least(4, 3), naive.p_at_least(4, 3))
