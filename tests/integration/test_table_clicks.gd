extends GutTest
## М22: клики по столу. Предметы стоят в «мёртвых» зонах, отвечают с паузой; клик по пустому
## столу — всплеск (в Безумии — тушь); кнопки, чашка и портреты работают как раньше.

const Scene := preload("res://scenes/table.tscn")
const Phase := MatchController.Phase


var _gut_layer: CanvasLayer


func before_each() -> void:
	MatchSetup.pending = null
	TouchUI.forced = null
	for flag in HintPanel.TOPICS:
		Stats.set_flag(flag)


func after_each() -> void:
	if _gut_layer != null:
		_gut_layer.show()
		_gut_layer = null
	TouchUI.forced = null
	Stats.clear_flags()


func _rng(seed_value := 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _table(seed_value := 3, setup: MatchSetup = null) -> Control:
	Rng.set_master_seed(seed_value)
	MatchSetup.pending = setup if setup != null else MatchSetup.from_settings()
	return add_child_autofree(Scene.instantiate())


## Настоящий клик мышью (нажатие и отпускание) в экранной точке.
func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		get_viewport().push_input(e, true)
	await get_tree().process_frame


## Окно GUT лежит поверх сцены и забирает мышь — на время теста с кликами прячем его.
func _hide_gut_ui() -> void:
	var layer := get_tree().root.get_node_or_null("GutRunner/GutLayer") as CanvasLayer
	if layer != null and layer.visible:
		layer.hide()
		_gut_layer = layer


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


# --- Набор предметов и раскладка ----------------------------------------------------------

func test_default_set_has_four_known_props() -> void:
	var s := TablePropSet.default_set()
	var kinds: Array[StringName] = []
	for slot in s.props:
		assert_true(PropArt.has_kind(slot.kind), "известный предмет %s" % slot.kind)
		kinds.append(slot.kind)
	assert_eq(kinds, [PropArt.CANDLE, PropArt.MUG, PropArt.SKULL, PropArt.CRACK]
			as Array[StringName])


func test_every_prop_has_two_or_three_reactions() -> void:
	for kind in PropArt.kinds():
		var n := PropArt.reactions(kind).size()
		assert_between(n, 2, 3, "%s: реакций" % kind)
		for r in PropArt.reactions(kind):
			assert_true(PropArt.CUES.has(r), "%s: есть звук" % r)
			assert_true(SfxSynth.CUES.has(PropArt.CUES[r]), "%s: звук в синтезаторе" % r)


func _layout_ok(touch: bool) -> void:
	TouchUI.forced = touch
	var rects: Array[Rect2i] = []
	for slot in TablePropSet.default_set().props:
		var p := TableProp.make(slot, _rng())
		rects.append(p.hit_rect())
		p.free()
	var forbidden: Array[Rect2i] = TableLayout.CLICK_BLOCKED.duplicate()
	forbidden.append(TableLayout.OWN_PANEL_RECT)
	forbidden.append(TableLayout.STATUS_RECT.grow_individual(-60, 0, -60, 0))  # подписи и «Трясти»
	for count in range(1, MatchController.MAX_PLAYERS):
		for pos in TableLayout.seat_positions(count):
			forbidden.append(Rect2i(pos, TableLayout.SEAT_SIZE))
	for i in rects.size():
		assert_true(Rect2i(Vector2i.ZERO, TableLayout.SCREEN).encloses(rects[i]), "в экране")
		for f in forbidden:
			assert_false(rects[i].intersects(f), "предмет %d не заходит на %s" % [i, f])
		for j in range(i + 1, rects.size()):
			assert_false(rects[i].intersects(rects[j]), "предметы %d и %d не перекрываются" % [i, j])


func test_props_stand_in_dead_zones() -> void:
	_layout_ok(false)


func test_props_stand_in_dead_zones_on_android() -> void:
	_layout_ok(true)
	var p := TableProp.make(TablePropSet.default_set().props[0], _rng())
	assert_true(p.size.x >= TableClickBalance.PROP_TOUCH_HIT.x and p.size.y >= TableClickBalance.PROP_TOUCH_HIT.y, "зона тапа увеличена")
	p.free()


# --- Предмет: реакция и пауза ---------------------------------------------------------------

func test_prop_reacts_then_ignores_clicks_until_cooldown() -> void:
	var p: TableProp = add_child_autofree(TableProp.make(TablePropSlot.make(PropArt.SKULL,
			Vector2i(100, 100)), _rng()))
	p.set_process(false)
	watch_signals(p)
	assert_true(p.poke(), "первый клик — реакция")
	var first := p.reaction
	assert_true(PropArt.reactions(PropArt.SKULL).has(first))
	assert_false(p.poke(), "пока идёт реакция — молчит")
	var length := PropArt.frame_count(PropArt.SKULL, first) / TableClickBalance.PROP_FPS
	p.advance(length + 0.01)
	assert_false(p.is_reacting(), "реакция кончилась")
	assert_false(p.poke(), "пауза после реакции")
	p.advance(TableClickBalance.PROP_COOLDOWN + 0.01)
	assert_true(p.poke(), "после паузы — снова")
	assert_ne(p.reaction, first, "подряд не та же реакция")
	assert_signal_emit_count(p, "reacted", 2)


# --- Всплеск --------------------------------------------------------------------------------

func _clicks(mad := false) -> TableClicks:
	var c: TableClicks = add_child_autofree(TableClicks.new())
	c.setup(func() -> bool: return mad, _rng())
	c.set_process(false)
	return c


func test_splash_only_on_empty_table() -> void:
	var c := _clicks()
	c.set_blocked_rects([Rect2i(250, 0, 124, 106)])
	assert_not_null(c.splash_at(Vector2(200, 60)), "пустая стена / стол")
	c._since_splash = INF
	assert_null(c.splash_at(Vector2(300, 50)), "место соперника")
	assert_null(c.splash_at(Vector2(60, 150)), "лента ставок")
	assert_null(c.splash_at(Vector2(300, 140)), "текущая ставка")
	assert_null(c.splash_at(Vector2(300, 300)), "своя зона")
	assert_eq(c.splash_count(), 1)


func test_splash_rate_and_limit() -> void:
	var c := _clicks()
	assert_not_null(c.splash_at(Vector2(200, 200)))
	assert_null(c.splash_at(Vector2(205, 200)), "слишком часто")
	for i in TableClickBalance.SPLASH_MAX + 2:
		c._since_splash = INF
		c.splash_at(Vector2(180 + i, 200))
	assert_eq(c.splash_count(), TableClickBalance.SPLASH_MAX, "не больше SPLASH_MAX")


func test_splash_finishes_and_frees_itself() -> void:
	var s: TableSplash = TableSplash.make(Vector2i(10, 10), false, _rng())
	add_child(s)
	s.set_process(false)
	s.advance(TableClickBalance.SPLASH_FRAMES / TableClickBalance.SPLASH_FPS + 0.01)
	assert_true(s.is_queued_for_deletion())


func test_madness_splash_is_ink() -> void:
	Sound.clear_history()
	var c := _clicks(true)
	var s := c.splash_at(Vector2(200, 200))
	assert_true(s.mad, "в Безумии — тушь и щупальца")
	assert_eq(s.frames(), TableClickBalance.MAD_SPLASH_FRAMES)
	var normal := _clicks(false).splash_at(Vector2(200, 200))
	assert_false(normal.mad)


# --- За столом: клики не мешают игре ----------------------------------------------------------

func test_buttons_and_cup_still_work_with_real_clicks() -> void:
	_hide_gut_ui()
	var screen := _table()
	await get_tree().process_frame
	var clicks: TableClicks = screen._clicks
	assert_eq(clicks.props().size(), 4, "предметы на столе")
	assert_true(screen._roll_button.visible)
	await _click(_center(screen._roll_button))
	assert_eq(screen._session.phase, Phase.BIDDING, "«Трясти чашки» нажалась")
	assert_eq(clicks.splash_count(), 0, "клик по кнопке — без всплеска")

	var cup: TextureButton = screen._own._cup_button
	var was_open: bool = screen._session.view_for(0).cup_open
	await _click(_center(cup))
	assert_ne(screen._session.view_for(0).cup_open, was_open, "чашка открылась / закрылась")
	assert_eq(clicks.splash_count(), 0, "клик по чашке — без всплеска")

	await _click(_center(screen._seats[1]))
	assert_eq(clicks.splash_count(), 0, "клик по портрету — без всплеска")

	await _click(Vector2(210, 200))
	assert_eq(clicks.splash_count(), 1, "клик по пустому столу — всплеск")

	var skull := clicks.prop(PropArt.SKULL)
	clicks._since_splash = INF
	await _click(_center(skull))
	assert_true(skull.is_reacting(), "череп откликнулся")
	assert_eq(clicks.splash_count(), 1, "клик по предмету — не всплеск")


func test_props_do_not_cover_roll_button() -> void:
	var screen := _table()
	await get_tree().process_frame
	var roll := Rect2i(screen._roll_button.get_global_rect())
	for p in screen._clicks.props():
		assert_false(p.hit_rect().intersects(roll), "%s не на кнопке" % p.kind)


func test_campaign_can_set_own_props() -> void:
	var setup := MatchSetup.from_settings()
	setup.table_props = TablePropSet.new()
	setup.table_props.props.append(TablePropSlot.make(PropArt.CANDLE, Vector2i(166, 235)))
	var screen := _table(3, setup)
	assert_eq(screen._clicks.props().size(), 1)
	assert_eq(screen._clicks.props()[0].kind, PropArt.CANDLE)
