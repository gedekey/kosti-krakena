class_name Glossary
extends RefCounted
## Словарь игровых терминов (М13, доп.): что подсвечивать в текстах и что показывать
## во всплывающей подсказке. Логика без нод: перевод — через инъекцию translate(key).
##
## У каждого термина три ключа локализации (i18n/strings.csv):
##   TERM_<ID>        — название (заголовок подсказки);
##   TERM_<ID>_DESC   — описание (у трюков — CHEAT_<ID>_HINT + цена и риск из Cheat);
##   TERM_<ID>_FORMS  — словоформы через «|» в нижнем регистре: по ним термин узнаётся
##                      в любом тексте (в русском — все нужные падежи).
## Разметка: найденные словоформы оборачиваются в [url=<id>][color=…]…[/color][/url]
## (BBCode для RichTextLabel; meta = id термина).

const FORMS_SEPARATOR := "|"
const KEY_PREFIX := "TERM_"

## Порядок не важен для поиска (длинные формы проверяются раньше), но задаёт порядок в тестах.
const ALL: Array[StringName] = [
	&"BID", &"PACO", &"LIAR", &"CALZA", &"PALIFICO", &"BLUFF",
	&"CHEATING", &"TRICK", &"RISK", &"NEIGHBOUR", &"SANITY", &"MADNESS",
	&"EVIDENCE", &"ACCUSE",
	&"PEEK", &"SLEIGHT", &"LOADED_DIE", &"NUDGE_CUP", &"SLEEVE_DIE", &"ABYSS_WHISPER",
]

## Термины-трюки → вид трюка (описание собирается из подсказки трюка и его цены).
const TRICKS := {
	&"PEEK": Cheat.Kind.PEEK,
	&"SLEIGHT": Cheat.Kind.SLEIGHT,
	&"LOADED_DIE": Cheat.Kind.LOADED_DIE,
	&"NUDGE_CUP": Cheat.Kind.NUDGE_CUP,
	&"SLEEVE_DIE": Cheat.Kind.SLEEVE_DIE,
	&"ABYSS_WHISPER": Cheat.Kind.ABYSS_WHISPER,
}

## Найденное вхождение термина: [start, length, id].
class Match:
	var start: int
	var length: int
	var id: StringName

	func _init(p_start: int, p_length: int, p_id: StringName) -> void:
		start = p_start
		length = p_length
		id = p_id


var _translate: Callable
## Кэш форм для текущего языка: [[форма, id], …], длинные первыми.
var _forms: Array = []
var _forms_locale := ""
var _locale: Callable


## translate(key) -> String; locale() -> String — для сброса кэша при смене языка.
func _init(translate: Callable = Callable(), locale: Callable = Callable()) -> void:
	_translate = translate if translate.is_valid() else Callable(TranslationServer, "translate")
	_locale = locale if locale.is_valid() else Callable(TranslationServer, "get_locale")


static func is_term(id: StringName) -> bool:
	return ALL.has(id)


static func trick_term(kind: Cheat.Kind) -> StringName:
	return TRICKS.find_key(kind)


static func name_key(id: StringName) -> String:
	if TRICKS.has(id):
		return Cheat.name_key(TRICKS[id])
	return KEY_PREFIX + String(id)


static func desc_key(id: StringName) -> String:
	return KEY_PREFIX + String(id) + "_DESC"


static func forms_key(id: StringName) -> String:
	return KEY_PREFIX + String(id) + "_FORMS"


## Числа для описания — из правил и баланса (в текстах они не дублируются).
static func desc_args(id: StringName) -> Array:
	match id:
		&"CALZA":
			return [PerudoRules.MAX_DICE]
		&"CHEATING":
			return [CheatBalance.CAUGHT_DICE_PENALTY]
		&"RISK":
			return [_pct(CheatBalance.RISK_LOW), _pct(CheatBalance.RISK_MEDIUM),
					_pct(CheatBalance.RISK_HIGH)]
		&"SANITY":
			return [CheatBalance.START_SANITY]
		&"MADNESS":
			return [_pct(MadnessBalance.HALLUCINATION_CHANCE)]
		&"EVIDENCE":
			return [_pct(CheatBalance.TRICK_EVIDENCE_CHANCE),
					_pct(CheatBalance.FALSE_EVIDENCE_CHANCE)]
		&"ACCUSE":
			return [CheatBalance.CAUGHT_DICE_PENALTY, CheatBalance.FALSE_ACCUSATION_PENALTY]
	return []


