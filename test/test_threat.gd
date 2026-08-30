extends GutTest

func _place(grid: BattleGrid, cell: Vector2i, move_range: int, attack_range: int) -> BattleUnit:
	var data := UnitData.new()
	data.max_hp = 10
	data.move_range = move_range
	data.attack_range = attack_range
	data.team = UnitData.Team.ENEMY
	var unit := BattleUnit.new(data, cell)
	grid.place_unit(unit, cell)

	return unit

func _open_field() -> BattleGrid:
	return BattleGrid.from_ascii(PackedStringArray([
		".....",
		".....",
		".....",
		".....",
		".....",
	]))

func test_a_rooted_unit_threatens_only_its_own_reach() -> void:
	var grid := _open_field()
	var unit := _place(grid, Vector2i(2, 2), 0, 1)

	var threat := Movement.threat_cells(grid, unit)

	assert_eq(threat.size(), 4, "four orthogonal neighbors and nothing else")
	assert_true(threat.has(Vector2i(2, 1)))
	assert_true(threat.has(Vector2i(1, 2)))
	assert_false(threat.has(Vector2i(0, 2)), "two tiles away is out of reach when it cannot move")

func test_movement_widens_the_threat_to_a_diamond() -> void:
	var grid := _open_field()
	var unit := _place(grid, Vector2i(2, 2), 1, 1)

	var threat := Movement.threat_cells(grid, unit)

	assert_eq(threat.size(), 13, "the Manhattan radius-2 diamond, centre included")
	assert_true(threat.has(Vector2i(0, 2)), "reachable by moving one then striking one")
	assert_true(threat.has(Vector2i(2, 0)))
	assert_false(threat.has(Vector2i(0, 0)), "a diagonal corner is Manhattan distance 4")

func test_reach_two_threatens_further_than_it_can_walk() -> void:
	var grid := _open_field()
	var unit := _place(grid, Vector2i(2, 2), 0, 2)

	var threat := Movement.threat_cells(grid, unit)

	assert_true(threat.has(Vector2i(0, 2)), "an archer strikes two tiles without moving")
	assert_false(threat.has(Vector2i(2, 2)), "it does not threaten the tile it stands on")

func test_walls_shrink_the_threat() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		"..#..",
		"..#..",
		"..#..",
	]))
	var unit := _place(grid, Vector2i(0, 1), 3, 1)

	var threat := Movement.threat_cells(grid, unit)

	assert_false(threat.has(Vector2i(3, 1)), "the wall column cannot be crossed or reached past")
	assert_true(threat.has(Vector2i(2, 1)), "but the wall tile itself is still within striking distance")

func test_threat_never_leaves_the_board() -> void:
	var grid := _open_field()
	var unit := _place(grid, Vector2i(0, 0), 1, 1)

	for cell in Movement.threat_cells(grid, unit):
		assert_true(grid.is_in_bounds(cell), "%s is off the board" % cell)
