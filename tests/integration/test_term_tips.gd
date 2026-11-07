extends GutTest
## М13 (доп.): подсказки к игровым терминам — словарь в обоих языках, подсветка в текстах,
## стек вложенных подсказок, наведение, щелчок/тап, Esc, привязка к кнопкам и значкам.

const TableScene := preload("res://scenes/table.tscn")
const RulesScene := preload("res://scenes/rules.tscn")
const SettingsScene := preload("res://scenes/settings.tscn")
const LOCALES := ["ru", "en"]
## Подальше от курсора (в headless он в (0, 0)), чтобы подсказка не держалась наведением.
const FAR := Rect2(300, 150, 10, 10)

var _saved_locale: String


func before_each() -> void:
	_saved_locale = Settings.get_value(&"locale")
	MatchSetup.pending = null
	TermTips.close_all()
	TermTips.touch_mode = false
	for flag in HintPanel.TOPICS:
		Stats.set_flag(flag)


func after_each() -> void:
	TermTips.close_all()
	TermTips.touch_mode = false
	Settings.set_value(&"locale", _saved_locale)
	Stats.clear_flags()


func _label(text: String) -> TermLabel:
	var l: TermLabel = add_child_autofree(TermLabel.make(TableKit.TEXT, false, 200))
	l.set_term_text(text)
	return l


# --- Словарь -------------------------------------------------------------------------

func test_every_term_has_title_description_and_forms_in_both_languages() -> void:
	for locale in LOCALES:
		Settings.set_value(&"locale", locale)
		for id in Glossary.ALL:
			var g := TermTips.glossary
			var title := g.title(id)
			assert_ne(title, Glossary.name_key(id), "%s %s: название" % [locale, id])
			var desc := g.description(id)
			assert_false(desc.begins_with("TERM_") or desc.begins_with("CHEAT_"),
					"%s %s: описание" % [locale, id])
			assert_false(desc.contains("%d") or desc.contains("%s"), "%s %s: числа" % [locale, id])
			assert_gt(g.forms(id).size(), 0, "%s %s: словоформы" % [locale, id])
			assert_true(g.forms(id)[0] != Glossary.forms_key(id).to_lower(),
					"%s %s: словоформы переведены" % [locale, id])


func test_terms_are_recognised_in_game_texts() -> void:
	Settings.set_value(&"locale", "ru")
	var g := TermTips.glossary
	var cases := {
		"RULES_PALIFICO_TEXT": &"PALIFICO",
		"HINT_TRICKS_TEXT": &"SANITY",
		"RULES_MADNESS_TEXT": &"MADNESS",
		"RULES_EVIDENCE_TEXT": &"EVIDENCE",
		"TUT_ACCUSE": &"ACCUSE",
		"RULES_ONES_TEXT": &"PACO",
		"SETTINGS_CALZA": &"CALZA",
	}
	for locale in LOCALES:
		Settings.set_value(&"locale", locale)
		for key: String in cases:
			var ids := []
			for m in g.find_terms(tr(key)):
				ids.append(m.id)
			assert_has(ids, cases[key], "%s %s → %s" % [locale, key, cases[key]])


func test_tooltips_fit_on_screen_in_both_languages() -> void:
	for locale in LOCALES:
		Settings.set_value(&"locale", locale)
		for id in Glossary.ALL:
			var source := _label("x")
			TermTips.toggle_term(source, id, Rect2(4, 300, 10, 12))
			var p := TermTips.panel(0)
			assert_eq(int(p.size.x), TutorialLayout.TERM_TIP_WIDTH, "%s %s: ширина" % [locale, id])
			var r := p.get_global_rect()
			assert_true(Rect2(Vector2.ZERO, Vector2(TableLayout.SCREEN)).encloses(r),
					"%s %s в экране: %s" % [locale, id, r])
			assert_eq(p.title_text(), TermTips.glossary.title(id))
			assert_false(p.description().terms().has(id), "свой термин не подсвечен")
			TermTips.close_all()


# --- TermLabel -----------------------------------------------------------------------

func test_term_label_highlights_and_keeps_plain_text() -> void:
	Settings.set_value(&"locale", "ru")
	var l := _label("Ваш Рассудок: [9]. Безумие близко.")
	assert_eq(l.plain_text(), "Ваш Рассудок: [9]. Безумие близко.")
	assert_eq(l.terms(), [&"SANITY", &"MADNESS"] as Array[StringName])
	assert_true(l.text.contains("[url=SANITY]"))
	assert_true(l.meta_underlined, "термины подчёркнуты")


