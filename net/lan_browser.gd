class_name LanBrowser
extends RefCounted
## Список игр в локальной сети у гостя (М19): ловит объявления LanBeacon на
## NetBalance.DISCOVERY_PORT. Игра пропадает из списка, если объявлений от неё нет
## GAME_LIST_TTL_MS. Широковещательный приём включён явно — на Android только так
## берётся блокировка мультикаста (разрешение CHANGE_WIFI_MULTICAST_STATE).

## Список игр изменился (появилась, пропала, поменялось число мест).
signal changed


class Game:
	var address := ""
	var port := NetBalance.PORT
	var host_name := ""
	var humans := 1
	var seats := 2
	var version := ""
	var seen_at := 0

	## Версия совпадает с нашей — можно подключаться.
	func is_compatible() -> bool:
		return version == NetProtocol.game_version()


var _socket: PacketPeerUDP
var _clock: Callable
## address → Game
var _games := {}


func _init(clock := Callable()) -> void:
	_clock = clock if clock.is_valid() else Callable(Time, &"get_ticks_msec")


## Слушать порт. false — порт занят (например, вторая копия игры на этом ПК).
func start() -> bool:
	_socket = PacketPeerUDP.new()
	_socket.set_broadcast_enabled(true)
	if _socket.bind(NetBalance.DISCOVERY_PORT) != OK:
		_socket = null
		return false
	return true


func is_listening() -> bool:
	return _socket != null


func stop() -> void:
	if _socket != null:
		_socket.close()
		_socket = null


## Звать каждый кадр.
func update() -> void:
	var dirty := false
	if _socket != null:
		while _socket.get_available_packet_count() > 0:
			var packet := _socket.get_packet()
			var address := _socket.get_packet_ip()
			dirty = _receive(address, packet) or dirty
	dirty = _expire() or dirty
	if dirty:
		changed.emit()


## Принять объявление (из сокета или из теста). true — список изменился.
func feed(address: String, packet: PackedByteArray) -> bool:
	var dirty := _receive(address, packet)
	if dirty:
		changed.emit()
	return dirty


func _receive(address: String, packet: PackedByteArray) -> bool:
	var info: Variant = LanBeacon.read_packet(packet)
	if info == null or address == "":
		return false
	var game: Game = _games.get(address)
	var fresh := game == null
	if fresh:
		game = Game.new()
		game.address = address
		_games[address] = game
	var dirty: bool = fresh or game.host_name != info["name"] or game.humans != info["humans"] \
			or game.seats != info["seats"] or game.version != info["version"]
	game.host_name = info["name"]
	game.humans = info["humans"]
	game.seats = info["seats"]
	game.version = info["version"]
	game.port = info["port"]
	game.seen_at = _clock.call()
	return dirty


func _expire() -> bool:
	var now: int = _clock.call()
	var dirty := false
	for address: String in _games.keys():
		if now - (_games[address] as Game).seen_at > NetBalance.GAME_LIST_TTL_MS:
			_games.erase(address)
			dirty = true
	return dirty


## Найденные игры по адресу.
func games() -> Array[Game]:
	var out: Array[Game] = []
	var keys := _games.keys()
	keys.sort()
	for address: String in keys:
		out.append(_games[address])
	return out
