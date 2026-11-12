extends GutTest
## М24: реплики соперников — выбор реплики (детерминизм по seed), одно облако за раз,
## паузы персонажей, важные реплики, выключатель, сюжетные реплики, тексты RU + EN,
## «бормотание».

const Occ := BarkBalance.Occasion


class Clock:
	var t := 100.0

	func now() -> float:
		return t


var clock: Clock
var said: Array = []


func before_each() -> void:
	clock = Clock.new()
	said.clear()


## Ключи-заглушки: у каждого персонажа по 2 варианта на каждый повод.
static func _fake_has(key: String) -> bool:
	return key.ends_with("_1") or key.ends_with("_2")


func _director(seed_value := 1, speakers: Array = [&"", &"sailor", &"witch", &"craber"],
		has_key: Callable = _fake_has, all_chances := true) -> BarkDirector:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var d := BarkDirector.new(rng, BarkLines.new(has_key), clock.now, func(k: String) -> String: return k)
	if all_chances:
		for occ in d.chances:
			d.chances[occ] = 1.0
	d.set_speakers(speakers)
	d.bark.connect(func(b: BarkDirector.Bark) -> void: said.append(b))
	return d


func _reveal(kind: MatchAction.Kind, bidder: int, caller: int) -> ChallengeReveal:
	return ChallengeReveal.new(kind, Bid.new(3, 4), bidder, caller, [], false, null)


# --- Ключи -----------------------------------------------------------------------------

func test_keys_by_character_and_occasion() -> void:
	assert_eq(BarkLines.base_key("", &"plague_cultist", Occ.LIAR_AGAINST),
			"BARK_PLAGUE_CULTIST_LIAR_AGAINST")
	assert_eq(BarkLines.base_key("L5", &"drowned", Occ.LOSE), "BARK_L5_DROWNED_LOSE")
	var lines := BarkLines.new(_fake_has)
	assert_eq(lines.regular(&"sailor", Occ.WIN),
			PackedStringArray(["BARK_SAILOR_WIN_1", "BARK_SAILOR_WIN_2"]))
	assert_eq(lines.story_lines(&"sailor", Occ.WIN).size(), 0, "без уровня сюжетных нет")


func test_duration_is_two_to_four_seconds_by_length() -> void:
	assert_eq(BarkBalance.duration_for(1), BarkBalance.DURATION_MIN)
	assert_eq(BarkBalance.duration_for(500), BarkBalance.DURATION_MAX)
	assert_gt(BarkBalance.duration_for(40), BarkBalance.duration_for(10))
	assert_between(BarkBalance.duration_for(30), 2.0, 4.0)


# --- Выбор -----------------------------------------------------------------------------

## Длинная история событий; облака «проходят» между событиями.
func _script(d: BarkDirector) -> PackedStringArray:
	var out := PackedStringArray()
	d.on_match_started(4, 0)
	for i in 40:
		clock.t += 3.0
		match i % 6:
			0: d.on_bid_placed(0, Bid.new(2, 3))
			1: d.on_challenge_revealed(_reveal(MatchAction.Kind.DUDO, 0, 1 + i % 3))
			2: d.on_dice_count_changed(1 + i % 3, 3, -1)
			3: d.on_evidence_shown(0)
			4: d.on_challenge_revealed(_reveal(MatchAction.Kind.CALZA, 1, 2))
			5: d.on_madness_began(0)
	for b: BarkDirector.Bark in said:
		out.append("%d:%s" % [b.speaker_id, b.key])
	return out


func test_same_seed_same_barks() -> void:
	var first := _script(_director(7, [&"", &"sailor", &"witch", &"craber"], _fake_has, false))
	said.clear()
	clock.t = 100.0
	var second := _script(_director(7, [&"", &"sailor", &"witch", &"craber"], _fake_has, false))
	assert_gt(first.size(), 3, "реплики были")
	assert_eq(first, second, "тот же seed — те же реплики")
	said.clear()
	clock.t = 100.0
	var other := _script(_director(8, [&"", &"sailor", &"witch", &"craber"], _fake_has, false))
	assert_ne(first, other, "другой seed — другие")


func test_human_never_speaks_and_bots_comment_on_human_bid() -> void:
	var d := _director()
	d.on_bid_placed(1, Bid.new(2, 3))
	assert_eq(said.size(), 0, "ставка бота — не повод")
	d.on_bid_placed(0, Bid.new(2, 3))
	assert_eq(said.size(), 1)
	assert_ne(said[0].speaker_id, 0)
	assert_eq(said[0].occasion, Occ.PLAYER_BID)
	clock.t += 100.0
	d.on_cheat_failed(0, Cheat.Kind.PEEK)
	assert_eq(said[1].occasion, Occ.GLOAT, "поймали человека — злорадствует бот")
	assert_ne(said[1].speaker_id, 0)


