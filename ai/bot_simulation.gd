class_name BotSimulation
extends RefCounted
## Симуляция матчей бот против бота (без нод и UI) и отчёт: винрейты (М3),
## стиль жульничества и обвинений по персонажам, частота Безумия, абляция трюков (М6).
## Запуск одной командой: tools/run_simulation.ps1.

## Защита от зацикливания: столько шагов автоматики на матч — заведомо больше нужного.
const MAX_STEPS_PER_MATCH := 20000
const DEFAULT_TABLE_SIZE := 4
## Абляция трюков: основа характера и её параметры для «жулика одного трюка».
const ABLATION_BASE_ID := &"witch"
const ABLATION_CHEAT_CHANCE := 0.5
const ABLATION_ACCUSE_THRESHOLD := 0.6
const ABLATION_EVIDENCE_MEMORY := 0.5


## Счёт персонажа: сыграно / выиграно.
class Tally:
	var played := 0
	var won := 0

	func rate() -> float:
		return 0.0 if played == 0 else float(won) / played


## Стиль персонажа за все матчи: трюки, провалы, обвинения, Безумие.
class Profile:
	var played := 0
	var won := 0
	## По Cheat.Kind: попытки и мгновенные провалы.
	var cheats: Array[int] = [0, 0, 0, 0, 0, 0]
	var failed: Array[int] = [0, 0, 0, 0, 0, 0]
	## Пойман по обвинению / обвинён зря.
	var caught_by_accusation := 0
	var falsely_accused := 0
	var accusations := 0
	var accusations_right := 0
	## Матчей, в которых сошёл с ума.
	var went_mad := 0

	func total_cheats() -> int:
		var t := 0
		for c in cheats:
			t += c
		return t

	func total_failed() -> int:
		var t := 0
		for c in failed:
			t += c
		return t

	func per_match(value: int) -> float:
		return 0.0 if played == 0 else float(value) / played

	func rate() -> float:
		return 0.0 if played == 0 else float(won) / played


## Пишет события матча в профили персонажей.
class Recorder:
	var _lineup: Array[BotPersonality]
	var _profiles: Dictionary

	func _init(lineup: Array[BotPersonality], profiles: Dictionary) -> void:
		_lineup = lineup
		_profiles = profiles

	func connect_to(mc: MatchController) -> void:
		mc.cheat_resolved.connect(_on_cheat_resolved)
		mc.cheat_failed.connect(_on_cheat_failed)
		mc.accusation_made.connect(_on_accusation)
		mc.madness_began.connect(_on_madness)

	func _of(player_id: int) -> Profile:
		return _profiles.get(_lineup[player_id].id)

	func _on_cheat_resolved(outcome: CheatOutcome) -> void:
		var pr := _of(outcome.player_id)
		if pr != null:
			pr.cheats[outcome.action.kind] += 1

	func _on_cheat_failed(player_id: int, kind: Cheat.Kind) -> void:
		var pr := _of(player_id)
		if pr != null:
			pr.cheats[kind] += 1
			pr.failed[kind] += 1

	func _on_accusation(accuser: int, target: int, guilty: bool) -> void:
		var a := _of(accuser)
		var t := _of(target)
		if a != null:
			a.accusations += 1
			if guilty:
				a.accusations_right += 1
		if t != null:
			if guilty:
				t.caught_by_accusation += 1
			else:
				t.falsely_accused += 1

	func _on_madness(player_id: int) -> void:
		var pr := _of(player_id)
		if pr != null:
			pr.went_mad += 1


## Один матч. lineup — персонажи по местам. Возвращает индекс победителя в lineup.
## profiles (id → Profile) — если задан, туда пишется статистика стиля.
static func play_match(lineup: Array[BotPersonality], options: RuleOptions,
		rng: RandomNumberGenerator, profiles: Dictionary = {}) -> int:
	var agents: Array[MatchAgent] = []
	for p in lineup:
		agents.append(BotAgent.new(p, _child_rng(rng)))
	var mc := MatchController.new(agents, options, _child_rng(rng))
	var track := not profiles.is_empty()
	var recorder: Recorder = null
	if track:
		recorder = Recorder.new(lineup, profiles)
		recorder.connect_to(mc)
	mc.start_match()
	var steps := 0
	while mc.advance_auto():
		steps += 1
		assert(steps < MAX_STEPS_PER_MATCH, "Simulation: match does not end")
	if track:
		for i in lineup.size():
			var prof: Profile = profiles.get(lineup[i].id)
			if prof == null:
				continue
			prof.played += 1
			if i == mc.winner_id:
				prof.won += 1
	return mc.winner_id


## Дуэль 1×1: доля побед a. Места чередуются, первый ход — случайный.
static func duel(a: BotPersonality, b: BotPersonality, matches: int,
		rng: RandomNumberGenerator, options := RuleOptions.new()) -> float:
	var wins := 0
	for i in matches:
		var a_first := i % 2 == 0
		var lineup: Array[BotPersonality] = [a, b]
		if not a_first:
			lineup.reverse()
		var winner := play_match(lineup, options, rng)
		if (winner == 0) == a_first:
			wins += 1
	return float(wins) / matches


