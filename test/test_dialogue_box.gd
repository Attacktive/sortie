extends GutTest

var _box: DialogueBox

func before_each() -> void:
	_box = DialogueBox.new()
	add_child_autofree(_box)
	await get_tree().process_frame

func _make_runner() -> DialogueRunner:
	var tree := DialogueTree.from_dict({
		"start": "q",
		"nodes": {
			"q": {
				"speaker": "Guard",
				"text": "Pass or halt?",
				"choices": [
					{ "text": "Pass", "next": "pass" },
					{ "text": "Halt", "next": "halt" }
				]
			},
			"pass": { "speaker": "Guard", "text": "Move on.", "next": "" },
			"halt": { "speaker": "Guard", "text": "Stay back.", "next": "" }
		}
	})
	return DialogueRunner.new(tree)

func test_dialogue_box_renders_speaker_and_text() -> void:
	var runner := _make_runner()
	_box.start(runner)

	assert_true(_box.visible)
	assert_eq(_box.get_speaker(), "Guard")
	assert_eq(_box.get_text(), "Pass or halt?")
	assert_eq(_box.get_choice_count(), 2)

func test_keyboard_choice_navigation() -> void:
	var runner := _make_runner()
	_box.start(runner)
	assert_eq(_box.get_selected_choice_index(), 0)

	_box.handle_input_action("ui_down")
	assert_eq(_box.get_selected_choice_index(), 1)

	_box.handle_input_action("ui_up")
	assert_eq(_box.get_selected_choice_index(), 0)

func test_accept_advances_and_finishes() -> void:
	var runner := _make_runner()
	_box.start(runner)

	watch_signals(_box)
	_box.handle_input_action("ui_accept")
	assert_eq(_box.get_text(), "Move on.")

	_box.handle_input_action("ui_accept")
	assert_false(_box.visible)
	assert_signal_emitted(_box, "finished")
