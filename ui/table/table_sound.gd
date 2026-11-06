class_name TableSound
extends Node
## Звуки стола (М12): подписывается на Events и говорит Sound, что играть. Правил нет.
##
## Секретное (успешные трюки, своя чашка) звучит только для своего игрока — иначе звук
## выдал бы чужой трюк. Удар чашки — в такт анимации TableFx (та же скорость).
## Музыка: таверна; слой Безумия, пока игрок безумен и в игре; стинги победы / поражения.

const HUMAN_ID := 0

var _speed: Callable


## speed() → множитель темпа (как у TableFx).
func setup(speed: Callable) -> void:
	_speed = speed


func _ready() -> void:
	Sound.play_music(SoundCatalog.MUSIC_TAVERN)
	Events.match_started.connect(_on_match_started)
	Events.round_started.connect(_on_round_started)
	Events.dice_rolled.connect(_on_dice_rolled)
	Events.turn_started.connect(_on_turn_started)
	Events.bid_placed.connect(_on_bid_placed)
	Events.challenge_revealed.connect(_on_challenge_revealed)
	Events.dice_count_changed.connect(_on_dice_count_changed)
	Events.player_eliminated.connect(_on_player_eliminated)
	Events.match_ended.connect(_on_match_ended)
	Events.cheat_resolved.connect(_on_cheat_resolved)
	Events.cheat_failed.connect(_on_cheat_failed)
	Events.evidence_shown.connect(_on_evidence_shown)
	Events.madness_began.connect(_on_madness_began)
	Events.accusation_made.connect(_on_accusation_made)
	Events.cup_changed.connect(_on_cup_changed)


func _exit_tree() -> void:
	Sound.set_madness_layer(false)


## Через сколько секунд после броска чашка бьёт о стол (конец тряски TableFx).
func slam_delay() -> float:
	return (TableFx.RATTLE_TIME + TableFx.RATTLE_STEP + TableFx.SLAM_TIME) / _cur_speed()


func _cur_speed() -> float:
	return maxf(_speed.call(), 0.01) if _speed.is_valid() else 1.0


# --- События -------------------------------------------------------------------------

func _on_match_started(_count: int, _first: int) -> void:
	Sound.set_madness_layer(false)
	Sound.play_music(SoundCatalog.MUSIC_TAVERN)


func _on_round_started(_round: int, _starter: int, is_palifico: bool) -> void:
	if is_palifico:
		Sound.play(SoundCatalog.PALIFICO)


func _on_dice_rolled(_round: int) -> void:
	Sound.play(SoundCatalog.DICE_SHAKE)
	Sound.play_later(SoundCatalog.CUP_SLAM, slam_delay())


func _on_turn_started(player_id: int) -> void:
	if player_id == HUMAN_ID:
		Sound.play(SoundCatalog.YOUR_TURN)


func _on_bid_placed(_player_id: int, _bid: Bid) -> void:
	Sound.play(SoundCatalog.BID)


func _on_challenge_revealed(reveal: ChallengeReveal) -> void:
	Sound.play(SoundCatalog.LIAR_CALL if reveal.kind == MatchAction.Kind.DUDO
			else SoundCatalog.CALZA_CALL)
	Sound.play_later(SoundCatalog.CUP_LIFT, TableFx.HOP_TIME / _cur_speed())


func _on_dice_count_changed(_player_id: int, _count: int, delta: int) -> void:
	if delta < 0:
		Sound.play(SoundCatalog.DIE_LOST)
	elif delta > 0:
		Sound.play(SoundCatalog.DIE_GAINED)


func _on_player_eliminated(player_id: int) -> void:
	if player_id == HUMAN_ID:
		Sound.set_madness_layer(false)
		Sound.play_sting(SoundCatalog.STING_DEFEAT)
	else:
		Sound.play(SoundCatalog.ELIMINATED)


## Поражение уже прозвучало при выбывании игрока — здесь только победа.
func _on_match_ended(winner_id: int) -> void:
	if winner_id == HUMAN_ID:
		Sound.set_madness_layer(false)
		Sound.play_sting(SoundCatalog.STING_VICTORY)


## СЕКРЕТНО: свой удачный трюк.
func _on_cheat_resolved(outcome: CheatOutcome) -> void:
	if outcome.player_id != HUMAN_ID:
		return
	match outcome.action.kind:
		Cheat.Kind.ABYSS_WHISPER:
			Sound.play(SoundCatalog.WHISPER_ABYSS)
		Cheat.Kind.SLEIGHT, Cheat.Kind.LOADED_DIE:
			Sound.play(SoundCatalog.TRICK)
			Sound.play(SoundCatalog.DICE_ROLL, -6.0)
		_:
			Sound.play(SoundCatalog.TRICK)


func _on_cheat_failed(_player_id: int, _kind: int) -> void:
	Sound.play(SoundCatalog.CHEAT_FAIL)


func _on_evidence_shown(_player_id: int) -> void:
	Sound.play(SoundCatalog.EVIDENCE)


func _on_madness_began(player_id: int) -> void:
	if player_id == HUMAN_ID:
		Sound.play(SoundCatalog.MADNESS_ONSET)
		Sound.set_madness_layer(true)
	else:
		Sound.play(SoundCatalog.MADNESS_OTHER)


func _on_accusation_made(_accuser_id: int, _target_id: int, guilty: bool) -> void:
	Sound.play(SoundCatalog.ACCUSE)
	if guilty:
		Sound.play_later(SoundCatalog.CHEAT_FAIL, TableFx.HOP_TIME / _cur_speed())


## Слышна только своя чашка: чужую в Безумии открывают молча (что бот смотрит — его дело).
func _on_cup_changed(player_id: int, is_open: bool) -> void:
	if player_id == HUMAN_ID:
		Sound.play(SoundCatalog.CUP_LIFT if is_open else SoundCatalog.CUP_CLOSE)
