extends Control
## Тестовая сцена шрифтов и локализации (М7).
##
## Показывает оба шрифта (основной и заголовочный, «камень» и «свечение»),
## панграммы на текущем языке и образцы обоих алфавитов одновременно.
## Кнопки переключают язык в рантайме (через Settings) и размер окна ×1 / ×2 / ×3.

const MARGIN := 8
const SEPARATION := 4
const WINDOW_SCALES: Array[int] = [1, 2, 3]
const BG_COLOR := Color("#1e1a2b")
const TEXT_COLOR := Color("#e8d9b0")
const MUTED_COLOR := Color("#c9a66b")

var _status_label: Label
var _scale_buttons: Array[Button] = []


func _ready() -> void:
	_build_ui()
	Events.locale_changed.connect(func(_locale: String) -> void: _refresh())
	get_window().size_changed.connect(_refresh)
	_refresh()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(root)

	_add_label(root, "FONT_TEST_TITLE", PixelFonts.VARIATION_TITLE)
	_add_label(root, "FONT_TEST_TITLE_PANGRAM", PixelFonts.VARIATION_TITLE_GLOW)
	_add_label(root, "FONT_TEST_PANGRAM", &"", TEXT_COLOR)
	root.add_child(HSeparator.new())

	# Оба алфавита сразу, независимо от языка.
	for key in ["FONT_SAMPLE_ALPHABET_RU", "FONT_SAMPLE_ALPHABET_EN",
			"FONT_SAMPLE_PANGRAM_RU", "FONT_SAMPLE_PANGRAM_EN", "FONT_SAMPLE_SYMBOLS"]:
		_add_label(root, key, &"", MUTED_COLOR)
	_add_label(root, "FONT_SAMPLE_TITLE_RU", PixelFonts.VARIATION_TITLE)
	_add_label(root, "FONT_SAMPLE_TITLE_EN", PixelFonts.VARIATION_TITLE)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", SEPARATION)
	root.add_child(controls)

	_add_label(controls, "FONT_TEST_LANGUAGE").autowrap_mode = TextServer.AUTOWRAP_OFF
	for locale in Settings.SUPPORTED_LOCALES:
		var button := Button.new()
		button.text = "LANG_" + locale.to_upper()
		button.pressed.connect(Settings.set_value.bind(&"locale", locale))
		controls.add_child(button)

	_add_label(controls, "FONT_TEST_SCALE").autowrap_mode = TextServer.AUTOWRAP_OFF
	for factor in WINDOW_SCALES:
		var button := Button.new()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.pressed.connect(_set_window_scale.bind(factor))
		controls.add_child(button)
		_scale_buttons.append(button)

	_status_label = _add_label(root, "", &"", MUTED_COLOR)
	_status_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _add_label(parent: Node, key: String, variation: StringName = &"",
		color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = key
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation.is_empty():
		label.add_theme_color_override("font_color", color)
	else:
		label.theme_type_variation = variation
	parent.add_child(label)
	return label


func _set_window_scale(factor: int) -> void:
	var window := get_window()
	if window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
	var target := _base_size() * factor
	window.size = target
	var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
	window.position = screen.position + (screen.size - target) / 2


func _refresh() -> void:
	for i in _scale_buttons.size():
		_scale_buttons[i].text = tr("FONT_TEST_SCALE_OPTION") % WINDOW_SCALES[i]
	var window_size := get_window().size
	var base := _base_size()
	# Масштаб целочисленный (scale_mode = integer), поэтому делим нацело.
	var factor := maxi(1, mini(window_size.x / base.x, window_size.y / base.y))
	_status_label.text = tr("FONT_TEST_STATUS") % [window_size.x, window_size.y, factor,
			TranslationServer.get_locale()]


func _base_size() -> Vector2i:
	return Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
