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
