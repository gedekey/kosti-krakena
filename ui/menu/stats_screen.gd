extends MenuScreen
## Статистика (М11, DESIGN.md §8): счётчики из Stats, доля побед, сброс с подтверждением.
## М20: сверху — одиночный и сетевой ранги (сброс статистики ранги не трогает).

## Строки по порядку: ключ счётчика Stats → ключ подписи.
const ROWS := [
	[&"matches_played", "STATS_MATCHES_PLAYED"],
	[&"matches_won", "STATS_MATCHES_WON"],
	[&"", "STATS_WIN_RATE"],
	[&"cheaters_caught", "STATS_CHEATERS_CAUGHT"],
	[&"false_accusations", "STATS_FALSE_ACCUSATIONS"],
	[&"madness_count", "STATS_MADNESS_COUNT"],
]

var reset_button: Button
var confirm: ChoicePanel
var _values := {}       # подпись → Label значения
var single_rank: RankBadge
var net_rank: RankBadge


func _ready() -> void:
	_build_backdrop("STATS_TITLE")
	var box := _form_panel(MenuLayout.STATS_RECT, MenuLayout.FORM_ROW_GAP)
	single_rank = RankBadge.new().setup("RANK_SINGLE")
	box.add_child(single_rank)
	net_rank = RankBadge.new().setup("RANK_NET")
	box.add_child(net_rank)
	var gap := Control.new()
	gap.custom_minimum_size.y = MenuLayout.FORM_NOTE_GAP
	box.add_child(gap)
	for row: Array in ROWS:
		var line := TableKit.hbox(4)
		var caption := TableKit.label(row[1], TableKit.TEXT_MUTED)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(caption)
		var value := TableKit.label("", TableKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		line.add_child(value)
		box.add_child(line)
		_values[row[1]] = value

	_placed_button("MENU_BACK", MenuLayout.BACK_RECT, go_back)
	reset_button = _placed_button("STATS_RESET", MenuLayout.PRIMARY_RECT, _ask_reset,
			Sprites.ButtonKind.LIAR)
	confirm = ChoicePanel.new()
	confirm.picked.connect(_on_confirm)
	add_child(confirm)
	Stats.changed.connect(_on_stats_changed)
	refresh()


func refresh() -> void:
	single_rank.show_mode(RankTracker.Mode.SINGLE)
	net_rank.show_mode(RankTracker.Mode.NET)
	for row: Array in ROWS:
		var key: StringName = row[0]
		var text := "%d%%" % Stats.win_percent() if key == &"" else str(Stats.get_count(key))
		_values[row[1]].text = text


func value_of(caption_key: String) -> String:
	return _values[caption_key].text


func go_back() -> void:
	if confirm.visible:
		confirm.cancel()
		return
	super.go_back()


func _ask_reset() -> void:
	var choices: Array[ChoicePanel.Choice] = [ChoicePanel.Choice.new("STATS_RESET_YES", true)]
	confirm.open(tr("STATS_RESET_CONFIRM"), choices)


func _on_confirm(_value: Variant) -> void:
	confirm.hide()
	Stats.reset()
	refresh()


func _on_stats_changed(_key: StringName, _value: int) -> void:
	refresh()
