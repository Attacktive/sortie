class_name TestBattleMissionDialogue
extends GutTest


func test_turn_start_dialogue_modal_locks_input_and_completes() -> void:
	var battle: Battle = load("res://scenes/battle.tscn").instantiate()
	battle.mission_id = "M01_CABBAGE"
	add_child_autofree(battle)
	await get_tree().process_frame

	var dialogue: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
	assert_not_null(dialogue, "DialogueBox should be spawned on Turn 1 start")
	assert_false(battle._cursor.active, "Cursor should be locked during dialogue")

	dialogue.handle_input_action("ui_accept")
	dialogue.handle_input_action("ui_accept")
	await get_tree().process_frame

	assert_null(battle.get_node_or_null("BattleDialogueBox"))
	assert_true(battle._cursor.active, "Cursor unlocks when dialogue finishes")


func test_area_trigger_fires_once_when_entering_catapult_zone() -> void:
	var battle: Battle = load("res://scenes/battle.tscn").instantiate()
	battle.mission_id = "M01_CABBAGE"
	add_child_autofree(battle)
	await get_tree().process_frame

	var turn_dlg: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
	if turn_dlg != null:
		turn_dlg.handle_input_action("ui_accept")
		turn_dlg.handle_input_action("ui_accept")
		await get_tree().process_frame

	var brute: BattleUnit = battle._grid.unit_at(Vector2i(0, 7))
	battle._selected = brute
	battle._origin_cell = brute.cell
	battle._grid.move_unit(brute, Vector2i(7, 2))
	battle._on_move_finished()
	await get_tree().process_frame

	var area_dlg: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
	assert_not_null(area_dlg, "Area dialogue fires when entering CatapultZone")
	area_dlg.handle_input_action("ui_accept")
	await get_tree().process_frame

	assert_null(battle.get_node_or_null("BattleDialogueBox"))
	assert_true(battle._consumed_area_triggers.has(Rect2i(Vector2i(7, 2), Vector2i(3, 4))))
