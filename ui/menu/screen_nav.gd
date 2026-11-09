class_name ScreenNav
extends RefCounted
## Переходы между экранами (М11). В тестах test_mode = true: сцена не меняется,
## переходы только записываются в history (см. tests/gut_pre_run.gd).

const MAIN_MENU := "res://scenes/main_menu.tscn"
const OPPONENTS := "res://scenes/opponents.tscn"
const SETTINGS := "res://scenes/settings.tscn"
const STATS := "res://scenes/stats.tscn"
const RULES := "res://scenes/rules.tscn"
const TABLE := "res://scenes/table.tscn"
const ACHIEVEMENTS := "res://scenes/achievements.tscn"
## М19: сетевая игра — создать / присоединиться, лобби.
const NET_MENU := "res://scenes/net_menu.tscn"
const LOBBY := "res://scenes/lobby.tscn"
## Запись в history вместо выхода из игры.
const QUIT := "quit"

static var test_mode := false
static var history: PackedStringArray = []


static func go(path: String) -> void:
	if test_mode:
		history.append(path)
		return
	(Engine.get_main_loop() as SceneTree).change_scene_to_file(path)


static func quit() -> void:
	if test_mode:
		history.append(QUIT)
		return
	(Engine.get_main_loop() as SceneTree).quit()


## Выход из игры есть только на ПК (на Android — системная кнопка «Назад»).
static func can_quit() -> bool:
	return not (OS.has_feature("mobile") or OS.has_feature("web"))


static func last() -> String:
	return history[history.size() - 1] if not history.is_empty() else ""
