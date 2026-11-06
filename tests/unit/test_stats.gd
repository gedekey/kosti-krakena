extends GutTest

const StatsScript := preload("res://autoload/stats.gd")

var _stats: Node


func before_each() -> void:
	_stats = autofree(StatsScript.new())


func test_counters_start_at_zero() -> void:
	for key in StatsScript.KEYS:
		assert_eq(_stats.get_count(key), 0, String(key))


func test_increment_adds_and_emits() -> void:
	watch_signals(_stats)
	_stats.increment(&"matches_won")
	_stats.increment(&"matches_won", 2)
	assert_eq(_stats.get_count(&"matches_won"), 3)
	assert_signal_emitted_with_parameters(_stats, "changed", [&"matches_won", 3])