func test_liar_by_bot_or_against_bot() -> void:
	var d := _director()
	d.on_challenge_revealed(_reveal(MatchAction.Kind.DUDO, 0, 2))
	assert_eq(said[0].speaker_id, 2)
	assert_eq(said[0].occasion, Occ.LIAR)
	clock.t += 100.0
	d.on_challenge_revealed(_reveal(MatchAction.Kind.DUDO, 3, 0))
	assert_eq(said[1].speaker_id, 3)
	assert_eq(said[1].occasion, Occ.LIAR_AGAINST, "человек оспорил ставку бота")


func test_one_cloud_at_a_time() -> void:
	var d := _director()
	d.on_challenge_revealed(_reveal(MatchAction.Kind.DUDO, 0, 1))
	assert_eq(said.size(), 1)
	var shown: BarkDirector.Bark = said[0]
	clock.t += 1.0
	d.on_evidence_shown(0)
	assert_eq(said.size(), 1, "облако ещё висит — молчим")
	clock.t = shown.shown_at + shown.duration + 0.1
	d.on_evidence_shown(0)
	assert_eq(said.size(), 1, "и паузу после облака тоже")
	clock.t = shown.shown_at + shown.duration + BarkBalance.GAP_AFTER_BUBBLE
	d.on_evidence_shown(0)
	assert_eq(said.size(), 2, "после паузы — снова можно")


func test_character_cooldown() -> void:
	var d := _director(1, [&"", &"sailor"])
	d.on_challenge_revealed(_reveal(MatchAction.Kind.DUDO, 0, 1))
	assert_eq(said.size(), 1)
	clock.t += BarkBalance.DURATION_MAX + BarkBalance.GAP_AFTER_BUBBLE + 0.1
	d.on_challenge_revealed(_reveal(MatchAction.Kind.DUDO, 0, 1))
	assert_eq(said.size(), 1, "у персонажа пауза между репликами")
	clock.t = said[0].shown_at + BarkBalance.CHARACTER_COOLDOWN
	d.on_challenge_revealed(_reveal(MatchAction.Kind.DUDO, 0, 1))
	assert_eq(said.size(), 2)


func test_important_bark_replaces_fresh_cloud_only() -> void:
	var d := _director()
	d.on_dice_count_changed(1, 0, -1)
	assert_eq(said.size(), 0, "ноль кубиков — повод «выбыл», не «потерял»")
	d.on_player_eliminated(1)
	assert_eq(said[0].occasion, Occ.LOSE)
	d.on_match_ended(2)
	assert_eq(said.size(), 2, "победа важнее и в ту же секунду — сменяет облако")
	assert_eq(d.current().occasion, Occ.WIN)
	assert_eq(d.current().speaker_id, 2)
	clock.t += 100.0
	d.on_evidence_shown(0)
	assert_eq(said.size(), 3)
	d.on_bid_placed(0, Bid.new(2, 3))
	assert_eq(said.size(), 3, "менее важное не сменяет")


func test_late_important_bark_does_not_replace() -> void:
	var d := _director()
	d.on_player_eliminated(1)
	clock.t += BarkBalance.REPLACE_WINDOW + 0.1
	d.on_match_ended(2)
	assert_eq(said.size(), 1, "облако уже читают — не сменяем")


func test_eliminated_bot_is_silent() -> void:
	var d := _director(1, [&"", &"sailor", &"witch"])
	d.on_player_eliminated(1)
	clock.t += 100.0
	for i in 10:
		clock.t += 100.0
		d.on_bid_placed(0, Bid.new(2, 3))
	for b: BarkDirector.Bark in said.slice(1):
		assert_eq(b.speaker_id, 2, "выбывший молчит")


func test_switch_off() -> void:
	var d := _director()
	d.enabled = false
	d.on_match_started(4, 0)
	d.on_challenge_revealed(_reveal(MatchAction.Kind.DUDO, 0, 1))
	d.on_match_ended(1)
	assert_eq(said.size(), 0)
	d.enabled = true
	d.on_match_started(4, 0)
	assert_eq(said.size(), 1)


func test_chance_zero_means_silence() -> void:
	var d := _director()
	d.chances[Occ.LIAR] = 0.0
	d.on_challenge_revealed(_reveal(MatchAction.Kind.DUDO, 0, 1))
	assert_eq(said.size(), 0)


