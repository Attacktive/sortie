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


func test_m02_ale_run_configuration() -> void:
	var mission := MissionRegistry.get_mission("M02_ALE_RUN")
	assert_not_null(mission)
	if mission == null:
		return

	assert_eq(mission.title, "The Seasonal Ale Run")
	assert_eq(mission.completion_flag, "mission_m02_completed")
	assert_eq(mission.map_ascii, PackedStringArray([
		"F.F....F.F",
		"..##..##..",
		"..........",
		"..F....F..",
		"..........",
		"F.##..##.F",
		"..........",
		"..........",
	]))
	assert_eq(mission.player_spawns, [
		Vector2i(4, 7),
		Vector2i(5, 7),
		Vector2i(3, 7),
		Vector2i(6, 7),
	])
	assert_eq(mission.enemy_spawns, [
		Vector2i(3, 2),
		Vector2i(6, 2),
		Vector2i(4, 0),
		Vector2i(5, 0),
	])

	var grid := MissionRegistry.build_battle_grid(mission)
	assert_not_null(grid)
	if grid == null:
		return

	var units := MissionRegistry.populate_units(grid, mission)
	assert_eq(units.size(), 8)

	var turn_tree: DialogueTree = mission.turn_dialogue_triggers.get(1)
	assert_not_null(turn_tree)
	if turn_tree != null:
		assert_eq(turn_tree.get_node(turn_tree.start_node_id).speaker, "Scout")

	var ale_gap := Rect2i(Vector2i(4, 1), Vector2i(2, 1))
	assert_true(mission.area_dialogue_triggers.has(ale_gap))
	for x in range(ale_gap.position.x, ale_gap.end.x):
		for y in range(ale_gap.position.y, ale_gap.end.y):
			var cell := Vector2i(x, y)
			assert_true(Terrain.is_passable(grid.terrain_at(cell)), "M02 area trigger cell %s must be walkable" % cell)

	var area_tree: DialogueTree = mission.area_dialogue_triggers.get(ale_gap)
	assert_not_null(area_tree)
	if area_tree != null:
		assert_eq(area_tree.get_node(area_tree.start_node_id).speaker, "Brute")

	assert_not_null(mission.victory_debrief)
	if mission.victory_debrief != null:
		assert_eq(mission.victory_debrief.get_node(mission.victory_debrief.start_node_id).speaker, "Raider")

	assert_not_null(mission.defeat_debrief)
	if mission.defeat_debrief != null:
		assert_eq(mission.defeat_debrief.get_node(mission.defeat_debrief.start_node_id).speaker, "Vanguard")

	assert_eq(mission.enemy_roster.size(), 4)
	assert_eq(mission.enemy_roster[0].unit_name, "Agile Thug")
	assert_eq(mission.enemy_roster[0].accuracy, 0.90)
	assert_eq(mission.enemy_roster[0].evasion, 0.30)
	assert_eq(mission.enemy_roster[0].crit_rate, 0.10)
	assert_eq(mission.enemy_roster[1].unit_name, "Agile Rogue")
	assert_eq(mission.enemy_roster[1].evasion, 0.30)
	assert_eq(mission.enemy_roster[2].unit_name, "Thirsty Bruiser")
	assert_eq(mission.enemy_roster[3].unit_name, "Keg Thief")
	assert_eq(mission.enemy_roster[3].attack_range, 2)


