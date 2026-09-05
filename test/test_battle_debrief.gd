class_name TestBattleDebrief
extends GutTest


func test_victory_triggers_victory_debrief_before_result_screen() -> void:
	var battle: Battle = load("res://scenes/battle.tscn").instantiate()
	battle.mission_id = "M01_CABBAGE"
	add_child_autofree(battle)
	await get_tree().process_frame

	var turn_dlg: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
	if turn_dlg != null:
		turn_dlg.handle_input_action("ui_accept")
		turn_dlg.handle_input_action("ui_accept")
		await get_tree().process_frame

	for enemy in battle._grid.living_units_of_team(UnitData.Team.ENEMY):
		enemy.hp = 0
	battle._turns.check_resolution()
	battle._finish_if_resolved()
	await get_tree().process_frame

	var debrief_dlg: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
	assert_not_null(debrief_dlg, "Victory debrief displays on victory")
	assert_false(battle._result_screen.visible, "Result screen waits for debrief")

	debrief_dlg.handle_input_action("ui_accept")
	debrief_dlg.handle_input_action("ui_accept")
	await get_tree().process_frame

	assert_true(battle._result_screen.visible, "Result screen shows after debrief")


func test_defeat_triggers_defeat_debrief_before_result_screen() -> void:
	var battle: Battle = load("res://scenes/battle.tscn").instantiate()
	battle.mission_id = "M01_CABBAGE"
	add_child_autofree(battle)
	await get_tree().process_frame

	var turn_dlg: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
	if turn_dlg != null:
		turn_dlg.handle_input_action("ui_accept")
		turn_dlg.handle_input_action("ui_accept")
		await get_tree().process_frame

	for player in battle._grid.living_units_of_team(UnitData.Team.PLAYER):
		player.hp = 0
	battle._turns.check_resolution()
	battle._finish_if_resolved()
	await get_tree().process_frame

	var debrief_dlg: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
	assert_not_null(debrief_dlg, "Defeat debrief displays on defeat")
	assert_false(battle._result_screen.visible, "Result screen waits for debrief")

	debrief_dlg.handle_input_action("ui_accept")
	await get_tree().process_frame

	assert_true(battle._result_screen.visible, "Result screen shows after debrief")
