extends GutTest

func test_the_map_is_the_expected_shape() -> void:
	var grid := Scenario.build_grid()

	assert_eq(grid.size, Vector2i(10, 8))

func test_both_teams_are_present() -> void:
	var grid := Scenario.build_grid()
	Scenario.populate(grid)

	assert_eq(grid.living_units_of_team(UnitData.Team.PLAYER).size(), 3)
	assert_eq(grid.living_units_of_team(UnitData.Team.ENEMY).size(), 3)

func test_every_unit_starts_in_bounds_on_passable_ground() -> void:
	var grid := Scenario.build_grid()

	for unit in Scenario.populate(grid):
		assert_true(grid.is_in_bounds(unit.cell), "%s starts out of bounds at %s" % [unit.data.unit_name, unit.cell])
		assert_true(Terrain.is_passable(grid.terrain_at(unit.cell)), "%s starts inside a wall" % unit.data.unit_name)

func test_no_two_units_share_a_cell() -> void:
	var grid := Scenario.build_grid()
	var seen: Dictionary[Vector2i, bool] = {}

	for unit in Scenario.populate(grid):
		assert_false(seen.has(unit.cell), "two units start on %s" % unit.cell)
		seen[unit.cell] = true

func test_the_battle_does_not_open_already_resolved() -> void:
	var grid := Scenario.build_grid()
	Scenario.populate(grid)
	var turns := TurnOrder.new(grid)
	turns.check_resolution()

	assert_false(turns.is_over(), "someone would have to be wiped out before the first move")

func test_the_teams_do_not_start_within_reach_of_each_other() -> void:
	var grid := Scenario.build_grid()
	Scenario.populate(grid)

	for player in grid.living_units_of_team(UnitData.Team.PLAYER):
		for enemy in grid.living_units_of_team(UnitData.Team.ENEMY):
			var reach: int = maxi(player.data.attack_range, enemy.data.attack_range)
			assert_true(Movement.manhattan(player.cell, enemy.cell) > reach, "the armies start already in contact")
