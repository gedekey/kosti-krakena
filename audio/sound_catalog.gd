class_name SoundCatalog
extends RefCounted
## Где лежит каждый звук и трек (М12).
##
## Сначала ищем сгенерированный автором файл (assets/generated/sfx|music/<имя>.ogg|.wav|.mp3,
## имена — из ART_PROMPTS.md), иначе берём свою заглушку из audio/sfx|music/<имя>.wav
## (собирается tools/build_sfx.gd).

const SFX_DIR := "res://audio/sfx"
const MUSIC_DIR := "res://audio/music"
const GENERATED_SFX_DIR := "res://assets/generated/sfx"
const GENERATED_MUSIC_DIR := "res://assets/generated/music"
const GENERATED_EXTS: PackedStringArray = ["ogg", "wav", "mp3"]

# --- Звуки ---
const UI_CLICK := &"ui_click"
const DICE_SHAKE := &"dice_shake"
const DICE_ROLL := &"dice_roll"
const CUP_SLAM := &"cup_slam"
const CUP_LIFT := &"cup_lift"
const CUP_CLOSE := &"cup_close"
const BID := &"bid"
const YOUR_TURN := &"your_turn"
const LIAR_CALL := &"liar_call"
const CALZA_CALL := &"calza_call"
const DIE_LOST := &"die_lost"
const DIE_GAINED := &"die_gained"
const ELIMINATED := &"eliminated"
const TRICK := &"trick"
const WHISPER_ABYSS := &"whisper_abyss"
const CHEAT_FAIL := &"cheat_fail"
const EVIDENCE := &"evidence"
const ACCUSE := &"accuse"
const MADNESS_ONSET := &"madness_onset"
const MADNESS_OTHER := &"madness_other"
const PALIFICO := &"palifico"
# М22: клики по столу.
const TABLE_KNOCK := &"table_knock"
const INK_SPLAT := &"ink_splat"
const CANDLE_BLOW := &"candle_blow"
const CANDLE_FLARE := &"candle_flare"
const MUG_SLOSH := &"mug_slosh"
const SKULL_CLACK := &"skull_clack"
const TENTACLE := &"tentacle"

# --- Музыка ---
const MUSIC_MENU := &"main_menu"
const MUSIC_TAVERN := &"tavern_ambient"
const MUSIC_MADNESS := &"madness_layer"
const STING_VICTORY := &"victory"
const STING_DEFEAT := &"defeat"
const TRACKS: Array[StringName] = [MUSIC_MENU, MUSIC_TAVERN, MUSIC_MADNESS, STING_VICTORY,
		STING_DEFEAT]


static func cues() -> Array[StringName]:
	return SfxSynth.CUES


## exists(path) → bool; по умолчанию — ResourceLoader.exists (подменяется в тестах).
static func sfx_path(cue: StringName, exists := Callable()) -> String:
	return _resolve(cue, GENERATED_SFX_DIR, SFX_DIR, exists)


static func music_path(track: StringName, exists := Callable()) -> String:
	return _resolve(track, GENERATED_MUSIC_DIR, MUSIC_DIR, exists)


static func is_looped(track: StringName) -> bool:
	return MusicSynth.is_looped(track)


static func cue_db(cue: StringName) -> float:
	return SoundBalance.CUE_DB.get(cue, 0.0)


static func _resolve(name: StringName, generated_dir: String, own_dir: String,
		exists: Callable) -> String:
	for ext in GENERATED_EXTS:
		var path := generated_dir.path_join("%s.%s" % [name, ext])
		if exists.call(path) if exists.is_valid() else ResourceLoader.exists(path):
			return path
	return own_dir.path_join("%s.wav" % name)
