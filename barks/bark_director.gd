class_name BarkDirector
extends RefCounted
## Кто из соперников что скажет (М24, DESIGN.md §8д). Без нод: RNG, часы и перевод — внедряются.
##
## Слушает события матча (те же сигналы, что в Events, шина передаётся параметром) и решает:
## будет ли реплика (шанс повода), кто её скажет (бот, не на паузе), какой текст (вариант,
## не повторяя прошлый). На экране одно облако за раз: пока оно висит и ещё GAP_AFTER_BUBBLE
## после, новые реплики молчат — кроме более важной в первые REPLACE_WINDOW секунд облака
## (выбыл → и сразу победил). Правил игры здесь нет: только поводы из событий.

## Решено: показать облако.
signal bark(b: Bark)

## Одна реплика.
class Bark:
	extends RefCounted
	var speaker_id: int
	var character: StringName
	var occasion: BarkBalance.Occasion
	var key: String
	var text: String
	## Сколько держать облако (сек), по длине текста.
	var duration: float
	## Когда показано (по часам директора).
	var shown_at: float
	## Пауза говорящего до этой реплики — вернуть, если облако тут же сменили.
	var prev_ready_at: float

## Реплики выключены (настройка «Реплики соперников», обучение).
var enabled := true
var lines: BarkLines
## Шансы поводов (по умолчанию BarkBalance.CHANCE; тесты ставят 1.0).
var chances: Dictionary = BarkBalance.CHANCE.duplicate()

var _rng: RandomNumberGenerator
var _clock: Callable
var _translate: Callable
## id места → персонаж; &"" — место не говорит (человек).
var _speakers: Array[StringName] = []
var _out := {}               # id → выбыл
var _ready_at := {}          # id → когда снова может говорить
var _last_key := {}          # id → прошлая реплика (не повторять подряд)
var _current: Bark
var _busy_until := -INF
var _bus: Object


## clock: Callable() -> float (секунды), translate: Callable(key) -> String.
func _init(rng: RandomNumberGenerator, p_lines: BarkLines = null,
		clock: Callable = Callable(), translate: Callable = Callable()) -> void:
	_rng = rng
	lines = p_lines if p_lines != null else BarkLines.new()
	_clock = clock if clock.is_valid() else BarkDirector.ticks
	_translate = translate if translate.is_valid() else BarkDirector.translated_text


static func ticks() -> float:
	return Time.get_ticks_msec() / 1000.0


static func translated_text(key: String) -> String:
	return String(TranslationServer.translate(key))


## Кто говорит: characters[id] — персонаж бота или &"" (человек, место не говорит).
func set_speakers(characters: Array) -> void:
	_speakers.clear()
	for c: Variant in characters:
		_speakers.append(StringName(c) if c != null else &"")


## Место перестало (или стало) говорить: в сети человек ↔ бот.
func set_speaker(player_id: int, character: StringName) -> void:
	if player_id >= 0 and player_id < _speakers.size():
		_speakers[player_id] = character


func speaker(player_id: int) -> StringName:
	return _speakers[player_id] if player_id >= 0 and player_id < _speakers.size() else &""


## Текущее облако (null — нет или уже исчезло).
func current() -> Bark:
	if _current != null and _now() >= _current.shown_at + _current.duration:
		_current = null
	return _current


## Облако убрали раньше времени (новый матч, выход) — можно говорить снова после паузы.
func dismiss() -> void:
	if _current != null:
		_busy_until = minf(_busy_until, _now() + BarkBalance.GAP_AFTER_BUBBLE)
	_current = null


# --- Подписка -------------------------------------------------------------------------

const _SIGNALS := {
	&"match_started": &"on_match_started",
	&"bid_placed": &"on_bid_placed",
	&"challenge_revealed": &"on_challenge_revealed",
	&"dice_count_changed": &"on_dice_count_changed",
	&"player_eliminated": &"on_player_eliminated",
	&"match_ended": &"on_match_ended",
	&"cheat_failed": &"on_cheat_failed",
	&"evidence_shown": &"on_evidence_shown",
	&"madness_began": &"on_madness_began",
	&"accusation_made": &"on_accusation_made",
}


## Слушать события матча на шине (Events или MatchSession).
func listen(bus: Object) -> void:
	unlisten()
	_bus = bus
	for sig: StringName in _SIGNALS:
		bus.connect(sig, Callable(self, _SIGNALS[sig]))


func unlisten() -> void:
	if _bus == null:
		return
	for sig: StringName in _SIGNALS:
		var c := Callable(self, _SIGNALS[sig])
		if is_instance_valid(_bus) and _bus.is_connected(sig, c):
			_bus.disconnect(sig, c)
	_bus = null


# --- События матча --------------------------------------------------------------------

func on_match_started(_player_count: int, _first_player: int) -> void:
	_out.clear()
	_ready_at.clear()
	_last_key.clear()
	_current = null
	_busy_until = -INF
	_offer([[BarkBalance.Occasion.MATCH_START, _bots()]])


func on_bid_placed(player_id: int, _bid: Bid) -> void:
	if speaker(player_id) == &"":
		_offer([[BarkBalance.Occasion.PLAYER_BID, _bots()]])


func on_challenge_revealed(reveal: ChallengeReveal) -> void:
	if reveal.kind == MatchAction.Kind.CALZA:
		_offer([[BarkBalance.Occasion.CALZA, [reveal.caller_id]]])
	else:
		_offer([[BarkBalance.Occasion.LIAR, [reveal.caller_id]],
				[BarkBalance.Occasion.LIAR_AGAINST, [reveal.bidder_id]]])


