extends GutTest
## Ставка: значение, форма, сравнение на равенство.


func test_stores_quantity_and_face() -> void:
	var bid := Bid.new(3, 5)
	assert_eq(bid.quantity, 3)
	assert_eq(bid.face, 5)


func test_is_ones() -> void:
	assert_true(Bid.new(2, 1).is_ones())
	assert_false(Bid.new(2, 6).is_ones())


func test_well_formed() -> void:
	assert_true(Bid.new(1, 1).is_well_formed())
	assert_true(Bid.new(30, 6).is_well_formed())
	assert_false(Bid.new(0, 3).is_well_formed(), "количество 0")
	assert_false(Bid.new(2, 0).is_well_formed(), "грань 0")
	assert_false(Bid.new(2, 7).is_well_formed(), "грань 7")


func test_equals() -> void:
	assert_true(Bid.new(4, 2).equals(Bid.new(4, 2)))
	assert_false(Bid.new(4, 2).equals(Bid.new(4, 3)))
	assert_false(Bid.new(4, 2).equals(null))


func test_to_string() -> void:
	assert_eq(str(Bid.new(4, 2)), "4x2")
