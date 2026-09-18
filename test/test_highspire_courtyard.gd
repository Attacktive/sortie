class_name TestHighspireCourtyard
extends GutTest


func test_barnaby_dialogue_is_sequential_and_unconditional() -> void:
	var field: Field = load("res://scenes/field.tscn").instantiate()
	add_child_autofree(field)
	await get_tree().process_frame

	var barnaby: FieldNpc = field.get_node_or_null("Barnaby")
	assert_not_null(barnaby, "Barnaby NPC exists in courtyard")
	if barnaby == null:
		return

	assert_eq(barnaby.npc_name, "Barnaby")
	assert_eq(barnaby.conditional_dialogues.size(), 0)

	var dialogue := barnaby.dialogue
	assert_not_null(dialogue)
	if dialogue == null:
		return

	assert_eq(dialogue.nodes.size(), 3)

	var pressure := dialogue.get_node(dialogue.start_node_id)
	assert_not_null(pressure)
	assert_eq(pressure.speaker, "Barnaby")
	assert_eq(pressure.text, "The barometric pressure is plummeting, which is dreadful for my arthritis.")

	var scry := dialogue.get_node(pressure.next_id)
	assert_not_null(scry)
	assert_eq(scry.speaker, "Barnaby")
	assert_eq(scry.text, "I am attempting to scry the kingdom's weather, if this infernal siege would just quiet down.")

	var eastern_wind := dialogue.get_node(scry.next_id)
	assert_not_null(eastern_wind)
	assert_eq(eastern_wind.speaker, "Barnaby")
	assert_eq(eastern_wind.text, "The eastern wind brings the scent of treason, and lightly toasted garlic.")
	assert_eq(eastern_wind.next_id, "")


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
