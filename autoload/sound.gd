extends Node
## Звук (М12): SFX на шине SFX, музыка на шине Music (громкость шин — Settings).
##
## Что и когда играть, решают подписчики событий (TableSound, экраны меню); здесь —
## только воспроизведение: пул голосов SFX, музыка с плавной сменой, слой Безумия поверх
## музыки и стинги победы / поражения (музыка на это время приглушается).
## Щелчок кнопки — сам, для любой BaseButton в дереве (кроме помеченных meta "silent").

const SILENT_META := &"silent"
const HOOKED_META := &"sound_hooked"

## Последние сыгранные звуки (для тестов и отладки), старые — в начале.
var history: Array[StringName] = []

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_played := {}           # звук → время (мс)
var _streams := {}               # путь → AudioStream (или null, если не загрузился)

var _music: Array[AudioStreamPlayer] = []
var _music_index := 0
var _track := &""
var _music_tween: Tween
var _layer: AudioStreamPlayer
var _layer_on := false
var _layer_tween: Tween
var _sting: AudioStreamPlayer
var _duck_tween: Tween
var _music_db := SoundBalance.MUSIC_DB


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SoundBalance.SFX_VOICES:
		_voices.append(_player(Settings.SFX_BUS))
	for i in 2:
		_music.append(_player(Settings.MUSIC_BUS))
	_layer = _player(Settings.MUSIC_BUS)
	_sting = _player(Settings.MUSIC_BUS)
	_sting.finished.connect(_unduck)
	get_tree().node_added.connect(_on_node_added)


# --- SFX ------------------------------------------------------------------------------

## Сыграть звук. Тот же звук чаще SoundBalance.MIN_REPEAT_SEC не повторяется.
func play(cue: StringName, volume_db := 0.0) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(cue, -100000)) < SoundBalance.MIN_REPEAT_SEC * 1000.0:
		return
	_last_played[cue] = now
	history.append(cue)
	if history.size() > SoundBalance.HISTORY_SIZE:
		history.remove_at(0)
	var stream := _load(SoundCatalog.sfx_path(cue))
	if stream == null:
		return
	var p := _free_voice()
	p.stream = stream
	p.volume_db = SoundCatalog.cue_db(cue) + volume_db
	p.pitch_scale = 1.0 + randf_range(-SoundBalance.PITCH_JITTER, SoundBalance.PITCH_JITTER)
	p.play()


## Сыграть звук через delay секунд (синхронно с анимацией).
func play_later(cue: StringName, delay: float, volume_db := 0.0) -> void:
	if delay <= 0.0:
		play(cue, volume_db)
		return
	get_tree().create_timer(delay).timeout.connect(play.bind(cue, volume_db))


func clear_history() -> void:
	history.clear()
	_last_played.clear()


# --- Музыка ---------------------------------------------------------------------------

## Плавно сменить музыку. Тот же трек не перезапускается.
func play_music(track: StringName) -> void:
	if track == _track:
		return
	_track = track
	var old := _music[_music_index]
	_music_index = 1 - _music_index
	var cur := _music[_music_index]
	var stream := _load(SoundCatalog.music_path(track), true)
	_kill(_music_tween)
	_music_tween = create_tween().set_parallel(true)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", SoundBalance.SILENT_DB,
				SoundBalance.MUSIC_FADE)
		_music_tween.chain().tween_callback(old.stop)
	cur.stop()
	if stream == null:
		return
	cur.stream = stream
	cur.volume_db = SoundBalance.SILENT_DB
	cur.play()
	_music_tween.tween_property(cur, "volume_db", _music_db, SoundBalance.MUSIC_FADE)


func stop_music() -> void:
	_track = &""
	_kill(_music_tween)
	_music_tween = create_tween().set_parallel(true)
	for p in _music:
		if p.playing:
			_music_tween.tween_property(p, "volume_db", SoundBalance.SILENT_DB,
					SoundBalance.MUSIC_FADE)
	_music_tween.chain().tween_callback(func() -> void:
		for p in _music:
			p.stop())
	set_madness_layer(false)


func current_track() -> StringName:
	return _track


## Слой Безумия поверх музыки (вкл. / выкл. плавно).
func set_madness_layer(on: bool) -> void:
	if on == _layer_on:
		return
	_layer_on = on
	_kill(_layer_tween)
	_layer_tween = create_tween()
	if on:
		var stream := _load(SoundCatalog.music_path(SoundCatalog.MUSIC_MADNESS), true)
		if stream == null:
			return
		if not _layer.playing:
			_layer.stream = stream
			_layer.volume_db = SoundBalance.SILENT_DB
			_layer.play()
		_layer_tween.tween_property(_layer, "volume_db", SoundBalance.LAYER_DB,
				SoundBalance.LAYER_FADE)
	elif _layer.playing:
		_layer_tween.tween_property(_layer, "volume_db", SoundBalance.SILENT_DB,
				SoundBalance.LAYER_FADE * 0.5)
		_layer_tween.tween_callback(_layer.stop)


func is_madness_layer_on() -> bool:
	return _layer_on


## Короткий стинг (победа / поражение). Музыка на это время приглушается.
func play_sting(track: StringName) -> void:
	history.append(track)
	var stream := _load(SoundCatalog.music_path(track))
	if stream == null:
		return
	_sting.stream = stream
	_sting.volume_db = SoundBalance.STING_DB
	_sting.play()
	_duck(SoundBalance.MUSIC_DB + SoundBalance.DUCK_DB)


func is_sting_playing() -> bool:
	return _sting.playing


func _unduck() -> void:
	_duck(SoundBalance.MUSIC_DB)


func _duck(db: float) -> void:
	_music_db = db
	_kill(_duck_tween)
	var cur := _music[_music_index]
	if not cur.playing:
		return
	_kill(_music_tween)
	_duck_tween = create_tween()
	_duck_tween.tween_property(cur, "volume_db", db, SoundBalance.DUCK_FADE)


# --- Внутреннее -----------------------------------------------------------------------

func _player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _free_voice() -> AudioStreamPlayer:
	for p in _voices:
		if not p.playing:
			return p
	# Все заняты — забираем по кругу (самый давний).
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	return p


func _load(path: String, looped := false) -> AudioStream:
	if not _streams.has(path):
		var stream: AudioStream = null
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
		if stream == null:
			push_warning("Нет звука: %s" % path)
		_streams[path] = stream
	var s: AudioStream = _streams[path]
	if looped and s != null:
		_make_looped(s)
	return s


## Петля для любого формата: свой WAV и сгенерированные автором OGG / MP3 / WAV.
static func _make_looped(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
	elif &"loop" in stream:
		stream.set(&"loop", true)


static func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _on_node_added(node: Node) -> void:
	# Узел могут переставить в дереве — подключаемся один раз.
	if node is BaseButton and not node.has_meta(HOOKED_META):
		node.set_meta(HOOKED_META, true)
		node.pressed.connect(_on_button_pressed.bind(node))


func _on_button_pressed(button: BaseButton) -> void:
	if is_instance_valid(button) and not button.get_meta(SILENT_META, false):
		play(SoundCatalog.UI_CLICK)
