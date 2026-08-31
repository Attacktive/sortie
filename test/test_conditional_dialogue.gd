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
