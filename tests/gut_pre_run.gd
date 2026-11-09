extends GutHookScript
## Перед прогоном тестов (М11): настройки, статистика, достижения (М17) и ранги (М20) — по умолчанию и только в памяти
## (сохранения игрока в user:// не трогаем), переходы между экранами — без смены сцены.
## Подключён в .gutconfig.json (pre_run_script).


func run() -> void:
	Settings.save_path = ""
	Settings.reset_to_defaults()
	Stats.save_path = ""
	Stats.reset()
	Stats.clear_flags()
	Achievements.save_path = ""
	Achievements.reset()
	Ranks.save_path = ""
	Ranks.reset()
	ScreenNav.test_mode = true
