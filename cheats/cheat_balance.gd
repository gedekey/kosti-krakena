class_name CheatBalance
extends RefCounted
## Числа баланса жульничества (DESIGN.md §3–4). Единственное место, где они заданы.
## Итоговые значения М15 (абляция и столы в tools/run_simulation.ps1, DESIGN.md §3).

## Рассудок на матч. Не восполняется.
const START_SANITY := 9

## Шанс мгновенного провала по уровням риска.
const RISK_NONE := 0.0
const RISK_LOW := 0.03
const RISK_MEDIUM := 0.06
const RISK_HIGH := 0.10

## Шанс ложной улики у честного игрока за ход.
const FALSE_EVIDENCE_CHANCE := 0.10

## Шанс, что успешный трюк оставит улику (кроме «Шёпота Бездны» — он улик не оставляет).
const TRICK_EVIDENCE_CHANCE := 0.35

## Пойманный жулик теряет столько кубиков…
const CAUGHT_DICE_PENALTY := 1
## …и столько Рассудка (START_SANITY — весь, т. е. сразу Безумие).
const CAUGHT_SANITY_PENALTY := START_SANITY
## Ложное обвинение: обвинитель теряет столько кубиков.
const FALSE_ACCUSATION_PENALTY := 1

## Цена трюков в Рассудке.
const COST_PEEK := 1
const COST_SLEIGHT := 1
const COST_LOADED_DIE := 2
const COST_NUDGE_CUP := 2
const COST_SLEEVE_DIE := 3
const COST_ABYSS_WHISPER := 5
