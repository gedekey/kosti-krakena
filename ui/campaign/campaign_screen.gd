extends MenuScreen
## Экран кампании (М23, DESIGN.md §8г): карта таверны с 6 точками, карточка уровня,
## «Играть» → сцена с Хобом → стол. Внизу — «Портрет», «Вступление», «Заново».
##
## Порядок при входе:
##   - кампания не начата — выбор портрета, затем вступление (5 слайдов);
##   - только что выигран уровень (Campaign.tracker.last_won) — сцена с Хобом «после»,
##     а после уровня 6 — финал (4 слайда) и экран «Конец»;
##   - иначе — карта с выбранным самым дальним открытым уровнем.
## Прогресс и правила — в Campaign / CampaignProgress; экран только показывает и зовёт.

var map: TavernMap
var card: LevelCard
var portrait_button: Button
var intro_button: Button
var restart_button: Button
var picker: PortraitPicker
var hob: HobScene
var slides: SlideShow
var confirm: ChoicePanel
## Экран «Конец» (после финала).
var end_view: Control
var _levels: Array[CampaignLevel] = []
var _selected := 1
## Выбор портрета для новой кампании (иначе — смена портрета).
var _picking_new := false


func _ready() -> void:
	_build_backdrop("CAMP_TITLE")
	_levels = CampaignLevels.all()
	map = TavernMap.new()
	add_child(map)
	map.setup(_levels)
	map.point_pressed.connect(select)
	card = LevelCard.new()
	add_child(card)
	card.play_pressed.connect(play)

	_placed_button("MENU_BACK", MenuLayout.BACK_RECT, go_back)
	portrait_button = _placed_button("CAMP_PORTRAIT", CampaignLayout.PORTRAIT_BUTTON_RECT,
			change_portrait)
	intro_button = _placed_button("CAMP_INTRO", CampaignLayout.INTRO_BUTTON_RECT, replay_intro)
	restart_button = _placed_button("CAMP_RESTART", CampaignLayout.RESTART_BUTTON_RECT,
			ask_restart)

	confirm = ChoicePanel.new()
	confirm.show_cancel = false
	confirm.picked.connect(_on_confirm)
	add_child(confirm)
	picker = PortraitPicker.new()
	add_child(picker)
	picker.picked.connect(_on_portrait_picked)
	hob = HobScene.new()
	add_child(hob)
	slides = SlideShow.new()
	add_child(slides)
	end_view = _build_end_view()
	add_child(end_view)
	_enter()


func _enter() -> void:
	var progress := Campaign.progress
	var won := Campaign.tracker.last_won
	if won != CampaignTracker.NO_LEVEL:
		Campaign.tracker.last_won = CampaignTracker.NO_LEVEL
		select(won)
		_play_after(won)
	elif not progress.started:
		select(1)
		_pick_new()
	else:
		select(progress.frontier())


# --- Команды -------------------------------------------------------------------

func select(level: int) -> void:
	_selected = clampi(level, 1, _levels.size())
	map.show_progress(Campaign.progress, _selected)
	card.show_level(_levels[_selected - 1], Campaign.progress)


func selected() -> int:
	return _selected


## «Играть»: сцена с Хобом перед уровнем, затем стол.
func play(level: int) -> void:
	if not Campaign.progress.is_unlocked(level):
		return
	var lvl := _levels[level - 1]
	_once(hob.finished, _start_match.bind(lvl))
	hob.play(HobScene.lines_for(lvl, false))


func change_portrait() -> void:
	_picking_new = false
	picker.open(_portrait())


func replay_intro() -> void:
	slides.play(SlideShow.INTRO)


func ask_restart() -> void:
	var choices: Array[ChoicePanel.Choice] = [
		ChoicePanel.Choice.new("CAMP_RESTART_YES", true),
		ChoicePanel.Choice.new("CAMP_RESTART_NO", false),
	]
	confirm.open(tr("CAMP_RESTART_TITLE"), choices, 2)


## Esc: сначала закрывает сцену / слайды / окна, иначе — в главное меню.
func go_back() -> void:
	if end_view.visible:
		ScreenNav.go(ScreenNav.MAIN_MENU)
	elif slides.is_playing():
		slides.skip()
	elif hob.is_playing():
		hob.skip()
	elif confirm.visible:
		confirm.hide()
	elif picker.visible and Campaign.progress.started and not _picking_new:
		picker.hide()
	elif not picker.visible:
		ScreenNav.go(ScreenNav.MAIN_MENU)


# --- Поток ---------------------------------------------------------------------

func _start_match(level: CampaignLevel) -> void:
	MatchSetup.pending = MatchSetup.for_campaign(level, _portrait())
	ScreenNav.go(ScreenNav.TABLE)


func _play_after(level: int) -> void:
	var lvl := _levels[level - 1]
	if level >= CampaignBalance.LEVEL_COUNT:
		_once(hob.finished, _play_finale)
	else:
		# После сцены — на карте следующий уровень.
		_once(hob.finished, func() -> void: select(Campaign.progress.frontier()))
	hob.play(HobScene.lines_for(lvl, true))


func _play_finale() -> void:
	_once(slides.finished, func() -> void: end_view.show())
	slides.play(SlideShow.FINALE)


func _pick_new() -> void:
	_picking_new = true
	picker.open(_portrait())


func _on_portrait_picked(portrait: StringName) -> void:
	if _picking_new:
		_picking_new = false
		Campaign.start_new(portrait)
		select(1)
		_once(slides.finished, Campaign.mark_intro_seen)
		slides.play(SlideShow.INTRO)
	else:
		Campaign.set_portrait(portrait)


func _on_confirm(value: Variant) -> void:
	confirm.hide()
	if value == true:
		_pick_new()


## Портрет игрока кампании (если в сохранении чужое значение — первый).
func _portrait() -> StringName:
	var p := Campaign.progress.portrait
	return p if Sprites.PLAYER_PORTRAITS.has(p) else Sprites.PLAYER_PORTRAITS[0]


static func _once(sig: Signal, callable: Callable) -> void:
	sig.connect(callable, CONNECT_ONE_SHOT)


func _build_end_view() -> Control:
	var view := Control.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = KrakenPalette.INK
	back.size = MenuLayout.SCREEN
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(back)
	var title := TableKit.title("CAMP_END_TITLE", true)
	TableKit.place(title, CampaignLayout.END_TITLE_RECT)
	view.add_child(title)
	var text := TableKit.label("CAMP_END_TEXT", TableKit.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TableKit.place(text, CampaignLayout.END_TEXT_RECT)
	view.add_child(text)
	var b := TableKit.button("CAMP_END_MENU", Sprites.ButtonKind.BID)
	TableKit.place(b, CampaignLayout.END_BUTTON_RECT)
	b.pressed.connect(ScreenNav.go.bind(ScreenNav.MAIN_MENU))
	view.add_child(b)
	view.set_meta(&"button", b)
	view.hide()
	return view
