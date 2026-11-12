class_name CampaignLevel
extends Resource
## Уровень кампании (DESIGN.md §8г). Данные: campaign/levels/level_<N>.tres.
## Модификатор — значение enum, а сами правила — MatchModifier (CampaignModifiers.build).

enum Modifier { NONE, EVIL_EYE, SCARCE_SANITY, DEAD_HAND, LAIR }

## Номер уровня, 1…CampaignBalance.LEVEL_COUNT.
@export var number := 1
## Ключ названия уровня («Мокрые карманы»…).
@export var name_key := ""
## Ключ места на карте таверны (стойка, угол у окна…).
@export var place_key := ""
## Соперники по порядку мест (BotPersonality.id).
@export var opponents: Array[StringName] = []
@export var modifier := Modifier.NONE
## Чей модификатор: Ведьма («Дурной глаз»), Утопленник («Мёртвая рука»),
## Глубоководный («Логово»). Пусто — у модификатора нет хозяина.
@export var modifier_owner: StringName
## Оттенок освещения таверны на этом уровне (М25 заменит фоном / деталями).
@export var background_tint := Color.WHITE
## «Живые» предметы стола (М22); null — обычный набор.
@export var table_props: TablePropSet
## Точка на карте таверны, пиксели экрана 640×360.
@export var map_point := Vector2i.ZERO
## Реплики Хоба перед уровнем и после победы (ключи локализации).
@export var before_keys: PackedStringArray = []
@export var after_keys: PackedStringArray = []
## Префикс сюжетных реплик соперников (М24, MatchSetup.bark_story).
@export var bark_story := ""
## С какой реплики «перед уровнем» Хоб сбрасывает облик и говорит Глубоководный
## (и после победы — тоже он). −1 — Хоб остаётся Хобом.
@export var hob_reveal_from := -1
## Пока уровень не пройден, карточка скрывает соперника и модификатор (уровень 6:
## иначе поворот «Хоб — это Глубоководный» раскрыт до сцены).
@export var secret_until_completed := false


## Кто говорит реплику сцены: &"hob" или персонаж, в которого он превратился.
func scene_speaker(after: bool, index: int) -> StringName:
	if hob_reveal_from < 0:
		return &"hob"
	if after or index >= hob_reveal_from:
		return modifier_owner
	return &"hob"


## Ключ названия модификатора (пусто — без модификатора).
static func modifier_key(m: Modifier) -> String:
	match m:
		Modifier.EVIL_EYE:
			return "CAMP_MOD_EVIL_EYE"
		Modifier.SCARCE_SANITY:
			return "CAMP_MOD_SCARCE_SANITY"
		Modifier.DEAD_HAND:
			return "CAMP_MOD_DEAD_HAND"
		Modifier.LAIR:
			return "CAMP_MOD_LAIR"
	return ""


## Место хозяина модификатора за столом (человек — 0, соперники — с 1) или −1.
func owner_seat() -> int:
	var i := opponents.find(modifier_owner)
	return -1 if i < 0 else i + 1
