extends GutTest

func _grid() -> BattleGrid:
	return BattleGrid.from_ascii(PackedStringArray([
		"..F.",
		".#..",
		"....",
	]))

func _unit(team: UnitData.Team) -> BattleUnit:
	var data := UnitData.new()
	data.max_hp = 10
	data.team = team

	return BattleUnit.new(data, Vector2i.ZERO)

func test_ascii_sets_size_and_terrain() -> void:
	var grid := _grid()
	assert_eq(grid.size, Vector2i(4, 3))
	assert_eq(grid.terrain_at(Vector2i(0, 0)), Terrain.Type.PLAIN)
	assert_eq(grid.terrain_at(Vector2i(2, 0)), Terrain.Type.FOREST)
	assert_eq(grid.terrain_at(Vector2i(1, 1)), Terrain.Type.WALL)

func test_out_of_bounds_reads_as_wall() -> void:
	var grid := _grid()
	assert_false(grid.is_in_bounds(Vector2i(-1, 0)))
	assert_false(grid.is_in_bounds(Vector2i(4, 0)))
	assert_eq(grid.terrain_at(Vector2i(-1, 0)), Terrain.Type.WALL)
	assert_eq(grid.terrain_at(Vector2i(99, 99)), Terrain.Type.WALL)

func test_placing_and_moving_updates_occupancy() -> void:
	var grid := _grid()
	var unit := _unit(UnitData.Team.PLAYER)
	grid.place_unit(unit, Vector2i(0, 0))
	assert_eq(grid.unit_at(Vector2i(0, 0)), unit)
	assert_eq(unit.cell, Vector2i(0, 0))

	grid.move_unit(unit, Vector2i(2, 2))
	assert_null(grid.unit_at(Vector2i(0, 0)))
	assert_eq(grid.unit_at(Vector2i(2, 2)), unit)
	assert_eq(unit.cell, Vector2i(2, 2))

func test_empty_cell_has_no_unit() -> void:
	assert_null(_grid().unit_at(Vector2i(3, 2)))

func test_living_units_of_team_excludes_the_dead() -> void:
	var grid := _grid()
	var alive := _unit(UnitData.Team.PLAYER)
	var dead := _unit(UnitData.Team.PLAYER)
	var enemy := _unit(UnitData.Team.ENEMY)
	grid.place_unit(alive, Vector2i(0, 0))
	grid.place_unit(dead, Vector2i(0, 2))
	grid.place_unit(enemy, Vector2i(3, 0))
	dead.hp = 0

	var players := grid.living_units_of_team(UnitData.Team.PLAYER)
	assert_eq(players.size(), 1)
	assert_eq(players[0], alive)
