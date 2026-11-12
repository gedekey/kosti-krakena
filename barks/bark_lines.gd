class_name BarkLines
extends RefCounted
## Где лежат тексты реплик (М24, DESIGN.md §8д): ключи локализации по персонажу и поводу.
##
##   обычные:  BARK_<ПЕРСОНАЖ>_<ПОВОД>_<N>          (BARK_SAILOR_LIAR_2)
##   сюжетные: BARK_<УРОВЕНЬ>_<ПЕРСОНАЖ>_<ПОВОД>_<N> (BARK_L5_DROWNED_LOSE_1)
##
## Сколько вариантов есть — узнаём у локализации (N = 1, 2, … пока ключ есть), поэтому
## добавить реплику — это только добавить строку в i18n/barks.csv. Сюжетные реплики уровня —
## точка расширения для кампании (М23): уровень задаёт свой префикс (story).
## Проверка «ключ есть» — внедряемая (has_key), тесты подставляют свою.

const PREFIX := "BARK_"

## Callable(key: String) -> bool. По умолчанию — есть ли перевод в TranslationServer.
var has_key: Callable
## Префикс сюжетных реплик уровня кампании ("" — обычный матч).
var story := ""

var _cache := {}


func _init(p_has_key: Callable = Callable()) -> void:
	has_key = p_has_key if p_has_key.is_valid() else BarkLines.translated


## Ключи обычных реплик персонажа на повод.
func regular(character: StringName, occasion: BarkBalance.Occasion) -> PackedStringArray:
	return _variants(base_key("", character, occasion))


## Ключи сюжетных реплик текущего уровня (пусто, если уровня нет или реплик на повод нет).
func story_lines(character: StringName, occasion: BarkBalance.Occasion) -> PackedStringArray:
	if story == "":
		return PackedStringArray()
	return _variants(base_key(story, character, occasion))


## Ключ без номера варианта: BARK_[<story>_]<CHARACTER>_<OCCASION>.
static func base_key(p_story: String, character: StringName,
		occasion: BarkBalance.Occasion) -> String:
	var head := PREFIX + (p_story.to_upper() + "_" if p_story != "" else "")
	return head + String(character).to_upper() + "_" + BarkBalance.occasion_name(occasion)


## Есть ли перевод ключа (TranslationServer возвращает сам ключ, если перевода нет).
static func translated(key: String) -> bool:
	return TranslationServer.translate(key) != StringName(key)


func _variants(base: String) -> PackedStringArray:
	if _cache.has(base):
		return _cache[base]
	var out := PackedStringArray()
	for n in range(1, BarkBalance.MAX_VARIANTS + 1):
		var key := "%s_%d" % [base, n]
		if not has_key.call(key):
			break
		out.append(key)
	_cache[base] = out
	return out
