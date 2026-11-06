class_name CheatBalance
extends RefCounted
## Числа баланса жульничества (DESIGN.md §3–4). Единственное место, где они заданы.
## Стартовые значения — из дизайн-документа, балансируются на плейтесте (М15).

## Рассудок на матч. Не восполняется.
const START_SANITY := 9

## Шанс мгновенного провала по уровням риска.
const RISK_NONE := 0.0
const RISK_LOW := 0.10
const RISK_MEDIUM := 0.20
const RISK_HIGH := 0.35

## Шанс ложной улики у честного игрока за ход.
const FALSE_EVIDENCE_CHANCE := 0.15

## Пойманный жулик теряет столько кубиков, Рассудок → 0.
const CAUGHT_DICE_PENALTY := 2
## Ложное обвинение: обвинитель теряет столько кубиков.
const FALSE_ACCUSATION_PENALTY := 1

## Цена трюков в Рассудке.
const COST_PEEK := 1
const COST_SLEIGHT := 1
const COST_LOADED_DIE := 2
const COST_NUDGE_CUP := 2
const COST_SLEEVE_DIE := 3
const COST_ABYSS_WHISPER := 3
