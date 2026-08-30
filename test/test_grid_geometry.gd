extends GutTest

## These assert relationships to CELL_SIZE rather than baked-in pixel values,
## so changing the cell size is a one-line change and not a test rewrite.

const CELL := GridGeometry.CELL_SIZE

func test_a_cell_maps_to_its_top_left_corner() -> void:
	assert_eq(GridGeometry.cell_to_position(Vector2i(0, 0)), Vector2(0, 0))
	assert_eq(GridGeometry.cell_to_position(Vector2i(2, 3)), Vector2(2 * CELL, 3 * CELL))

func test_cell_center_is_half_a_cell_in() -> void:
	assert_eq(GridGeometry.cell_center(Vector2i(0, 0)), Vector2(CELL, CELL) * 0.5)
	assert_eq(GridGeometry.cell_center(Vector2i(1, 1)), Vector2(CELL, CELL) * 1.5)

func test_a_position_maps_back_to_its_cell() -> void:
	assert_eq(GridGeometry.position_to_cell(Vector2(0, 0)), Vector2i(0, 0))
	assert_eq(GridGeometry.position_to_cell(Vector2(CELL - 1, CELL - 1)), Vector2i(0, 0), "still inside the first cell")
	assert_eq(GridGeometry.position_to_cell(Vector2(CELL, 0)), Vector2i(1, 0), "one pixel further is the next cell")

func test_negative_positions_floor_rather_than_truncate() -> void:
	assert_eq(GridGeometry.position_to_cell(Vector2(-1, -1)), Vector2i(-1, -1), "truncation would wrongly give (0, 0)")

func test_the_round_trip_is_stable() -> void:
	for x in 5:
		for y in 5:
			var cell := Vector2i(x, y)
			assert_eq(GridGeometry.position_to_cell(GridGeometry.cell_center(cell)), cell)

func test_a_cell_holds_an_lpc_sprite_exactly() -> void:
	assert_eq(CELL, 64, "LPC characters are 64x64; any other cell size scales them and ruins the pixel art")
