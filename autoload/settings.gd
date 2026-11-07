extends Node
## Настройки игрока (DESIGN.md §6, §8). Сохраняются в user://settings.cfg (М11).
##
## Любое изменение сохраняется само (раз в кадр, сколько бы значений ни поменялось).
## save_path = "" — не трогать диск (тесты, см. tests/gut_pre_run.gd).
## Громкость применяется к шинам MUSIC_BUS / SFX_BUS, если они есть (шины заводит М12).
## М17: полный экран и размер окна (целое кратное 640×360), F11 — полный экран вкл/выкл.

signal changed(key: StringName, value: Variant)

const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"

const SUPPORTED_LOCALES: PackedStringArray = ["ru", "en"]
const FALLBACK_LOCALE := "en"

const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
## Шаг громкости на экране настроек.
const VOLUME_STEP := 0.1
## Варианты скорости ботов и анимаций на экране настроек (множитель темпа).
const BOT_SPEEDS: Array[float] = [0.5, 1.0, 1.5, 2.0, 3.0]
const BOT_SPEED_MIN := 0.25
const BOT_SPEED_MAX := 4.0
## Внутреннее разрешение; размер окна — его целое кратное (pixel-perfect).
const BASE_SIZE := Vector2i(640, 360)
const WINDOW_SCALE_MIN := 1
const WINDOW_SCALE_MAX := 6
## Если размер экрана неизвестен (headless) — считаем, что влезает такой масштаб.
const WINDOW_SCALE_FALLBACK := 3

## Значения по умолчанию. Пустой locale = взять язык системы.
## player_portrait … opponents — что игрок выбрал на экране соперников в прошлый раз.
const DEFAULTS := {
	&"locale": "",
	&"music_volume": 0.8,
	&"sfx_volume": 0.8,
	&"bot_speed": 1.0,
	&"palifico": true,
	&"calza": true,
	## М15: крупное число кубиков у каждой чашки от броска до конца раунда.
	&"show_dice_counts": true,
	## М17: полноэкранный режим и масштаб окна (2 = 1280×720).
	&"fullscreen": false,
	&"window_scale": 2,
	&"player_portrait": "player1",
	&"opponents_random": true,
	&"opponent_count": 3,
	&"opponents": [],
}

var save_path := SAVE_PATH

var _values: Dictionary = DEFAULTS.duplicate(true)
var _save_queued := false


func _ready() -> void:
	# F11 работает и на паузе (меню паузы стола, М17).
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_saved()
	_apply_locale()
	_apply_volumes()
	_apply_display.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F11 			and can_change_display():
		get_viewport().set_input_as_handled()
		set_value(&"fullscreen", not _values[&"fullscreen"])


func get_value(key: StringName) -> Variant:
	assert(_values.has(key), "Unknown setting: %s" % key)
	return _values[key]


func set_value(key: StringName, value: Variant) -> void:
	assert(_values.has(key), "Unknown setting: %s" % key)
	var clean: Variant = sanitize(key, value)
	if clean == null or _values[key] == clean:
		return
	_values[key] = clean
	_on_value_set(key)
	changed.emit(key, clean)
	_queue_save()


func reset_to_defaults() -> void:
	reset_keys(DEFAULTS.keys())


## Вернуть к значениям по умолчанию только эти ключи.
func reset_keys(keys: Array) -> void:
	for key: StringName in keys:
		var def: Variant = DEFAULTS[key]
		set_value(key, def.duplicate() if def is Array else def)


## Итоговый язык: явно выбранный, иначе системный, иначе запасной.
func resolve_locale() -> String:
	var chosen: String = _values[&"locale"]
	if chosen in SUPPORTED_LOCALES:
		return chosen
	var system := OS.get_locale_language()
	if system in SUPPORTED_LOCALES:
		return system
	return FALLBACK_LOCALE


## Значение, приведённое к типу и диапазону настройки, или null, если оно негодно.
func sanitize(key: StringName, value: Variant) -> Variant:
	var def: Variant = DEFAULTS[key]
	match typeof(def):
		TYPE_BOOL:
			return value if value is bool else null
		TYPE_FLOAT:
			if not (value is float or value is int):
				return null
			if key == &"bot_speed":
				return clampf(float(value), BOT_SPEED_MIN, BOT_SPEED_MAX)
			return clampf(float(value), 0.0, 1.0)
		TYPE_INT:
			if not (value is int or value is float):
				return null
			if key == &"window_scale":
				return clampi(int(value), WINDOW_SCALE_MIN, WINDOW_SCALE_MAX)
			return clampi(int(value), MatchController.MIN_PLAYERS - 1,
					MatchController.MAX_PLAYERS - 1)
		TYPE_STRING:
			if not (value is String or value is StringName):
				return null
			var s := String(value)
			if key == &"locale" and s != "" and not s in SUPPORTED_LOCALES:
				return null
			return s
		TYPE_ARRAY:
			if not value is Array:
				return null
			var out: Array = []
			for item: Variant in value:
				if item is String or item is StringName:
					out.append(String(item))
			return out
	return null


