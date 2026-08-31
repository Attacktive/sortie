extends GutTest

func test_world_state_flag_storage_and_queries() -> void:
	var state := WorldState.new()
	assert_false(state.has_flag('quest_started'))
	assert_null(state.get_flag('quest_started'))
	assert_eq(state.get_flag('gold', 0), 0)

	state.set_flag('quest_started', true)
	state.set_flag('gold', 50)
	assert_true(state.has_flag('quest_started'))
	assert_eq(state.get_flag('quest_started'), true)
	assert_eq(state.get_flag('gold'), 50)

	state.clear()
	assert_false(state.has_flag('quest_started'))
	assert_false(state.has_flag('gold'))

func test_world_state_serialization() -> void:
	var state := WorldState.new()
	state.set_flag('talked_to_mage', true)
	state.set_flag('chest_opened', 1)

	var serialized := state.to_dict()
	var restored := WorldState.from_dict(serialized)

	assert_eq(restored.get_flag('talked_to_mage'), true)
	assert_eq(restored.get_flag('chest_opened'), 1)

func test_event_condition_evaluations() -> void:
	var state := WorldState.new()
	state.set_flag('active', true)
	state.set_flag('count', 5)

	var cond_true := EventCondition.is_true('active')
	var cond_false := EventCondition.is_false('active')
	var cond_eq := EventCondition.eq('count', 5)
	var cond_gte := EventCondition.gte('count', 5)
	var cond_lte := EventCondition.lte('count', 5)
	var cond_gt := EventCondition.new('count', EventCondition.Op.GREATER_THAN, 5)
	var cond_lt := EventCondition.new('count', EventCondition.Op.LESS_THAN, 10)
	var cond_neq := EventCondition.new('count', EventCondition.Op.NOT_EQUAL, 6)

	assert_true(cond_true.evaluate(state))
	assert_false(cond_false.evaluate(state))
	assert_true(cond_eq.evaluate(state))
	assert_true(cond_gte.evaluate(state))
	assert_true(cond_lte.evaluate(state))
	assert_false(cond_gt.evaluate(state))
	assert_true(cond_lt.evaluate(state))
	assert_true(cond_neq.evaluate(state))
	assert_false(cond_true.evaluate(null))
