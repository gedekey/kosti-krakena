extends GutTest
## Пример теста и проверка главного требования к случайности: детерминизм по seed.

const RngScript := preload("res://autoload/rng.gd")


func _roll_sequence(rng: RandomNumberGenerator, count: int) -> Array[int]:
	var result: Array[int] = []
	for i in count:
		result.append(rng.randi_range(1, 6))
	return result


func test_same_seed_gives_same_rolls() -> void:
	var a := RngScript.make_seeded(42)
	var b := RngScript.make_seeded(42)
	assert_eq(_roll_sequence(a, 20), _roll_sequence(b, 20))


func test_different_seeds_give_different_rolls() -> void:
	var a := RngScript.make_seeded(1)
	var b := RngScript.make_seeded(2)
	assert_ne(_roll_sequence(a, 20), _roll_sequence(b, 20))


func test_master_seed_makes_child_rngs_reproducible() -> void:
	var factory_a: Node = autofree(RngScript.new())
	var factory_b: Node = autofree(RngScript.new())
	factory_a.set_master_seed(7)
	factory_b.set_master_seed(7)
	assert_eq(_roll_sequence(factory_a.make_rng(), 10), _roll_sequence(factory_b.make_rng(), 10))
