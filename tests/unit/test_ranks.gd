extends GutTest
## М20: ранги (RankLadder, RankTracker) — Слава за место, повышение, понижение, сохранение.

const Tier := RankBalance.Tier
const Mode := RankTracker.Mode
const HUMAN := RankTracker.HUMAN_ID

var t: RankTracker


func before_each() -> void:
	t = RankTracker.new()


func _ladder(tier: Tier, glory: int) -> RankLadder:
	var l := RankLadder.new()
	l.tier = tier
	l.glory = glory
	return l


# --- Слава за место ---------------------------------------------------------------

func test_place_glory_four_players_at_gold() -> void:
	var gold := _ladder(Tier.GOLD, 50)
	assert_eq(gold.place_glory(1, 4), 40)
	assert_eq(gold.place_glory(2, 4), 17)
	assert_eq(gold.place_glory(3, 4), -7)
	assert_eq(gold.place_glory(4, 4), -30)


func test_duel_is_win_or_last() -> void:
	var gold := _ladder(Tier.GOLD, 0)
	assert_eq(gold.place_glory(1, 2), RankBalance.WIN_GLORY)
	assert_eq(gold.place_glory(2, 2), RankBalance.LAST_PLACE_GLORY)


func test_losses_scale_by_tier() -> void:
	assert_eq(RankLadder.glory_for(4, 4, Tier.WOOD), 0, "на Дереве не теряешь")
	assert_eq(RankLadder.glory_for(4, 4, Tier.BRONZE), -15)
	assert_eq(RankLadder.glory_for(4, 4, Tier.SILVER), -23)
	assert_eq(RankLadder.glory_for(4, 4, Tier.RUBY), -38)
	assert_eq(RankLadder.glory_for(4, 4, Tier.PHILOSOPHER), -45)


func test_gain_multiplier_only_for_gains() -> void:
	assert_eq(RankLadder.glory_for(1, 4, Tier.GOLD, 0.75), 30)
	assert_eq(RankLadder.glory_for(1, 4, Tier.GOLD, 1.25), 50)
	assert_eq(RankLadder.glory_for(4, 4, Tier.GOLD, 0.75), -30)


func test_star_multiplier_is_average() -> void:
	assert_eq(RankBalance.star_multiplier([1]), 0.75)
	assert_eq(RankBalance.star_multiplier([2, 2, 2]), 1.0)
	assert_eq(RankBalance.star_multiplier([1, 3]), 1.0)
	assert_eq(RankBalance.star_multiplier([3, 3]), 1.25)
	assert_eq(RankBalance.star_multiplier([]), 1.0)


# --- Повышение и понижение --------------------------------------------------------

func test_promotion_carries_over_glory() -> void:
	var l := _ladder(Tier.WOOD, 90)
	var change := l.apply(40)
	assert_eq(l.tier, Tier.BRONZE)
	assert_eq(l.glory, 30)
	assert_true(change.promoted())
	assert_eq(change.old_tier, Tier.WOOD)
	assert_eq(change.old_glory, 90)


func test_top_tier_keeps_accumulating() -> void:
	var l := _ladder(Tier.PHILOSOPHER, 1000)
	l.apply(40)
	assert_eq(l.tier, Tier.PHILOSOPHER)
	assert_eq(l.glory, 1040)


func test_loss_stops_at_zero_first() -> void:
	var l := _ladder(Tier.SILVER, 10)
	var change := l.apply(-22)
	assert_eq(l.tier, Tier.SILVER)
	assert_eq(l.glory, 0)
	assert_false(change.demoted())


func test_loss_at_zero_demotes_with_half_threshold() -> void:
	var l := _ladder(Tier.SILVER, 0)
	var change := l.apply(-5)
	assert_eq(l.tier, Tier.BRONZE)
	assert_eq(l.glory, 75)
	assert_true(change.demoted())


func test_wood_never_demotes() -> void:
	var l := _ladder(Tier.WOOD, 0)
	l.apply(-10)
	assert_eq(l.tier, Tier.WOOD)
	assert_eq(l.glory, 0)


func test_zero_delta_at_zero_glory_keeps_rank() -> void:
	var l := _ladder(Tier.GOLD, 0)
	l.apply(0)
	assert_eq(l.tier, Tier.GOLD)