func test_m03_silver_spoons_configuration() -> void:
	var mission := MissionRegistry.get_mission("M03_SILVER_SPOONS")
	assert_not_null(mission)
	if mission == null:
		return

	assert_eq(mission.mission_id, "M03_SILVER_SPOONS")
	assert_eq(mission.title, "The Royal Cutlery")
	assert_eq(mission.completion_flag, "mission_m03_completed")
	assert_eq(mission.map_ascii, PackedStringArray([
		".##....##.",
		".F......F.",
		"..........",
		"####..####",
		"..........",
		"..........",
		".F......F.",
		"..........",
	]))
	assert_eq(mission.player_spawns, [
		Vector2i(4, 7),
		Vector2i(5, 7),
		Vector2i(4, 6),
		Vector2i(5, 6),
	])
	assert_eq(mission.enemy_spawns, [
		Vector2i(4, 1),
		Vector2i(3, 2),
		Vector2i(6, 2),
		Vector2i(3, 0),
		Vector2i(6, 0),
	])

	var grid := MissionRegistry.build_battle_grid(mission)
	assert_not_null(grid)
	if grid == null:
		return

	var units := MissionRegistry.populate_units(grid, mission)
	assert_eq(units.size(), 9)

	var turn_tree: DialogueTree = mission.turn_dialogue_triggers.get(1)
	assert_not_null(turn_tree)
	if turn_tree != null:
		assert_eq(turn_tree.get_node(turn_tree.start_node_id).speaker, "Scout")

	var center_gap := Rect2i(Vector2i(4, 3), Vector2i(2, 1))
	assert_true(mission.area_dialogue_triggers.has(center_gap))
	for x in range(center_gap.position.x, center_gap.end.x):
		for y in range(center_gap.position.y, center_gap.end.y):
			var cell := Vector2i(x, y)
			assert_true(Terrain.is_passable(grid.terrain_at(cell)), "M03 area trigger cell %s must be walkable" % cell)

	var area_tree: DialogueTree = mission.area_dialogue_triggers.get(center_gap)
	assert_not_null(area_tree)
	if area_tree != null:
		assert_eq(area_tree.get_node(area_tree.start_node_id).speaker, "Brute")

	assert_not_null(mission.victory_debrief)
	if mission.victory_debrief != null:
		assert_eq(mission.victory_debrief.get_node(mission.victory_debrief.start_node_id).speaker, "Raider")

	assert_not_null(mission.defeat_debrief)
	if mission.defeat_debrief != null:
		assert_eq(mission.defeat_debrief.get_node(mission.defeat_debrief.start_node_id).speaker, "Vanguard")

	assert_eq(mission.enemy_roster.size(), 5)
	assert_eq(mission.enemy_roster[0].unit_name, "Cutlery Guard")
	assert_eq(mission.enemy_roster[1].unit_name, "Fork Pilferer")
	assert_eq(mission.enemy_roster[1].accuracy, 0.90)
	assert_eq(mission.enemy_roster[1].evasion, 0.30)
	assert_eq(mission.enemy_roster[1].crit_rate, 0.10)
	assert_eq(mission.enemy_roster[2].unit_name, "Spoon Pilferer")
	assert_eq(mission.enemy_roster[2].evasion, 0.30)
	assert_eq(mission.enemy_roster[3].unit_name, "Camp Lookout")
	assert_eq(mission.enemy_roster[4].unit_name, "Silver Smuggler")
	assert_eq(mission.enemy_roster[4].attack_range, 2)


func test_m04_field_oven_configuration() -> void:
	var mission := MissionRegistry.get_mission("M04_FIELD_OVEN")
	assert_not_null(mission)
	if mission == null:
		return

	assert_eq(mission.mission_id, "M04_FIELD_OVEN")
	assert_eq(mission.title, "The Tactical Bakery")
	assert_eq(mission.completion_flag, "mission_m04_completed")
	assert_eq(mission.map_ascii, PackedStringArray([
		"...####...",
		"..F####F..",
		"...####...",
		"..........",
		"F........F",
		"..........",
		".##....##.",
		"..........",
	]))
	assert_eq(mission.player_spawns, [
		Vector2i(3, 7),
		Vector2i(4, 7),
		Vector2i(5, 7),
		Vector2i(6, 7),
	])
	assert_eq(mission.enemy_spawns, [
		Vector2i(2, 1),
		Vector2i(7, 1),
		Vector2i(4, 3),
		Vector2i(5, 3),
		Vector2i(3, 3),
	])

	var grid := MissionRegistry.build_battle_grid(mission)
	assert_not_null(grid)
	if grid == null:
		return

	var units := MissionRegistry.populate_units(grid, mission)
	assert_eq(units.size(), 9)

	var turn_tree: DialogueTree = mission.turn_dialogue_triggers.get(1)
	assert_not_null(turn_tree)
	if turn_tree != null:
		assert_eq(turn_tree.get_node(turn_tree.start_node_id).speaker, "Scout")

	var oven_front := Rect2i(Vector2i(3, 3), Vector2i(4, 1))
	assert_true(mission.area_dialogue_triggers.has(oven_front))
	for x in range(oven_front.position.x, oven_front.end.x):
		for y in range(oven_front.position.y, oven_front.end.y):
			var cell := Vector2i(x, y)
			assert_true(Terrain.is_passable(grid.terrain_at(cell)), "M04 area trigger cell %s must be walkable" % cell)

	var occupied_trigger_cells := 0
	for enemy_spawn in mission.enemy_spawns:
		if oven_front.has_point(enemy_spawn):
			occupied_trigger_cells += 1

	assert_eq(occupied_trigger_cells, 3)
	assert_null(grid.unit_at(Vector2i(6, 3)))

	var area_tree: DialogueTree = mission.area_dialogue_triggers.get(oven_front)
	assert_not_null(area_tree)
	if area_tree != null:
		assert_eq(area_tree.get_node(area_tree.start_node_id).speaker, "Brute")

	assert_not_null(mission.victory_debrief)
	if mission.victory_debrief != null:
		assert_eq(mission.victory_debrief.get_node(mission.victory_debrief.start_node_id).speaker, "Raider")

	assert_not_null(mission.defeat_debrief)
	if mission.defeat_debrief != null:
		assert_eq(mission.defeat_debrief.get_node(mission.defeat_debrief.start_node_id).speaker, "Vanguard")

	assert_eq(mission.enemy_roster.size(), 5)
	assert_eq(mission.enemy_roster[0].unit_name, "Dough Sentinel")
	assert_eq(mission.enemy_roster[1].unit_name, "Dough Sentinel")
	assert_eq(mission.enemy_roster[2].unit_name, "Pastry Enforcer")
	assert_eq(mission.enemy_roster[3].unit_name, "Oven Stoker")
	assert_eq(mission.enemy_roster[3].attack_range, 2)
	assert_eq(mission.enemy_roster[4].unit_name, "Flour Scout")


