class_name ENetTransport
extends NetTransport
## Транспорт поверх ENetMultiplayerPeer (UDP, надёжная доставка по порядку).
## Работает с пиром напрямую, без SceneMultiplayer и RPC: пакеты — var_to_bytes словарей,
## приём — bytes_to_var (объекты не декодируются; allow_object_decoding не нужен).

var _peer: ENetMultiplayerPeer
var _server := false
## Гость: связь с хостом установлена (чтобы peer_disconnected(HOST_ID) пришёл один раз).
var _linked := false
var _closed := false


## Хост: слушать порт. null — порт занят или ошибка.
static func host(port := NetBalance.PORT,
		max_guests := MatchController.MAX_PLAYERS - 1) -> ENetTransport:
	var t := ENetTransport.new()
	t._peer = ENetMultiplayerPeer.new()
	if t._peer.create_server(port, max_guests) != OK:
		return null
	t._server = true
	t._setup()
	return t


## Гость: подключиться к хосту. null — адрес не разобран или ошибка сокета.
## Удалось ли подключиться — придёт сигналом из poll().
static func join(address: String, port := NetBalance.PORT) -> ENetTransport:
	var t := ENetTransport.new()
	t._peer = ENetMultiplayerPeer.new()
	if t._peer.create_client(address, port) != OK:
		return null
	t._setup()
	return t


func _setup() -> void:
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)


func is_open() -> bool:
	return not _closed


func poll() -> void:
	if _closed:
		return
	_peer.poll()
	while not _closed and _peer.get_available_packet_count() > 0:
		var from := _peer.get_packet_peer()
		var msg: Variant = NetTransport.decode(_peer.get_packet())
		if msg != null:
			message_received.emit(from, msg)
	if not _closed and not _server and not _linked \
			and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		# Подключиться не удалось.
		_close_with_signal()


func send(peer_id: int, msg: Dictionary) -> void:
	if _closed:
		return
	_peer.set_target_peer(peer_id)
	_peer.put_packet(NetTransport.encode(msg))


func kick(peer_id: int) -> void:
	if not _closed and _server:
		_peer.disconnect_peer(peer_id)


func close() -> void:
	if _closed:
		return
	_closed = true
	# Отправить то, что в очереди (отказ, «хост вышел»), и закрыть.
	if _peer.host != null:
		_peer.host.flush()
	_peer.close()


func _on_peer_connected(peer_id: int) -> void:
	var enet_peer := _peer.get_peer(peer_id)
	if enet_peer != null:
		enet_peer.set_timeout(0, NetBalance.PEER_TIMEOUT_MS / 2, NetBalance.PEER_TIMEOUT_MS)
	if not _server:
		_linked = true
	peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if _server:
		peer_disconnected.emit(peer_id)
	elif _linked:
		_close_with_signal()


func _close_with_signal() -> void:
	_linked = false
	close()
	peer_disconnected.emit(NetTransport.HOST_ID)
