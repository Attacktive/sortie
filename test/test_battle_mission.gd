class_name TestBattleMission
extends GutTest


func test_battle_parameterized_with_m01_spawns_mission_squads() -> void:
	var battle: Battle = load("res://scenes/battle.tscn").instantiate()
	battle.mission_id = "M01_CABBAGE"
	add_child_autofree(battle)
	await get_tree().process_frame

	var grid: BattleGrid = battle._grid
	assert_not_null(grid)
	var players := grid.living_units_of_team(UnitData.Team.PLAYER)
	var enemies := grid.living_units_of_team(UnitData.Team.ENEMY)

	assert_eq(players.size(), 4)
	assert_eq(enemies.size(), 4)

	assert_eq(grid.unit_at(Vector2i(0, 6)).data.unit_name, "Vanguard")
	assert_eq(grid.unit_at(Vector2i(1, 7)).data.unit_name, "Scout")
	assert_eq(grid.unit_at(Vector2i(0, 7)).data.unit_name, "Brute")
	assert_eq(grid.unit_at(Vector2i(1, 6)).data.unit_name, "Raider")

	assert_eq(grid.unit_at(Vector2i(8, 2)).data.unit_name, "Siege Vanguard")
	assert_eq(grid.unit_at(Vector2i(9, 3)).data.unit_name, "Catapult Guard")
