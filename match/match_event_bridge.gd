class_name MatchEventBridge
extends RefCounted
## Пробрасывает все сигналы MatchController в глобальную шину (автолоад Events).
## Шина передаётся параметром, чтобы логика не зависела от автолоадов.
## М19: источник — MatchController или MatchSession. Сигналы сессии, которых нет
## в шине (сетевые: seat_replaced, match_aborted, …), стол слушает у сессии сам.


static func connect_all(source: Object, bus: Object) -> void:
	for sig in source.get_script().get_script_signal_list():
		var sig_name: StringName = sig["name"]
		if source is MatchController:
			assert(bus.has_signal(sig_name), "Events has no signal %s" % sig_name)
		elif not bus.has_signal(sig_name):
			continue
		source.connect(sig_name, _forwarder(bus, sig_name, sig["args"].size()))


static func _forwarder(bus: Object, sig_name: StringName, argc: int) -> Callable:
	match argc:
		0:
			return func() -> void: bus.emit_signal(sig_name)
		1:
			return func(a) -> void: bus.emit_signal(sig_name, a)
		2:
			return func(a, b) -> void: bus.emit_signal(sig_name, a, b)
		3:
			return func(a, b, c) -> void: bus.emit_signal(sig_name, a, b, c)
	push_error("Unsupported signal arity: %s" % sig_name)
	return Callable()
