extends GutTest

var _menu: TitleMenu = null

func before_each() -> void:
	_menu = TitleMenu.new()
	add_child_autofree(_menu)
	await get_tree().process_frame

func test_menu_renders_options() -> void:
	assert_eq(_menu.get_option_count(), 4)
	assert_eq(_menu.get_selected_index(), 0)


func test_directional_navigation_wraps_cleanly() -> void:
	_menu.handle_input_action("ui_down")
	assert_eq(_menu.get_selected_index(), 1)

	_menu.handle_input_action("ui_down")
	assert_eq(_menu.get_selected_index(), 2)

	_menu.handle_input_action("ui_down")
	assert_eq(_menu.get_selected_index(), 3)

	_menu.handle_input_action("ui_down")
	assert_eq(_menu.get_selected_index(), 0, "down wraps to top")

	_menu.handle_input_action("ui_up")
	assert_eq(_menu.get_selected_index(), 3, "up wraps to bottom")


func test_accept_on_new_game_emits_signal() -> void:
	watch_signals(_menu)
	_menu.handle_input_action("ui_accept")
	assert_signal_emitted(_menu, "new_game_requested")


func test_accept_on_load_game_emits_signal() -> void:
	watch_signals(_menu)
	_menu.handle_input_action("ui_down")
	_menu.handle_input_action("ui_accept")
	assert_signal_emitted(_menu, "load_game_requested")


func test_accept_on_quick_battle_emits_signal() -> void:
	watch_signals(_menu)
	_menu.handle_input_action("ui_down")
	_menu.handle_input_action("ui_down")
	_menu.handle_input_action("ui_accept")
	assert_signal_emitted(_menu, "quick_battle_requested")


func test_accept_on_quit_emits_signal() -> void:
	watch_signals(_menu)
	_menu.handle_input_action("ui_down")
	_menu.handle_input_action("ui_down")
	_menu.handle_input_action("ui_down")
	_menu.handle_input_action("ui_accept")
	assert_signal_emitted(_menu, "quit_requested")