## Столы по table_size случайных разных персонажей. id → Tally.
## profiles — если задан (id → Profile для каждого персонажа), туда пишется стиль.
static func tables(roster: Array[BotPersonality], table_size: int, matches: int,
		rng: RandomNumberGenerator, options := RuleOptions.new(),
		profiles: Dictionary = {}) -> Dictionary:
	var tally := {}
	for p in roster:
		tally[p.id] = Tally.new()
	for i in matches:
		var lineup := _random_lineup(roster, table_size, rng)
		var winner := play_match(lineup, options, rng, profiles)
		for p in lineup:
			tally[p.id].played += 1
		tally[lineup[winner].id].won += 1
	return tally


## Пустые профили для персонажей.
static func new_profiles(roster: Array[BotPersonality]) -> Dictionary:
	var out := {}
	for p in roster:
		out[p.id] = Profile.new()
	return out


## Жулик одного трюка: основа характера, жульничает только kind (null — честный контроль).
static func single_trick_cheater(base: BotPersonality, kind: Variant) -> BotPersonality:
	var p: BotPersonality = base.duplicate()
	p.id = StringName("only_%s" % Cheat.Kind.keys()[kind]) if kind != null else &"honest"
	var weights := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	if kind != null:
		weights[kind] = 1.0
	p.cheat_weights = weights
	p.cheat_chance = ABLATION_CHEAT_CHANCE if kind != null else 0.0
	p.risk_tolerance = 1.0
	p.sanity_reserve = 0
	p.accuse_threshold = ABLATION_ACCUSE_THRESHOLD
	p.evidence_memory = ABLATION_EVIDENCE_MEMORY
	return p


## Абляция: за столом жулик одного трюка против (table_size − 1) честных копий той же
## основы (они обвиняют). Ключ — имя трюка или «honest», значение — Profile жулика.
static func trick_ablation(base: BotPersonality, matches: int, table_size: int,
		rng: RandomNumberGenerator, options := RuleOptions.new()) -> Dictionary:
	var out := {}
	var kinds: Array = [null]
	kinds.append_array(Cheat.ALL)
	var honest := single_trick_cheater(base, null)
	honest.id = &"honest_rival"
	for kind in kinds:
		var subject := single_trick_cheater(base, kind)
		var profiles := {subject.id: Profile.new(), honest.id: Profile.new()}
		for i in matches:
			var lineup: Array[BotPersonality] = []
			var seat := i % table_size
			for s in table_size:
				lineup.append(subject if s == seat else honest)
			play_match(lineup, options, rng, profiles)
		out[subject.id] = profiles[subject.id]
	return out


## Полный текстовый отчёт: матрица дуэлей, винрейты и стиль за общим столом, абляция трюков.
static func report(roster: Array[BotPersonality], duel_matches: int, table_matches: int,
		table_size: int, rng: RandomNumberGenerator, options := RuleOptions.new(),
		ablation_matches := 0) -> String:
	var lines: PackedStringArray = []
	if duel_matches > 0:
		lines.append_array(_duel_report(roster, duel_matches, rng, options))
		lines.append("")

	lines.append("=== Столы по %d игрока (%d матчей), ожидание при равной силе %.0f%% ==="
			% [table_size, table_matches, 100.0 / table_size])
	var profiles := new_profiles(roster)
	var tally := tables(roster, table_size, table_matches, rng, options, profiles)
	var rates := {}
	for p in roster:
		rates[p.id] = tally[p.id].rate()
	for p in _sorted_by(roster, rates):
		var t: Tally = tally[p.id]
		lines.append("  %-16s %5.1f%%  (%d из %d)" % [_label(p), t.rate() * 100.0, t.won, t.played])

	lines.append("")
	lines.append_array(style_report(roster, profiles))

	if ablation_matches > 0:
		lines.append("")
		lines.append_array(ablation_report(
				trick_ablation(BotRoster.by_id(ABLATION_BASE_ID), ablation_matches, table_size,
						rng, options),
				ablation_matches, table_size))
	return "
".join(lines)


## Матрица дуэлей 1×1 и средний винрейт.
static func _duel_report(roster: Array[BotPersonality], duel_matches: int,
		rng: RandomNumberGenerator, options: RuleOptions) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("=== Дуэли 1×1 (%d матчей на пару): доля побед строки над столбцом ===" % duel_matches)
	var header := "%-16s" % ""
	for p in roster:
		header += "%8s" % _short(p)
	lines.append(header)
	# Каждая пара играется один раз; вторая половина матрицы — дополнение до 100%.
	var matrix := {}
	for i in roster.size():
		for j in range(i + 1, roster.size()):
			var rate := duel(roster[i], roster[j], duel_matches, rng, options)
			matrix[[i, j]] = rate
			matrix[[j, i]] = 1.0 - rate
	var duel_total := {}
	for i in roster.size():
		var row := "%-16s" % _label(roster[i])
		var total := 0.0
		for j in roster.size():
			if i == j:
				row += "%8s" % "—"
				continue
			total += matrix[[i, j]]
			row += "%7.0f%%" % (matrix[[i, j]] * 100.0)
		duel_total[roster[i].id] = total
		lines.append(row)
	lines.append("")
	lines.append("Средний винрейт в дуэлях:")
	for p in _sorted_by(roster, duel_total):
		lines.append("  %-16s %5.1f%%" % [_label(p), duel_total[p.id] / (roster.size() - 1) * 100.0])
	return lines


