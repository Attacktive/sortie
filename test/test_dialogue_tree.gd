extends GutTest

func test_choice_creation() -> void:
	var choice := DialogueChoice.new("Yes", "accept")
	assert_eq(choice.text, "Yes")
	assert_eq(choice.next_id, "accept")

func test_node_creation_and_choice_check() -> void:
	var node := DialogueNode.new("intro", "Guard", "Halt!", "next_step")
	assert_eq(node.id, "intro")
	assert_eq(node.speaker, "Guard")
	assert_eq(node.text, "Halt!")
	assert_eq(node.next_id, "next_step")
	assert_false(node.has_choices())

	node.choices.append(DialogueChoice.new("Option A", "a"))
	assert_true(node.has_choices())

func test_tree_construction_from_dict() -> void:
	var data := {
		"start": "greeting",
		"nodes": {
			"greeting": {
				"speaker": "Elder",
				"text": "Welcome to our village.",
				"choices": [
					{ "text": "Thank you.", "next": "thanks" },
					{ "text": "Where is the inn?", "next": "inn" }
				]
			},
			"thanks": {
				"speaker": "Elder",
				"text": "Rest well.",
				"next": ""
			},
			"inn": {
				"speaker": "Elder",
				"text": "To the east.",
				"next": ""
			}
		}
	}

	var tree := DialogueTree.from_dict(data)
	assert_eq(tree.start_node_id, "greeting")
	assert_true(tree.has_node("greeting"))
	assert_true(tree.has_node("thanks"))
	assert_true(tree.has_node("inn"))
	assert_false(tree.has_node("missing"))

	var greeting := tree.get_node("greeting")
	assert_eq(greeting.speaker, "Elder")
	assert_eq(greeting.choices.size(), 2)
	assert_eq(greeting.choices[0].text, "Thank you.")
	assert_eq(greeting.choices[0].next_id, "thanks")