static func _pct(chance: float) -> int:
	return roundi(chance * 100.0)


func title(id: StringName) -> String:
	return _tr(name_key(id))


## Описание термина простым текстом (числа подставлены).
func description(id: StringName) -> String:
	if TRICKS.has(id):
		var kind: Cheat.Kind = TRICKS[id]
		return _tr(Cheat.name_key(kind) + "_HINT") + "\n" + _tr("TERM_TRICK_PRICE") % [
				Cheat.cost(kind), _pct(Cheat.risk(kind))]
	var args := desc_args(id)
	var text := _tr(desc_key(id))
	return text % args if not args.is_empty() else text


## Словоформы термина в текущем языке.
func forms(id: StringName) -> PackedStringArray:
	var result := PackedStringArray()
	for f in _tr(forms_key(id)).split(FORMS_SEPARATOR, false):
		var form := f.strip_edges().to_lower()
		if form != "" and not result.has(form):
			result.append(form)
	return result


## Все вхождения терминов в text, без пересечений, по возрасту позиции.
## exclude — термин, который не подсвечивать (в его собственном описании).
func find_terms(text: String, exclude: StringName = &"") -> Array[Match]:
	var lower := text.to_lower()
	var taken := PackedByteArray()
	taken.resize(text.length())
	var found: Array[Match] = []
	for entry: Array in _all_forms():
		var form: String = entry[0]
		var id: StringName = entry[1]
		if id == exclude:
			continue
		var from := 0
		while true:
			var at := lower.find(form, from)
			if at < 0:
				break
			from = at + 1
			if not _bounded(lower, at, form.length()) or _overlaps(taken, at, form.length()):
				continue
			for i in form.length():
				taken[at + i] = 1
			found.append(Match.new(at, form.length(), id))
	found.sort_custom(func(a: Match, b: Match) -> bool: return a.start < b.start)
	return found


## Текст → BBCode: квадратные скобки экранированы, термины обёрнуты в ссылки.
func markup(text: String, color: Color, exclude: StringName = &"") -> String:
	var out := ""
	var pos := 0
	var hex := color.to_html(false)
	for m in find_terms(text, exclude):
		out += escape(text.substr(pos, m.start - pos))
		out += "[url=%s][color=#%s]%s[/color][/url]" % [m.id, hex,
				escape(text.substr(m.start, m.length))]
		pos = m.start + m.length
	return out + escape(text.substr(pos))


static func escape(text: String) -> String:
	return text.replace("[", "[lb]")


func _tr(key: String) -> String:
	return String(_translate.call(key))


func _all_forms() -> Array:
	var locale := String(_locale.call())
	if locale == _forms_locale and not _forms.is_empty():
		return _forms
	_forms_locale = locale
	_forms = []
	for id in ALL:
		for form in forms(id):
			_forms.append([form, id])
	_forms.sort_custom(func(a: Array, b: Array) -> bool:
		return (a[0] as String).length() > (b[0] as String).length())
	return _forms


## Вхождение не внутри слова: соседние символы — не буквы и не цифры.
static func _bounded(lower: String, at: int, length: int) -> bool:
	if at > 0 and _is_word_char(lower.unicode_at(at - 1)):
		return false
	var end := at + length
	if end < lower.length() and _is_word_char(lower.unicode_at(end)):
		return false
	return true


static func _is_word_char(c: int) -> bool:
	return (c >= 0x30 and c <= 0x39) or (c >= 0x61 and c <= 0x7a) \
			or (c >= 0x430 and c <= 0x44f) or c == 0x451 \
			or (c >= 0x41 and c <= 0x5a) or (c >= 0x410 and c <= 0x42f) or c == 0x401


static func _overlaps(taken: PackedByteArray, at: int, length: int) -> bool:
	for i in length:
		if taken[at + i] != 0:
			return true
	return false
