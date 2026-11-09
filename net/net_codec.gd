class_name NetCodec
extends RefCounted
## Значения матча ↔ простые массивы и словари для сети (только int / bool / Array /
## Dictionary — никаких Object). Номера игроков пишутся в системе отсчёта получателя
## (SeatFrame): кодер переводит глобальные в локальные, декодер — локальные в глобальные
## (у гостя система тождественная).
##
## Декодер проверяет всё: типы, диапазоны, размеры. При любой ошибке — null.
## Там, где null — допустимое значение (нет ставки), вызывающий проверяет это сам.

## Количество в ставке не больше этого (кубиков на столе максимум 6×5 + рукава).
const MAX_QUANTITY := 64
## Записей в ленте ставок раунда не больше этого.
const MAX_HISTORY := 256
## Итогов своих трюков за раунд не больше этого.
const MAX_OUTCOMES := 64
## Кубиков в руке / рукаве не больше этого.
const MAX_HAND := 16
const NONE := CheatAction.NONE


# --- Проверки ------------------------------------------------------------------

static func _int_in(v: Variant, lo: int, hi: int) -> bool:
	return typeof(v) == TYPE_INT and v >= lo and v <= hi


static func _is_bool(v: Variant) -> bool:
	return typeof(v) == TYPE_BOOL


static func _face_ok(v: Variant) -> bool:
	return _int_in(v, 1, PerudoRules.FACES)


## Массив граней 1..6 не длиннее max_size.
static func _faces_ok(v: Variant, max_size := MAX_HAND) -> bool:
	if typeof(v) != TYPE_ARRAY or v.size() > max_size:
		return false
	for x in v:
		if not _face_ok(x):
			return false
	return true


static func _ints_ok(v: Variant, size: int, lo: int, hi: int) -> bool:
	if typeof(v) != TYPE_ARRAY or v.size() != size:
		return false
	for x in v:
		if not _int_in(x, lo, hi):
			return false
	return true


static func _bools_ok(v: Variant, size: int) -> bool:
	if typeof(v) != TYPE_ARRAY or v.size() != size:
		return false
	for x in v:
		if not _is_bool(x):
			return false
	return true


## Место в системе получателя или NO_PLAYER.
static func _player_or_none(v: Variant, frame: SeatFrame) -> bool:
	return typeof(v) == TYPE_INT and (v == PerudoRules.NO_PLAYER or frame.is_seat(v))


static func _dict_has(v: Variant, keys: Array) -> bool:
	if typeof(v) != TYPE_DICTIONARY:
		return false
	for k in keys:
		if not v.has(k):
			return false
	return true


static func _ints(v: Array) -> Array[int]:
	var out: Array[int] = []
	out.assign(v)
	return out


static func _local_ids(ids: Array, frame: SeatFrame) -> Array:
	var out := []
	for id in ids:
		out.append(frame.to_local(id))
	return out


# --- Bid -----------------------------------------------------------------------

static func encode_bid(bid: Bid) -> Variant:
	return null if bid == null else [bid.quantity, bid.face]


static func decode_bid(v: Variant) -> Bid:
	if typeof(v) != TYPE_ARRAY or v.size() != 2:
		return null
	if not _int_in(v[0], 1, MAX_QUANTITY) or not _face_ok(v[1]):
		return null
	return Bid.new(v[0], v[1])


# --- MatchAction ---------------------------------------------------------------

static func encode_action(action: MatchAction, frame: SeatFrame) -> Dictionary:
	var d := {"k": action.kind}
	match action.kind:
		MatchAction.Kind.BID:
			d["b"] = encode_bid(action.bid)
		MatchAction.Kind.ACCUSE:
			d["p"] = frame.to_local(action.target_id)
	return d


static func decode_action(v: Variant, frame: SeatFrame) -> MatchAction:
	if not _dict_has(v, ["k"]) or not _int_in(v["k"], 0, MatchAction.Kind.size() - 1):
		return null
	match v["k"]:
		MatchAction.Kind.BID:
			var bid := decode_bid(v.get("b"))
			return null if bid == null else MatchAction.new(MatchAction.Kind.BID, bid)
		MatchAction.Kind.ACCUSE:
			if not frame.is_seat(v.get("p")):
				return null
			return MatchAction.accuse(frame.to_global(v["p"]))
		MatchAction.Kind.DUDO:
			return MatchAction.dudo()
	return MatchAction.calza()


