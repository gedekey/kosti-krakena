extends GutTest
## М12: шины и громкость из настроек, щелчки кнопок, звуки событий стола (секретное — только
## своё), музыка по состояниям: меню, таверна, слой Безумия, стинги.

const TableScene := preload("res://scenes/table.tscn")
const MenuScene := preload("res://scenes/main_menu.tscn")


func before_each() -> void:
	MatchSetup.pending = null
	Sound.clear_history()


func after_all() -> void:
	Settings.reset_keys([&"music_volume", &"sfx_volume"])
	Sound.set_madness_layer(false)


func _table(seed_value: int) -> Control:
	Rng.set_master_seed(seed_value)
	var setup := MatchSetup.from_settings()
	setup.opponents = []
	setup.opponent_count = 3
	MatchSetup.pending = setup
	var screen: Control = add_child_autofree(TableScene.instantiate())
	Sound.clear_history()
	return screen


func _heard(cue: StringName) -> bool:
	return Sound.history.has(cue)


func _roll(screen: Control) -> void:
	if screen._roll_button.visible:
		screen._roll_button.pressed.emit()


## Узел, который просит музыку при входе в дерево (как главное меню при запуске игры).
class MusicAtEnterTree:
	extends Node
	var sound: Node

	func _enter_tree() -> void:
		sound.play_music(SoundCatalog.MUSIC_MENU)


func test_music_can_start_before_sound_is_ready() -> void:
	# При запуске игры _enter_tree главной сцены идёт раньше _ready автозагрузок (баг М15:
	# в релизной сборке игра падала на старте).
	var root := Node.new()
	var sound: Node = load("res://autoload/sound.gd").new()
	var probe := MusicAtEnterTree.new()
	probe.sound = sound
	root.add_child(sound)
	root.add_child(probe)
	add_child_autofree(root)
	assert_eq(sound.current_track(), SoundCatalog.MUSIC_MENU)


func test_buses_exist_and_follow_settings() -> void:
	var music := AudioServer.get_bus_index(Settings.MUSIC_BUS)
	var sfx := AudioServer.get_bus_index(Settings.SFX_BUS)
	assert_gt(music, 0, "шина Music")
	assert_gt(sfx, 0, "шина SFX")
	Settings.set_value(&"music_volume", 0.5)
	assert_almost_eq(AudioServer.get_bus_volume_db(music), linear_to_db(0.5), 0.01)
	Settings.set_value(&"sfx_volume", 0.0)
	assert_true(AudioServer.is_bus_mute(sfx), "ноль — без звука")
	Settings.set_value(&"sfx_volume", 1.0)
	assert_false(AudioServer.is_bus_mute(sfx))
	assert_almost_eq(AudioServer.get_bus_volume_db(sfx), 0.0, 0.01)


func test_players_use_right_buses() -> void:
	for p: AudioStreamPlayer in Sound._voices:
		assert_eq(p.bus, Settings.SFX_BUS)
	for p: AudioStreamPlayer in Sound._music:
		assert_eq(p.bus, Settings.MUSIC_BUS)
	assert_eq(Sound._layer.bus, Settings.MUSIC_BUS)
	assert_eq(Sound._sting.bus, Settings.MUSIC_BUS)


func test_play_loads_stream_and_skips_rapid_repeats() -> void:
	Sound.play(SoundCatalog.DICE_ROLL)
	Sound.play(SoundCatalog.DICE_ROLL)
	assert_eq(Sound.history.count(SoundCatalog.DICE_ROLL), 1, "дубль в тот же миг не звучит")
	var used := Sound._voices.filter(func(p: AudioStreamPlayer) -> bool: return p.stream != null)
	assert_gt(used.size(), 0, "звук загружен в голос")
	var cues := SoundCatalog.cues()
	Sound.clear_history()
	for i in SoundBalance.SFX_VOICES + 3:   # больше звуков, чем голосов, — не падаем
		Sound.play(cues[i % cues.size()])
	assert_eq(Sound.history.size(), SoundBalance.SFX_VOICES + 3)