func test_term_label_retranslates() -> void:
	Settings.set_value(&"locale", "ru")
	var l := _label("SANITY")
	assert_eq(l.plain_text(), "Рассудок")
	Settings.set_value(&"locale", "en")
	await get_tree().process_frame
	assert_eq(l.plain_text(), "Sanity")
	assert_eq(l.terms(), [&"SANITY"] as Array[StringName])


# --- Стек подсказок ------------------------------------------------------------------

func _mouse(button: MouseButton, pressed: bool, pos := Vector2(630, 10)) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	return e


## ПКМ по термину term в l: курсор над термином, затем нажатие.
func _right_click(l: TermLabel, term: StringName) -> void:
	l.meta_hover_started.emit(term)
	l.gui_input.emit(_mouse(MOUSE_BUTTON_RIGHT, true))


func test_hover_and_left_click_do_not_open() -> void:
	var l := _label("Рассудок")
	l.meta_hover_started.emit(&"SANITY")
	assert_eq(TermTips.count(), 0, "наведение не открывает")
	l.meta_clicked.emit(&"SANITY")
	l.gui_input.emit(_mouse(MOUSE_BUTTON_LEFT, true))
	assert_eq(TermTips.count(), 0, "ЛКМ не открывает")


func test_right_click_opens_and_toggles() -> void:
	var l := _label("Рассудок и Безумие")
	_right_click(l, &"SANITY")
	assert_eq(TermTips.count(), 1)
	assert_eq(TermTips.term_at(0), &"SANITY")
	l.meta_hover_ended.emit(&"SANITY")
	TermTips._process(10.0)
	assert_eq(TermTips.count(), 1, "мышь ушла — подсказка остаётся")
	_right_click(l, &"MADNESS")
	assert_eq(TermTips.count(), 1)
	assert_eq(TermTips.term_at(0), &"MADNESS", "ПКМ по другому термину — сменить")
	_right_click(l, &"MADNESS")
	assert_eq(TermTips.count(), 0, "повторный ПКМ — закрыть")
	l.meta_hover_ended.emit(&"MADNESS")
	l.gui_input.emit(_mouse(MOUSE_BUTTON_RIGHT, true))
	assert_eq(TermTips.count(), 0, "ПКМ не по термину ничего не открывает")


func test_nested_tooltip_opens_next_to_parent() -> void:
	Settings.set_value(&"locale", "ru")
	var l := _label("Безумие")
	TermTips.toggle_term(l, &"MADNESS", FAR)
	var inner := TermTips.panel(0).description()
	assert_has(inner.terms(), &"SANITY", "в описании Безумия есть Рассудок")
	_right_click(inner, &"SANITY")
	assert_eq(TermTips.count(), 2, "вложенная подсказка")
	assert_eq(TermTips.term_at(1), &"SANITY")
	TermTips._input(_mouse(MOUSE_BUTTON_LEFT, true, TermTips.panel(0).get_global_rect().get_center()))
	TermTips._resolve_click()
	assert_eq(TermTips.count(), 1, "щелчок по родителю закрывает вложенную")


func test_click_outside_and_escape_close() -> void:
	var l := _label("Рассудок")
	TermTips.toggle_term(l, &"SANITY", FAR)
	TermTips._input(_mouse(MOUSE_BUTTON_LEFT, true))
	TermTips._resolve_click()
	assert_eq(TermTips.count(), 0, "ЛКМ мимо")

	TermTips.toggle_term(l, &"SANITY", FAR)
	TermTips._input(_mouse(MOUSE_BUTTON_RIGHT, true))
	TermTips._resolve_click()
	assert_eq(TermTips.count(), 0, "ПКМ мимо")

	TermTips.toggle_term(l, &"SANITY", FAR)
	TermTips._input(_mouse(MOUSE_BUTTON_LEFT, true, TermTips.panel(0).get_global_rect().get_center()))
	TermTips._resolve_click()
	assert_eq(TermTips.count(), 1, "щелчок по самой подсказке её не закрывает")

	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	TermTips._input(esc)
	assert_eq(TermTips.count(), 0, "Esc")


func test_touch_tap_opens_and_closes() -> void:
	TermTips.touch_mode = true
	var l := _label("Рассудок")
	l.meta_clicked.emit(&"SANITY")
	assert_eq(TermTips.term_at(0), &"SANITY", "тап по термину")
	TermTips._input(_mouse(MOUSE_BUTTON_LEFT, true))
	TermTips._resolve_click()
	assert_eq(TermTips.count(), 1, "на сенсорном экране закрывает отпускание, не касание")
	TermTips._input(_mouse(MOUSE_BUTTON_LEFT, false))
	TermTips._resolve_click()
	assert_eq(TermTips.count(), 0, "тап мимо")


