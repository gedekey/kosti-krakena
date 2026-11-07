extends CanvasLayer
## Всплывающие подсказки к игровым терминам (М13, доп.), как в Path of Exile.
##
## Источники: TermLabel (термины в тексте) и любые элементы, к которым термин
## привязан через attach() (кнопки, значки, подписи). Подсказки — стек: термин внутри
## подсказки открывает следующую рядом, предыдущая остаётся.
##
## ПК: наведение открывает, подсказка живёт, пока мышь на термине, на ней самой или на
## вложенной (с небольшой задержкой на переход). Щелчок по термину закрепляет подсказку:
## тогда её не сменит наведение на другой термин того же уровня, закрывает щелчок мимо или Esc.
## Android (тап): тап по термину открывает и закрепляет, повторный тап по нему же или тап
## мимо — закрывает. У кнопок на сенсорном экране подсказки нет: тап по кнопке — действие.
## Правил игры здесь нет — тексты даёт Glossary.

## Сколько секунд подсказка ждёт, пока мышь переходит с термина на неё.
const HOVER_GRACE := 0.25
const LAYER := 100
const ATTACH_META := &"term_tip"

var glossary := Glossary.new()


class Tip:
	var source: Control
	var term: StringName
	var panel: TermTooltip
	var hovered := false
	var pinned := false
	var lost := 0.0


var _tips: Array[Tip] = []
var _click_pending := false
var _click_pos := Vector2.ZERO
var _term_clicked := false
## Был сенсорный ввод — у кнопок подсказки не показываем.
var touch_mode := false


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.locale_changed.connect(func(_l: String) -> void: close_all())


# --- Привязка к элементам -------------------------------------------------------------

## Показывать подсказку term при наведении на control (и по тапу, если это не кнопка).
func attach(control: Control, term: StringName) -> void:
	assert(Glossary.is_term(term), "нет термина %s" % term)
	control.set_meta(ATTACH_META, term)
	control.tooltip_text = ""
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		control.mouse_filter = Control.MOUSE_FILTER_PASS
	if control.mouse_entered.is_connected(_on_attached_entered):
		return
	control.mouse_entered.connect(_on_attached_entered.bind(control))
	control.mouse_exited.connect(unhover.bind(control))
	control.gui_input.connect(_on_attached_input.bind(control))
	control.tree_exiting.connect(_close_source.bind(control))


static func attached_term(control: Control) -> StringName:
	return control.get_meta(ATTACH_META, &"")


# --- Команды источников ---------------------------------------------------------------

## Мышь над термином term в source.
func hover_term(source: Control, term: StringName, anchor := Rect2()) -> void:
	var level := _level_of(source)
	if level < _tips.size():
		var tip := _tips[level]
		if tip.source == source and tip.term == term:
			tip.hovered = true
			tip.lost = 0.0
			return
		if tip.pinned:
			return
	_open(level, source, term, anchor, false).hovered = true


## Мышь ушла с термина в source.
func unhover(source: Control) -> void:
	for tip in _tips:
		if tip.source == source:
			tip.hovered = false


## Щелчок/тап по термину: открыть и закрепить, повторный — закрыть.
func click_term(source: Control, term: StringName, anchor := Rect2()) -> void:
	_term_clicked = true
	var level := _level_of(source)
	if level < _tips.size():
		var tip := _tips[level]
		if tip.source == source and tip.term == term:
			if tip.pinned:
				close_from(level)
			else:
				tip.pinned = true
				close_from(level + 1)
			return
	_open(level, source, term, anchor, true).pinned = true


func close_all() -> void:
	close_from(0)


func close_from(level: int) -> void:
	while _tips.size() > level:
		var tip: Tip = _tips.pop_back()
		if is_instance_valid(tip.panel):
			tip.panel.queue_free()


# --- Для тестов и экранов -------------------------------------------------------------

func count() -> int:
	return _tips.size()


func panel(level: int) -> TermTooltip:
	return _tips[level].panel if level < _tips.size() else null


func term_at(level: int) -> StringName:
	return _tips[level].term if level < _tips.size() else &""


func is_pinned(level: int) -> bool:
	return level < _tips.size() and _tips[level].pinned


# --- Внутреннее -----------------------------------------------------------------------

func _open(level: int, source: Control, term: StringName, anchor: Rect2, pinned: bool) -> Tip:
	close_from(level)
	var tip := Tip.new()
	tip.source = source
	tip.term = term
	tip.pinned = pinned
	tip.panel = TermTooltip.new()
	add_child(tip.panel)
	tip.panel.show_term(term)
	tip.panel.place_near(anchor if anchor.has_area() else _anchor_for(source))
	_tips.append(tip)
	return tip


## Уровень новой подсказки: источник внутри подсказки k → k + 1, иначе 0.
func _level_of(source: Control) -> int:
	for i in range(_tips.size() - 1, -1, -1):
		if is_instance_valid(_tips[i].panel) and _tips[i].panel.is_ancestor_of(source):
			return i + 1
	return 0


## Термин в тексте — рядом с курсором; привязанный элемент — по его рамке.
func _anchor_for(source: Control) -> Rect2:
	if source is TermLabel or not source.is_inside_tree():
		var mouse := get_viewport().get_mouse_position()
		return Rect2(mouse - TutorialLayout.TERM_TIP_CURSOR, TutorialLayout.TERM_TIP_CURSOR * 2)
	return source.get_global_rect()


func _process(delta: float) -> void:
	if _tips.is_empty():
		return
	var mouse := get_viewport().get_mouse_position()
	var i := _tips.size() - 1
	while i >= 0:
		var tip := _tips[i]
		if not is_instance_valid(tip.source) or not tip.source.is_visible_in_tree() \
				or not is_instance_valid(tip.panel):
			close_from(i)
		else:
			var keep := tip.pinned or tip.hovered or i < _tips.size() - 1 \
					or tip.panel.get_global_rect().grow(1).has_point(mouse)
			tip.lost = 0.0 if keep else tip.lost + delta
			if tip.lost >= HOVER_GRACE:
				close_from(i)
		i -= 1


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_mode = true
	if _tips.is_empty():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_all()
	elif event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# Термин сообщит о щелчке в этом же кадре; иначе — это щелчок мимо.
		_click_pos = event.position
		_term_clicked = false
		if not _click_pending:
			_click_pending = true
			_resolve_click.call_deferred()


func _resolve_click() -> void:
	_click_pending = false
	if _term_clicked:
		return
	# Закрыть всё выше самой верхней подсказки, по которой щёлкнули.
	for i in range(_tips.size() - 1, -1, -1):
		if is_instance_valid(_tips[i].panel) and _tips[i].panel.get_global_rect().has_point(_click_pos):
			close_from(i + 1)
			return
	close_all()


func _on_attached_entered(control: Control) -> void:
	if touch_mode and control is BaseButton:
		return
	hover_term(control, attached_term(control), control.get_global_rect())


func _on_attached_input(event: InputEvent, control: Control) -> void:
	if control is BaseButton:
		return
	if event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		click_term(control, attached_term(control), control.get_global_rect())


func _close_source(source: Control) -> void:
	for i in _tips.size():
		if _tips[i].source == source:
			close_from(i)
			return
