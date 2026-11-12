class_name BarkBalance
extends RefCounted
## Числа реплик соперников (М24, DESIGN.md §8д): шансы поводов, паузы, время облака.
## Все — здесь, в коде реплик магических чисел нет.

## Поводы реплик. Имя повода — часть ключа локализации (BARK_<ПЕРСОНАЖ>_<ПОВОД>_<N>).
enum Occasion {
	MATCH_START,      ## начало матча
	PLAYER_BID,       ## ставка человека (изредка)
	LIAR,             ## бот сказал «Ложь!»
	LIAR_AGAINST,     ## «Ложь!» сказали ставке бота
	CALZA,            ## бот сказал «Точно!»
	ACCUSE,           ## бот обвиняет
	EVIDENCE,         ## бот заметил улику у другого
	CAUGHT,           ## бот пойман (трюк провалился или верное обвинение)
	GLOAT,            ## поймали другого — бот злорадствует
	DIE_LOST,         ## бот потерял кубик
	MADNESS_SELF,     ## бот впал в Безумие
	MADNESS_PLAYER,   ## человек впал в Безумие
	LAST_DIE,         ## у бота остался один кубик (Palifico)
	WIN,              ## бот выиграл матч
	LOSE,             ## бот выбыл
}

## Шанс, что повод вызовет реплику (если говорить есть кому).
const CHANCE := {
	Occasion.MATCH_START: 0.8,
	Occasion.PLAYER_BID: 0.1,
	Occasion.LIAR: 0.5,
	Occasion.LIAR_AGAINST: 0.35,
	Occasion.CALZA: 0.6,
	Occasion.ACCUSE: 0.75,
	Occasion.EVIDENCE: 0.3,
	Occasion.CAUGHT: 0.85,
	Occasion.GLOAT: 0.5,
	Occasion.DIE_LOST: 0.3,
	Occasion.MADNESS_SELF: 0.85,
	Occasion.MADNESS_PLAYER: 0.6,
	Occasion.LAST_DIE: 0.6,
	Occasion.WIN: 1.0,
	Occasion.LOSE: 0.75,
}

## Важность повода: более важная реплика может сменить облако, показанное только что
## (в ту же секунду — например, «выбыл» и сразу «победа»).
const PRIORITY := {
	Occasion.MATCH_START: 1,
	Occasion.PLAYER_BID: 0,
	Occasion.LIAR: 2,
	Occasion.LIAR_AGAINST: 1,
	Occasion.CALZA: 2,
	Occasion.ACCUSE: 2,
	Occasion.EVIDENCE: 0,
	Occasion.CAUGHT: 3,
	Occasion.GLOAT: 1,
	Occasion.DIE_LOST: 1,
	Occasion.MADNESS_SELF: 3,
	Occasion.MADNESS_PLAYER: 2,
	Occasion.LAST_DIE: 2,
	Occasion.WIN: 4,
	Occasion.LOSE: 3,
}

## Пауза персонажа между его репликами (сек).
const CHARACTER_COOLDOWN := 14.0
## Пауза после того, как облако исчезло, до следующего (сек).
const GAP_AFTER_BUBBLE := 1.5
## Сменить облако важной репликой можно только в первые столько секунд его показа.
const REPLACE_WINDOW := 0.4

## Облако держится 2–4 с по длине текста: BASE + символы × PER_CHAR, в пределах MIN…MAX.
const DURATION_MIN := 2.0
const DURATION_MAX := 4.0
const DURATION_BASE := 1.6
const DURATION_PER_CHAR := 0.04
## Печать по буквам (символов в секунду).
const TYPE_SPEED := 40.0

## Сюжетные реплики уровня кампании (если они есть для повода) берутся с этим шансом
## вместо обычных.
const STORY_CHANCE := 0.7
## Сколько вариантов текста на повод искать в локализации (BARK_…_1 … _N).
const MAX_VARIANTS := 5


## Сколько показывать облако с текстом длины length (сек).
static func duration_for(length: int) -> float:
	return clampf(DURATION_BASE + length * DURATION_PER_CHAR, DURATION_MIN, DURATION_MAX)


static func occasion_name(occasion: Occasion) -> String:
	return Occasion.keys()[occasion]
