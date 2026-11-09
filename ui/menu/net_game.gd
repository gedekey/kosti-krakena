class_name NetGame
extends RefCounted
## Сетевая игра между экранами меню (М19): сессия, которую экран «Сетевая игра» передаёт
## лобби, и сообщение, которое лобби оставляет экрану «Сетевая игра» (отказ, хост вышел).
## Стол получает сессию через MatchSetup.session.

## Сессия для лобби: HostSession (создал игру) или ClientSession (подключился).
static var session: MatchSession
## Уже переведённый текст для экрана «Сетевая игра» ("" — нет).
static var notice := ""


## Забрать сессию (экран лобби).
static func take_session() -> MatchSession:
	var s := session
	session = null
	return s


static func take_notice() -> String:
	var n := notice
	notice = ""
	return n


## Имя игрока для сети: из настроек, иначе — «Игрок».
static func player_name() -> String:
	var n := SeatInfo.clean_name(String(Settings.get_value(&"net_name")))
	return n if n != "" else TranslationServer.translate("NET_DEFAULT_NAME")


## Номер портрета игрока (тот же выбор, что на экране соперников).
static func player_portrait() -> int:
	return maxi(Sprites.PLAYER_PORTRAITS.find(
			StringName(Settings.get_value(&"player_portrait"))), 0)


## Подпись к своему адресу: Radmin VPN узнаётся по сети 26.x.
static func address_caption(address: String) -> String:
	if LanBeacon.is_radmin(address):
		return TranslationServer.translate("NET_ADDRESS_RADMIN") % address
	return address
