extends GutTest

func test_start_battle_action_creation() -> void:
	var action := EventAction.start_battle()
	assert_eq(action.type, EventAction.Type.START_BATTLE)
	assert_eq(action.params.get("battle_id"), "default")

func test_start_battle_action_with_custom_id() -> void:
	var action := EventAction.start_battle("forest_boss")
	assert_eq(action.type, EventAction.Type.START_BATTLE)
	assert_eq(action.params.get("battle_id"), "forest_boss")
