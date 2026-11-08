extends MenuScreen
## Настройки (М11, DESIGN.md §6): язык, громкость музыки и звуков, скорость ботов,
## Palifico и Calza, полный экран и разрешение окна (М17, только на ПК). Каждое изменение сразу уходит в Settings (а он сам сохраняется).

## Ключи Settings, которые сбрасывает «По умолчанию» на этом экране.
const SCREEN_KEYS: Array[StringName] = [
	&"locale", &"music_volume", &"sfx_volume", &"bot_speed", &"palifico", &"calza",
	&"fullscreen", &"window_scale",
]

var language: ValueStepper
var music: ValueStepper
var sfx: ValueStepper
var speed: ValueStepper
var palifico: ValueStepper
var calza: ValueStepper
var fullscreen: ValueStepper
var resolution: ValueStepper
var defaults_button: Button


func _ready() -> void:
	_build_backdrop("SETTINGS_TITLE")
	var box := _form_panel(MenuLayout.FORM_RECT, MenuLayout.FORM_ROW_GAP)
	language = _row(box, "SETTINGS_LANGUAGE", _step_language)
	fullscreen = _row(box, "SETTINGS_DISPLAY", _toggle.bind(&"fullscreen"))
	resolution = _row(box, "SETTINGS_RESOLUTION", _step_resolution)
	# На Android и в вебе окно не меняется — строк нет.
	var desktop := ScreenNav.can_quit()
	fullscreen.visible = desktop
	resolution.visible = desktop
	music = _row(box, "SETTINGS_MUSIC", _step_volume.bind(&"music_volume"))
	sfx = _row(box, "SETTINGS_SFX", _step_volume.bind(&"sfx_volume"))
	speed = _row(box, "SETTINGS_BOT_SPEED", _step_speed)
	palifico = _row(box, "SETTINGS_PALIFICO", _toggle.bind(&"palifico"))
	calza = _row(box, "SETTINGS_CALZA", _toggle.bind(&"calza"))
	TermTips.attach(palifico.caption_label(), &"PALIFICO")
	TermTips.attach(calza.caption_label(), &"CALZA")
	var spacer := Control.new()
	spacer.custom_minimum_size.y = MenuLayout.FORM_NOTE_GAP
	box.add_child(spacer)
	box.add_child(TableKit.label("SETTINGS_RULES_NOTE", TableKit.TEXT_MUTED,
			HORIZONTAL_ALIGNMENT_CENTER))

	_placed_button("MENU_BACK", MenuLayout.BACK_RECT, go_back)
	defaults_button = _placed_button("SETTINGS_DEFAULTS", MenuLayout.PRIMARY_RECT,
			_on_defaults)
	Settings.changed.connect(_on_setting_changed)
	refresh()


func _row(box: VBoxContainer, caption: String, handler: Callable) -> ValueStepper:
	var s := ValueStepper.new()
	box.add_child(s)
	s.setup(caption, MenuLayout.FORM_CAPTION_WIDTH, MenuLayout.FORM_FIELD_WIDTH)
	s.alignment = BoxContainer.ALIGNMENT_CENTER
	s.stepped.connect(handler)
	return s


func refresh() -> void:
	var locale := Settings.resolve_locale()
	language.set_value_text("LANG_" + locale.to_upper())
	_refresh_volume(music, Settings.get_value(&"music_volume"))
	_refresh_volume(sfx, Settings.get_value(&"sfx_volume"))
	var full: bool = Settings.get_value(&"fullscreen")
	fullscreen.set_value_text("SETTINGS_FULLSCREEN" if full else "SETTINGS_WINDOWED")
	_refresh_resolution(full)
	var index := _speed_index()
	speed.set_value_text("×" + str(Settings.BOT_SPEEDS[index]).trim_suffix(".0"))
	speed.set_can_step(index > 0, index < Settings.BOT_SPEEDS.size() - 1)
	for pair: Array in [[palifico, &"palifico"], [calza, &"calza"]]:
		pair[0].set_value_text("SETTINGS_ON" if Settings.get_value(pair[1]) else "SETTINGS_OFF")


## В полном экране картинка во весь монитор — показываем его разрешение, листать нельзя.
func _refresh_resolution(full: bool) -> void:
	if full:
		var screen := Settings.screen_size()
		resolution.set_value_text("%d×%d" % [screen.x, screen.y])
		resolution.set_can_step(false, false)
		return
	var scales := Settings.window_scales()
	var current := Settings.effective_window_scale()
	resolution.set_value_text(Settings.resolution_text(current))
	resolution.set_can_step(current > scales[0], current < scales[scales.size() - 1])


func _step_resolution(delta: int) -> void:
	if Settings.get_value(&"fullscreen"):
		return
	var scales := Settings.window_scales()
	var i := clampi(scales.find(Settings.effective_window_scale()) + delta, 0, scales.size() - 1)
	Settings.set_value(&"window_scale", scales[i])


func _refresh_volume(stepper: ValueStepper, volume: float) -> void:
	stepper.set_value_text("%d%%" % roundi(volume * 100.0))
	stepper.set_can_step(volume > 0.0, volume < 1.0)


func _step_language(delta: int) -> void:
	var locales := Settings.SUPPORTED_LOCALES
	var i := locales.find(Settings.resolve_locale())
	Settings.set_value(&"locale", locales[posmod(i + delta, locales.size())])


func _step_volume(delta: int, key: StringName) -> void:
	var volume: float = Settings.get_value(key)
	Settings.set_value(key, snappedf(volume + delta * Settings.VOLUME_STEP, Settings.VOLUME_STEP))


func _step_speed(delta: int) -> void:
	var i := clampi(_speed_index() + delta, 0, Settings.BOT_SPEEDS.size() - 1)
	Settings.set_value(&"bot_speed", Settings.BOT_SPEEDS[i])


func _toggle(_delta: int, key: StringName) -> void:
	Settings.set_value(key, not Settings.get_value(key))


## Ближайший к текущей скорости вариант.
func _speed_index() -> int:
	var current: float = Settings.get_value(&"bot_speed")
	var best := 0
	for i in Settings.BOT_SPEEDS.size():
		if absf(Settings.BOT_SPEEDS[i] - current) < absf(Settings.BOT_SPEEDS[best] - current):
			best = i
	return best


func _on_defaults() -> void:
	Settings.reset_keys(SCREEN_KEYS)
	refresh()


func _on_setting_changed(_key: StringName, _value: Variant) -> void:
	refresh()