func on_dice_count_changed(player_id: int, count: int, delta: int) -> void:
	if delta >= 0 or count <= 0:
		return
	var occasion := BarkBalance.Occasion.LAST_DIE if count == 1 else BarkBalance.Occasion.DIE_LOST
	_offer([[occasion, [player_id]]])


func on_player_eliminated(player_id: int) -> void:
	_offer([[BarkBalance.Occasion.LOSE, [player_id]]])
	_out[player_id] = true


func on_match_ended(winner_id: int) -> void:
	_offer([[BarkBalance.Occasion.WIN, [winner_id]]])


func on_cheat_failed(player_id: int, _kind: int) -> void:
	_offer([[BarkBalance.Occasion.CAUGHT, [player_id]],
			[BarkBalance.Occasion.GLOAT, _bots([player_id])]])


func on_evidence_shown(player_id: int) -> void:
	_offer([[BarkBalance.Occasion.EVIDENCE, _bots([player_id])]])


func on_madness_began(player_id: int) -> void:
	if speaker(player_id) != &"":
		_offer([[BarkBalance.Occasion.MADNESS_SELF, [player_id]]])
	else:
		_offer([[BarkBalance.Occasion.MADNESS_PLAYER, _bots([player_id])]])


func on_accusation_made(accuser_id: int, target_id: int, guilty: bool) -> void:
	var groups := []
	if guilty:
		groups.append([BarkBalance.Occasion.CAUGHT, [target_id]])
		groups.append([BarkBalance.Occasion.GLOAT, _bots([target_id])])
	groups.append([BarkBalance.Occasion.ACCUSE, [accuser_id]])
	_offer(groups)


# --- Выбор ------------------------------------------------------------------------------

## groups — [[повод, [id…]], …] по важности: первая группа, где выпал шанс и есть кому
## сказать, даёт реплику. Шанс бросается только для групп, где говорить есть кому.
func _offer(groups: Array) -> void:
	if not enabled:
		return
	for group: Array in groups:
		var occasion: BarkBalance.Occasion = group[0]
		if not _may_speak_now(occasion):
			continue
		var who := _eligible(group[1], occasion)
		if who.is_empty():
			continue
		if _rng.randf() >= float(chances[occasion]):
			continue
		var id: int = who[_rng.randi_range(0, who.size() - 1)]
		var key := _pick_line(id, occasion)
		if key != "":
			_say(id, occasion, key)
			return


## Можно ли сейчас показать облако повода: свободно, или важнее только что показанного.
func _may_speak_now(occasion: BarkBalance.Occasion) -> bool:
	var now := _now()
	if now >= _busy_until:
		return true
	var cur := current()
	return cur != null and now - cur.shown_at <= BarkBalance.REPLACE_WINDOW \
			and int(BarkBalance.PRIORITY[occasion]) > int(BarkBalance.PRIORITY[cur.occasion])


func _eligible(ids: Array, occasion: BarkBalance.Occasion) -> Array[int]:
	var now := _now()
	var out: Array[int] = []
	for id: int in ids:
		if speaker(id) == &"" or now < float(_ready_at.get(id, -INF)):
			continue
		if _out.has(id) and occasion != BarkBalance.Occasion.LOSE:
			continue
		var cur := current()
		if cur != null and cur.speaker_id == id:
			continue
		if not _has_lines(id, occasion):
			continue
		out.append(id)
	return out


func _has_lines(id: int, occasion: BarkBalance.Occasion) -> bool:
	return not lines.regular(speaker(id), occasion).is_empty() \
			or not lines.story_lines(speaker(id), occasion).is_empty()


## Вариант текста: сюжетный (с шансом STORY_CHANCE, если есть) или обычный; не тот же, что
## персонаж сказал в прошлый раз.
func _pick_line(id: int, occasion: BarkBalance.Occasion) -> String:
	var character := speaker(id)
	var pool := lines.story_lines(character, occasion)
	var regular := lines.regular(character, occasion)
	if pool.is_empty() or (not regular.is_empty() and _rng.randf() >= BarkBalance.STORY_CHANCE):
		pool = regular
	if pool.is_empty():
		return ""
	var options := Array(pool)
	if options.size() > 1:
		options.erase(_last_key.get(id, ""))
	return options[_rng.randi_range(0, options.size() - 1)]


func _say(id: int, occasion: BarkBalance.Occasion, key: String) -> void:
	var now := _now()
	if _current != null and now < _current.shown_at + _current.duration:
		# Сменили только что показанное облако: тот, кого перебили, не потерял очередь.
		_ready_at[_current.speaker_id] = _current.prev_ready_at
	var b := Bark.new()
	b.speaker_id = id
	b.character = speaker(id)
	b.occasion = occasion
	b.key = key
	b.text = _translate.call(key)
	b.duration = BarkBalance.duration_for(b.text.length())
	b.shown_at = now
	b.prev_ready_at = float(_ready_at.get(id, -INF))
	_current = b
	_last_key[id] = key
	_ready_at[id] = now + BarkBalance.CHARACTER_COOLDOWN
	_busy_until = now + b.duration + BarkBalance.GAP_AFTER_BUBBLE
	bark.emit(b)


## Боты за столом, кроме except (и выбывших — их отсеет _eligible).
func _bots(except: Array = []) -> Array:
	var out := []
	for id in _speakers.size():
		if _speakers[id] != &"" and not id in except:
			out.append(id)
	return out


func _now() -> float:
	return float(_clock.call())
