class_name NetTransport
extends RefCounted
## Канал сообщений хост ↔ гости. Хост — HOST_ID, у гостей — свои id.
## Реализации: ENetTransport (UDP, игра) и LoopbackTransport (в памяти, тесты).
##
## Сигналы испускаются только из poll() — сессия сама решает, когда принимать сообщения.
## У гостя: связь с хостом появилась — peer_connected(HOST_ID), пропала или не
## установилась — peer_disconnected(HOST_ID).
## Пакет разбирается bytes_to_var (без объектов); не словарь или слишком большой —
## отбрасывается здесь же.

const HOST_ID := 1

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal message_received(peer_id: int, msg: Dictionary)


## Принять входящее и испустить сигналы.
func poll() -> void:
	pass


## Отправить сообщение (надёжно, по порядку).
func send(_peer_id: int, _msg: Dictionary) -> void:
	pass


## Хост: разорвать связь с гостем.
func kick(_peer_id: int) -> void:
	pass


## Закрыть канал. Сигналов после этого нет.
func close() -> void:
	pass


func is_open() -> bool:
	return false


static func encode(msg: Dictionary) -> PackedByteArray:
	return var_to_bytes(msg)


## Пакет → словарь или null (кривой, слишком большой, с объектами).
static func decode(packet: PackedByteArray) -> Variant:
	if packet.is_empty() or packet.size() > NetBalance.MAX_PACKET_BYTES:
		return null
	var v: Variant = bytes_to_var(packet)
	if typeof(v) != TYPE_DICTIONARY:
		return null
	return v
