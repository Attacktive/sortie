extends GutTest

var _menu: SaveSlotMenu = null


func before_each() -> void:
	_menu = SaveSlotMenu.new()
	add_child_autofree(_menu)
	await get_tree().process_frame


func test_setup_populates_10_slots_with_summaries() -> void:
	var summaries: Array[Dictionary] = []
	for i in range(1, 11):
		summaries.append({
			"slot_id": i,
			"is_empty": i != 1,
			"timestamp": "2026-09-05 12:00:00" if i == 1 else "",
			"playtime_seconds": 3661.0 if i == 1 else 0.0,
			"location_name": "Overworld" if i == 1 else "",
			"party_leader": "Vanguard" if i == 1 else "",
		})

	_menu.setup(summaries, SaveSlotMenu.Mode.SAVE)
	assert_eq(_menu.get_slot_count(), 10)
	assert_string_contains(_menu.get_slot_label_text(0), "01:01:01")
	assert_string_contains(_menu.get_slot_label_text(1), "[Empty]")


func test_navigation_up_and_down_wraps_index() -> void:
	var summaries: Array[Dictionary] = []
	for i in range(1, 11):
		summaries.append({"slot_id": i, "is_empty": true, "timestamp": "", "playtime_seconds": 0.0, "location_name": "", "party_leader": ""})

	_menu.setup(summaries, SaveSlotMenu.Mode.SAVE)
	assert_eq(_menu.selected_index, 0)

	_menu.handle_input_action("ui_down")
	assert_eq(_menu.selected_index, 1)

	_menu.handle_input_action("ui_up")
	assert_eq(_menu.selected_index, 0)

	_menu.handle_input_action("ui_up")
	assert_eq(_menu.selected_index, 9)

	_menu.handle_input_action("ui_down")
	assert_eq(_menu.selected_index, 0)


func test_load_mode_blocks_empty_slots() -> void:
	watch_signals(_menu)
	var summaries: Array[Dictionary] = []
	for i in range(1, 11):
		summaries.append({
			"slot_id": i,
			"is_empty": i != 2,
			"timestamp": "2026-09-05 10:00:00" if i == 2 else "",
			"playtime_seconds": 120.0 if i == 2 else 0.0,
			"location_name": "Dungeon" if i == 2 else "",
			"party_leader": "Mage" if i == 2 else "",
		})

	_menu.setup(summaries, SaveSlotMenu.Mode.LOAD)
	_menu.selected_index = 0
	_menu.handle_input_action("ui_accept")
	assert_signal_not_emitted(_menu, "slot_selected")

	_menu.selected_index = 1
	_menu.handle_input_action("ui_accept")
	assert_signal_emitted(_menu, "slot_selected")
	var params = get_signal_parameters(_menu, "slot_selected")
	assert_eq(params[0], 2)
	assert_eq(params[1], SaveSlotMenu.Mode.LOAD)


func test_save_mode_occupied_slot_prompts_confirmation() -> void:
	watch_signals(_menu)
	var summaries: Array[Dictionary] = []
	for i in range(1, 11):
		summaries.append({
			"slot_id": i,
			"is_empty": i != 1,
			"timestamp": "2026-09-05 10:00:00" if i == 1 else "",
			"playtime_seconds": 60.0 if i == 1 else 0.0,
			"location_name": "Plains" if i == 1 else "",
			"party_leader": "Vanguard" if i == 1 else "",
		})

	_menu.setup(summaries, SaveSlotMenu.Mode.SAVE)
	_menu.selected_index = 0
	_menu.handle_input_action("ui_accept")
	assert_true(_menu.is_confirming_overwrite(), "prompting confirmation before overwrite")
	assert_signal_not_emitted(_menu, "slot_selected")

	_menu.handle_input_action("ui_accept")
	assert_signal_emitted(_menu, "slot_selected")
	var params = get_signal_parameters(_menu, "slot_selected")
	assert_eq(params[0], 1)
	assert_eq(params[1], SaveSlotMenu.Mode.SAVE)


func test_cancel_action_emits_cancelled_signal() -> void:
	watch_signals(_menu)
	var summaries: Array[Dictionary] = []
	for i in range(1, 11):
		summaries.append({"slot_id": i, "is_empty": true, "timestamp": "", "playtime_seconds": 0.0, "location_name": "", "party_leader": ""})

	_menu.setup(summaries, SaveSlotMenu.Mode.SAVE)
	_menu.handle_input_action("ui_cancel")
	assert_signal_emitted(_menu, "cancelled")
