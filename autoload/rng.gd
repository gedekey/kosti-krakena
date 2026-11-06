extends Node
## Фабрика генераторов случайных чисел.
##
## Логика (core/, match/, cheats/, madness/, ai/) никогда не обращается к этому синглтону
## и не вызывает глобальные randi()/randf(): она получает RandomNumberGenerator параметром.
## Этот синглтон — единственное место, где такие RNG создаются для реальной игры.
## Тесты создают RNG с фиксированным seed напрямую через make_seeded().

var _master := RandomNumberGenerator.new()


func _init() -> void:
	_master.randomize()


## Зафиксировать мастер-seed (для воспроизводимых матчей и отладки).
func set_master_seed(value: int) -> void:
	_master.seed = value


## Новый независимый RNG, seed которого берётся из мастер-генератора.
func make_rng() -> RandomNumberGenerator:
	return make_seeded(_master.randi())


## RNG с заданным seed.
static func make_seeded(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng
