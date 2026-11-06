extends GutTest
## Статистика (М0, М11): счётчики, подсчёт по событиям матча, флаги, сохранение.

const StatsScript := preload("res://autoload/stats.gd")
const EventsScript := preload("res://autoload/events.gd")
const PATH := "user://test_profile_m11.cfg"

var _stats: Node
var _events: Node


func before_each() -> void:
	_stats = autofree(StatsScript.new())
	_stats.save_path = ""
	_events = autofree(EventsScript.new())
	_stats.listen(_events)


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func test_counters_start_at_zero() -> void:
	for key in StatsScript.KEYS:
		assert_eq(_stats.get_count(key), 0, String(key))


func test_increment_adds_and_emits() -> void:
	watch_signals(_stats)
	_stats.increment(&"matches_won")
	_stats.increment(&"matches_won", 2)
	assert_eq(_stats.get_count(&"matches_won"), 3)
	assert_signal_emitted_with_parameters(_stats, "changed", [&"matches_won", 3])


func test_counts_match_events_for_the_human_only() -> void:
	_events.match_started.emit(4, 0)
	_events.madness_began.emit(2)
	_events.madness_began.emit(0)
	_events.accusation_made.emit(0, 1, true)
	_events.accusation_made.emit(0, 2, false)
	_events.accusation_made.emit(3, 0, true)
	_events.match_ended.emit(0)
	_events.match_started.emit(4, 1)
	_events.match_ended.emit(2)
	assert_eq(_stats.get_count(&"matches_played"), 2)
	assert_eq(_stats.get_count(&"matches_won"), 1)
	assert_eq(_stats.get_count(&"cheaters_caught"), 1)
	assert_eq(_stats.get_count(&"false_accusations"), 1)
	assert_eq(_stats.get_count(&"madness_count"), 1)
	assert_eq(_stats.win_percent(), 50)


func test_recording_off_counts_nothing() -> void:
	_stats.recording = false
	_events.match_started.emit(2, 0)
	_events.match_ended.emit(0)
	assert_eq(_stats.get_count(&"matches_played"), 0)


func test_win_percent_without_matches_is_zero() -> void:
	assert_eq(_stats.win_percent(), 0)
	_stats.increment(&"matches_played", 3)
	_stats.increment(&"matches_won", 2)
	assert_eq(_stats.win_percent(), 67)


func test_flags() -> void:
	assert_false(_stats.has_flag(StatsScript.FLAG_TUTORIAL_DONE))
	watch_signals(_stats)
	_stats.set_flag(StatsScript.FLAG_TUTORIAL_DONE)
	_stats.set_flag(StatsScript.FLAG_TUTORIAL_DONE)
	assert_true(_stats.has_flag(StatsScript.FLAG_TUTORIAL_DONE))
	assert_signal_emit_count(_stats, "flag_set", 1)


func test_reset_keeps_flags() -> void:
	_stats.increment(&"madness_count")
	_stats.set_flag(&"hint_peek")
	_stats.reset()
	assert_eq(_stats.get_count(&"madness_count"), 0)
	assert_true(_stats.has_flag(&"hint_peek"))


func test_save_and_load_round_trip() -> void:
	_stats.save_path = PATH
	_stats.increment(&"matches_played", 7)
	_stats.increment(&"cheaters_caught", 2)
	_stats.set_flag(StatsScript.FLAG_TUTORIAL_DONE)
	var other: Node = autofree(StatsScript.new())
	other.save_path = PATH
	other.load_saved()
	assert_eq(other.get_count(&"matches_played"), 7)
	assert_eq(other.get_count(&"cheaters_caught"), 2)
	assert_eq(other.get_count(&"matches_won"), 0)
	assert_true(other.has_flag(StatsScript.FLAG_TUTORIAL_DONE))


func test_broken_values_are_ignored() -> void:
	var file := ConfigFile.new()
	file.set_value(StatsScript.STATS_SECTION, "matches_played", -5)
	file.set_value(StatsScript.STATS_SECTION, "matches_won", "many")
	file.set_value(StatsScript.STATS_SECTION, "madness_count", 4)
	file.save(PATH)
	var other: Node = autofree(StatsScript.new())
	other.save_path = PATH
	other.load_saved()
	assert_eq(other.get_count(&"matches_played"), 0)
	assert_eq(other.get_count(&"matches_won"), 0)
	assert_eq(other.get_count(&"madness_count"), 4)
