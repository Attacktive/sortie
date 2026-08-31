extends GutTest

func test_trigger_filtering_and_once_exhaustion() -> void:
	var state := WorldState.new()
	var action := EventAction.set_flag('found_key', true)
	var trigger := EventTrigger.new(EventTrigger.TriggerType.STEP, Vector2i(3, 4), EventCondition.is_false('found_key'), [action], true)

	assert_true(trigger.can_fire(state))
	trigger.fired = true
	assert_false(trigger.can_fire(state), 'one-shot trigger cannot fire again once marked fired')

func test_trigger_registry_spatial_lookup() -> void:
	var registry := TriggerRegistry.new()
	var step_trig := EventTrigger.new(EventTrigger.TriggerType.STEP, Vector2i(2, 2))
	var interact_trig := EventTrigger.new(EventTrigger.TriggerType.INTERACT, Vector2i(2, 2))

	registry.register_trigger(step_trig)
	registry.register_trigger(interact_trig)

	var step_results := registry.get_triggers_at(Vector2i(2, 2), EventTrigger.TriggerType.STEP)
	assert_eq(step_results.size(), 1)
	assert_same(step_results[0], step_trig)

	var interact_results := registry.get_triggers_at(Vector2i(2, 2), EventTrigger.TriggerType.INTERACT)
	assert_eq(interact_results.size(), 1)
	assert_same(interact_results[0], interact_trig)

	var empty_results := registry.get_triggers_at(Vector2i(0, 0), EventTrigger.TriggerType.STEP)
	assert_true(empty_results.is_empty())
