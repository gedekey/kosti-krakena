class_name BotPersonality
extends Resource
## Характер бота (DESIGN.md §5). Data-driven: персонажи лежат в ai/personalities/*.tres.
## Здесь — честная часть параметров (М3). Трюки и обвинения добавит М6.
##
## Все вероятности — «как бот их видит», после шума.

## Идентификатор персонажа (scholar, sailor, …).
@export var id: StringName
## Ключ локализации имени.
@export var name_key: String
## Сложность ★–★★★.
@export_range(1, 3) var stars := 1

## Шанс блефа в ход: поставить не лучшую ставку, а случайную из «терпимых».
@export_range(0.0, 1.0) var bluff_chance := 0.1
## Минимальная вера в ставку, при которой бот ещё готов её сделать блефуя.
@export_range(0.0, 1.0) var bluff_floor := 0.35
## Порог «Лжи!»: оспаривает, если верит в текущую ставку меньше, чем на это значение.
@export_range(0.0, 1.0) var dudo_threshold := 0.4
## Порог «Точно!»: зовёт, если шанс ровного попадания не меньше этого значения.
@export_range(0.0, 1.0) var calza_threshold := 0.5
## Насколько уверенной должна быть первая ставка раунда (выше — скромнее открывает).
@export_range(0.0, 1.0) var opening_confidence := 0.6
## Насколько верит ставкам соперников (см. TableEstimate).
@export_range(0.0, 1.0) var bid_reading := 0.0
## «Шум» расчёта: стандартное отклонение ошибки в оценке вероятностей.
@export_range(0.0, 1.0) var noise := 0.0
