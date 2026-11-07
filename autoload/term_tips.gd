extends CanvasLayer
## Всплывающие подсказки к игровым терминам (М13, доп.), как в Path of Exile.
##
## Источники: TermLabel (термины в тексте) и любые элементы, к которым термин
## привязан через attach() (кнопки, значки, подписи). Подсказки — стек: термин внутри
## подсказки открывает следующую рядом, предыдущая остаётся.
##
## ПК: подсказка открывается только правой кнопкой мыши по термину — наведение и левая
## кнопка ничего не открывают, чтобы подсказки не мешали игре. Повторный ПКМ по тому же
## термину, щелчок мимо подсказок или Esc — закрывают.
## Сенсорный экран (Android): тап по термину открывает, повторный тап или тап мимо —
## закрывает; у кнопок подсказки нет — тап по кнопке остаётся действием.
## Правил игры здесь нет — тексты даёт Glossary.

const LAYER := 100
const ATTACH_META := &"term_tip"
## Кнопка мыши, открывающая подсказку.
const OPEN_BUTTON := MOUSE_BUTTON_RIGHT

var glossary := Glossary.new()


class Tip:
	var source: Control
	var term: StringName
	var panel: TermTooltip


var _tips: Array[Tip] = []
var _click_pending := false
var _click_pos := Vector2.ZERO
var _term_clicked := false
## Был сенсорный ввод — термины открываются тапом, у кнопок подсказок нет.
var touch_mode := false


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.locale_changed.connect(func(_l: String) -> void: close_all())


# --- Привязка к элементам -------------------------------------------------------------

## Подсказка term по ПКМ на control (и по тапу, если это не кнопка).
func attach(control: Control, term: StringName) -> void:
	assert(Glossary.is_term(term), "нет термина %s" % term)
	control.set_meta(ATTACH_META, term)
	control.tooltip_text = ""
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		control.mouse_filter = Control.MOUSE_FILTER_PASS
	if control.gui_input.is_connected(_on_attached_input):
		return
	control.gui_input.connect(_on_attached_input.bind(control))
	control.tree_exiting.connect(_close_source.bind(control))


static func attached_term(control: Control) -> StringName:
	return control.get_meta(ATTACH_META, &"")


## Это нажатие открывает подсказку: ПКМ, а на сенсорном экране — тап (отпускание).
func is_open_event(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index == OPEN_BUTTON:
		return mb.pressed
	return touch_mode and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed


# --- Команды источников ---------------------------------------------------------------

## Открыть подсказку term от source; если она уже открыта — закрыть.
func toggle_term(source: Control, term: StringName, anchor := Rect2()) -> void:
	_term_clicked = true
	var level := _level_of(source)
	if level < _tips.size() and _tips[level].source == source and _tips[level].term == term:
		close_from(level)
		return
	_open(level, source, term, anchor)


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


# --- Внутреннее -----------------------------------------------------------------------

func _open(level: int, source: Control, term: StringName, anchor: Rect2) -> void:
	close_from(level)
	var tip := Tip.new()
	tip.source = source
	tip.term = term
	tip.panel = TermTooltip.new()
	add_child(tip.panel)
	tip.panel.show_term(term)
	tip.panel.place_near(anchor if anchor.has_area() else _anchor_for(source))
	_tips.append(tip)


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


## Источник пропал или скрыт (сменился экран, закрылась панель) — закрыть его подсказку.
func _process(_delta: float) -> void:
	for i in _tips.size():
		var tip := _tips[i]
		if not is_instance_valid(tip.source) or not tip.source.is_visible_in_tree() \
				or not is_instance_valid(tip.panel):
			close_from(i)
			return


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_mode = true
	if _tips.is_empty():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_all()
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	# ПКМ и ЛКМ (на сенсорном — по отпусканию, как тап) мимо подсказок закрывают их.
	# Термин под курсором сообщит о себе в этом же кадре — тогда решает он.
	var closing := (mb.button_index == OPEN_BUTTON and mb.pressed) \
			or (mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed != touch_mode)
	if closing:
		_click_pos = mb.position
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


func _on_attached_input(event: InputEvent, control: Control) -> void:
	if not is_open_event(event):
		return
	if touch_mode and control is BaseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return
	control.accept_event()
	toggle_term(control, attached_term(control), control.get_global_rect())


func _close_source(source: Control) -> void:
	for i in _tips.size():
		if _tips[i].source == source:
			close_from(i)
			return
