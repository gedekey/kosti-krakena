class_name BotPersonality
extends Resource
## Характер бота (DESIGN.md §5). Data-driven: персонажи лежат в ai/personalities/*.tres.
## Честная часть (М3) + жульничество, обвинения и Безумие (М6).
## По умолчанию (BotPersonality.new()) бот честен и никого не обвиняет.
##
## Все вероятности — «как бот их видит», после шума.

## Идентификатор персонажа (scholar, sailor, …).
@export var id: StringName
## Ключ локализации имени.
@export var name_key: String
## Сложность ★–★★★.
@export_range(1, 3) var stars := 1

@export_group("Honest play")
## Шанс блефа в ход: поставить не лучшую ставку, а случайную из «терпимых».
@export_range(0.0, 1.0) var bluff_chance := 0.1
## Минимальная вера в ставку, при которой бот ещё готов её сделать блефуя.
@export_range(0.0, 1.0) var bluff_floor := 0.35
## Порог «Лжи!»: оспаривает, если верит в текущую ставку меньше, чем на это значение.
@export_range(0.0, 1.0) var dudo_threshold := 0.4
## Порог «Точно!»: зовёт, если шанс ровного попадания не меньше этого значения.
@export_range(0.0, 1.0) var calza_threshold := 0.5
## Насколько уверенной должна быть первая ставка раунда (выше — скромнее открывает).
@export_range(0.0, 1.0) var opening_confidence := 0.6
## Насколько верит ставкам соперников (см. TableEstimate).
@export_range(0.0, 1.0) var bid_reading := 0.0
## «Шум» расчёта: стандартное отклонение ошибки в оценке вероятностей.
@export_range(0.0, 1.0) var noise := 0.0

@export_group("Cheating")
## Шанс попробовать трюк в ход (и, с долей веса «Утяжелённой кости», — в фазе броска).
@export_range(0.0, 1.0) var cheat_chance := 0.0
## Любимые трюки: вес каждого Cheat.Kind (по порядку Cheat.ALL). 0 — никогда.
@export var cheat_weights: PackedFloat32Array = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
## Самый высокий риск провала, на который бот согласен (CheatBalance.RISK_*).
@export_range(0.0, 1.0) var risk_tolerance := 0.35
## Неприкосновенный запас Рассудка: трюк, после которого останется меньше, не делается.
## 0 — тратит до дна (и сходит с ума).
@export_range(0, 9) var sanity_reserve := 0

@export_group("Accusations")
## Обвиняет, если вера в то, что соперник жульничал в раунде, не меньше этого значения.
## 1 — никогда.
@export_range(0.0, 1.0) var accuse_threshold := 1.0
## Память об уликах прошлых раундов: 0 — забывает сразу, 1 — помнит всё.
@export_range(0.0, 1.0) var evidence_memory := 0.0

@export_group("Madness")
## Понимает ли бот в Безумии, что глаза врут: 0 — верит увиденному,
## 1 — правильно делает поправку на галлюцинации (MadnessBalance).
@export_range(0.0, 1.0) var mad_awareness := 0.0


## Вес трюка (0, если не задан).
func cheat_weight(kind: Cheat.Kind) -> float:
	return cheat_weights[kind] if kind < cheat_weights.size() else 0.0
