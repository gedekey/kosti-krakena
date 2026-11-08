extends GutTest
## М16: Android — системная «Назад» и увеличенные зоны нажатия на сенсорном экране.

const MainMenu := preload("res://scenes/main_menu.tscn")
const SettingsScene := preload("res://scenes/settings.tscn")


func before_each() -> void:
	ScreenNav.history.clear()


func after_each() -> void:
	TouchUI.forced = null


func test_go_back_does_not_quit_engine_by_itself() -> void:
	# Иначе «Назад» на любом экране закрыл бы игру вместо перехода назад.
	assert_false(ProjectSettings.get_setting("application/config/quit_on_go_back", true))


func test_landscape_orientation() -> void:
	# 4 = sensor landscape: только ландшафт, телефон можно перевернуть.
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 4)


func test_back_in_main_menu_quits() -> void:
	var menu: Control = add_child_autofree(MainMenu.instantiate())
	menu.offer.hide()
	menu.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(ScreenNav.last(), ScreenNav.QUIT)


func test_back_in_main_menu_closes_tutorial_offer_first() -> void:
	var menu: Control = add_child_autofree(MainMenu.instantiate())
	menu.offer.show()
	menu.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(menu.offer.visible)
	assert_ne(ScreenNav.last(), ScreenNav.QUIT)


func test_back_in_other_screen_goes_to_menu() -> void:
	var s: Control = add_child_autofree(SettingsScene.instantiate())
	s.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(ScreenNav.last(), ScreenNav.MAIN_MENU)


func test_arrows_keep_sprite_size_on_desktop() -> void:
	TouchUI.forced = false
	var b: TextureButton = autofree(TableKit.arrow(true))
	assert_eq(Vector2i(b.get_combined_minimum_size()), Sprites.ARROW_SIZE)


func test_arrows_get_bigger_hit_area_on_touch() -> void:
	TouchUI.forced = true
	var b: TextureButton = autofree(TableKit.arrow(false))
	assert_eq(Vector2i(b.get_combined_minimum_size()), TouchUI.ARROW_HIT)
	assert_eq(b.stretch_mode, TextureButton.STRETCH_KEEP_CENTERED)


func test_android_preset_exists() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	var found := false
	for section in cfg.get_sections():
		if cfg.get_value(section, "platform", "") == "Android":
			found = true
			assert_true(str(cfg.get_value(section, "exclude_filter", "")).contains("tests/*"))
	assert_true(found, "нет пресета Android")
