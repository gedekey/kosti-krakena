extends GutHookScript
## Перед прогоном тестов (М11): настройки и статистика — по умолчанию и только в памяти
## (сохранения игрока в user:// не трогаем), переходы между экранами — без смены сцены.
## Подключён в .gutconfig.json (pre_run_script).


func run() -> void:
	Settings.save_path = ""
	Settings.reset_to_defaults()
	Stats.save_path = ""
	Stats.reset()
	Stats.clear_flags()
	ScreenNav.test_mode = true