# --- CheatAction ---------------------------------------------------------------

static func encode_cheat(action: CheatAction, frame: SeatFrame) -> Array:
	var target := action.target_id
	if target != NONE:
		target = frame.to_local(target)
	return [action.kind, target, action.die_index, action.face]


static func decode_cheat(v: Variant, frame: SeatFrame) -> CheatAction:
	if typeof(v) != TYPE_ARRAY or v.size() != 4:
		return null
	if not _int_in(v[0], 0, Cheat.Kind.size() - 1) or not _player_or_none(v[1], frame):
		return null
	if not _int_in(v[2], NONE, MAX_HAND - 1) or not _int_in(v[3], NONE, PerudoRules.FACES):
		return null
	return CheatAction.new(v[0], frame.to_global(v[1]), v[2], v[3])


# --- CheatOutcome --------------------------------------------------------------

static func encode_outcome(o: CheatOutcome, frame: SeatFrame) -> Array:
	return [frame.to_local(o.player_id), encode_cheat(o.action, frame), o.failed,
			o.peeked_face, o.whisper_count, o.new_face, o.die_index]


static func decode_outcome(v: Variant, frame: SeatFrame) -> CheatOutcome:
	if typeof(v) != TYPE_ARRAY or v.size() != 7 or not frame.is_seat(v[0]):
		return null
	var action := decode_cheat(v[1], frame)
	if action == null or not _is_bool(v[2]):
		return null
	if not _int_in(v[3], NONE, PerudoRules.FACES) or not _int_in(v[4], NONE, MAX_QUANTITY) \
			or not _int_in(v[5], NONE, PerudoRules.FACES) \
			or not _int_in(v[6], NONE, MAX_HAND - 1):
		return null
	var o := CheatOutcome.new(frame.to_global(v[0]), action)
	o.failed = v[2]
	o.peeked_face = v[3]
	o.whisper_count = v[4]
	o.new_face = v[5]
	o.die_index = v[6]
	return o


# --- ChallengeReveal -----------------------------------------------------------

static func encode_reveal(r: ChallengeReveal, frame: SeatFrame) -> Dictionary:
	var res := r.result
	return {
		"k": r.kind,
		"b": encode_bid(r.bid),
		"bi": frame.to_local(r.bidder_id),
		"c": frame.to_local(r.caller_id),
		"h": frame.rotate(r.hands),
		"pal": r.is_palifico,
		"r": [res.actual_count, res.bid_holds, frame.to_local(res.player_id), res.dice_delta],
		"s": frame.rotate(r.sleeve_dice),
	}


static func decode_reveal(v: Variant, frame: SeatFrame) -> ChallengeReveal:
	if not _dict_has(v, ["k", "b", "bi", "c", "h", "pal", "r", "s"]):
		return null
	if typeof(v["k"]) != TYPE_INT \
			or not (v["k"] == MatchAction.Kind.DUDO or v["k"] == MatchAction.Kind.CALZA):
		return null
	var bid := decode_bid(v["b"])
	if bid == null or not frame.is_seat(v["bi"]) or not frame.is_seat(v["c"]) \
			or not _is_bool(v["pal"]):
		return null
	var hands: Variant = _decode_by_player_hands(v["h"], frame)
	var sleeves: Variant = _decode_by_player_hands(v["s"], frame)
	if hands == null or sleeves == null:
		return null
	var r: Variant = v["r"]
	if typeof(r) != TYPE_ARRAY or r.size() != 4 or not _int_in(r[0], 0, MAX_QUANTITY) \
			or not _is_bool(r[1]) or not frame.is_seat(r[2]) \
			or not _int_in(r[3], -PerudoRules.MAX_DICE, PerudoRules.MAX_DICE):
		return null
	var result := RevealResult.new(r[0], r[1], frame.to_global(r[2]), r[3])
	return ChallengeReveal.new(v["k"], bid, frame.to_global(v["bi"]), frame.to_global(v["c"]),
			hands, v["pal"], result, sleeves)


