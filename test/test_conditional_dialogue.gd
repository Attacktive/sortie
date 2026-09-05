extends GutTest

func test_npc_switches_dialogue_based_on_world_state() -> void:
	var default_tree := DialogueTree.from_dict({
		"start": "p1",
		"nodes": { "p1": { "speaker": "Guard", "text": "Halt!" } }
	})
	var friendly_tree := DialogueTree.from_dict({
		"start": "p1",
		"nodes": { "p1": { "speaker": "Guard", "text": "Pass, friend." } }
	})

	var npc: FieldNpc = autofree(FieldNpc.new())
	npc.setup("res://assets/lpc/units/mage_walkcycle.png", "Guard", default_tree)
	npc.conditional_dialogues = [
		{ "condition": EventCondition.is_true("saved_village"), "dialogue": friendly_tree }
	]

	var state := WorldState.new()
	assert_eq(npc.get_dialogue_for_state(state).get_node("p1").text, "Halt!")

	state.set_flag("saved_village", true)
	assert_eq(npc.get_dialogue_for_state(state).get_node("p1").text, "Pass, friend.")

func test_choice_condition_stored() -> void:
	var cond := EventCondition.is_true("has_gold")
	var choice := DialogueChoice.new("Bribe", "pass", cond)
	assert_same(choice.condition, cond)

func test_dialogue_tree_from_dict_parses_choice_condition() -> void:
	var cond := EventCondition.is_true("has_key")
	var tree := DialogueTree.from_dict({
		"start": "choice_node",
		"nodes": {
			"choice_node": {
				"speaker": "Door",
				"text": "Locked door.",
				"choices": [
					{ "text": "Leave", "next": "leave" },
					{ "text": "Unlock", "next": "unlock", "condition": cond },
					{ "text": "Force", "next": "force", "condition": { "flag": "strength", "op": ">=", "value": 10 } }
				]
			},
			"leave": { "speaker": "Door", "text": "Bye." },
			"unlock": { "speaker": "Door", "text": "Open!" },
			"force": { "speaker": "Door", "text": "Broke it open!" }
		}
	})

	var choices := tree.get_node("choice_node").choices
	assert_eq(choices.size(), 3)
	assert_null(choices[0].condition)
	assert_same(choices[1].condition, cond)
	assert_not_null(choices[2].condition)
	assert_eq(choices[2].condition.key, "strength")
	assert_eq(choices[2].condition.op, EventCondition.Op.GREATER_EQUAL)
	assert_eq(choices[2].condition.target_value, 10)

func test_dialogue_runner_filters_choices_by_world_state() -> void:
	var tree := DialogueTree.from_dict({
		"start": "q",
		"nodes": {
			"q": {
				"speaker": "Guard",
				"text": "Halt! Who goes there?",
				"choices": [
					{ "text": "Walk away", "next": "leave" },
					{ "text": "Bribe (10 gold)", "next": "pass", "condition": EventCondition.gte("gold", 10) }
				]
			},
			"leave": { "speaker": "Guard", "text": "Move along." },
			"pass": { "speaker": "Guard", "text": "Proceed." }
		}
	})

	var state := WorldState.new()
	var runner := DialogueRunner.new(tree, state)

	## Without gold, only the unconditional choice is available.
	var choices := runner.get_available_choices()
	assert_eq(choices.size(), 1)
	assert_eq(choices[0].text, "Walk away")
	assert_false(runner.select_choice(1), "selecting an unavailable choice index fails")

	## With sufficient gold, both choices become available and selecting index 1 works.
	state.set_flag("gold", 15)
	choices = runner.get_available_choices()
	assert_eq(choices.size(), 2)
	assert_eq(choices[0].text, "Walk away")
	assert_eq(choices[1].text, "Bribe (10 gold)")

	assert_true(runner.select_choice(1))
	assert_eq(runner.current_node().id, "pass")
