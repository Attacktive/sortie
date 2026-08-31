extends GutTest

func _make_sample_tree() -> DialogueTree:
	return DialogueTree.from_dict({
		"start": "page1",
		"nodes": {
			"page1": {
				"speaker": "Hero",
				"text": "Hello!",
				"next": "page2"
			},
			"page2": {
				"speaker": "Hero",
				"text": "What do you want?",
				"choices": [
					{ "text": "Fight", "next": "fight" },
					{ "text": "Flee", "next": "flee" }
				]
			},
			"fight": {
				"speaker": "Hero",
				"text": "En garde!",
				"next": ""
			},
			"flee": {
				"speaker": "Hero",
				"text": "Coward!",
				"next": ""
			}
		}
	})

func test_linear_flow_advances_to_completion() -> void:
	var tree := DialogueTree.from_dict({
		"start": "p1",
		"nodes": {
			"p1": { "speaker": "A", "text": "1", "next": "p2" },
			"p2": { "speaker": "A", "text": "2", "next": "" }
		}
	})

	var runner := DialogueRunner.new(tree)
	assert_false(runner.is_finished())
	assert_eq(runner.current_node().text, "1")

	var advanced := runner.advance()
	assert_true(advanced)
	assert_false(runner.is_finished())
	assert_eq(runner.current_node().text, "2")

	advanced = runner.advance()
	assert_false(advanced)
	assert_true(runner.is_finished())
	assert_null(runner.current_node())

func test_choices_prevent_linear_advance() -> void:
	var runner := DialogueRunner.new(_make_sample_tree())
	runner.advance()

	assert_true(runner.current_node().has_choices())
	assert_false(runner.advance(), "cannot linearly advance past a choice prompt")
	assert_false(runner.is_finished())

func test_choice_selection_branches_graph() -> void:
	var runner := DialogueRunner.new(_make_sample_tree())
	runner.advance()

	assert_false(runner.select_choice(-1))
	assert_false(runner.select_choice(5))

	var selected := runner.select_choice(0)
	assert_true(selected)
	assert_eq(runner.current_node().id, "fight")
	assert_eq(runner.current_node().text, "En garde!")

	runner.advance()
	assert_true(runner.is_finished())
