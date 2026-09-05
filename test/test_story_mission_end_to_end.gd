class_name TestStoryMissionEndToEnd
extends GutTest


func test_full_cabbage_mission_loop() -> void:
	var game: Game = load("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	await get_tree().process_frame

	game.start_new_game()
	await get_tree().process_frame
	assert_eq(game.current_mode, Game.Mode.FIELD)

	# Simulate Sir Roderick Sortie choice triggering battle
	game.start_battle("M01_CABBAGE", false)
	await get_tree().process_frame
	assert_eq(game.current_mode, Game.Mode.BATTLE)

	var battle: Battle = game.get_active_scene()
	assert_eq(battle.mission_id, "M01_CABBAGE")

	# Dismiss turn 1 banter
	var turn_dlg: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
	if turn_dlg != null:
		turn_dlg.handle_input_action("ui_accept")
		turn_dlg.handle_input_action("ui_accept")
		await get_tree().process_frame

	# Eliminate enemy squad to trigger victory
	for enemy in battle._grid.living_units_of_team(UnitData.Team.ENEMY):
		enemy.hp = 0
	battle._turns.check_resolution()
	battle._finish_if_resolved()
	await get_tree().process_frame

	# Dismiss victory debrief
	var debrief_dlg: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
	if debrief_dlg != null:
		debrief_dlg.handle_input_action("ui_accept")
		debrief_dlg.handle_input_action("ui_accept")
		await get_tree().process_frame
		await get_tree().process_frame
	assert_true(game.world_state.has_flag("mission_m01_completed"))
	assert_true(game.world_state.get_flag("mission_m01_completed"))