func test_no_same_line_twice_in_a_row() -> void:
	var d := _director(3, [&"", &"sailor"])
	for i in 12:
		d.on_challenge_revealed(_reveal(MatchAction.Kind.DUDO, 0, 1))
		clock.t += BarkBalance.CHARACTER_COOLDOWN + 1.0
	assert_eq(said.size(), 12)
	for i in range(1, said.size()):
		assert_ne(said[i].key, said[i - 1].key)


func test_story_lines_extend_regular() -> void:
	var has := func(key: String) -> bool:
		return key == "BARK_L1_SAILOR_MATCH_START_1" or _fake_has(key)
	var story := 0
	for seed_value in 30:
		said.clear()
		var d := _director(seed_value, [&"", &"sailor"], has)
		d.lines.story = "L1"
		d.on_match_started(2, 0)
		if said[0].key.begins_with("BARK_L1_"):
			story += 1
	assert_between(story, 10, 29, "сюжетные — чаще обычных, но не всегда")
	said.clear()
	var plain := _director(1, [&"", &"sailor"], has)
	plain.on_match_started(2, 0)
	assert_false(said[0].key.begins_with("BARK_L1_"), "вне кампании — только обычные")


func test_seat_given_to_bot_in_net_stays_silent_until_set() -> void:
	var d := _director(1, [&"", &""])
	d.on_challenge_revealed(_reveal(MatchAction.Kind.DUDO, 0, 1))
	assert_eq(said.size(), 0, "человек за сетевым столом не говорит")
	d.set_speaker(1, &"witch")
	d.on_challenge_revealed(_reveal(MatchAction.Kind.DUDO, 0, 1))
	assert_eq(said.size(), 1)


func test_listens_to_bus() -> void:
	var bus := Node.new()
	bus.set_script(load("res://autoload/events.gd"))
	var d := _director()
	d.listen(bus)
	bus.match_started.emit(4, 0)
	assert_eq(said.size(), 1)
	d.unlisten()
	clock.t += 100.0
	bus.match_started.emit(4, 0)
	assert_eq(said.size(), 1, "отписался")
	bus.free()


# --- Тексты ----------------------------------------------------------------------------

func test_every_opponent_has_lines_for_every_occasion_in_both_languages() -> void:
	var saved := TranslationServer.get_locale()
	for locale in ["ru", "en"]:
		TranslationServer.set_locale(locale)
		var lines := BarkLines.new()
		for p in BotRoster.all():
			for occ in Occ.values():
				var keys := lines.regular(p.id, occ)
				assert_between(keys.size(), 2, 3, "%s %s %s" % [locale, p.id, Occ.keys()[occ]])
				for key in keys:
					var text := tr(key)
					assert_ne(text, key)
					assert_lt(text.length(), 50, key)
	TranslationServer.set_locale(saved)


func test_story_lines_for_campaign_levels() -> void:
	var lines := BarkLines.new()
	var levels := {"L1": [&"sailor"], "L2": [&"ulits", &"ichthyander", &"craber"],
			"L3": [&"witch", &"omen"], "L4": [&"occultist", &"plague_cultist", &"scholar"],
			"L5": [&"drowned", &"horror_master"], "L6": [&"deep_one"]}
	for level: String in levels:
		lines.story = level
		for character: StringName in levels[level]:
			assert_gt(lines.story_lines(character, Occ.MATCH_START).size(), 0, level + character)
			assert_gt(lines.story_lines(character, Occ.LOSE).size(), 0, level + character)


# --- Бормотание ------------------------------------------------------------------------

func test_every_opponent_has_own_voice() -> void:
	var seen := {}
	for p in BotRoster.all():
		assert_true(BarkVoice.TIMBRES.has(p.id), String(p.id))
		seen[BarkVoice.timbre(p.id)["hz"]] = true
	assert_gt(seen.size(), 8, "тембры разные")


func test_syllable_is_deterministic_by_seed() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 5
	var b := RandomNumberGenerator.new()
	b.seed = 5
	var s1 := BarkVoice.render_syllable(&"craber", a)
	var s2 := BarkVoice.render_syllable(&"craber", b)
	assert_gt(s1.size(), 100)
	assert_eq(s1, s2)
	assert_almost_eq(SfxSynth.peak_of(s1), BarkVoice.PEAK, 0.01)
	assert_lt(BarkVoice.render_syllable(&"craber", a).size(),
			BarkVoice.render_syllable(&"ulits", a).size(), "Крабер отрывист, Улитс тянет")


func test_syllable_letters() -> void:
	assert_true(BarkVoice.is_syllable("а"))
	assert_true(BarkVoice.is_syllable("O"))
	assert_false(BarkVoice.is_syllable("к"))
	assert_false(BarkVoice.is_syllable("!"))