## Массив рук по игрокам в системе получателя → по глобальным номерам.
static func _decode_by_player_hands(v: Variant, frame: SeatFrame) -> Variant:
	if typeof(v) != TYPE_ARRAY or v.size() != frame.count:
		return null
	var out := []
	out.resize(frame.count)
	for local in v.size():
		if not _faces_ok(v[local]):
			return null
		out[frame.to_global(local)] = _ints(v[local])
	return out


# --- PlayerView ----------------------------------------------------------------

static func encode_view(view: PlayerView, frame: SeatFrame) -> Dictionary:
	var history := []
	for entry in view.bid_history:
		history.append([frame.to_local(entry.player_id), entry.bid.quantity, entry.bid.face])
	var outcomes := []
	for o in view.cheat_outcomes:
		outcomes.append(encode_outcome(o, frame))
	return {
		"p": frame.to_local(view.player_id),
		"rn": view.round_number,
		"od": view.own_dice.duplicate(),
		"co": view.cup_open,
		"dc": frame.rotate(view.dice_counts),
		"cb": encode_bid(view.current_bid),
		"cbi": frame.to_local(view.current_bidder),
		"bh": history,
		"pal": view.round_rules.is_palifico,
		"opt": encode_options(view.options),
		"sa": view.own_sanity,
		"md": frame.rotate(view.mad),
		"ev": frame.rotate(view.evidence),
		"sl": view.sleeve_dice.duplicate(),
		"oc": outcomes,
		"cw": view.cheat_window,
		"cu": view.cheat_used,
	}


static func decode_view(v: Variant, frame: SeatFrame) -> PlayerView:
	if not _dict_has(v, ["p", "rn", "od", "co", "dc", "cb", "cbi", "bh", "pal", "opt", "sa",
			"md", "ev", "sl", "oc", "cw", "cu"]):
		return null
	var n := frame.count
	if not frame.is_seat(v["p"]) or not _int_in(v["rn"], 0, 1 << 30) \
			or not _faces_ok(v["od"]) or not _is_bool(v["co"]) \
			or not _ints_ok(v["dc"], n, 0, PerudoRules.MAX_DICE) \
			or not _player_or_none(v["cbi"], frame) or not _is_bool(v["pal"]) \
			or not _int_in(v["sa"], 0, CheatBalance.START_SANITY) \
			or not _bools_ok(v["md"], n) or not _ints_ok(v["ev"], n, 0, 1 << 16) \
			or not _faces_ok(v["sl"]) \
			or not _int_in(v["cw"], 0, CheatRules.CheatWindow.size() - 1) \
			or not _is_bool(v["cu"]):
		return null
	var options := decode_options(v["opt"])
	if options == null:
		return null
	var view := PlayerView.new()
	if v["cb"] != null:
		view.current_bid = decode_bid(v["cb"])
		if view.current_bid == null:
			return null
	var bh: Variant = v["bh"]
	if typeof(bh) != TYPE_ARRAY or bh.size() > MAX_HISTORY:
		return null
	for e in bh:
		if typeof(e) != TYPE_ARRAY or e.size() != 3 or not frame.is_seat(e[0]):
			return null
		var bid := decode_bid([e[1], e[2]])
		if bid == null:
			return null
		view.bid_history.append(BidEntry.new(frame.to_global(e[0]), bid))
	var oc: Variant = v["oc"]
	if typeof(oc) != TYPE_ARRAY or oc.size() > MAX_OUTCOMES:
		return null
	for raw in oc:
		var o := decode_outcome(raw, frame)
		if o == null:
			return null
		view.cheat_outcomes.append(o)
	view.player_id = frame.to_global(v["p"])
	view.round_number = v["rn"]
	view.own_dice = _ints(v["od"])
	view.cup_open = v["co"]
	view.dice_counts = _ints(_unrotate(v["dc"], frame))
	view.current_bidder = frame.to_global(v["cbi"])
	view.round_rules = RoundRules.new(v["pal"])
	view.options = options
	view.own_sanity = v["sa"]
	view.mad.assign(_unrotate(v["md"], frame))
	view.evidence = _ints(_unrotate(v["ev"], frame))
	view.sleeve_dice = _ints(v["sl"])
	view.cheat_window = v["cw"]
	view.cheat_used = v["cu"]
	return view