# --- Учёт матча --------------------------------------------------------------------

func test_single_win_counts_with_star_multiplier() -> void:
	t.begin_single(4, [3, 3, 3])
	t.player_eliminated(2)
	t.player_eliminated(3)
	t.match_ended(HUMAN)
	assert_eq(t.glory(Mode.SINGLE), 50)
	assert_eq(t.last_change.place, 1)
	assert_eq(t.last_change.mode, Mode.SINGLE)
	assert_eq(t.glory(Mode.NET), 0, "сетевой ранг не тронут")


func test_place_by_elimination_order() -> void:
	t.ladder(Mode.SINGLE).tier = Tier.GOLD
	t.ladder(Mode.SINGLE).glory = 100
	t.begin_single(4, [2, 2, 2])
	t.player_eliminated(1)
	t.player_eliminated(HUMAN)       # двое остались — третье место
	assert_eq(t.last_change.place, 3)
	assert_eq(t.glory(Mode.SINGLE), 93)
	t.match_ended(2)
	assert_eq(t.glory(Mode.SINGLE), 93, "после места матч ранг не трогает")


func test_settles_once_and_emits() -> void:
	watch_signals(t)
	t.begin_single(2, [2])
	t.player_eliminated(HUMAN)
	t.match_ended(1)
	assert_signal_emit_count(t, "settled", 1)
	assert_false(t.is_counting())


func test_forfeit_is_worst_remaining_place() -> void:
	t.ladder(Mode.SINGLE).tier = Tier.GOLD
	t.ladder(Mode.SINGLE).glory = 100
	t.begin_single(5, [2, 2, 2, 2])
	t.player_eliminated(4)
	t.forfeit()
	assert_eq(t.last_change.place, 4)
	assert_eq(t.glory(Mode.SINGLE), 100 - 13)


func test_net_needs_two_humans() -> void:
	t.begin_net(4, 1)
	assert_false(t.is_counting())
	t.match_ended(HUMAN)
	assert_eq(t.glory(Mode.NET), 0)
	assert_null(t.last_change)
	t.begin_net(4, 2)
	t.match_ended(HUMAN)
	assert_eq(t.glory(Mode.NET), 40)
	assert_eq(t.glory(Mode.SINGLE), 0)


func test_abort_changes_nothing() -> void:
	t.begin_net(3, 3)
	t.abort()
	t.forfeit()
	t.match_ended(1)
	assert_eq(t.glory(Mode.NET), 0)
	assert_null(t.last_change)


func test_skip_ignores_events() -> void:
	t.skip()
	t.match_ended(HUMAN)
	assert_eq(t.glory(Mode.SINGLE), 0)


# --- Сохранение -------------------------------------------------------------------

func test_save_round_trip() -> void:
	t.ladder(Mode.SINGLE).tier = Tier.RUBY
	t.ladder(Mode.SINGLE).glory = 120
	t.ladder(Mode.NET).tier = Tier.BRONZE
	t.ladder(Mode.NET).glory = 7
	var other := RankTracker.new()
	other.from_dict(t.to_dict())
	assert_eq(other.tier(Mode.SINGLE), Tier.RUBY)
	assert_eq(other.glory(Mode.SINGLE), 120)
	assert_eq(other.tier(Mode.NET), Tier.BRONZE)
	assert_eq(other.glory(Mode.NET), 7)


func test_bad_save_falls_back_to_wood() -> void:
	t.from_dict({"single": {"tier": "mithril", "glory": 5}, "net": {"tier": "gold", "glory": -3}})
	assert_eq(t.tier(Mode.SINGLE), Tier.WOOD)
	assert_eq(t.glory(Mode.SINGLE), 0)
	assert_eq(t.tier(Mode.NET), Tier.GOLD)
	assert_eq(t.glory(Mode.NET), 0)


func test_saved_glory_capped_below_threshold() -> void:
	t.from_dict({"single": {"tier": "wood", "glory": 999}})
	assert_eq(t.glory(Mode.SINGLE), 99)


func test_rank_names_translated() -> void:
	for tier in RankBalance.ALL_TIERS:
		var key := RankBalance.name_key(tier)
		assert_ne(tr(key), key, key)
