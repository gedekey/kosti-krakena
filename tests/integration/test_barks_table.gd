extends GutTest
## М24: облака реплик на столе — место у каждого портрета на столах 2–6, печать по буквам,
## автоисчезновение, клики насквозь, настройка «Реплики соперников», обучение и сеть.

const Scene := preload("res://scenes/table.tscn")
const SettingsScene := preload("res://scenes/settings.tscn")
const Occ := BarkBalance.Occasion


func before_each() -> void:
	MatchSetup.pending = null
	for flag in HintPanel.TOPICS:
		Stats.set_flag(flag)


func after_each() -> void:
	Stats.clear_flags()
	Settings.reset_keys([&"barks"])
	MatchSetup.pending = null


func _table(count := 3, tutorial := false) -> Control:
	Rng.set_master_seed(5)
	var setup := MatchSetup.for_tutorial() if tutorial else MatchSetup.from_settings()
	setup.opponent_count = count
	MatchSetup.pending = setup
	return add_child_autofree(Scene.instantiate())


func _bark(speaker: int, character: StringName, key: String) -> BarkDirector.Bark:
	var b := BarkDirector.Bark.new()
	b.speaker_id = speaker
	b.character = character
	b.occasion = Occ.LIAR
	b.key = key
	b.text = tr(key)
	b.duration = BarkBalance.duration_for(b.text.length())
	return b


func test_cloud_points_at_every_portrait_on_tables_of_two_to_six() -> void:
	for count in range(1, 6):
		var screen := _table(count)
		var cloud: BarkCloud = screen.bark_cloud()
		for id in range(1, count + 1):
			var seat: SeatView = screen._seats[id]
			var key := "BARK_HORROR_MASTER_WIN_1"      # самая длинная реплика
			cloud.show_bark(_bark(id, &"horror_master", key), seat)
			var body := cloud.body_rect()
			var screen_rect := Rect2i(Vector2i.ZERO, TableLayout.SCREEN)
			assert_true(screen_rect.encloses(body), "облако на экране: %d/%d %s" % [id, count, body])
			assert_true(body.position.y >= TableLayout.SEAT_TOP + TableLayout.SEAT_SIZE.y,
					"под местами соперников")
			assert_lt(body.end.y, TableLayout.OWN_PANEL_RECT.position.y, "не залезает на свою зону")
			var tip := cloud.tail_tip()
			var portrait_x := int(seat.global_position.x)
			assert_between(tip.x, portrait_x, portrait_x + TableLayout.FRAME_SIZE.x,
					"хвостик под портретом говорящего")
			assert_eq(cloud.position, cloud.position.round(), "целые пиксели")
			var label: Label = cloud.get_child(0)
			assert_gt(label.get_line_count(), 1, "длинная реплика переносится")
			assert_true(Rect2(body).encloses(Rect2(Vector2(cloud.position) + label.position,
					label.size)), "текст внутри облака")
		screen.free()


func test_types_letter_by_letter_and_disappears() -> void:
	var screen := _table()
	var cloud: BarkCloud = screen.bark_cloud()
	var b := _bark(1, &"sailor", "BARK_SAILOR_LIAR_1")
	cloud.show_bark(b, screen._seats[1])
	assert_true(cloud.is_showing())
	assert_false(cloud.is_typed())
	cloud.advance(0.1)
	assert_false(cloud.is_typed(), "печатается по буквам")
	cloud.advance(b.text.length() / BarkBalance.TYPE_SPEED)
	assert_true(cloud.is_typed())
	assert_eq(cloud.text(), b.text)
	cloud.advance(b.duration)
	assert_false(cloud.is_showing(), "исчезает само")


func test_clicks_pass_through_cloud() -> void:
	var screen := _table()
	var cloud: BarkCloud = screen.bark_cloud()
	cloud.show_bark(_bark(1, &"sailor", "BARK_SAILOR_LIAR_1"), screen._seats[1])
	var nodes: Array[Node] = [cloud]
	nodes.append_array(cloud.find_children("*", "Control", true, false))
	for n in nodes:
		assert_eq((n as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, n.name)
	# Под облаком ничего не перехватывается: кнопки стола по-прежнему жмутся.
	assert_eq(get_viewport().gui_get_hovered_control() == cloud, false)


func test_bots_speak_during_match_and_human_never() -> void:
	var screen := _table(5)
	var d: BarkDirector = screen.bark_director()
	assert_eq(d.speaker(0), &"", "игрок не говорит")
	for id in range(1, 6):
		assert_eq(d.speaker(id), screen._setup.opponents[id - 1])
	assert_true(d.enabled)
	var said := []
	d.bark.connect(func(b: BarkDirector.Bark) -> void: said.append(b))
	for occ in d.chances:
		d.chances[occ] = 1.0
	d.on_match_started(6, 0)
	assert_eq(said.size(), 1, "начало матча — реплика")
	assert_true(screen.bark_cloud().is_showing(), "облако на столе")
	assert_eq(screen.bark_cloud().speaker_id(), said[0].speaker_id)
	assert_ne(said[0].speaker_id, 0)


func test_setting_turns_barks_off() -> void:
	var screen := _table()
	var d: BarkDirector = screen.bark_director()
	screen.bark_cloud().show_bark(_bark(1, &"sailor", "BARK_SAILOR_LIAR_1"), screen._seats[1])
	Settings.set_value(&"barks", false)
	assert_false(d.enabled)
	assert_false(screen.bark_cloud().is_showing(), "выключили — облако убрано")
	Settings.set_value(&"barks", true)
	assert_true(d.enabled)


func test_settings_screen_has_barks_switch() -> void:
	var s: Control = add_child_autofree(SettingsScene.instantiate())
	assert_true(Settings.get_value(&"barks"), "по умолчанию вкл")
	s.barks.stepped.emit(1)
	assert_false(Settings.get_value(&"barks"))
	s.defaults_button.pressed.emit()
	assert_true(Settings.get_value(&"barks"))


func test_tutorial_is_silent() -> void:
	var screen := _table(1, true)
	assert_false(screen.bark_director().enabled)


func test_only_bots_speak_at_network_table() -> void:
	var clock := [1000]
	var now := func() -> int: return clock[0]
	var hub := LoopbackTransport.make_host()
	var host := HostSession.new(hub, "Хозяин", 1, now, "test/1")
	var client := ClientSession.new(hub.connect_guest(), "Анна", 2, now, "test/1")
	for i in 3:
		host.update()
		client.update()
	var plan: Array[SeatInfo] = [SeatInfo.host("", 0),
			SeatInfo.guest(client._transport.peer_id, "", 0), SeatInfo.bot(&"craber")]
	assert_true(host.begin_match(plan, RuleOptions.new(), Rng.make_seeded(3), false))
	host.update()
	client.update()
	MatchSetup.pending = MatchSetup.for_session(client)
	var screen: Control = add_child_autofree(Scene.instantiate())
	var d: BarkDirector = screen.bark_director()
	# У гостя он сам — место 0, хост — 2, бот-Крабер — 1 (места повёрнуты к себе).
	var talkers := []
	for id in 3:
		if d.speaker(id) != &"":
			talkers.append(d.speaker(id))
	assert_eq(talkers, [&"craber"], "говорят только боты")
	host.leave()
