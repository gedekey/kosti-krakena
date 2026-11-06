extends GutTest
## М7: пиксельные шрифты собраны и покрывают все строки локализации.

const CSV_PATH := "res://i18n/strings.csv"
const RU_UPPER := "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
const EN_UPPER := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const DIGITS := "0123456789"
const TITLE_PUNCTUATION := " .,:;!?'\"-–—−+=×·()[]/%*#«»…◀▶"


func test_fonts_are_pixel_perfect() -> void:
	var cases := [[PixelFonts.BODY, PixelFonts.BODY_SIZE], [PixelFonts.TITLE, PixelFonts.TITLE_SIZE],
			[PixelFonts.TITLE_GLOW, PixelFonts.TITLE_SIZE]]
	for c: Array in cases:
		var font: FontFile = c[0]
		assert_eq(font.fixed_size, c[1], font.font_name)
		assert_eq(font.fixed_size_scale_mode, TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY, font.font_name)
		assert_false(font.allow_system_fallback, font.font_name)
		# Высота строки = размер: целые пиксели, без дробей.
		assert_eq(font.get_height(c[1]), float(c[1]), font.font_name)


func test_body_covers_both_alphabets() -> void:
	var text := RU_UPPER + RU_UPPER.to_lower() + EN_UPPER + EN_UPPER.to_lower() + DIGITS
	assert_eq(_missing(PixelFonts.BODY, text), "")


func test_title_covers_letters_digits_and_punctuation() -> void:
	var text := RU_UPPER + RU_UPPER.to_lower() + EN_UPPER + EN_UPPER.to_lower() + DIGITS \
			+ TITLE_PUNCTUATION
	assert_eq(_missing(PixelFonts.TITLE, text), "")
	assert_eq(_missing(PixelFonts.TITLE_GLOW, text), "")


func test_lowercase_in_title_is_drawn_as_uppercase() -> void:
	var font := PixelFonts.TITLE
	for pair in [["я", "Я"], ["q", "Q"], ["ё", "Ё"]]:
		assert_eq(font.get_char_size(pair[0].unicode_at(0), PixelFonts.TITLE_SIZE),
				font.get_char_size(pair[1].unicode_at(0), PixelFonts.TITLE_SIZE), pair[0])


func test_body_covers_every_translation() -> void:
	for locale in Settings.SUPPORTED_LOCALES:
		var translation := _translation(locale)
		assert_not_null(translation, locale)
		if translation == null:
			continue
		for key in _csv_keys():
			var text := String(translation.get_message(key))
			assert_eq(_missing(PixelFonts.BODY, text), "", "%s / %s: «%s»" % [locale, key, text])


func test_every_key_is_translated_to_both_languages() -> void:
	var keys := _csv_keys()
	assert_gt(keys.size(), 0)
	for locale in Settings.SUPPORTED_LOCALES:
		var translation := _translation(locale)
		for key in keys:
			assert_false(String(translation.get_message(key)).is_empty(), "%s / %s" % [locale, key])


func test_project_theme_uses_pixel_fonts() -> void:
	var path: String = ProjectSettings.get_setting("gui/theme/custom")
	var theme: Theme = load(path)
	assert_eq(theme.default_font, PixelFonts.BODY)
	assert_eq(theme.default_font_size, PixelFonts.BODY_SIZE)
	assert_eq(theme.get_font(&"font", PixelFonts.VARIATION_TITLE), PixelFonts.TITLE)
	assert_eq(theme.get_font(&"font", PixelFonts.VARIATION_TITLE_GLOW), PixelFonts.TITLE_GLOW)


# --- Вспомогательное ------------------------------------------------------------

## Символы текста, которых нет в шрифте (переводы строк и табы не считаются).
func _missing(font: Font, text: String) -> String:
	var result := ""
	for ch in text:
		if ch == "\n" or ch == "\t":
			continue
		if not font.has_char(ch.unicode_at(0)) and not ch in result:
			result += ch
	return result


func _csv_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	file.get_csv_line()  # заголовок
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() > 0 and not line[0].is_empty():
			keys.append(line[0])
	return keys


func _translation(locale: String) -> Translation:
	for path: String in ProjectSettings.get_setting("internationalization/locale/translations"):
		var t: Translation = load(path)
		if t.locale == locale:
			return t
	return null
