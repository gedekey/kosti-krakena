class_name RankBalance
extends RefCounted
## Числа рангов (DESIGN.md §8в, М20). Все константы баланса рангов — здесь.

enum Tier { WOOD, BRONZE, SILVER, GOLD, RUBY, PHILOSOPHER }

const ALL_TIERS: Array[Tier] = [
	Tier.WOOD, Tier.BRONZE, Tier.SILVER, Tier.GOLD, Tier.RUBY, Tier.PHILOSOPHER,
]
const TOP_TIER := Tier.PHILOSOPHER

## Слава до следующего ранга (по рангу). У высшего ранга порога нет.
const PROMOTE_GLORY: Array[int] = [100, 150, 200, 250, 300]
## Множитель отрицательной Славы (по рангу): на Дереве ничего не теряешь.
const LOSS_MULTIPLIER: Array[float] = [0.0, 0.5, 0.75, 1.0, 1.25, 1.5]

## Слава за первое и последнее место; средние места — поровну между ними.
const WIN_GLORY := 40
const LAST_PLACE_GLORY := -30

## Одиночная игра: множитель положительной Славы по звёздам бота (среднее по столу).
const STAR_GAIN_MULTIPLIER := {1: 0.75, 2: 1.0, 3: 1.25}

## Понижение: на ранг ниже с такой долей его порога.
const DEMOTE_GLORY_SHARE := 0.5

## Сетевой матч засчитывается, если в начале за столом столько людей или больше.
const NET_MIN_HUMANS := 2

## Ключи сохранения и локализации по рангу.
const SAVE_NAMES: Array[String] = ["wood", "bronze", "silver", "gold", "ruby", "philosopher"]


static func name_key(tier: Tier) -> String:
	return "RANK_" + SAVE_NAMES[tier].to_upper()


## Слава до следующего ранга; −1 — высший ранг.
static func promote_glory(tier: Tier) -> int:
	return PROMOTE_GLORY[tier] if tier < TOP_TIER else -1


## Множитель Славы за стол ботов с такими звёздами (среднее по ботам; пусто — 1).
static func star_multiplier(stars: Array[int]) -> float:
	if stars.is_empty():
		return 1.0
	var total := 0.0
	for s in stars:
		total += STAR_GAIN_MULTIPLIER.get(clampi(s, 1, 3), 1.0)
	return total / stars.size()
