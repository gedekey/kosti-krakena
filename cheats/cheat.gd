class_name Cheat
extends RefCounted
## Каталог трюков (DESIGN.md §3.2): цена, риск, цель, фаза, улики.
## Только статические функции. Числа — в CheatBalance.

enum Kind { PEEK, SLEIGHT, LOADED_DIE, NUDGE_CUP, SLEEVE_DIE, ABYSS_WHISPER }

## Что нужно указать для трюка.
enum Target {
	## Ничего.
	NONE,
	## Свой кубик (индекс в чашке).
	OWN_DIE,
	## Сосед (id) и его кубик (индекс).
	NEIGHBOR_DIE,
	## Сосед (id).
	NEIGHBOR,
	## Грань 1..6.
	FACE,
}

const ALL: Array[Kind] = [
	Kind.PEEK, Kind.SLEIGHT, Kind.LOADED_DIE, Kind.NUDGE_CUP, Kind.SLEEVE_DIE, Kind.ABYSS_WHISPER,
]

const _COST := {
	Kind.PEEK: CheatBalance.COST_PEEK,
	Kind.SLEIGHT: CheatBalance.COST_SLEIGHT,
	Kind.LOADED_DIE: CheatBalance.COST_LOADED_DIE,
	Kind.NUDGE_CUP: CheatBalance.COST_NUDGE_CUP,
	Kind.SLEEVE_DIE: CheatBalance.COST_SLEEVE_DIE,
	Kind.ABYSS_WHISPER: CheatBalance.COST_ABYSS_WHISPER,
}

const _RISK := {
	Kind.PEEK: CheatBalance.RISK_LOW,
	Kind.SLEIGHT: CheatBalance.RISK_MEDIUM,
	Kind.LOADED_DIE: CheatBalance.RISK_MEDIUM,
	Kind.NUDGE_CUP: CheatBalance.RISK_HIGH,
	Kind.SLEEVE_DIE: CheatBalance.RISK_HIGH,
	Kind.ABYSS_WHISPER: CheatBalance.RISK_NONE,
}

const _TARGET := {
	Kind.PEEK: Target.NEIGHBOR_DIE,
	Kind.SLEIGHT: Target.OWN_DIE,
	Kind.LOADED_DIE: Target.FACE,
	Kind.NUDGE_CUP: Target.NEIGHBOR,
	Kind.SLEEVE_DIE: Target.NONE,
	Kind.ABYSS_WHISPER: Target.FACE,
}

const _NAME_KEY := {
	Kind.PEEK: "CHEAT_PEEK",
	Kind.SLEIGHT: "CHEAT_SLEIGHT",
	Kind.LOADED_DIE: "CHEAT_LOADED_DIE",
	Kind.NUDGE_CUP: "CHEAT_NUDGE_CUP",
	Kind.SLEEVE_DIE: "CHEAT_SLEEVE_DIE",
	Kind.ABYSS_WHISPER: "CHEAT_ABYSS_WHISPER",
}


static func cost(kind: Kind) -> int:
	return _COST[kind]


static func risk(kind: Kind) -> float:
	return _RISK[kind]


static func target(kind: Kind) -> Target:
	return _TARGET[kind]


static func name_key(kind: Kind) -> String:
	return _NAME_KEY[kind]


## «Шёпот Бездны» — сделка с Кракеном, а не жульничество: обвинение его не находит.
static func is_cheating(kind: Kind) -> bool:
	return kind != Kind.ABYSS_WHISPER


## Успешный трюк оставляет улику у портрета (кроме «Шёпота Бездны»).
static func leaves_evidence(kind: Kind) -> bool:
	return is_cheating(kind)


## «Утяжелённая кость» — в фазе броска, остальные — в свой ход до действия.
static func is_roll_phase(kind: Kind) -> bool:
	return kind == Kind.LOADED_DIE


static func targets_neighbor(kind: Kind) -> bool:
	var t := target(kind)
	return t == Target.NEIGHBOR or t == Target.NEIGHBOR_DIE
