extends SceneTree
## Консольная симуляция ботов (М3). Запуск: tools/run_simulation.ps1
## Параметры (после «--»): --duels=N --tables=N --players=N --seed=N
##   --duels   матчей на каждую пару персонажей в дуэлях 1×1 (по умолчанию 200)
##   --tables  матчей за общими столами (по умолчанию 2000)
##   --players игроков за столом (по умолчанию 4)
##   --seed    seed (по умолчанию случайный)

const DEFAULT_DUELS := 200
const DEFAULT_TABLES := 2000


func _initialize() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var rng := RandomNumberGenerator.new()
	if args.has("seed"):
		rng.seed = int(args["seed"])
	else:
		rng.randomize()
	var duels := int(args.get("duels", DEFAULT_DUELS))
	var tables := int(args.get("tables", DEFAULT_TABLES))
	var players := int(args.get("players", BotSimulation.DEFAULT_TABLE_SIZE))
	print("Кости Кракена — симуляция ботов, seed %d" % rng.seed)
	var started := Time.get_ticks_msec()
	print(BotSimulation.report(BotRoster.all(), duels, tables, players, rng))
	print("\nГотово за %.1f с" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit(0)


func _parse_args(raw: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in raw:
		if arg.begins_with("--") and arg.contains("="):
			var parts := arg.substr(2).split("=", true, 1)
			out[parts[0]] = parts[1]
	return out