# --- Сохранение ------------------------------------------------------------------

## Записать настройки на диск сейчас.
func save() -> Error:
	_save_queued = false
	if save_path == "":
		return OK
	var file := ConfigFile.new()
	for key: StringName in _values:
		file.set_value(SECTION, String(key), _values[key])
	return file.save(save_path)


## Прочитать настройки с диска. Неизвестные и негодные значения пропускаются.
func load_saved() -> void:
	if save_path == "" or not FileAccess.file_exists(save_path):
		return
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	for key: StringName in DEFAULTS:
		if not file.has_section_key(SECTION, String(key)):
			continue
		var clean: Variant = sanitize(key, file.get_value(SECTION, String(key)))
		if clean != null:
			_values[key] = clean
	_apply_locale()
	_apply_volumes()


func _queue_save() -> void:
	if save_path == "" or _save_queued:
		return
	_save_queued = true
	if is_inside_tree():
		save.call_deferred()
	else:
		save()


# --- Применение -------------------------------------------------------------------

func _on_value_set(key: StringName) -> void:
	match key:
		&"locale":
			_apply_locale()
		&"music_volume", &"sfx_volume":
			_apply_volumes()
		&"fullscreen", &"window_scale":
			_apply_display()


func _apply_locale() -> void:
	var locale := resolve_locale()
	if TranslationServer.get_locale() == locale:
		return
	TranslationServer.set_locale(locale)
	if is_inside_tree():
		Events.locale_changed.emit(locale)


func _apply_volumes() -> void:
	_apply_bus_volume(MUSIC_BUS, _values[&"music_volume"])
	_apply_bus_volume(SFX_BUS, _values[&"sfx_volume"])


static func _apply_bus_volume(bus: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))


# --- Экран (М17) ----------------------------------------------------------------------

## Можно ли менять окно: на ПК — да; на Android, в вебе и без окна (тесты) — нет.
static func can_change_display() -> bool:
	return DisplayServer.get_name() != "headless" 			and not (OS.has_feature("mobile") or OS.has_feature("web"))


## Масштабы окна, при которых оно целиком влезает в область area (по возрастанию).
## Масштаб 1 есть всегда. Пустая area (размер неизвестен) — до WINDOW_SCALE_FALLBACK.
static func scales_fitting(area: Vector2i) -> Array[int]:
	var top := WINDOW_SCALE_FALLBACK
	if area.x > 0 and area.y > 0:
		top = mini(area.x / BASE_SIZE.x, area.y / BASE_SIZE.y)
	top = clampi(top, WINDOW_SCALE_MIN, WINDOW_SCALE_MAX)
	var out: Array[int] = []
	for k in range(WINDOW_SCALE_MIN, top + 1):
		out.append(k)
	return out


## Масштабы окна для текущего монитора (без панели задач).
func window_scales() -> Array[int]:
	var area := Vector2i.ZERO
	if can_change_display():
		area = DisplayServer.screen_get_usable_rect(_screen()).size
	return scales_fitting(area)


## Масштаб окна, который реально применяется: выбранный, но не больше влезающего.
func effective_window_scale() -> int:
	var scales := window_scales()
	return mini(_values[&"window_scale"], scales[scales.size() - 1])


static func resolution_text(scale: int) -> String:
	return "%d×%d" % [BASE_SIZE.x * scale, BASE_SIZE.y * scale]


## Размер экрана монитора (для подписи в полноэкранном режиме).
func screen_size() -> Vector2i:
	if not can_change_display():
		return BASE_SIZE * effective_window_scale()
	return DisplayServer.screen_get_size(_screen())


func _screen() -> int:
	if is_inside_tree():
		return get_window().current_screen
	return DisplayServer.window_get_current_screen()


func _apply_display() -> void:
	if not can_change_display() or not is_inside_tree():
		return
	var win := get_window()
	if _values[&"fullscreen"]:
		win.mode = Window.MODE_FULLSCREEN
		return
	if win.mode != Window.MODE_WINDOWED:
		win.mode = Window.MODE_WINDOWED
	var size := BASE_SIZE * effective_window_scale()
	var area := DisplayServer.screen_get_usable_rect(win.current_screen)
	win.size = size
	win.position = area.position + (area.size - size) / 2
