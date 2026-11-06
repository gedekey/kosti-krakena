extends Node
## Настройки игрока.
##
## Сейчас — только значения в памяти и значения по умолчанию.
## Сохранение в user:// и экран настроек — модуль 11.

signal changed(key: StringName, value: Variant)

const SUPPORTED_LOCALES: PackedStringArray = ["ru", "en"]
const FALLBACK_LOCALE := "en"

## Значения по умолчанию. Пустой locale = взять язык системы.
const DEFAULTS := {
	&"locale": "",
	&"music_volume": 0.8,
	&"sfx_volume": 0.8,
	&"bot_speed": 1.0,
	&"palifico": true,
	&"calza": true,
}

var _values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	_apply_locale()


func get_value(key: StringName) -> Variant:
	assert(_values.has(key), "Unknown setting: %s" % key)
	return _values[key]


func set_value(key: StringName, value: Variant) -> void:
	assert(_values.has(key), "Unknown setting: %s" % key)
	if _values[key] == value:
		return
	_values[key] = value
	if key == &"locale":
		_apply_locale()
	changed.emit(key, value)


func reset_to_defaults() -> void:
	for key: StringName in DEFAULTS:
		set_value(key, DEFAULTS[key])


## Итоговый язык: явно выбранный, иначе системный, иначе запасной.
func resolve_locale() -> String:
	var chosen: String = _values[&"locale"]
	if chosen in SUPPORTED_LOCALES:
		return chosen
	var system := OS.get_locale_language()
	if system in SUPPORTED_LOCALES:
		return system
	return FALLBACK_LOCALE


func _apply_locale() -> void:
	var locale := resolve_locale()
	TranslationServer.set_locale(locale)
	if is_inside_tree():
		Events.locale_changed.emit(locale)
