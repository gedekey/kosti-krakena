class_name BidEntry
extends RefCounted
## Запись в ленте ставок раунда: кто и что поставил.

var player_id: int
var bid: Bid


func _init(p_player_id: int, p_bid: Bid) -> void:
	player_id = p_player_id
	bid = p_bid
