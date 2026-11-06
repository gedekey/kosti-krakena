extends GutTest
## М8: витрина спрайтов собирается на обоих языках, страницы и анимации работают.

const SCENE := "res://scenes/sprite_showcase.tscn"

var _saved_locale: String


func before_each() -> void:
	_saved_locale = Settings.get_value(&"locale")


func after_each() -> void:
	Settings.set_value(&"locale", _saved_locale)


func test_showcase_builds_in_both_languages() -> void:
	for locale in ["ru", "en"]:
		Settings.set_value(&"locale", locale)
		var screen: Control = add_child_autofree(load(SCENE).instantiate())
		await wait_process_frames(1)
		assert_gt(screen.get_child_count(), 0, locale)


func test_pages_switch_and_roll_finishes() -> void:
	var screen: Control = add_child_autofree(load(SCENE).instantiate())
	await wait_process_frames(1)
	for page in screen.PAGE_KEYS:
		screen._show_page(page)
		assert_true(screen._pages[page].visible, str(page))
	screen.roll_dice()
	for i in screen.ROLL_TICKS:
		screen._on_roll_tick()
	assert_true(screen._roll_timer.is_stopped(), "бросок закончился")
	var rects: Array = screen._dice_rects[Sprites.DiceSet.BONE]
	for i in rects.size():
		assert_eq(rects[i].texture, Sprites.die(Sprites.DiceSet.BONE, screen._faces[i]))


func test_madness_toggle_swaps_portraits() -> void:
	var screen: Control = add_child_autofree(load(SCENE).instantiate())
	await wait_process_frames(1)
	screen.set_madness(true)
	assert_eq(screen._portrait_rects[&"witch"].texture, Sprites.portrait(&"witch", true))
	screen.set_madness(false)
	assert_eq(screen._portrait_rects[&"witch"].texture, Sprites.portrait(&"witch", false))
