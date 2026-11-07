class_name Achievement
extends RefCounted
## Каталог достижений (DESIGN.md §8а): 15 штук, ключи локализации, пороги, иконки.
## Только статические функции и константы. Условия проверяет AchievementTracker.

enum Id {
	FIRST_WIN,
	VETERAN,
	FULL_HOUSE,
	FLAWLESS,
	LAST_DIE,
	LIAR_CALL,
	CALZA_HIT,
	CLEAN_HANDS,
	FIRST_TRICK,
	TRICKSTER,
	ABYSS_VOICE,
	SHARP_EYE,
	HUNTER,
	INTO_ABYSS,
	MAD_CAPTAIN,
}

const ALL: Array[Id] = [
	Id.FIRST_WIN, Id.VETERAN, Id.FULL_HOUSE, Id.FLAWLESS, Id.LAST_DIE,
	Id.LIAR_CALL, Id.CALZA_HIT, Id.CLEAN_HANDS, Id.FIRST_TRICK, Id.TRICKSTER,
	Id.ABYSS_VOICE, Id.SHARP_EYE, Id.HUNTER, Id.INTO_ABYSS, Id.MAD_CAPTAIN,
]

# --- Пороги ---
## «Морской волк»: побед всего.
const VETERAN_WINS := 10
## «Охотник на шулеров»: поймано жуликов всего.
const HUNTER_CATCHES := 5
## «Хозяин таверны»: игроков за столом (полный стол).
const FULL_HOUSE_PLAYERS := 6
## «Чистые руки»: победа без трюков за столом хотя бы из стольких игроков.
const CLEAN_HANDS_MIN_PLAYERS := 4
## «На волоске»: победа, когда кубиков осталось не больше стольких.
const LAST_DIE_DICE := 1

## Имя для сохранения (не меняется при переупорядочивании enum).
const _SAVE_NAME := {
	Id.FIRST_WIN: "first_win",
	Id.VETERAN: "veteran",
	Id.FULL_HOUSE: "full_house",
	Id.FLAWLESS: "flawless",
	Id.LAST_DIE: "last_die",
	Id.LIAR_CALL: "liar_call",
	Id.CALZA_HIT: "calza_hit",
	Id.CLEAN_HANDS: "clean_hands",
	Id.FIRST_TRICK: "first_trick",
	Id.TRICKSTER: "trickster",
	Id.ABYSS_VOICE: "abyss_voice",
	Id.SHARP_EYE: "sharp_eye",
	Id.HUNTER: "hunter",
	Id.INTO_ABYSS: "into_abyss",
	Id.MAD_CAPTAIN: "mad_captain",
}


static func save_name(id: Id) -> String:
	return _SAVE_NAME[id]


## Id по имени сохранения или -1.
static func from_save_name(name: String) -> int:
	for id: Id in _SAVE_NAME:
		if _SAVE_NAME[id] == name:
			return id
	return -1


## Ключ названия: ACH_<ИМЯ>.
static func name_key(id: Id) -> String:
	return "ACH_" + save_name(id).to_upper()


## Ключ описания: ACH_<ИМЯ>_DESC (с %d — подставляется desc_arg(id)).
static func desc_key(id: Id) -> String:
	return name_key(id) + "_DESC"


## Число для описания или -1, если описание без чисел.
static func desc_arg(id: Id) -> int:
	match id:
		Id.VETERAN:
			return VETERAN_WINS
		Id.HUNTER:
			return HUNTER_CATCHES
		Id.FULL_HOUSE:
			return FULL_HOUSE_PLAYERS
		Id.CLEAN_HANDS:
			return CLEAN_HANDS_MIN_PLAYERS - 1
	return -1


## Сколько нужно набрать (счётчик «N / M»); 1 — разовое достижение без счётчика.
static func goal(id: Id) -> int:
	match id:
		Id.VETERAN:
			return VETERAN_WINS
		Id.HUNTER:
			return HUNTER_CATCHES
		Id.TRICKSTER:
			return Cheat.ALL.size()
	return 1
