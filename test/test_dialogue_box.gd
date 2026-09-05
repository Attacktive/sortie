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

## Freed nodes do not leave the tree until the end of the frame, so a box that only calls queue_free on the old labels holds both pages' choices at once for the frame in between, and the container lays out twice as many rows as there are choices.
## get_choice_count reads the label array rather than the container, which is why this needs the container to see it.
func test_choices_are_replaced_rather_than_stacked() -> void:
	var tree := DialogueTree.from_dict({
		"start": "first",
		"nodes": {
			"first": {
				"speaker": "Guard",
				"text": "Pass or halt?",
				"choices": [
					{ "text": "Pass", "next": "second" },
					{ "text": "Halt", "next": "second" }
				]
			},
			"second": {
				"speaker": "Guard",
				"text": "Which way?",
				"choices": [
					{ "text": "North", "next": "" },
					{ "text": "South", "next": "" }
				]
			}
		}
	})

	_box.start(DialogueRunner.new(tree))
	_box.handle_input_action("ui_accept")

	assert_eq(_box.get_choice_count(), 2)
	assert_eq(_box._choices_container.get_child_count(), 2, "the page you just left is still on screen underneath the one you are looking at")

func test_dialogue_box_filters_choices_by_condition() -> void:
	var tree := DialogueTree.from_dict({
		"start": "choice_node",
		"nodes": {
			"choice_node": {
				"speaker": "Chest",
				"text": "Open chest?",
				"choices": [
					{ "text": "Leave it", "next": "" },
					{ "text": "Use Key", "next": "", "condition": EventCondition.is_true("has_key") }
				]
			}
		}
	})

	var state := WorldState.new()
	_box.start(DialogueRunner.new(tree, state))
	assert_eq(_box.get_choice_count(), 1)

	state.set_flag("has_key", true)
	_box.start(DialogueRunner.new(tree, state))
	assert_eq(_box.get_choice_count(), 2)