## Массив по игрокам в системе получателя → по глобальным номерам.
static func _unrotate(local_arr: Array, frame: SeatFrame) -> Array:
	var out := []
	out.resize(local_arr.size())
	for local in local_arr.size():
		out[frame.to_global(local)] = local_arr[local]
	return out


# --- Правила -------------------------------------------------------------------

static func encode_options(options: RuleOptions) -> Array:
	return [options.palifico_enabled, options.calza_enabled]


static func decode_options(v: Variant) -> RuleOptions:
	if not _bools_ok(v, 2):
		return null
	var options := RuleOptions.new()
	options.palifico_enabled = v[0]
	options.calza_enabled = v[1]
	return options


# --- События -------------------------------------------------------------------

## Аргументы сетевого события (NetProtocol.EVENTS) для получателя.
static func encode_args(spec: String, args: Array, frame: SeatFrame) -> Array:
	var out := []
	for i in spec.length():
		var a: Variant = args[i]
		match spec[i]:
			NetProtocol.ARG_PLAYER:
				out.append(frame.to_local(a))
			NetProtocol.ARG_BID:
				out.append(encode_bid(a))
			NetProtocol.ARG_REVEAL:
				out.append(encode_reveal(a, frame))
			NetProtocol.ARG_OUTCOME:
				out.append(encode_outcome(a, frame))
			_:
				out.append(a)
	return out


## Аргументы события из сети; null — если что-то не так.
static func decode_args(spec: String, v: Variant, frame: SeatFrame) -> Variant:
	if typeof(v) != TYPE_ARRAY or v.size() != spec.length():
		return null
	var out := []
	for i in spec.length():
		var a: Variant = v[i]
		var decoded: Variant = null
		match spec[i]:
			NetProtocol.ARG_INT:
				if typeof(a) != TYPE_INT:
					return null
				decoded = a
			NetProtocol.ARG_PLAYER:
				if not _player_or_none(a, frame):
					return null
				decoded = frame.to_global(a)
			NetProtocol.ARG_BOOL:
				if not _is_bool(a):
					return null
				decoded = a
			NetProtocol.ARG_PHASE:
				if not _int_in(a, 0, MatchController.Phase.size() - 1):
					return null
				decoded = a
			NetProtocol.ARG_CHEAT_KIND:
				if not _int_in(a, 0, Cheat.Kind.size() - 1):
					return null
				decoded = a
			NetProtocol.ARG_BID:
				decoded = decode_bid(a)
			NetProtocol.ARG_REVEAL:
				decoded = decode_reveal(a, frame)
			NetProtocol.ARG_OUTCOME:
				decoded = decode_outcome(a, frame)
		if decoded == null:
			return null
		out.append(decoded)
	return out


# --- Снимок для гостя ----------------------------------------------------------

## Что гость знает после события: его PlayerView + фаза, чей ход, победитель
## и сколько осталось на таймере (−1 — таймера нет).
static func encode_snapshot(view: PlayerView, phase: int, current: int, winner: int,
		time_left_ms: int, frame: SeatFrame) -> Dictionary:
	return {
		"v": encode_view(view, frame),
		"ph": phase,
		"cp": frame.to_local(current),
		"w": frame.to_local(winner),
		"tl": time_left_ms,
	}


## {view, phase, current, winner, time_left} или null.
static func decode_snapshot(v: Variant, frame: SeatFrame) -> Variant:
	if not _dict_has(v, ["v", "ph", "cp", "w", "tl"]):
		return null
	if not _int_in(v["ph"], 0, MatchController.Phase.size() - 1) \
			or not _player_or_none(v["cp"], frame) or not _player_or_none(v["w"], frame) \
			or not _int_in(v["tl"], -1, 1 << 30):
		return null
	var view := decode_view(v["v"], frame)
	if view == null:
		return null
	return {
		"view": view,
		"phase": v["ph"],
		"current": frame.to_global(v["cp"]),
		"winner": frame.to_global(v["w"]),
		"time_left": v["tl"],
	}
