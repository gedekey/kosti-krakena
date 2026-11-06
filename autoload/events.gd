extends Node
## Глобальная шина событий.
##
## Логика матча (match/) объявляет здесь сигналы и испускает их, UI только подписывается.
## Сигналы добавляются модулями по мере необходимости (М2 — фазы матча, М4 — трюки и т.д.).
## Правил здесь нет — только сигналы.

## Язык интерфейса сменился (испускает Settings).
signal locale_changed(locale: String)

# --- Матч (М2) ---------------------------------------------------------------
# Пробрасываются из MatchController через MatchEventBridge.
# Имена и параметры совпадают с сигналами MatchController.

## phase — MatchController.Phase.
signal phase_changed(phase: int)
signal match_started(player_count: int, first_player: int)
signal round_started(round_number: int, starter_id: int, is_palifico: bool)
signal dice_rolled(round_number: int)
signal turn_started(player_id: int)
signal bid_placed(player_id: int, bid: Bid)
signal challenge_revealed(reveal: ChallengeReveal)
signal dice_count_changed(player_id: int, count: int, delta: int)
signal player_eliminated(player_id: int)
signal round_ended(next_starter_id: int, next_is_palifico: bool)
signal match_ended(winner_id: int)