func test_m05_spice_wars_configuration() -> void:
	var mission := MissionRegistry.get_mission("M05_SPICE_WARS")
	assert_not_null(mission)
	if mission == null:
		return

	assert_eq(mission.mission_id, "M05_SPICE_WARS")
	assert_eq(mission.title, "The Paprika Defense")
	assert_eq(mission.completion_flag, "mission_m05_completed")
	assert_eq(mission.map_ascii, PackedStringArray([
		".########.",
		".F......F.",
		"...####...",
		"...####...",
		"..........",
		"F........F",
		"..##..##..",
		"..........",
	]))
	assert_eq(mission.map_ascii.size(), 8)
	for row in mission.map_ascii:
		assert_eq(row.length(), 10)
		for x in row.length():
			assert_true([".", "F", "#"].has(row.substr(x, 1)), "M05 map glyph at x=%d must be legal" % x)

	assert_eq(mission.player_spawns, [
		Vector2i(4, 7),
		Vector2i(5, 7),
		Vector2i(3, 7),
		Vector2i(6, 7),
	])
	assert_eq(mission.enemy_spawns, [
		Vector2i(4, 1),
		Vector2i(2, 2),
		Vector2i(7, 2),
		Vector2i(2, 4),
		Vector2i(7, 4),
		Vector2i(5, 1),
	])
	assert_eq(mission.player_spawns.size(), mission.player_roster.size())
	assert_eq(mission.enemy_spawns.size(), mission.enemy_roster.size())

	var grid := MissionRegistry.build_battle_grid(mission)
	assert_not_null(grid)
	if grid == null:
		return

	var units := MissionRegistry.populate_units(grid, mission)
	assert_eq(units.size(), 10)

	var spawn_cells: Dictionary[Vector2i, bool] = {}
	for spawn in mission.player_spawns + mission.enemy_spawns:
		assert_true(Terrain.is_passable(grid.terrain_at(spawn)), "M05 spawn cell %s must be walkable" % spawn)
		assert_false(spawn_cells.has(spawn), "M05 spawn cell %s must be unique" % spawn)
		spawn_cells[spawn] = true

	var turn_tree: DialogueTree = mission.turn_dialogue_triggers.get(1)
	assert_not_null(turn_tree)
	if turn_tree != null:
		assert_eq(turn_tree.get_node(turn_tree.start_node_id).speaker, "Scout")

	var cellar_front := Rect2i(Vector2i(3, 4), Vector2i(4, 1))
	assert_true(mission.area_dialogue_triggers.has(cellar_front))
	for x in range(cellar_front.position.x, cellar_front.end.x):
		for y in range(cellar_front.position.y, cellar_front.end.y):
			var cell := Vector2i(x, y)
			assert_true(Terrain.is_passable(grid.terrain_at(cell)), "M05 area trigger cell %s must be walkable" % cell)

	var area_tree: DialogueTree = mission.area_dialogue_triggers.get(cellar_front)
	assert_not_null(area_tree)
	if area_tree != null:
		assert_eq(area_tree.get_node(area_tree.start_node_id).speaker, "Brute")

	assert_not_null(mission.victory_debrief)
	if mission.victory_debrief != null:
		assert_eq(mission.victory_debrief.get_node(mission.victory_debrief.start_node_id).speaker, "Raider")

	assert_not_null(mission.defeat_debrief)
	if mission.defeat_debrief != null:
		assert_eq(mission.defeat_debrief.get_node(mission.defeat_debrief.start_node_id).speaker, "Vanguard")

	assert_eq(mission.enemy_roster.size(), 6)
	assert_eq(mission.enemy_roster[0].unit_name, "General Malakor")
	assert_eq(mission.enemy_roster[0].max_hp, 35)
	assert_eq(mission.enemy_roster[0].attack, 7)
	assert_eq(mission.enemy_roster[0].attack_range, 2)
	assert_eq(mission.enemy_roster[1].unit_name, "Elite Guard")
	assert_eq(mission.enemy_roster[2].unit_name, "Elite Guard")
	assert_eq(mission.enemy_roster[3].unit_name, "Spice Runner")
	assert_eq(mission.enemy_roster[3].evasion, 0.30)
	assert_eq(mission.enemy_roster[4].unit_name, "Spice Runner")
	assert_eq(mission.enemy_roster[4].evasion, 0.30)
	assert_eq(mission.enemy_roster[5].unit_name, "Siege Breaker")


func test_mission_registry_unknown_returns_null() -> void:
	assert_null(MissionRegistry.get_mission("NON_EXISTENT"))
