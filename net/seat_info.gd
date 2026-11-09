class_name SeatInfo
extends RefCounted
## Кто сидит на месте за столом: хост, гость или бот. Имя и портрет — у людей,
## персонаж — у ботов. Публичная информация: уходит всем гостям.

enum Kind { HOST, GUEST, BOT }

var kind: Kind = Kind.BOT
## Имя человека (как ввёл, без перевода). У ботов пусто — имя по персонажу.
var player_name := ""
## Номер портрета человека: 0..NetBalance.PORTRAIT_COUNT-1.
var portrait := 0
## Персонаж бота (BotRoster).
var bot_id: StringName = &""
## Сетевой id человека (только на хосте, по сети не уходит).
var peer_id := 0
## Место человека перешло боту: обрыв связи, «Сдаться» или «Выйти в меню».
var replaced := false
## Сетевой ранг человека (RankBalance.Tier, М20); −1 — неизвестен (бот).
var rank := -1


static func host(p_name: String, p_portrait: int) -> SeatInfo:
	var s := SeatInfo.new()
	s.kind = Kind.HOST
	s.player_name = p_name
	s.portrait = p_portrait
	s.peer_id = NetTransport.HOST_ID
	return s


static func guest(p_peer_id: int, p_name: String, p_portrait: int) -> SeatInfo:
	var s := SeatInfo.new()
	s.kind = Kind.GUEST
	s.player_name = p_name
	s.portrait = p_portrait
	s.peer_id = p_peer_id
	return s


static func bot(p_bot_id: StringName) -> SeatInfo:
	var s := SeatInfo.new()
	s.kind = Kind.BOT
	s.bot_id = p_bot_id
	return s


## Сейчас место ведёт человек.
func is_human() -> bool:
	return kind != Kind.BOT and not replaced


func duplicate_info() -> SeatInfo:
	var s := SeatInfo.new()
	s.kind = kind
	s.player_name = player_name
	s.portrait = portrait
	s.bot_id = bot_id
	s.peer_id = peer_id
	s.replaced = replaced
	s.rank = rank
	return s


## Для сети: без peer_id.
func to_wire() -> Array:
	return [kind, player_name, portrait, String(bot_id), replaced, rank]


## Из сети; null — если что-то не так.
static func from_wire(v: Variant) -> SeatInfo:
	if typeof(v) != TYPE_ARRAY or v.size() != 6:
		return null
	if typeof(v[0]) != TYPE_INT or v[0] < 0 or v[0] >= Kind.size():
		return null
	if typeof(v[1]) != TYPE_STRING or v[1].length() > NetBalance.MAX_NAME_LENGTH:
		return null
	if typeof(v[2]) != TYPE_INT or v[2] < 0 or v[2] >= NetBalance.PORTRAIT_COUNT:
		return null
	if typeof(v[3]) != TYPE_STRING or v[3].length() > NetBalance.MAX_NAME_LENGTH \
			or typeof(v[4]) != TYPE_BOOL or not is_valid_rank(v[5]):
		return null
	var s := SeatInfo.new()
	s.kind = v[0]
	s.player_name = v[1]
	s.portrait = v[2]
	s.bot_id = StringName(v[3])
	s.replaced = v[4]
	s.rank = v[5]
	return s


## Ранг из сети: −1 (неизвестен) или RankBalance.Tier.
static func is_valid_rank(v: Variant) -> bool:
	return typeof(v) == TYPE_INT and v >= -1 and v < RankBalance.ALL_TIERS.size()


## Имя от гостя: без управляющих символов и пробелов по краям, не длиннее MAX_NAME_LENGTH.
static func clean_name(raw: String) -> String:
	var out := ""
	for ch in raw:
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
			out += ch
	return out.strip_edges().substr(0, NetBalance.MAX_NAME_LENGTH).strip_edges()
