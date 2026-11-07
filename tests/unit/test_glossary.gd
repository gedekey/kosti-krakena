extends GutTest
## Словарь терминов (М13, доп.): разбор словоформ, поиск в тексте, разметка.
## Перевод подставляется словарём — без TranslationServer.

const FAKE := {
	"TERM_SANITY": "Рассудок",
	"TERM_SANITY_FORMS": "рассудок|рассудка|Рассудку | рассудок",
	"TERM_MADNESS_FORMS": "безумие|безумии",
	"TERM_SLEEVE_DIE_FORMS": "кубик в рукаве|в рукаве",
	"TERM_LIAR_FORMS": "ложь",
	"TERM_CALZA_FORMS": "точно!",
}


func _glossary() -> Glossary:
	return Glossary.new(func(key: String) -> String: return FAKE.get(key, ""),
			func() -> String: return "ru")


func _ids(g: Glossary, text: String, exclude: StringName = &"") -> Array:
	var ids := []
	for m in g.find_terms(text, exclude):
		ids.append(m.id)
	return ids


func test_forms_are_lowercased_trimmed_and_unique() -> void:
	assert_eq(_glossary().forms(&"SANITY"),
			PackedStringArray(["рассудок", "рассудка", "рассудку"]))


func test_finds_inflected_forms_in_any_case() -> void:
	var g := _glossary()
	assert_eq(_ids(g, "Ваш РАССУДОК на нуле: в Безумии рассудка нет."),
			[&"SANITY", &"MADNESS", &"SANITY"])


func test_whole_words_only() -> void:
	var g := _glossary()
	assert_eq(_ids(g, "Ложный след, ложь2 и рассудочный"), [], "внутри слова — не термин")
	assert_eq(_ids(g, "«Ложь!» — и всё"), [&"LIAR"], "кавычки и знаки — границы")


func test_longest_form_wins_and_no_overlaps() -> void:
	var g := _glossary()
	var found := g.find_terms("Кубик в рукаве исчезает")
	assert_eq(found.size(), 1)
	assert_eq(found[0].start, 0)
	assert_eq(found[0].length, "кубик в рукаве".length())


func test_form_with_punctuation() -> void:
	assert_eq(_ids(_glossary(), "Нажмите «Точно!», если уверены. Точно так."), [&"CALZA"])


func test_exclude_skips_own_term() -> void:
	assert_eq(_ids(_glossary(), "Рассудок и безумие", &"SANITY"), [&"MADNESS"])


func test_markup_wraps_terms_and_escapes_brackets() -> void:
	var g := _glossary()
	var bb := g.markup("[x] Рассудок", Color("#ffb347"))
	assert_eq(bb, "[lb]x] [url=SANITY][color=#ffb347]Рассудок[/color][/url]")


func test_cache_follows_locale() -> void:
	var lang := ["ru"]
	var dict := {"ru": {"TERM_SANITY_FORMS": "рассудок"}, "en": {"TERM_SANITY_FORMS": "sanity"}}
	var g := Glossary.new(func(key: String) -> String: return dict[lang[0]].get(key, ""),
			func() -> String: return lang[0])
	assert_eq(_ids(g, "sanity, рассудок"), [&"SANITY"])
	lang[0] = "en"
	assert_eq(g.find_terms("sanity, рассудок")[0].start, 0)


func test_trick_terms_map_to_cheats() -> void:
	for kind in Cheat.ALL:
		var id := Glossary.trick_term(kind)
		assert_true(Glossary.is_term(id), "термин у трюка %d" % kind)
		assert_eq(Glossary.name_key(id), Cheat.name_key(kind))


func test_trick_description_uses_cheat_numbers() -> void:
	var g := Glossary.new(func(key: String) -> String:
		return "%d|%d" if key == "TERM_TRICK_PRICE" else key)
	assert_eq(g.description(&"SLEEVE_DIE"), "CHEAT_SLEEVE_DIE_HINT\n%d|%d" % [
			Cheat.cost(Cheat.Kind.SLEEVE_DIE), roundi(Cheat.risk(Cheat.Kind.SLEEVE_DIE) * 100)])


func test_description_numbers_from_balance() -> void:
	var g := Glossary.new(func(key: String) -> String:
		return "%d" if key == "TERM_SANITY_DESC" else key)
	assert_eq(g.description(&"SANITY"), str(CheatBalance.START_SANITY))
