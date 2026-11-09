class_name NetProtocol
extends RefCounted
## Протокол сетевой игры (DESIGN.md §8б): типы сообщений, причины отказа и обрыва,
## таблица событий матча и правило, кому какое событие видно.
##
## Сообщение — Dictionary {"t": Msg, …} только из int / bool / String / Array / Dictionary.
## По сети идёт var_to_bytes; принимается bytes_to_var — без объектов.
## Каждое входящее сообщение проверяется получателем, лишнее и кривое отбрасывается.

## Растёт при любом несовместимом изменении формата.
const PROTOCOL := 3

enum Msg {
	## гость → хост: {ver: String, name: String, portrait: int, rank: int (М20, −1 — нет)}
	HELLO,
	## хост → гость: принят, ждёт начала матча.
	WELCOME,
	## хост → гость: {r: Reject, ver: String} — отказ, дальше связь рвётся.
	REJECT,
	## хост → гость: {seats: [SeatInfo…] (в системе гостя), opt: RuleOptions, timer: bool}
	MATCH_START,
	## хост → гость: {e: номер в EVENTS, a: аргументы, s: снимок после события}
	EVENT,
	## хост → гость: {p: место} — место человека перешло боту.
	SEAT_BOT,
	## хост → гость: {r: MatchController.Result} — команда гостя отклонена.
	NACK,
	## хост → гость: {r: Abort} — матч прерван.
	ABORT,
	## гость → хост: {a: MatchAction}
	ACTION,
	## гость → хост: {c: CheatAction}
	CHEAT,
	## гость → хост: {o: bool} — открыть / закрыть свою чашку.
	CUP,
	## гость → хост: {ph: Phase, rn: номер раунда} — готов к броску / следующему раунду.
	READY,
	## гость → хост: «Сдаться» / «Выйти» — место переходит боту.
	LEAVE,
	## хост → гости в лобби (М19): {seats: [SeatInfo…] (номера хоста), opt: RuleOptions,
	## timer: bool, you: место гостя или −1}. Бот с пустым bot_id — «случайный».
	LOBBY,
}

enum Reject {
	## Версии игры у хоста и гостя разные.
	VERSION_MISMATCH,
	## Все места заняты.
	FULL,
	## Матч уже идёт — вернуться нельзя.
	IN_PROGRESS,
	## Кривое приветствие.
	BAD_HELLO,
}

enum Abort {
	## Хост вышел из матча.
	HOST_LEFT,
	## Связь с хостом потеряна.
	CONNECTION_LOST,
	## Подключиться к хосту не удалось.
	CONNECTION_FAILED,
}

## Коды аргументов событий: число, id игрока (поворачивается), bool, Bid, ChallengeReveal,
## CheatOutcome, Cheat.Kind, MatchController.Phase.
const ARG_INT := "i"
const ARG_PLAYER := "p"
const ARG_BOOL := "b"
const ARG_BID := "B"
const ARG_REVEAL := "R"
const ARG_OUTCOME := "O"
const ARG_CHEAT_KIND := "k"
const ARG_PHASE := "h"

## События матча: сигнал MatchController и типы его аргументов. Индекс — номер на проводе.
const EVENTS := [
	[&"phase_changed", "h"],
	[&"match_started", "ip"],
	[&"round_started", "ipb"],
	[&"dice_rolled", "i"],
	[&"turn_started", "p"],
	[&"bid_placed", "pB"],
	[&"challenge_revealed", "R"],
	[&"dice_count_changed", "pii"],
	[&"player_eliminated", "p"],
	[&"round_ended", "pb"],
	[&"match_ended", "p"],
	[&"cheat_resolved", "O"],
	[&"cheat_failed", "pk"],
	[&"evidence_shown", "p"],
	[&"sanity_changed", "pii"],
	[&"madness_began", "p"],
	[&"accusation_made", "ppb"],
	[&"cup_changed", "pb"],
]


## Строка версии для рукопожатия: версия игры + версия протокола.
static func game_version() -> String:
	return "%s/%d" % [ProjectSettings.get_setting("application/config/version", "0"), PROTOCOL]


## Номер события по имени сигнала; −1 — не сетевое событие.
static func event_index(sig_name: StringName) -> int:
	for i in EVENTS.size():
		if EVENTS[i][0] == sig_name:
			return i
	return -1


## Видно ли событие игроку viewer (глобальный номер). Секреты (DESIGN.md §8б):
## итог трюка и Рассудок — только владельцу. Остальное публично (при вскрытии кубики
## видны всем, как в одиночной игре).
static func is_visible(sig_name: StringName, args: Array, viewer: int) -> bool:
	match sig_name:
		&"cheat_resolved":
			return (args[0] as CheatOutcome).player_id == viewer
		&"sanity_changed":
			return args[0] == viewer
	return true


## Тип сообщения или −1, если это не сообщение.
static func type_of(msg: Variant) -> int:
	if typeof(msg) != TYPE_DICTIONARY or not msg.has("t"):
		return -1
	var t: Variant = msg["t"]
	if typeof(t) != TYPE_INT or t < 0 or t >= Msg.size():
		return -1
	return t


static func make(type: Msg, fields := {}) -> Dictionary:
	var msg := fields.duplicate()
	msg["t"] = type
	return msg
