class_name BidFeed
extends PanelContainer
## Лента последних ставок раунда (М9): «Имя: N × [кубик]», новые снизу.

var _rows: VBoxContainer
var _entries: Array = []  # [name, quantity, face]


func _ready() -> void:
	add_theme_stylebox_override("panel", Sprites.panel(Sprites.PanelKind.DARK))
	TableKit.place(self, TableLayout.FEED_RECT)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := TableKit.vbox(1)
	add_child(box)
	box.add_child(TableKit.label("TABLE_FEED_TITLE", TableKit.TEXT_MUTED))
	_rows = TableKit.vbox(1)
	box.add_child(_rows)


func clear_entries() -> void:
	_entries.clear()
	_rebuild()


func add_entry(player_name: String, quantity: int, face: int) -> void:
	_entries.append([player_name, quantity, face])
	while _entries.size() > TableLayout.FEED_ROWS:
		_entries.pop_front()
	_rebuild()


func entry_count() -> int:
	return _entries.size()


func _rebuild() -> void:
	if _rows == null:
		return
	TableKit.clear(_rows)
	for i in _entries.size():
		var e: Array = _entries[i]
		var last := i == _entries.size() - 1
		var color := TableKit.TEXT if last else TableKit.TEXT_MUTED
		var row := TableKit.hbox(2)
		var name_label := TableKit.label("%s:" % e[0], color)
		name_label.custom_minimum_size.x = 86
		name_label.clip_text = true
		row.add_child(name_label)
		row.add_child(TableKit.label("%d ×" % e[1], color))
		row.add_child(TableKit.die_rect(e[2]))
		_rows.add_child(row)
