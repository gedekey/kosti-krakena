class_name HumanAgent
extends MatchAgent
## Живой игрок: действия приходят из UI через MatchController.submit_action.


func is_human() -> bool:
	return true
