class_name BarkCloud
extends Control
## Облако реплики соперника (М24, DESIGN.md §8д): пиксельная рамка с хвостиком к портрету,
## текст печатается по буквам под «бормотание», облако само исчезает. Клики проходят насквозь.
## Что и кто говорит, решает BarkDirector; здесь — только показ.

const FILL := KrakenPalette.PARCHMENT
const SHADE := KrakenPalette.BONE
const OUTLINE := KrakenPalette.INK

## Слоги по персонажам: персонаж → Array[AudioStreamWAV] (синтезируются один раз).
static var _syllables := {}

var _label: Label
var _player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _bark: BarkDirector.Bark
var _body := Rect2i()
var _tail_x := 0
var _elapsed := 0.0
var _last_syllable := -INF


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Печать по буквам не переносит слова заново: строки раскладываются по всему тексту.
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_label.add_theme_color_override("font_color", KrakenPalette.INK)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	add_child(_label)
	_player = AudioStreamPlayer.new()
	_player.bus = Settings.SFX_BUS
	add_child(_player)


## Показать реплику над местом target (SeatView). Прошлое облако сменяется.
func show_bark(b: BarkDirector.Bark, target: Control) -> void:
	_bark = b
	_elapsed = 0.0
	_last_syllable = -INF
	_rng.seed = hash(b.key)
	_label.text = b.text
	_label.visible_characters = 0
	visible = true
	_layout(target)
	queue_redraw()


func dismiss() -> void:
	visible = false
	_bark = null
	_player.stop()


func is_showing() -> bool:
	return visible and _bark != null


func text() -> String:
	return _label.text if is_showing() else ""


func speaker_id() -> int:
	return _bark.speaker_id if is_showing() else -1


## Напечатано всё.
func is_typed() -> bool:
	return _label.visible_characters < 0 or _label.visible_characters >= _label.text.length()


## Прямоугольник тела облака (без хвостика) в координатах экрана.
func body_rect() -> Rect2i:
	return Rect2i(Vector2i(position) + _body.position, _body.size)


## Кончик хвостика в координатах экрана.
func tail_tip() -> Vector2i:
	return Vector2i(position) + Vector2i(_tail_x, 0)


## Досрочно пройти время (тесты): допечатать и т.д.
func advance(seconds: float) -> void:
	_process(seconds)


func _process(delta: float) -> void:
	if not is_showing():
		return
	_elapsed += delta
	var shown := mini(int(_elapsed * BarkBalance.TYPE_SPEED), _label.text.length())
	if shown > _label.visible_characters and _label.visible_characters >= 0:
		for i in range(_label.visible_characters, shown):
			if BarkVoice.is_syllable(_label.text[i]):
				_mumble()
				break
		_label.visible_characters = shown
	if _elapsed >= _bark.duration:
		dismiss()


func _mumble() -> void:
	if _elapsed - _last_syllable < BarkVoice.SYLLABLE_GAP or not is_inside_tree():
		return
	_last_syllable = _elapsed
	var pool := _syllables_for(_bark.character)
	_player.stream = pool[_rng.randi_range(0, pool.size() - 1)]
	_player.play()


static func _syllables_for(character: StringName) -> Array:
	if not _syllables.has(character):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(character))
		var out := []
		for i in BarkVoice.SYLLABLES:
			out.append(SfxSynth.to_stream(BarkVoice.render_syllable(character, rng)))
		_syllables[character] = out
	return _syllables[character]


## Размер по тексту, место — под портретом говорящего, в пределах экрана.
func _layout(target: Control) -> void:
	var font := _label.get_theme_font(&"font")
	var font_size := _label.get_theme_font_size(&"font_size")
	var inner_max := TableLayout.BARK_MAX_WIDTH - TableLayout.BARK_PAD.x * 2
	var one_line := font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var inner_w := clampi(ceili(one_line.x) + 1, TableLayout.BARK_MIN_WIDTH - TableLayout.BARK_PAD.x * 2,
			inner_max)
	_label.position = TableLayout.BARK_PAD + Vector2i(0, TableLayout.BARK_TAIL_H)
	# Высота — по строкам при этой ширине (минимальный размер пересчитывается после смены ширины).
	_label.size = Vector2(inner_w, 0)
	_label.update_minimum_size()
	var inner_h := ceili(_label.get_minimum_size().y)
	_label.size = Vector2(inner_w, inner_h)
	_body = Rect2i(0, TableLayout.BARK_TAIL_H,
			inner_w + TableLayout.BARK_PAD.x * 2, inner_h + TableLayout.BARK_PAD.y * 2)
	size = Vector2(_body.size.x, _body.end.y)

	# Хвостик — к середине портрета; облако по центру под ним, но в пределах экрана.
	var anchor_x := int(target.global_position.x) + TableLayout.FRAME_SIZE.x / 2
	var m := TableLayout.BARK_SCREEN_MARGIN
	var left := clampi(anchor_x - _body.size.x / 2, m, TableLayout.SCREEN.x - m - _body.size.x)
	position = Vector2i(left, TableLayout.BARK_TOP - TableLayout.BARK_TAIL_H)
	_tail_x = clampi(anchor_x - left, 4, _body.size.x - 5)


func _draw() -> void:
	if _bark == null:
		return
	var b := _body
	# Тело: заливка, тень снизу, контур со срезанными углами (пиксельное скругление).
	draw_rect(Rect2i(b.position + Vector2i(1, 1), b.size - Vector2i(2, 2)), FILL)
	draw_rect(Rect2i(b.position.x + 1, b.end.y - 2, b.size.x - 2, 1), SHADE)
	draw_rect(Rect2i(b.position.x + 1, b.position.y, b.size.x - 2, 1), OUTLINE)
	draw_rect(Rect2i(b.position.x + 1, b.end.y - 1, b.size.x - 2, 1), OUTLINE)
	draw_rect(Rect2i(b.position.x, b.position.y + 1, 1, b.size.y - 2), OUTLINE)
	draw_rect(Rect2i(b.end.x - 1, b.position.y + 1, 1, b.size.y - 2), OUTLINE)
	# Хвостик вверх: ступеньки сужаются к кончику.
	var h := TableLayout.BARK_TAIL_H
	for row in h + 1:
		var y := b.position.y - h + row
		var half := row / 2
		var x0 := _tail_x - half
		var w := half * 2 + 2
		if row == h:
			draw_rect(Rect2i(x0 + 1, y, w - 2, 1), FILL)   # вход в тело — без контура
		else:
			draw_rect(Rect2i(x0, y, w, 1), OUTLINE)
			if w > 2:
				draw_rect(Rect2i(x0 + 1, y, w - 2, 1), FILL)
