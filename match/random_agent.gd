class_name RandomAgent
extends MatchAgent
## Случайный бот для отладки контроллера (М2). Настоящий ИИ — модуль 3.
## Всегда выбирает допустимое действие.

## Шанс сказать «Ложь!», если есть что оспаривать.
const DUDO_CHANCE := 0.25
## Шанс сказать «Точно!», если это разрешено.
const CALZA_CHANCE := 0.05
## На сколько бот может поднять количество сверх минимального.
const MAX_EXTRA_QUANTITY := 1

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


func choose_action(view: PlayerView) -> MatchAction:
	var faces := view.allowed_faces()
	if faces.is_empty():
		return MatchAction.dudo()
	if view.can_dudo() and _rng.randf() < DUDO_CHANCE:
		return MatchAction.dudo()
	if view.can_calza() and _rng.randf() < CALZA_CHANCE:
		return MatchAction.calza()
	var face := faces[_rng.randi_range(0, faces.size() - 1)]
	var quantity := view.min_quantity_for_face(face) + _rng.randi_range(0, MAX_EXTRA_QUANTITY)
	return MatchAction.make_bid(mini(quantity, view.max_bid_quantity()), face)
