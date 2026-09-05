class_name TestHighspireCourtyard
extends GutTest


func test_sir_roderick_presents_cabbage_briefing_with_sortie_choice() -> void:
	var field: Field = load("res://scenes/field.tscn").instantiate()
	add_child_autofree(field)
	await get_tree().process_frame

	var roderick: FieldNpc = field.get_node_or_null("SirRoderick")
	assert_not_null(roderick, "Sir Roderick NPC exists in courtyard")

	var dialogue: DialogueTree = roderick.get_dialogue_for_state(field.world_state)
	assert_not_null(dialogue)
	var start_node := dialogue.get_node("briefing_dishonor")
	assert_not_null(start_node)
	assert_string_contains(start_node.text, "gravest dishonor")


func test_sir_roderick_updates_dialogue_after_mission_completion() -> void:
	var field: Field = load("res://scenes/field.tscn").instantiate()
	add_child_autofree(field)
	await get_tree().process_frame

	field.world_state.set_flag("mission_m01_completed", true)
	var roderick: FieldNpc = field.get_node_or_null("SirRoderick")
	var dialogue: DialogueTree = roderick.get_dialogue_for_state(field.world_state)

	var start_node := dialogue.get_node("post_victory")
	assert_not_null(start_node)
	assert_string_contains(start_node.text, "Splendid work out there")
