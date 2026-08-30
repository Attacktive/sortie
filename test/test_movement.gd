extends GutTest

func _data(move_range: int, team: UnitData.Team) -> UnitData:
	var data := UnitData.new()
	data.max_hp = 10
	data.move_range = move_range
	data.attack_range = 1
	data.team = team

	return data

func _place(grid: BattleGrid, cell: Vector2i, move_range: int, team: UnitData.Team) -> BattleUnit:
	var unit := BattleUnit.new(_data(move_range, team), cell)
	grid.place_unit(unit, cell)

	return unit

func test_range_is_bounded_by_movement_budget() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".....",
		".....",
		".....",
	]))
	var unit := _place(grid, Vector2i(0, 0), 2, UnitData.Team.PLAYER)
	var field := Movement.field(grid, unit)

	assert_true(field.can_reach(Vector2i(2, 0)), "two tiles east costs 2")
	assert_true(field.can_reach(Vector2i(1, 1)), "one east one south costs 2")
	assert_false(field.can_reach(Vector2i(3, 0)), "three tiles east costs 3")
	assert_eq(field.cost_to(Vector2i(2, 0)), 2)
	assert_eq(field.cost_to(Vector2i(3, 0)), -1)

func test_forest_costs_two_and_eats_the_budget() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".F..",
	]))
	var unit := _place(grid, Vector2i(0, 0), 2, UnitData.Team.PLAYER)
	var field := Movement.field(grid, unit)

	assert_eq(field.cost_to(Vector2i(1, 0)), 2, "entering forest costs 2")
	assert_false(field.can_reach(Vector2i(2, 0)), "no budget left to leave the forest")

func test_walls_are_impassable_and_force_a_detour() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".#.",
		"...",
	]))
	var unit := _place(grid, Vector2i(0, 0), 4, UnitData.Team.PLAYER)
	var field := Movement.field(grid, unit)

	assert_false(field.can_reach(Vector2i(1, 0)), "the wall itself is never reachable")
	assert_eq(field.cost_to(Vector2i(2, 0)), 4, "down, across twice, then back up — not the two-step direct line")

func test_a_wall_can_push_a_nearby_cell_out_of_budget() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".#.",
		"...",
	]))
	var unit := _place(grid, Vector2i(0, 0), 3, UnitData.Team.PLAYER)

	assert_false(Movement.field(grid, unit).can_reach(Vector2i(2, 0)), "two tiles away by sight, four by foot")

func test_enemies_block_movement_entirely() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		"....",
	]))
	var mover := _place(grid, Vector2i(0, 0), 3, UnitData.Team.PLAYER)
	_place(grid, Vector2i(1, 0), 3, UnitData.Team.ENEMY)
	var field := Movement.field(grid, mover)

	assert_false(field.can_reach(Vector2i(1, 0)), "cannot enter an enemy's cell")
	assert_false(field.can_reach(Vector2i(2, 0)), "cannot pass through an enemy")

func test_allies_are_passable_but_not_landable() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		"....",
	]))
	var mover := _place(grid, Vector2i(0, 0), 3, UnitData.Team.PLAYER)
	_place(grid, Vector2i(1, 0), 3, UnitData.Team.PLAYER)
	var field := Movement.field(grid, mover)

	assert_false(field.can_reach(Vector2i(1, 0)), "cannot stop on an ally")
	assert_true(field.can_reach(Vector2i(2, 0)), "but may walk through one")

func test_path_lists_steps_without_the_origin() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		"...",
	]))
	var unit := _place(grid, Vector2i(0, 0), 3, UnitData.Team.PLAYER)
	var path := Movement.field(grid, unit).path_to(Vector2i(2, 0))

	assert_eq(path, [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])

func test_unreachable_target_yields_an_empty_path() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".#.",
	]))
	var unit := _place(grid, Vector2i(0, 0), 3, UnitData.Team.PLAYER)

	assert_eq(Movement.field(grid, unit).path_to(Vector2i(2, 0)).size(), 0)

func test_attack_range_is_manhattan_and_stays_in_bounds() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		"...",
		"...",
		"...",
	]))
	var cells := Movement.attackable_cells(grid, Vector2i(0, 0), 1)

	assert_eq(cells.size(), 2, "a corner has only two orthogonal neighbors")
	assert_true(cells.has(Vector2i(1, 0)))
	assert_true(cells.has(Vector2i(0, 1)))

func test_attack_range_two_reaches_diagonals_and_straights() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		"...",
		"...",
		"...",
	]))
	var cells := Movement.attackable_cells(grid, Vector2i(1, 1), 2)

	assert_true(cells.has(Vector2i(0, 0)), "diagonal is Manhattan distance 2")
	assert_false(cells.has(Vector2i(1, 1)), "a unit does not attack its own cell")
