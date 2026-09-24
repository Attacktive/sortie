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
	if roderick == null:
		return

	var dialogue: DialogueTree = roderick.get_dialogue_for_state(field.world_state)
	assert_not_null(dialogue)
	var start_node := dialogue.get_node("briefing_dishonor")
	assert_not_null(start_node)
	assert_string_contains(start_node.text, "gravest dishonor")
	assert_eq(_find_sortie_battle_id(dialogue), "M01_CABBAGE")


func test_sir_roderick_briefing_chain_matches_campaign_state() -> void:
	var field: Field = load("res://scenes/field.tscn").instantiate()
	add_child_autofree(field)
	await get_tree().process_frame

	var roderick: FieldNpc = field.get_node_or_null("SirRoderick")
	assert_not_null(roderick, "Sir Roderick NPC exists in courtyard")
	if roderick == null:
		return

	var cases := [
		{
			"completed_flags": [],
			"start_node_id": "briefing_dishonor",
			"first_text": "Men, today Highspire faces its gravest dishonor.",
			"battle_id": "M01_CABBAGE",
		},
		{
			"completed_flags": ["mission_m01_completed"],
			"start_node_id": "m02_briefing_ale",
			"first_text": "Splendid work out there! The royal herb garden is safe. The scout reports the remaining cabbage hurled over the ramparts was surprisingly edible in soup.",
			"battle_id": "M02_ALE_RUN",
		},
		{
			"completed_flags": ["mission_m01_completed", "mission_m02_completed"],
			"start_node_id": "m03_briefing_cutlery",
			"first_text": "The ale flows, and morale is secure. However, a tragedy has struck the royal scullery!",
			"battle_id": "M03_SILVER_SPOONS",
		},
		{
			"completed_flags": ["mission_m01_completed", "mission_m02_completed", "mission_m03_completed"],
			"start_node_id": "m04_briefing_oven",
			"first_text": "The forks are polished and returned to their velvet case. But smell the air, Pip!",
			"battle_id": "M04_FIELD_OVEN",
		},
		{
			"completed_flags": ["mission_m01_completed", "mission_m02_completed", "mission_m03_completed", "mission_m04_completed"],
			"start_node_id": "m05_briefing_paprika",
			"first_text": "The rogue oven is cold, and the King's pastry monopoly is safe.",
			"battle_id": "M05_SPICE_WARS",
		},
		{
			"completed_flags": ["mission_m01_completed", "mission_m02_completed", "mission_m03_completed", "mission_m04_completed", "mission_m05_completed"],
			"start_node_id": "terminal_paprika_safe",
			"first_text": "The paprika is safe, and Malakor has been routed! You have saved the realm's palate!",
			"battle_id": "",
		},
	]

	for case in cases:
		var state := WorldState.new()
		var completed_flags: Array = case.get("completed_flags", [])
		for flag in completed_flags:
			state.set_flag(str(flag), true)

		var dialogue: DialogueTree = roderick.get_dialogue_for_state(state)
		assert_not_null(dialogue)
		if dialogue == null:
			continue

		var expected_start_id := str(case.get("start_node_id", ""))
		var expected_first_text := str(case.get("first_text", ""))
		var expected_battle_id := str(case.get("battle_id", ""))
		assert_eq(dialogue.start_node_id, expected_start_id)

		var first_node := dialogue.get_node(dialogue.start_node_id)
		assert_not_null(first_node)
		if first_node != null:
			assert_eq(first_node.text, expected_first_text)

		assert_eq(_find_sortie_battle_id(dialogue), expected_battle_id)

		if expected_battle_id.is_empty():
			for node_value in dialogue.nodes.values():
				var node: DialogueNode = node_value
				assert_false(node.has_choices(), "Terminal Roderick dialogue must not offer choices")


func test_sir_roderick_updates_dialogue_after_mission_completion() -> void:
	var field: Field = load("res://scenes/field.tscn").instantiate()
	add_child_autofree(field)
	await get_tree().process_frame

	field.world_state.set_flag("mission_m01_completed", true)
	var roderick: FieldNpc = field.get_node_or_null("SirRoderick")
	assert_not_null(roderick, "Sir Roderick NPC exists in courtyard")
	if roderick == null:
		return

	var dialogue: DialogueTree = roderick.get_dialogue_for_state(field.world_state)
	assert_eq(dialogue.start_node_id, "m02_briefing_ale")

	var start_node := dialogue.get_node("m02_briefing_ale")
	assert_not_null(start_node)
	assert_string_contains(start_node.text, "Splendid work out there")


func _find_sortie_battle_id(dialogue: DialogueTree) -> String:
	if dialogue == null:
		return ""

	for node_value in dialogue.nodes.values():
		var node: DialogueNode = node_value
		for choice in node.choices:
			if choice.text != "[Sortie!]":
				continue

			var action_node := dialogue.get_node(choice.next_id)
			if action_node == null or action_node.action == null:
				return ""
			if action_node.action.type != EventAction.Type.START_BATTLE:
				return ""

			return str(action_node.action.params.get("battle_id", ""))

	return ""
