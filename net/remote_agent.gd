class_name RemoteAgent
extends MatchAgent
## Место человека в сетевом матче — хоста или гостя (DESIGN.md §8б). Пока место за
## человеком, контроллер действий не спрашивает: они приходят командами сессии.
## Обрыв связи, «Сдаться» или «Выйти» — место переходит нейтральному честному боту;
## кубики и Рассудок остаются при месте (они в контроллере).

## Сетевой id человека (NetTransport.HOST_ID — хост).
var peer_id: int
## Бот, занявший место; null — место за человеком.
var bot: BotAgent


func _init(p_peer_id: int) -> void:
	peer_id = p_peer_id


func is_human() -> bool:
	return bot == null


func is_replaced() -> bool:
	return bot != null


## Отдать место боту. Повторный вызов ничего не меняет.
func replace_with_bot(rng: RandomNumberGenerator) -> void:
	if bot == null:
		bot = BotAgent.new(neutral_personality(), rng)


func choose_action(view: PlayerView) -> MatchAction:
	if bot == null:
		return super(view)
	return bot.choose_action(view)


func choose_roll_cheat(view: PlayerView) -> CheatAction:
	return null if bot == null else bot.choose_roll_cheat(view)


func choose_turn_cheat(view: PlayerView) -> CheatAction:
	return null if bot == null else bot.choose_turn_cheat(view)


## Нейтральный «честный» характер: не жульничает, не обвиняет, блефует умеренно
## (значения BotPersonality по умолчанию).
static func neutral_personality() -> BotPersonality:
	var p := BotPersonality.new()
	p.id = &"neutral"
	p.cheat_chance = 0.0
	p.accuse_threshold = 1.0
	return p