func test_tooltip_closes_with_its_source() -> void:
	var l := _label("Рассудок")
	TermTips.toggle_term(l, &"SANITY", FAR)
	l.hide()
	TermTips._process(0.01)
	assert_eq(TermTips.count(), 0)


# --- Экраны --------------------------------------------------------------------------

func test_rules_screen_tells_how_to_open_tips() -> void:
	var rules: Control = add_child_autofree(RulesScene.instantiate())
	var found := false
	for c in rules.get_children():
		if c is Label and (c as Label).text == rules.term_hint_key():
			found = true
	assert_true(found, "подпись про ПКМ на экране правил")


func test_rules_text_has_terms() -> void:
	Settings.set_value(&"locale", "ru")
	var rules: Control = add_child_autofree(RulesScene.instantiate())
	for i in rules.page_count():
		rules.show_page(i)
		assert_gt(rules.page_label().terms().size(), 0, "термины на странице %d" % i)


func test_table_buttons_icons_and_log_have_terms() -> void:
	Settings.set_value(&"locale", "ru")
	Rng.set_master_seed(5)
	var setup := MatchSetup.from_settings()
	setup.opponent_count = 2
	MatchSetup.pending = setup
	var screen: Control = add_child_autofree(TableScene.instantiate())
	assert_eq(TermTips.attached_term(screen._liar_button), &"LIAR")
	assert_eq(TermTips.attached_term(screen._calza_button), &"CALZA")
	assert_eq(TermTips.attached_term(screen._accuse_button), &"ACCUSE")
	assert_eq(TermTips.attached_term(screen._tricks_button), &"TRICK")
	assert_eq(TermTips.attached_term(screen._palifico_label), &"PALIFICO")
	var seat: SeatView = screen._seats[1]
	assert_eq(TermTips.attached_term(seat._evidence_box), &"EVIDENCE")
	assert_eq(TermTips.attached_term(seat._madness_icon), &"MADNESS")
	screen._add_message(tr("TABLE_MSG_MADNESS_YOU"))
	var msg: TermLabel = screen._messages.get_child(0)
	assert_has(msg.terms(), &"MADNESS", "лог подсвечивает термины")

	# Наведение на кнопку ничего не открывает, ПКМ — подсказка; на сенсорном экране
	# тап по кнопке — только действие.
	screen._liar_button.mouse_entered.emit()
	assert_eq(TermTips.count(), 0)
	screen._liar_button.gui_input.emit(_mouse(MOUSE_BUTTON_RIGHT, true))
	assert_eq(TermTips.term_at(0), &"LIAR")
	TermTips.close_all()
	TermTips.touch_mode = true
	screen._liar_button.gui_input.emit(_mouse(MOUSE_BUTTON_LEFT, false))
	assert_eq(TermTips.count(), 0)


func test_trick_menu_buttons_have_trick_terms() -> void:
	Rng.set_master_seed(5)
	MatchSetup.pending = MatchSetup.from_settings()
	var screen: Control = add_child_autofree(TableScene.instantiate())
	var menu: TrickMenu = screen._trick_menu
	menu.open_for(screen._controller.view_for(0), screen._name, screen._trick_denial)
	var buttons := menu.buttons()
	for i in Cheat.ALL.size():
		assert_eq(TermTips.attached_term(buttons[i]), Glossary.trick_term(Cheat.ALL[i]))
	assert_false(menu.footer_text().is_empty())


func test_settings_captions_have_terms() -> void:
	var screen: Control = add_child_autofree(SettingsScene.instantiate())
	assert_eq(TermTips.attached_term(screen.palifico.caption_label()), &"PALIFICO")
	assert_eq(TermTips.attached_term(screen.calza.caption_label()), &"CALZA")
	var caption: Label = screen.palifico.caption_label()
	caption.gui_input.emit(_mouse(MOUSE_BUTTON_LEFT, false))
	assert_eq(TermTips.count(), 0, "ЛКМ по подписи на ПК — ничего")
	caption.gui_input.emit(_mouse(MOUSE_BUTTON_RIGHT, true))
	assert_eq(TermTips.term_at(0), &"PALIFICO", "ПКМ по подписи")
	TermTips.close_all()
	# Подпись — не кнопка: на сенсорном экране тап по ней открывает подсказку.
	TermTips.touch_mode = true
	caption.gui_input.emit(_mouse(MOUSE_BUTTON_LEFT, false))
	assert_eq(TermTips.term_at(0), &"PALIFICO")