func test_buttons_click_unless_silent() -> void:
	var b := Button.new()
	add_child_autofree(b)
	b.pressed.emit()
	assert_true(_heard(SoundCatalog.UI_CLICK), "кнопка щёлкает")
	Sound.clear_history()
	b.set_meta(Sound.SILENT_META, true)
	b.pressed.emit()
	assert_false(_heard(SoundCatalog.UI_CLICK), "silent — без щелчка")
	# Переставили в дереве — всё равно один щелчок, не два.
	b.remove_meta(Sound.SILENT_META)
	remove_child(b)
	add_child(b)
	Sound.clear_history()
	b.pressed.emit()
	assert_eq(Sound.history.count(SoundCatalog.UI_CLICK), 1)


func test_menu_plays_menu_music_and_table_plays_tavern() -> void:
	add_child_autofree(MenuScene.instantiate())
	assert_eq(Sound.current_track(), SoundCatalog.MUSIC_MENU)
	assert_true(Sound._music[Sound._music_index].playing)
	_table(21)
	assert_eq(Sound.current_track(), SoundCatalog.MUSIC_TAVERN)
	var stream: AudioStream = Sound._music[Sound._music_index].stream
	assert_not_null(stream, "трек загрузился (авторский mp3 или своя заглушка)")
	if stream is AudioStreamWAV:
		assert_eq((stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, "музыка — петлёй")
	else:
		assert_true(stream.get(&"loop"), "музыка — петлёй")


func test_table_events_have_sounds() -> void:
	var screen := _table(22)
	_roll(screen)
	assert_true(_heard(SoundCatalog.DICE_SHAKE), "бросок — тряска")
	assert_false(_heard(SoundCatalog.UI_CLICK), "кнопка броска озвучена броском, не щелчком")
	await wait_seconds(screen._sound.slam_delay() + 0.1)
	assert_true(_heard(SoundCatalog.CUP_SLAM), "чашка бьёт о стол после тряски")

	var cases := [
		[func() -> void: Events.bid_placed.emit(1, Bid.new(2, 3)), SoundCatalog.BID],
		[func() -> void: Events.turn_started.emit(0), SoundCatalog.YOUR_TURN],
		[func() -> void: Events.dice_count_changed.emit(1, 3, -1), SoundCatalog.DIE_LOST],
		[func() -> void: Events.dice_count_changed.emit(1, 4, 1), SoundCatalog.DIE_GAINED],
		[func() -> void: Events.player_eliminated.emit(2), SoundCatalog.ELIMINATED],
		[func() -> void: Events.cheat_failed.emit(1, Cheat.Kind.PEEK), SoundCatalog.CHEAT_FAIL],
		[func() -> void: Events.evidence_shown.emit(1), SoundCatalog.EVIDENCE],
		[func() -> void: Events.accusation_made.emit(1, 2, false), SoundCatalog.ACCUSE],
		[func() -> void: Events.madness_began.emit(2), SoundCatalog.MADNESS_OTHER],
		[func() -> void: Events.round_started.emit(2, 1, true), SoundCatalog.PALIFICO],
		[func() -> void: Events.cup_changed.emit(0, true), SoundCatalog.CUP_LIFT],
		[func() -> void: Events.cup_changed.emit(0, false), SoundCatalog.CUP_CLOSE],
	]
	for c: Array in cases:
		Sound.clear_history()
		(c[0] as Callable).call()
		assert_true(_heard(c[1]), "звук %s" % c[1])
	Sound.clear_history()
	Events.turn_started.emit(1)
	Events.cup_changed.emit(2, true)
	assert_false(_heard(SoundCatalog.YOUR_TURN), "чужой ход — без колокольчика")
	assert_false(_heard(SoundCatalog.CUP_LIFT), "чужую чашку не слышно")


func test_challenge_is_heard_and_action_buttons_do_not_click() -> void:
	var screen := _table(23)
	var mc: MatchController = screen._controller
	_roll(screen)
	var steps := 0
	var clicked := false
	# Раунд может кончиться обвинением без вскрытия — тогда играем следующий.
	while _count_reveals() == 0 and steps < 500 and mc.phase != MatchController.Phase.MATCH_OVER:
		steps += 1
		if mc.is_waiting_for_human():
			var clicks := Sound.history.count(SoundCatalog.UI_CLICK)
			if not screen._liar_button.disabled:
				screen._liar_button.pressed.emit()
			else:
				screen._bid_button.pressed.emit()
			clicked = clicked or Sound.history.count(SoundCatalog.UI_CLICK) > clicks
		elif screen._result_panel.visible:
			screen._result_panel.press_continue()
		elif screen._roll_button.visible:
			screen._roll_button.pressed.emit()
		else:
			screen._on_timer()
	assert_gt(_count_reveals(), 0, "вскрытие озвучено")
	assert_false(clicked, "кнопки действий — без щелчка, звучит само действие")


func _count_reveals() -> int:
	return Sound.history.count(SoundCatalog.LIAR_CALL) \
			+ Sound.history.count(SoundCatalog.CALZA_CALL)


func test_own_tricks_are_heard_only_by_the_player() -> void:
	_table(24)
	Events.cheat_resolved.emit(
			CheatOutcome.new(1, CheatAction.new(Cheat.Kind.ABYSS_WHISPER, -1, -1, 3)))
	Events.cheat_resolved.emit(CheatOutcome.new(2, CheatAction.new(Cheat.Kind.SLEIGHT, -1, 0)))
	assert_eq(Sound.history.size(), 0, "чужой удачный трюк — тишина")
	Events.cheat_resolved.emit(
			CheatOutcome.new(0, CheatAction.new(Cheat.Kind.ABYSS_WHISPER, -1, -1, 3)))
	assert_true(_heard(SoundCatalog.WHISPER_ABYSS))
	Events.cheat_resolved.emit(CheatOutcome.new(0, CheatAction.new(Cheat.Kind.SLEIGHT, -1, 0)))
	assert_true(_heard(SoundCatalog.TRICK))
	assert_true(_heard(SoundCatalog.DICE_ROLL), "ловкость рук — кубик перекатился")


func test_madness_layer_follows_the_player() -> void:
	var screen := _table(25)
	_roll(screen)
	assert_false(Sound.is_madness_layer_on())
	screen._controller.debug_set_sanity(0, 0)
	assert_true(_heard(SoundCatalog.MADNESS_ONSET), "наступление Безумия")
	assert_true(Sound.is_madness_layer_on(), "слой Безумия поверх таверны")
	assert_eq(Sound.current_track(), SoundCatalog.MUSIC_TAVERN, "таверна продолжает играть")
	Events.player_eliminated.emit(0)
	assert_false(Sound.is_madness_layer_on(), "выбыл — слой снят")
	assert_true(_heard(SoundCatalog.STING_DEFEAT), "стинг поражения")
	assert_true(Sound.is_sting_playing())


func test_new_match_and_leaving_table_drop_madness_layer() -> void:
	var screen := _table(26)
	Sound.set_madness_layer(true)
	screen._on_rematch()
	assert_false(Sound.is_madness_layer_on(), "реванш — без слоя")
	Sound.set_madness_layer(true)
	remove_child(screen)
	assert_false(Sound.is_madness_layer_on(), "ушли со стола — без слоя")
	add_child(screen)


func test_victory_sting_only_for_player() -> void:
	_table(27)
	Events.match_ended.emit(2)
	assert_false(_heard(SoundCatalog.STING_VICTORY))
	assert_false(_heard(SoundCatalog.STING_DEFEAT), "поражение звучит при выбывании, не дважды")
	Events.match_ended.emit(0)
	assert_true(_heard(SoundCatalog.STING_VICTORY))
