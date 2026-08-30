extends GutTest

func test_plain_costs_one_and_grants_nothing() -> void:
	assert_eq(Terrain.move_cost(Terrain.Type.PLAIN), 1)
	assert_eq(Terrain.defense_bonus(Terrain.Type.PLAIN), 0)
	assert_almost_eq(Terrain.evasion_bonus(Terrain.Type.PLAIN), 0.0, 0.0001)

func test_forest_costs_two_and_grants_cover() -> void:
	assert_eq(Terrain.move_cost(Terrain.Type.FOREST), 2)
	assert_eq(Terrain.defense_bonus(Terrain.Type.FOREST), 2)
	assert_almost_eq(Terrain.evasion_bonus(Terrain.Type.FOREST), 0.2, 0.0001)

func test_walls_are_impassable_and_everything_else_is_not() -> void:
	assert_false(Terrain.is_passable(Terrain.Type.WALL))
	assert_true(Terrain.is_passable(Terrain.Type.PLAIN))
	assert_true(Terrain.is_passable(Terrain.Type.FOREST))
