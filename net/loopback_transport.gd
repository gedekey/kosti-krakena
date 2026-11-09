class_name LoopbackTransport
extends NetTransport
## Транспорт в памяти для тестов: хост и гости в одном процессе. Сообщения проходят
## var_to_bytes / bytes_to_var и доставляются только в poll() получателя — как по сети.
##
##   var host := LoopbackTransport.make_host()
##   var guest := host.connect_guest()

var peer_id := HOST_ID
## Все пакеты, пришедшие сюда (для проверок в тестах): [from, PackedByteArray].
var received_log: Array = []

## У гостя — хост (слабая ссылка: хост держит гостей, иначе цикл RefCounted).
var _host_ref: WeakRef
var _guests := {}
var _next_id := HOST_ID + 1
## Очередь: ["msg", from, bytes] | ["up", peer] | ["down", peer].
var _inbox: Array = []
var _closed := false


func _is_guest() -> bool:
	return _host_ref != null


func _host() -> LoopbackTransport:
	return null if _host_ref == null else _host_ref.get_ref()


static func make_host() -> LoopbackTransport:
	return LoopbackTransport.new()


## Хост: новый гость подключается. Оба узнают об этом в своём poll().
func connect_guest() -> LoopbackTransport:
	assert(not _is_guest(), "connect_guest only on host")
	var guest := LoopbackTransport.new()
	guest._host_ref = weakref(self)
	guest.peer_id = _next_id
	_next_id += 1
	if _closed:
		guest._inbox.append(["down", HOST_ID])
		return guest
	_guests[guest.peer_id] = guest
	_inbox.append(["up", guest.peer_id])
	guest._inbox.append(["up", HOST_ID])
	return guest


func is_open() -> bool:
	return not _closed


func poll() -> void:
	while not _inbox.is_empty() and not _closed:
		var item: Array = _inbox.pop_front()
		match item[0]:
			"up":
				peer_connected.emit(item[1])
			"down":
				if _is_guest():
					_closed = true
				peer_disconnected.emit(item[1])
			"msg":
				received_log.append([item[1], item[2]])
				var msg: Variant = NetTransport.decode(item[2])
				if msg != null:
					message_received.emit(item[1], msg)


func send(to: int, msg: Dictionary) -> void:
	deliver_raw(to, NetTransport.encode(msg))


## Отправить произвольные байты (тесты кривых пакетов).
func deliver_raw(to: int, bytes: PackedByteArray) -> void:
	if _closed:
		return
	var target: LoopbackTransport = _host() if _is_guest() else _guests.get(to)
	if target == null or target._closed or (_is_guest() and to != HOST_ID):
		return
	target._inbox.append(["msg", peer_id, bytes])


func kick(guest_id: int) -> void:
	if _is_guest() or not _guests.has(guest_id):
		return
	var guest: LoopbackTransport = _guests[guest_id]
	_guests.erase(guest_id)
	guest._inbox.append(["down", HOST_ID])
	_inbox.append(["down", guest_id])


func close() -> void:
	if _closed:
		return
	_closed = true
	if _is_guest():
		var host := _host()
		if host != null and host._guests.get(peer_id) == self:
			host._guests.erase(peer_id)
			host._inbox.append(["down", peer_id])
	else:
		for guest: LoopbackTransport in _guests.values():
			guest._inbox.append(["down", HOST_ID])
		_guests.clear()
