class_name LanBeacon
extends RefCounted
## Объявление об игре в локальной сети (М19, DESIGN.md §8б). Хост в лобби раз в секунду
## рассылает широковещательный UDP-пакет: название (имя хоста), сколько мест занято
## людьми и сколько всего, версия, порт игры. Гости ловят его LanBrowser'ом.
##
## Рассылка — на 255.255.255.255 и на широковещательные адреса своих сетей
## (x.y.z.255; у Radmin VPN сеть 26.0.0.0/8 — ещё 26.255.255.255): адрес «всем»
## Windows отправляет только через основной сетевой адаптер.

const MAGIC := "kraken-dice"

var _socket: PacketPeerUDP
var _clock: Callable
var _last_sent := -NetBalance.BEACON_INTERVAL_MS
var _targets: PackedStringArray = []
var _packet := PackedByteArray()


## clock — Callable без аргументов, миллисекунды (по умолчанию Time.get_ticks_msec).
func _init(clock := Callable()) -> void:
	_clock = clock if clock.is_valid() else Callable(Time, &"get_ticks_msec")
	_targets = broadcast_targets(local_ipv4())


## Начать рассылку. false — сокет не открылся (объявлений не будет, игра всё равно
## доступна по IP).
func start() -> bool:
	_socket = PacketPeerUDP.new()
	_socket.set_broadcast_enabled(true)
	if _socket.bind(0) != OK:
		_socket = null
		return false
	return true


func stop() -> void:
	if _socket != null:
		_socket.close()
		_socket = null


## Что объявлять. Можно звать каждый кадр — пакет пересобирается.
func set_info(host_name: String, humans: int, seats: int, version := "") -> void:
	_packet = make_packet(host_name, humans, seats, version)


## Звать каждый кадр: раз в BEACON_INTERVAL_MS — рассылка.
func update() -> void:
	if _socket == null or _packet.is_empty():
		return
	var now: int = _clock.call()
	if now - _last_sent < NetBalance.BEACON_INTERVAL_MS:
		return
	_last_sent = now
	for address in _targets:
		_socket.set_dest_address(address, NetBalance.DISCOVERY_PORT)
		_socket.put_packet(_packet)


# --- Пакет -----------------------------------------------------------------------

static func make_packet(host_name: String, humans: int, seats: int,
		version := "") -> PackedByteArray:
	return var_to_bytes({
		"g": MAGIC,
		"ver": version if version != "" else NetProtocol.game_version(),
		"name": SeatInfo.clean_name(host_name),
		"n": humans,
		"max": seats,
		"port": NetBalance.PORT,
	})


## Пакет → {name, humans, seats, version, port} или null (чужой, кривой).
static func read_packet(packet: PackedByteArray) -> Variant:
	var v: Variant = NetTransport.decode(packet)
	if v == null or typeof(v.get("g")) != TYPE_STRING or v["g"] != MAGIC:
		return null
	var ver: Variant = v.get("ver")
	var host_name: Variant = v.get("name")
	var n: Variant = v.get("n")
	var total: Variant = v.get("max")
	var port: Variant = v.get("port")
	if typeof(ver) != TYPE_STRING or ver.length() > 64 or typeof(host_name) != TYPE_STRING \
			or host_name.length() > NetBalance.MAX_NAME_LENGTH or typeof(n) != TYPE_INT \
			or typeof(total) != TYPE_INT or typeof(port) != TYPE_INT:
		return null
	if total < MatchController.MIN_PLAYERS or total > MatchController.MAX_PLAYERS \
			or n < 1 or n > total or port <= 0 or port > 65535:
		return null
	return {"name": host_name, "humans": n, "seats": total, "version": ver, "port": port}


# --- Адреса ------------------------------------------------------------------------

## Свои IPv4-адреса (без 127.x и 169.254.x), адреса Radmin (26.x) — первыми.
static func local_ipv4() -> PackedStringArray:
	var radmin: PackedStringArray = []
	var other: PackedStringArray = []
	for address in IP.get_local_addresses():
		if not address.is_valid_ip_address() or address.contains(":"):
			continue
		if address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if is_radmin(address):
			radmin.append(address)
		else:
			other.append(address)
	radmin.sort()
	other.sort()
	radmin.append_array(other)
	return radmin


## Адрес из сети Radmin VPN (26.0.0.0/8).
static func is_radmin(address: String) -> bool:
	return address.begins_with("26.")


## Куда рассылать объявление при таких своих адресах.
static func broadcast_targets(addresses: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = ["255.255.255.255"]
	for address in addresses:
		var parts := address.split(".")
		if parts.size() != 4:
			continue
		var subnet := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
		if not subnet in out:
			out.append(subnet)
		if is_radmin(address) and not "26.255.255.255" in out:
			out.append("26.255.255.255")
	return out