## Стиль персонажей (на матч) и сводка по трюкам.
static func style_report(roster: Array[BotPersonality], profiles: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("=== Стиль за столом (на матч) ===")
	lines.append("%-16s %7s %7s %8s %8s %7s %8s %8s  %s" % ["", "трюков", "провал",
			"пойман*", "обвин.", "верных", "зря обв.", "Безумие", "любимые трюки"])
	for p in roster:
		var pr: Profile = profiles[p.id]
		var tc := pr.total_cheats()
		lines.append("%-16s %7.2f %6.0f%% %8.2f %8.2f %6.0f%% %8.2f %7.0f%%  %s" % [
				_label(p), pr.per_match(tc),
				_pct(pr.total_failed(), tc),
				pr.per_match(pr.caught_by_accusation),
				pr.per_match(pr.accusations),
				_pct(pr.accusations_right, pr.accusations),
				pr.per_match(pr.falsely_accused),
				_pct(pr.went_mad, pr.played),
				_favorites(pr)])
	lines.append("  * пойман — по обвинению; мгновенные провалы — в столбце «провал».")
	lines.append("")
	lines.append("Трюки за столом (все персонажи):")
	var totals: Array[int] = [0, 0, 0, 0, 0, 0]
	var fails: Array[int] = [0, 0, 0, 0, 0, 0]
	var all_uses := 0
	for p in roster:
		var pr: Profile = profiles[p.id]
		for k in Cheat.ALL:
			totals[k] += pr.cheats[k]
			fails[k] += pr.failed[k]
			all_uses += pr.cheats[k]
	for k in Cheat.ALL:
		lines.append("  %-14s %6d (%4.1f%% всех)  провал %4.1f%%" % [
				Cheat.Kind.keys()[k], totals[k], _pct(totals[k], all_uses), _pct(fails[k], totals[k])])
	return lines


## Абляция: винрейт жулика одного трюка против честных обвинителей.
static func ablation_report(result: Dictionary, matches: int, table_size: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("=== Абляция трюков: 1 жулик одного трюка против %d честных (основа %s, %d матчей) ==="
			% [table_size - 1, ABLATION_BASE_ID, matches])
	lines.append("    ожидание при равной силе %.0f%%; «honest» — тот же бот без трюков" % (100.0 / table_size))
	for key in result:
		var pr: Profile = result[key]
		var k: int = -1
		for kind in Cheat.ALL:
			if pr.cheats[kind] > 0:
				k = kind
		var uses := pr.cheats[k] if k >= 0 else 0
		var fails := pr.failed[k] if k >= 0 else 0
		lines.append("  %-22s побед %5.1f%%  трюков/матч %5.2f  провал %4.1f%%  пойман/матч %4.2f  Безумие %3.0f%%" % [
				key, pr.rate() * 100.0, pr.per_match(uses), _pct(fails, uses),
				pr.per_match(pr.caught_by_accusation), _pct(pr.went_mad, pr.played)])
	return lines


# --- Внутреннее ----------------------------------------------------------------

static func _favorites(pr: Profile) -> String:
	var total := pr.total_cheats()
	if total == 0:
		return "—"
	var kinds: Array = Cheat.ALL.duplicate()
	kinds.sort_custom(func(a: int, b: int) -> bool: return pr.cheats[a] > pr.cheats[b])
	var parts: PackedStringArray = []
	for k in kinds.slice(0, 2):
		if pr.cheats[k] > 0:
			parts.append("%s %.0f%%" % [Cheat.Kind.keys()[k], _pct(pr.cheats[k], total)])
	return ", ".join(parts)


static func _pct(part: int, whole: int) -> float:
	return 0.0 if whole == 0 else 100.0 * part / whole


static func _child_rng(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	var child := RandomNumberGenerator.new()
	child.seed = rng.randi()
	return child


static func _random_lineup(roster: Array[BotPersonality], size: int,
		rng: RandomNumberGenerator) -> Array[BotPersonality]:
	var pool := roster.duplicate()
	var lineup: Array[BotPersonality] = []
	for i in mini(size, pool.size()):
		lineup.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return lineup


static func _sorted_by(roster: Array[BotPersonality], values: Dictionary) -> Array[BotPersonality]:
	var sorted := roster.duplicate()
	sorted.sort_custom(func(x: BotPersonality, y: BotPersonality) -> bool:
		return values[x.id] > values[y.id])
	return sorted


static func _label(p: BotPersonality) -> String:
	return "%s %s" % ["★".repeat(p.stars), p.id]


static func _short(p: BotPersonality) -> String:
	return String(p.id).substr(0, 7)
