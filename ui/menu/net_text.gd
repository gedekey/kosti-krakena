class_name NetText
extends RefCounted
## Ключи локализации для сетевых причин (М19): отказ хоста и обрыв матча.


static func abort_key(reason: int) -> String:
	match reason:
		NetProtocol.Abort.HOST_LEFT:
			return "NET_ABORT_HOST_LEFT"
		NetProtocol.Abort.CONNECTION_FAILED:
			return "NET_ABORT_CONNECT_FAILED"
	return "NET_ABORT_CONNECTION_LOST"


## Текст отказа хоста (уже переведённый). host_version — версия у хоста.
static func reject_text(reason: int, host_version: String) -> String:
	match reason:
		NetProtocol.Reject.VERSION_MISMATCH:
			return TranslationServer.translate("NET_REJECT_VERSION") \
					% [host_version, NetProtocol.game_version()]
		NetProtocol.Reject.FULL:
			return TranslationServer.translate("NET_REJECT_FULL")
		NetProtocol.Reject.IN_PROGRESS:
			return TranslationServer.translate("NET_REJECT_IN_PROGRESS")
	return TranslationServer.translate("NET_REJECT_BAD")
