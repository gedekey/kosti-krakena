class_name AchievementToast
extends PanelContainer
## Уведомление «Достижение открыто!» (М17): иконка, подпись и название, держится
## TableLayout.TOAST_TIME сек. Несколько подряд — по очереди. Подписан на Achievements.unlocked.

var _queue: Array[Achievement.Id] = []
var _icon: TextureRect
var _name: Label
var _timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", Sprites.panel(Sprites.PanelKind.DARK))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	TableKit.place(self, TableLayout.TOAST_RECT)
	var row := TableKit.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	_icon = TableKit.icon_rect(Sprites.texture(Sprites.ICON_DICE))
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	var text := TableKit.vbox(0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	text.add_child(TableKit.label("ACH_TOAST", TableKit.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_name = TableKit.label("", TableKit.TEXT_GOOD, HORIZONTAL_ALIGNMENT_CENTER)
	text.add_child(_name)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_next)
	add_child(_timer)
	hide()
	Achievements.unlocked.connect(push)


## Показать (или поставить в очередь) уведомление о достижении.
func push(id: Achievement.Id) -> void:
	_queue.append(id)
	if not visible:
		_next()


## Что сейчас на экране (ключ названия) или "".
func shown_key() -> String:
	return _name.text if visible else ""


func _next() -> void:
	if _queue.is_empty():
		hide()
		return
	var id: Achievement.Id = _queue.pop_front()
	_icon.texture = AchievementView.icon(id)
	_name.text = Achievement.name_key(id)
	show()
	_timer.start(TableLayout.TOAST_TIME)
