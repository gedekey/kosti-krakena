extends GutTest
## М17: условия достижений (AchievementTracker) и их сохранение.

const Id := Achievement.Id
const HUMAN := AchievementTracker.HUMAN_ID
const BOT := 1

var t: AchievementTracker


func before_each() -> void:
	t = AchievementTracker.new()


func _win(players := 4) -> void:
	t.begin_match(players)
	t.match_ended(HUMAN)


func _unlocked() -> Array:
	var out := []
	for id in Achievement.ALL:
		if t.is_unlocked(id):
			out.append(id)
	return out


func test_catalog_has_18_distinct_achievements_with_texts() -> void:
	assert_eq(Achievement.ALL.size(), 18)
	var names := {}
	for id in Achievement.ALL:
		var name := Achievement.save_name(id)
		assert_false(names.has(name), name)
		names[name] = true
		assert_eq(Achievement.from_save_name(name), id)
		assert_ne(tr(Achievement.name_key(id)), Achievement.name_key(id), "есть перевод")
		assert_ne(tr(Achievement.desc_key(id)), Achievement.desc_key(id), "есть описание")
	assert_eq(Achievement.from_save_name("nope"), -1)


func test_nothing_unlocked_at_start() -> void:
	assert_eq(t.unlocked_count(), 0)


func test_clean_flawless_win_unlocks_win_achievements() -> void:
	_win(4)
	assert_true(t.is_unlocked(Id.FIRST_WIN))
	assert_true(t.is_unlocked(Id.FLAWLESS), "ни одного кубика не потеряно")
	assert_true(t.is_unlocked(Id.CLEAN_HANDS), "без трюков, 3 соперника")
	assert_false(t.is_unlocked(Id.FULL_HOUSE), "стол не полный")
	assert_false(t.is_unlocked(Id.LAST_DIE))
	assert_false(t.is_unlocked(Id.VETERAN))


func test_bot_win_gives_nothing() -> void:
	t.begin_match(4)
	t.match_ended(BOT)
	assert_eq(t.unlocked_count(), 0)
	assert_eq(t.progress(Id.VETERAN), 0)


func test_clean_hands_needs_enough_opponents_and_no_tricks() -> void:
	_win(3)
	assert_false(t.is_unlocked(Id.CLEAN_HANDS), "2 соперника — мало")
	t.begin_match(4)
	t.cheat_failed(HUMAN)
	t.match_ended(HUMAN)
	assert_false(t.is_unlocked(Id.CLEAN_HANDS), "пойманный трюк — тоже трюк")


func test_veteran_after_ten_wins_with_progress() -> void:
	for i in Achievement.VETERAN_WINS - 1:
		_win()
	assert_eq(t.progress(Id.VETERAN), Achievement.VETERAN_WINS - 1)
	assert_false(t.is_unlocked(Id.VETERAN))
	_win()
	assert_true(t.is_unlocked(Id.VETERAN))
	_win()
	assert_eq(t.progress(Id.VETERAN), Achievement.VETERAN_WINS, "не больше цели")


func test_full_house_on_six_players() -> void:
	_win(Achievement.FULL_HOUSE_PLAYERS)
	assert_true(t.is_unlocked(Id.FULL_HOUSE))


func test_last_die_and_lost_dice_break_flawless() -> void:
	t.begin_match(2)
	t.dice_changed(BOT, 4, -1)
	t.dice_changed(HUMAN, 4, -1)
	t.dice_changed(HUMAN, 1, -3)
	t.match_ended(HUMAN)
	assert_true(t.is_unlocked(Id.LAST_DIE))
	assert_false(t.is_unlocked(Id.FLAWLESS))


func test_abandoned_match_gives_nothing_and_next_match_starts_fresh() -> void:
	t.begin_match(4)
	t.dice_changed(HUMAN, 4, -1)
	# Сдался / вышел — match_ended не пришёл. Следующий матч — с чистого листа.
	t.begin_match(4)
	t.match_ended(HUMAN)
	assert_true(t.is_unlocked(Id.FLAWLESS))
	t.match_ended(HUMAN)
	assert_eq(t.progress(Id.VETERAN), 1, "повторный конец без начала не считается")


