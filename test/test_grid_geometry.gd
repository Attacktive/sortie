extends GutTest

func test_a_cell_maps_to_its_top_left_corner() -> void:
	assert_eq(GridGeometry.cell_to_position(Vector2i(0, 0)), Vector2(0, 0))
	assert_eq(GridGeometry.cell_to_position(Vector2i(2, 3)), Vector2(96, 144))

func test_cell_center_is_half_a_cell_in() -> void:
	assert_eq(GridGeometry.cell_center(Vector2i(0, 0)), Vector2(24, 24))
	assert_eq(GridGeometry.cell_center(Vector2i(1, 1)), Vector2(72, 72))

func test_a_position_maps_back_to_its_cell() -> void:
	assert_eq(GridGeometry.position_to_cell(Vector2(0, 0)), Vector2i(0, 0))
	assert_eq(GridGeometry.position_to_cell(Vector2(47, 47)), Vector2i(0, 0), "still inside the first cell")
	assert_eq(GridGeometry.position_to_cell(Vector2(48, 0)), Vector2i(1, 0))

func test_negative_positions_floor_rather_than_truncate() -> void:
	assert_eq(GridGeometry.position_to_cell(Vector2(-1, -1)), Vector2i(-1, -1), "truncation would wrongly give (0, 0)")

func test_the_round_trip_is_stable() -> void:
	for x in 5:
		for y in 5:
			var cell := Vector2i(x, y)
			assert_eq(GridGeometry.position_to_cell(GridGeometry.cell_center(cell)), cell)
