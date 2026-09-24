class_name TestStoryMissionEndToEnd
extends GutTest


func test_story_progresses_from_m01_into_m02() -> void:
	var game: Game = load("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	await get_tree().process_frame

	game.start_new_game()
	await get_tree().process_frame
	assert_eq(game.current_mode, Game.Mode.FIELD)

	var m01_battle: Battle = await _start_roderick_sortie(game, "M01_CABBAGE")
	if m01_battle == null:
		return

	await _win_mission(game, m01_battle)
	assert_true(game.world_state.has_flag("mission_m01_completed"))
	assert_true(game.world_state.get_flag("mission_m01_completed"))
	assert_eq(game.current_mode, Game.Mode.FIELD)

	var field: Field = game.get_active_scene()
	var roderick: FieldNpc = field.get_node_or_null("SirRoderick")
	assert_not_null(roderick)
	if roderick == null:
		return

	var m02_briefing := roderick.get_dialogue_for_state(game.world_state)
	assert_eq(m02_briefing.start_node_id, "m02_briefing_ale")

	var m02_battle: Battle = await _start_roderick_sortie(game, "M02_ALE_RUN")
	if m02_battle == null:
		return

	await _win_mission(game, m02_battle)
	assert_true(game.world_state.has_flag("mission_m02_completed"))
	assert_true(game.world_state.get_flag("mission_m02_completed"))


func _start_roderick_sortie(game: Game, expected_mission_id: String) -> Battle:
	assert_eq(game.current_mode, Game.Mode.FIELD)
	if game.current_mode != Game.Mode.FIELD:
		return null

	var field: Field = game.get_active_scene()
	var roderick: FieldNpc = field.get_node_or_null("SirRoderick")
	assert_not_null(roderick)
	if roderick == null:
		return null

	field._start_npc_dialogue(roderick)
	await get_tree().process_frame

	var dialogue_box: DialogueBox = field.get_node_or_null("DialogueBox")
	assert_not_null(dialogue_box)
	if dialogue_box == null:
		return null

	for _step in 8:
		if game.current_mode == Game.Mode.BATTLE:
			break

		assert_true(dialogue_box.visible, "Roderick dialogue should remain visible until the Sortie action fires")
		if not dialogue_box.visible:
			return null

		dialogue_box.handle_input_action("ui_accept")
		await get_tree().process_frame

	assert_eq(game.current_mode, Game.Mode.BATTLE)
	if game.current_mode != Game.Mode.BATTLE:
		return null

	var battle: Battle = game.get_active_scene()
	assert_eq(battle.mission_id, expected_mission_id)
	return battle


func _win_mission(game: Game, battle: Battle) -> void:
	await _dismiss_battle_dialogue(battle)

	for enemy in battle._grid.living_units_of_team(UnitData.Team.ENEMY):
		enemy.hp = 0

	battle._turns.check_resolution()
	battle._finish_if_resolved()

	for _step in 8:
		if game.current_mode == Game.Mode.FIELD:
			break

		var dialogue: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
		if dialogue != null and dialogue.visible:
			dialogue.handle_input_action("ui_accept")

		await get_tree().process_frame

	assert_eq(game.current_mode, Game.Mode.FIELD)


func _dismiss_battle_dialogue(battle: Battle) -> void:
	for _step in 4:
		var dialogue: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
		if dialogue == null or not dialogue.visible:
			return

		dialogue.handle_input_action("ui_accept")
		await get_tree().process_frame
