extends GutTest

var _field_menu: FieldMenu = null


func before_each() -> void:
	_field_menu = FieldMenu.new()
	add_child_autofree(_field_menu)
	await get_tree().process_frame


func test_field_menu_options_and_navigation() -> void:
	assert_eq(_field_menu.get_option_count(), 4)
	assert_string_contains(_field_menu.get_option_text(0), "Save")
	assert_string_contains(_field_menu.get_option_text(1), "Load")
	assert_string_contains(_field_menu.get_option_text(2), "Title")
	assert_string_contains(_field_menu.get_option_text(3), "Resume")

	assert_eq(_field_menu.selected_index, 0)
	_field_menu.handle_input_action("ui_down")
	assert_eq(_field_menu.selected_index, 1)
	_field_menu.handle_input_action("ui_up")
	assert_eq(_field_menu.selected_index, 0)
	_field_menu.handle_input_action("ui_up")
	assert_eq(_field_menu.selected_index, 3)


func test_field_menu_selection_emits_matching_signals() -> void:
	watch_signals(_field_menu)

	_field_menu.selected_index = 0
	_field_menu.handle_input_action("ui_accept")
	assert_signal_emitted(_field_menu, "save_requested")

	_field_menu.selected_index = 1
	_field_menu.handle_input_action("ui_accept")
	assert_signal_emitted(_field_menu, "load_requested")

	_field_menu.selected_index = 2
	_field_menu.handle_input_action("ui_accept")
	assert_signal_emitted(_field_menu, "title_requested")

	_field_menu.selected_index = 3
	_field_menu.handle_input_action("ui_accept")
	assert_signal_emitted(_field_menu, "resume_requested")

	_field_menu.handle_input_action("ui_cancel")
	assert_signal_emitted(_field_menu, "resume_requested")


func test_field_opens_menu_on_ui_cancel_and_freezes_player() -> void:
	var field := Field.new()
	add_child_autofree(field)
	await get_tree().process_frame

	var player: FieldPlayer = field.get_node("FieldPlayer")
	assert_false(player.frozen)
	assert_null(field.get_field_menu())

	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	field._unhandled_input(cancel_event)

	assert_not_null(field.get_field_menu())
	assert_true(player.frozen, "player frozen while field menu open")

	field.get_field_menu().resume_requested.emit()
	assert_false(player.frozen, "player unfrozen after resume")
	assert_null(field.get_field_menu())
