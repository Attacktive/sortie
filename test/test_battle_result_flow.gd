extends GutTest

var _screen: ResultScreen = null

func before_each() -> void:
	_screen = ResultScreen.new()
	add_child_autofree(_screen)
	await get_tree().process_frame

func test_victory_presents_continue_button() -> void:
	watch_signals(_screen)
	_screen.show_result(true)

	var buttons: Array = _screen._buttons_box.get_children()
	assert_eq(buttons.size(), 1)
	assert_eq(buttons[0].text, "Continue")

	buttons[0].emit_signal("pressed")
	assert_signal_emitted(_screen, "continue_requested")

func test_defeat_presents_retry_and_title_buttons() -> void:
	watch_signals(_screen)
	_screen.show_result(false)

	var buttons: Array = _screen._buttons_box.get_children()
	assert_eq(buttons.size(), 2)
	assert_eq(buttons[0].text, "Retry Battle")
	assert_eq(buttons[1].text, "Return to Title")

	buttons[0].emit_signal("pressed")
	assert_signal_emitted(_screen, "retry_requested")

	buttons[1].emit_signal("pressed")
	assert_signal_emitted(_screen, "title_requested")
