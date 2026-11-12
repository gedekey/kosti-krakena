class_name LevelCard
extends PanelContainer
## Карточка уровня кампании (М23, DESIGN.md §8г): название, место, соперники, модификатор,
## «Palifico и Calza всегда включены», отметка «пройдено» и «Играть».

signal play_pressed(level: int)

var play_button: Button
var _level_label: Label
var _done_label: Label
var _name: Label
var _place: Label
var _portraits: HBoxContainer
var _opponents: Label
var _mod_name: Label
var _mod_desc: Label
var _rules: Label
var _locked: Label
var _level: CampaignLevel
var _progress_ref: CampaignProgress


func _ready() -> void:
	add_theme_stylebox_override("panel", Sprites.panel(Sprites.PanelKind.DARK))
	mouse_filter = Control.MOUSE_FILTER_STOP
	TableKit.place(self, CampaignLayout.CARD_RECT)
	var margin := TutorialLayout.margin(CampaignLayout.CARD_MARGIN)
	add_child(margin)
	var box := TableKit.vbox(3)
	margin.add_child(box)
	var width := TutorialLayout.text_width(CampaignLayout.CARD_RECT.size.x,
			CampaignLayout.CARD_MARGIN)
	var head := TableKit.hbox(4)
	box.add_child(head)
	_level_label = TableKit.label("", TableKit.TEXT_MUTED)
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_level_label)
	_done_label = TableKit.label("CAMP_COMPLETED", TableKit.TEXT_GOOD)
	head.add_child(_done_label)
	_name = TableKit.title("", true)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.custom_minimum_size.x = width
	box.add_child(_name)
	_place = TableKit.label("", TableKit.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_place)
	_portraits = TableKit.hbox(4)
	_portraits.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_portraits)
	_opponents = _wrapped(TableKit.TEXT, width)
	_opponents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_opponents)
	_mod_name = TableKit.label("", TableKit.TEXT_MAGIC, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_mod_name)
	_mod_desc = _wrapped(TableKit.TEXT, width)
	box.add_child(_mod_desc)
	_rules = _wrapped(TableKit.TEXT_MUTED, width)
	_rules.text = "CAMP_RULES_FIXED"
	box.add_child(_rules)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	_locked = _wrapped(TableKit.TEXT_ALERT, width)
	_locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_locked)
	play_button = TableKit.button("CAMP_PLAY", Sprites.ButtonKind.BID)
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_button.pressed.connect(func() -> void:
		if _level != null:
			play_pressed.emit(_level.number))
	box.add_child(play_button)
	Events.locale_changed.connect(func(_l: String) -> void:
		if _level != null and _progress_ref != null:
			show_level(_level, _progress_ref))


func show_level(level: CampaignLevel, progress: CampaignProgress) -> void:
	_level = level
	_progress_ref = progress
	_level_label.text = tr("CAMP_LEVEL") % level.number
	_done_label.visible = progress.is_completed(level.number)
	_name.text = level.name_key
	_place.text = level.place_key
	TableKit.clear(_portraits)
	# Уровень 6: до прохождения соперник и модификатор скрыты — иначе поворот с Хобом
	# раскрыт заранее (решение автора).
	if is_secret(level, progress):
		_portraits.add_child(_secret_portrait())
		_opponents.text = "CAMP_SECRET_OPPONENT"
		_mod_name.text = "CAMP_SECRET_MODIFIER"
		_mod_desc.visible = false
		_mod_desc.text = ""
		_show_lock(level, progress)
		return
	var names: PackedStringArray = []
	for id in level.opponents:
		var p := BotRoster.by_id(id)
		_portraits.add_child(_small_portrait(id))
		if p != null:
			names.append("%s %s" % [tr(p.name_key), "★".repeat(p.stars)])
	_opponents.text = ", ".join(names)
	var key := CampaignLevel.modifier_key(level.modifier)
	_mod_name.text = key if key != "" else "CAMP_NO_MODIFIER"
	_mod_desc.visible = key != ""
	_mod_desc.text = modifier_text(level.modifier)
	_show_lock(level, progress)


## Скрыты ли соперник и модификатор (CampaignLevel.secret_until_completed).
static func is_secret(level: CampaignLevel, progress: CampaignProgress) -> bool:
	return level.secret_until_completed and not progress.is_completed(level.number)


func is_showing_secret() -> bool:
	return _opponents.text == "CAMP_SECRET_OPPONENT"


func _show_lock(level: CampaignLevel, progress: CampaignProgress) -> void:
	var unlocked := progress.is_unlocked(level.number)
	play_button.disabled = not unlocked
	_locked.visible = not unlocked
	if not unlocked:
		var prev := CampaignLevels.get_level(level.number - 1)
		_locked.text = tr("CAMP_LOCKED") % tr(prev.name_key if prev != null else "")


## Описание модификатора с числами из CampaignBalance.
static func modifier_text(m: CampaignLevel.Modifier) -> String:
	var key := CampaignLevel.modifier_key(m)
	if key == "":
		return ""
	var desc := TranslationServer.translate(key + "_DESC")
	match m:
		CampaignLevel.Modifier.EVIL_EYE:
			return desc % CampaignBalance.EVIL_EYE_DICE
		CampaignLevel.Modifier.SCARCE_SANITY:
			return desc % [CampaignBalance.SCARCE_SANITY, CheatBalance.START_SANITY]
		CampaignLevel.Modifier.DEAD_HAND:
			return desc % CampaignBalance.DEAD_HAND_DICE
		CampaignLevel.Modifier.LAIR:
			return desc % [CampaignBalance.LAIR_BOSS_DICE, CampaignBalance.TIDE_BOSS_DICE]
	return desc


func level_number() -> int:
	return _level.number if _level != null else 0


func modifier_description() -> String:
	return _mod_desc.text if _mod_desc.visible else ""


static func _small_portrait(id: StringName) -> TextureRect:
	return _small_rect(Sprites.portrait(id))


static func _small_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = CampaignLayout.CARD_PORTRAIT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Тёмный силуэт вместо портрета скрытого соперника.
static func _secret_portrait() -> TextureRect:
	var rect := _small_rect(HobPortrait.texture())
	rect.modulate = Color(0, 0, 0, 1)
	return rect


static func _wrapped(color: Color, width: int) -> Label:
	var l := TableKit.label("", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l
