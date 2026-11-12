extends Node
## Кампания (DESIGN.md §8г, М23). Логика — CampaignTracker / CampaignProgress; здесь —
## подписка на события матча (Events), достижения кампании и сохранение в
## user://campaign.cfg. Учёт матча начинает стол (begin / skip).
##
## save_path = "" — не трогать диск (тесты, см. tests/gut_pre_run.gd).

const SAVE_PATH := "user://campaign.cfg"
const SECTION := "campaign"

var save_path := SAVE_PATH
var tracker := CampaignTracker.new()
var progress: CampaignProgress:
	get:
		return tracker.progress


func _ready() -> void:
	tracker.changed.connect(save)
	tracker.level_won.connect(_on_level_won)
	tracker.campaign_completed.connect(_on_campaign_completed)
	load_saved()
	listen(Events)


## Подписаться на события матча (тесты подсовывают свою шину).
func listen(events: Node) -> void:
	events.cheat_resolved.connect(func(outcome: CheatOutcome) -> void:
		tracker.cheat_used(outcome.player_id))
	events.cheat_failed.connect(func(id: int, _kind: int) -> void: tracker.cheat_used(id))
	events.player_eliminated.connect(tracker.player_eliminated)
	events.match_ended.connect(tracker.match_ended)


func begin(level: int) -> void:
	tracker.begin(level)


func skip() -> void:
	tracker.skip()


func forfeit() -> void:
	tracker.forfeit()


func abort() -> void:
	tracker.abort()


func is_counting() -> bool:
	return tracker.is_counting()


## Новая кампания с выбранным портретом.
func start_new(portrait: StringName) -> void:
	progress.start_new(portrait)
	save()


func set_portrait(portrait: StringName) -> void:
	progress.set_portrait(portrait)
	save()


func mark_intro_seen() -> void:
	progress.intro_seen = true
	save()


## Забыть прогресс полностью, включая отметку о прохождении (тесты).
func reset() -> void:
	tracker.skip()
	tracker.last_won = CampaignTracker.NO_LEVEL
	progress.reset()
	save()


func _on_level_won(_level: int, clean: bool, _first: bool) -> void:
	if Stats.recording:
		Achievements.tracker.campaign_level_won(clean)


func _on_campaign_completed(flawless: bool) -> void:
	if Stats.recording:
		Achievements.tracker.campaign_completed(flawless)


# --- Сохранение ------------------------------------------------------------------

func save() -> Error:
	if save_path == "":
		return OK
	var file := ConfigFile.new()
	var data := progress.to_dict()
	for key: String in data:
		file.set_value(SECTION, key, data[key])
	return file.save(save_path)


func load_saved() -> void:
	if save_path == "" or not FileAccess.file_exists(save_path):
		return
	var file := ConfigFile.new()
	if file.load(save_path) != OK or not file.has_section(SECTION):
		return
	var data := {}
	for key in file.get_section_keys(SECTION):
		data[key] = file.get_value(SECTION, key)
	progress.from_dict(data)
