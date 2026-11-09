extends GutTest
## М20: ранги за столом (учёт матча, итог на экране поражения) и в меню.

const TableScene := preload("res://scenes/table.tscn")
const MainMenu := preload("res://scenes/main_menu.tscn")
const StatsScene := preload("res://scenes/stats.tscn")
const Mode := RankTracker.Mode
const Tier := RankBalance.Tier


func before_each() -> void:
	MatchSetup.pending = null
	ScreenNav.history.clear()
	for flag in HintPanel.TOPICS:
		Stats.set_flag(flag)
	Ranks.reset()


func after_each() -> void:
	get_tree().paused = false
	Stats.clear_flags()
	Stats.reset()
	Ranks.reset()
	MatchSetup.pending = null


func _set_rank(mode: Mode, tier: Tier, glory: int) -> void:
	Ranks.tracker.ladder(mode).tier = tier
	Ranks.tracker.ladder(mode).glory = glory


func _table(setup: MatchSetup = null) -> Control:
	Rng.set_master_seed(5)
	MatchSetup.pending = setup
	return add_child_autofree(TableScene.instantiate())


func test_single_match_is_counted_with_bot_stars() -> void:
	var setup := MatchSetup.from_settings()
	setup.opponents = [&"deep_one"]
	_table(setup)
	assert_true(Ranks.is_counting())
	assert_eq(Ranks.tracker._gain_multiplier, 1.25, "Глубоководный ★★★")


func test_surrender_costs_glory_and_shows_rank() -> void:
	_set_rank(Mode.SINGLE, Tier.GOLD, 100)
	var table := _table()
	table.open_pause()
	table._pause.surrender_button.pressed.emit()
	assert_eq(Ranks.glory(Mode.SINGLE), 70, "последнее из 4 мест на Золоте: −30")
	assert_false(Ranks.is_counting())
	var panel: MatchEndPanel = table._end_panel
	assert_true(panel.rank_badge.is_visible_in_tree())
	assert_eq(panel.rank_delta.text, tr("RANK_DELTA") % -30)
	assert_eq(Ranks.glory(Mode.NET), 0, "сетевой ранг не тронут")


func test_quit_to_menu_mid_match_counts_as_forfeit() -> void:
	_set_rank(Mode.SINGLE, Tier.BRONZE, 50)
	var table := _table()
	table.open_pause()
	table._pause.quit_button.pressed.emit()
	assert_eq(Ranks.glory(Mode.SINGLE), 35, "Бронза: потери ×0,5")


func test_promotion_message() -> void:
	_set_rank(Mode.SINGLE, Tier.WOOD, 90)
	var table := _table()
	Ranks.tracker.match_ended(RankTracker.HUMAN_ID)
	table._end_panel.show_result(true, null, "", false)
	table._show_rank()
	var panel: MatchEndPanel = table._end_panel
	assert_eq(Ranks.tier(Mode.SINGLE), Tier.BRONZE)
	assert_true(panel.rank_note.visible)
	assert_eq(panel.rank_note.text, tr("RANK_PROMOTED") % tr("RANK_BRONZE"))


func test_tutorial_does_not_count() -> void:
	var table := _table(MatchSetup.for_tutorial())
	assert_false(Ranks.is_counting())
	table._end_panel.show_result(true, null, "", false)
	table._show_rank()
	assert_false(table._end_panel.rank_badge.is_visible_in_tree())


func test_main_menu_shows_single_rank() -> void:
	_set_rank(Mode.SINGLE, Tier.RUBY, 12)
	Stats.set_flag(Stats.FLAG_TUTORIAL_OFFERED)
	var menu: Control = add_child_autofree(MainMenu.instantiate())
	assert_eq(menu.rank_badge.title_label.text, tr("RANK_RUBY"))
	assert_eq(menu.rank_badge.glory_label.text, tr("RANK_GLORY") % [12, 300])


func test_stats_screen_shows_both_ranks() -> void:
	_set_rank(Mode.SINGLE, Tier.PHILOSOPHER, 999)
	_set_rank(Mode.NET, Tier.SILVER, 40)
	var screen: Control = add_child_autofree(StatsScene.instantiate())
	assert_eq(screen.single_rank.title_label.text, tr("RANK_PHILOSOPHER"))
	assert_eq(screen.single_rank.glory_label.text, tr("RANK_GLORY_TOP") % 999)
	assert_eq(screen.net_rank.title_label.text, tr("RANK_SILVER"))


func test_rank_icons_exist_in_both_sizes() -> void:
	for tier in RankBalance.ALL_TIERS:
		var small := RankBadge.texture(tier)
		var big := RankBadge.texture(tier, true)
		assert_eq(small.get_size(), Vector2(32, 32), RankBalance.SAVE_NAMES[tier])
		assert_eq(big.get_size(), Vector2(64, 64), RankBalance.SAVE_NAMES[tier])