func test_liar_and_calza_only_when_right_and_called_by_human() -> void:
	t.challenge(MatchAction.Kind.DUDO, HUMAN, RevealResult.new(2, true, HUMAN, -1))
	t.challenge(MatchAction.Kind.DUDO, BOT, RevealResult.new(2, false, HUMAN, -1))
	t.challenge(MatchAction.Kind.CALZA, HUMAN, RevealResult.new(2, false, HUMAN, -1))
	assert_eq(t.unlocked_count(), 0)
	t.challenge(MatchAction.Kind.DUDO, HUMAN, RevealResult.new(1, false, BOT, -1))
	assert_true(t.is_unlocked(Id.LIAR_CALL))
	t.challenge(MatchAction.Kind.CALZA, HUMAN, RevealResult.new(3, true, HUMAN, 1))
	assert_true(t.is_unlocked(Id.CALZA_HIT))


func test_tricks_first_whisper_and_all_kinds() -> void:
	t.cheat_succeeded(BOT, Cheat.Kind.PEEK)
	assert_false(t.is_unlocked(Id.FIRST_TRICK), "чужой трюк не считается")
	t.cheat_succeeded(HUMAN, Cheat.Kind.PEEK)
	assert_true(t.is_unlocked(Id.FIRST_TRICK))
	t.cheat_succeeded(HUMAN, Cheat.Kind.PEEK)
	assert_eq(t.progress(Id.TRICKSTER), 1, "вид считается один раз")
	for kind in Cheat.ALL:
		assert_false(t.is_unlocked(Id.TRICKSTER))
		t.cheat_succeeded(HUMAN, kind)
	assert_true(t.is_unlocked(Id.TRICKSTER))
	assert_true(t.is_unlocked(Id.ABYSS_VOICE))


func test_accusations() -> void:
	t.accusation(HUMAN, false)
	t.accusation(BOT, true)
	assert_false(t.is_unlocked(Id.SHARP_EYE))
	for i in Achievement.HUNTER_CATCHES - 1:
		t.accusation(HUMAN, true)
	assert_true(t.is_unlocked(Id.SHARP_EYE))
	assert_false(t.is_unlocked(Id.HUNTER))
	t.accusation(HUMAN, true)
	assert_true(t.is_unlocked(Id.HUNTER))


func test_madness_and_mad_win() -> void:
	t.begin_match(4)
	t.madness(BOT)
	assert_false(t.is_unlocked(Id.INTO_ABYSS))
	t.madness(HUMAN)
	assert_true(t.is_unlocked(Id.INTO_ABYSS))
	t.match_ended(HUMAN)
	assert_true(t.is_unlocked(Id.MAD_CAPTAIN))
	t.begin_match(4)
	t.match_ended(HUMAN)
	assert_true(t.is_unlocked(Id.MAD_CAPTAIN), "открытое остаётся")


func test_unlock_signal_fires_once() -> void:
	watch_signals(t)
	_win()
	_win()
	assert_signal_emit_count(t, "unlocked", 3, "первая победа, ни царапины, чистые руки")


func test_save_roundtrip_and_bad_data() -> void:
	_win()
	t.accusation(HUMAN, true)
	t.cheat_succeeded(HUMAN, Cheat.Kind.SLEIGHT)
	var copy := AchievementTracker.new()
	copy.from_dict(t.to_dict())
	assert_eq(_unlocked().size(), copy.unlocked_count())
	for id in Achievement.ALL:
		assert_eq(copy.is_unlocked(id), t.is_unlocked(id), Achievement.save_name(id))
		assert_eq(copy.progress(id), t.progress(id), Achievement.save_name(id))
	copy.from_dict({"unlocked": ["first_win", "junk", 5], "wins": -3, "catches": "x",
			"trick_kinds": [0, 99, "a"]})
	assert_eq(copy.unlocked_count(), 1)
	assert_eq(copy.progress(Id.VETERAN), 0)
	assert_eq(copy.progress(Id.TRICKSTER), 1)
	copy.from_dict({})
	assert_eq(copy.unlocked_count(), 0)


# --- Автозагрузка Achievements ------------------------------------------------------

func test_autoload_listens_to_events_and_skips_tutorial() -> void:
	Achievements.reset()
	Stats.recording = false
	Events.match_started.emit(4, 0)
	Events.match_ended.emit(0)
	assert_eq(Achievements.unlocked_count(), 0, "обучение не считается")
	Stats.recording = true
	Events.match_started.emit(4, 0)
	Events.madness_began.emit(0)
	Events.match_ended.emit(0)
	assert_true(Achievements.is_unlocked(Id.FIRST_WIN))
	assert_true(Achievements.is_unlocked(Id.MAD_CAPTAIN))
	Achievements.reset()
	Stats.reset()
