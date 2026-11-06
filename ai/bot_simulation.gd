class_name BotSimulation
extends RefCounted
## Симуляция матчей бот против бота (без нод и UI) и отчёт о винрейтах.
## Запуск одной командой: tools/run_simulation.ps1.

## Защита от зацикливания: столько шагов автоматики на матч — заведомо больше нужного.
const MAX_STEPS_PER_MATCH := 20000
const DEFAULT_TABLE_SIZE := 4


## Счёт персонажа: сыграно / выиграно.
class Tally:
	var played := 0
	var won := 0

	func rate() -> float:
		return 0.0 if played == 0 else float(won) / played


## Один матч. lineup — персонажи по местам. Возвращает индекс победителя в lineup.
static func play_match(lineup: Array[BotPersonality], options: RuleOptions,
		rng: RandomNumberGenerator) -> int:
	var agents: Array[MatchAgent] = []
	for p in lineup:
		agents.append(BotAgent.new(p, _child_rng(rng)))
	var mc := MatchController.new(agents, options, _child_rng(rng))
	mc.start_match()
	var steps := 0
	while mc.advance_auto():
		steps += 1
		assert(steps < MAX_STEPS_PER_MATCH, "Simulation: match does not end")
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
static func tables(roster: Array[BotPersonality], table_size: int, matches: int,
		rng: RandomNumberGenerator, options := RuleOptions.new()) -> Dictionary:
	var tally := {}
	for p in roster:
		tally[p.id] = Tally.new()
	for i in matches:
		var lineup := _random_lineup(roster, table_size, rng)
		var winner := play_match(lineup, options, rng)
		for p in lineup:
			tally[p.id].played += 1
		tally[lineup[winner].id].won += 1
	return tally


## Полный текстовый отчёт: матрица дуэлей и винрейты за общим столом.
static func report(roster: Array[BotPersonality], duel_matches: int, table_matches: int,
		table_size: int, rng: RandomNumberGenerator, options := RuleOptions.new()) -> String:
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

	lines.append("")
	lines.append("=== Столы по %d игрока (%d матчей), ожидание при равной силе %.0f%% ==="
			% [table_size, table_matches, 100.0 / table_size])
	var tally := tables(roster, table_size, table_matches, rng, options)
	var rates := {}
	for p in roster:
		rates[p.id] = tally[p.id].rate()
	for p in _sorted_by(roster, rates):
		var t: Tally = tally[p.id]
		lines.append("  %-16s %5.1f%%  (%d из %d)" % [_label(p), t.rate() * 100.0, t.won, t.played])
	return "\n".join(lines)


# --- Внутреннее ----------------------------------------------------------------

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
