class_name TestMissionData
extends GutTest


func test_mission_data_defaults_and_properties() -> void:
	var mission := MissionData.new()
	assert_eq(mission.mission_id, "")
	assert_eq(mission.title, "")
	assert_eq(mission.map_ascii.size(), 0)
	assert_eq(mission.player_roster.size(), 0)
	assert_eq(mission.enemy_roster.size(), 0)
	assert_eq(mission.player_spawns.size(), 0)
	assert_eq(mission.enemy_spawns.size(), 0)
	assert_eq(mission.turn_dialogue_triggers.size(), 0)
	assert_eq(mission.area_dialogue_triggers.size(), 0)
	assert_null(mission.victory_debrief)
	assert_null(mission.defeat_debrief)
	assert_eq(mission.completion_flag, "mission_m01_completed")


func test_mission_registry_builds_m01_cabbage() -> void:
	var mission := MissionRegistry.get_mission("M01_CABBAGE")
	assert_not_null(mission)
	assert_eq(mission.mission_id, "M01_CABBAGE")
	assert_eq(mission.title, "The Cabbage Trajectory")
	assert_eq(mission.map_ascii.size(), 8)
	assert_eq(mission.player_roster.size(), 4)
	assert_eq(mission.enemy_roster.size(), 4)
	assert_eq(mission.player_spawns.size(), 4)
	assert_eq(mission.enemy_spawns.size(), 4)
	assert_true(mission.turn_dialogue_triggers.has(1))
	assert_gt(mission.area_dialogue_triggers.size(), 0)
	assert_not_null(mission.victory_debrief)
	assert_not_null(mission.defeat_debrief)
	assert_eq(mission.completion_flag, "mission_m01_completed")


func test_m01_spawns_are_walkable_and_unique() -> void:
	var mission := MissionRegistry.get_mission("M01_CABBAGE")
	assert_not_null(mission)
	if mission == null:
		return

	var grid := MissionRegistry.build_battle_grid(mission)
	assert_not_null(grid)
	if grid == null:
		return

	var units := MissionRegistry.populate_units(grid, mission)
	assert_eq(units.size(), mission.player_roster.size() + mission.enemy_roster.size())

	var cells: Dictionary[Vector2i, bool] = {}
	for unit in units:
		assert_true(Terrain.is_passable(grid.terrain_at(unit.cell)), "%s spawned on impassable terrain at %s" % [unit.data.unit_name, unit.cell])
		assert_false(cells.has(unit.cell), "duplicate spawn at %s" % unit.cell)
		cells[unit.cell] = true


func test_populate_units_rejects_invalid_spawn_data() -> void:
	var count_mismatch := MissionData.new()
	count_mismatch.mission_id = "COUNT_MISMATCH"
	count_mismatch.map_ascii = PackedStringArray(["."])
	count_mismatch.player_roster = [UnitData.new()]
	var count_grid := MissionRegistry.build_battle_grid(count_mismatch)
	assert_eq(MissionRegistry.populate_units(count_grid, count_mismatch).size(), 0)

	var wall_spawn := MissionData.new()
	wall_spawn.mission_id = "WALL_SPAWN"
	wall_spawn.map_ascii = PackedStringArray(["#"])
	wall_spawn.player_roster = [UnitData.new()]
	wall_spawn.player_spawns = [Vector2i.ZERO]
	var wall_grid := MissionRegistry.build_battle_grid(wall_spawn)
	assert_eq(MissionRegistry.populate_units(wall_grid, wall_spawn).size(), 0)

	var duplicate_spawn := MissionData.new()
	duplicate_spawn.mission_id = "DUPLICATE_SPAWN"
	duplicate_spawn.map_ascii = PackedStringArray(["."])
	duplicate_spawn.player_roster = [UnitData.new()]
	duplicate_spawn.player_spawns = [Vector2i.ZERO]
	duplicate_spawn.enemy_roster = [UnitData.new()]
	duplicate_spawn.enemy_spawns = [Vector2i.ZERO]
	var duplicate_grid := MissionRegistry.build_battle_grid(duplicate_spawn)
	assert_eq(MissionRegistry.populate_units(duplicate_grid, duplicate_spawn).size(), 0)

	assert_push_error_count(3)


func test_mission_builders_reject_null_mission() -> void:
	assert_null(MissionRegistry.build_battle_grid(null))
	assert_eq(MissionRegistry.populate_units(null, null).size(), 0)
	assert_push_error_count(2)


func test_mission_registry_unknown_returns_null() -> void:
	assert_null(MissionRegistry.get_mission("NON_EXISTENT"))
