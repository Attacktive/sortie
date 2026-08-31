class_name EventCondition
extends RefCounted

## Evaluates a comparison against a WorldState.

enum Op { EQUAL, NOT_EQUAL, LESS_THAN, LESS_EQUAL, GREATER_THAN, GREATER_EQUAL }

var key: String = ''
var op: Op = Op.EQUAL
var target_value: Variant = null

func _init(p_key: String = '', p_op: Op = Op.EQUAL, p_val: Variant = null) -> void:
	key = p_key
	op = p_op
	target_value = p_val

func evaluate(state: WorldState) -> bool:
	if state == null:
		return false

	var val = state.get_flag(key)
	match op:
		Op.EQUAL:
			if target_value is bool and val == null:
				return target_value == false

			return val == target_value
		Op.NOT_EQUAL:
			if target_value is bool and val == null:
				return target_value != false

			return val != target_value
		Op.LESS_THAN:
			return val != null and val < target_value
		Op.LESS_EQUAL:
			return val != null and val <= target_value
		Op.GREATER_THAN:
			return val != null and val > target_value
		Op.GREATER_EQUAL:
			return val != null and val >= target_value
	return false

static func is_true(flag_key: String) -> EventCondition:
	return EventCondition.new(flag_key, Op.EQUAL, true)

static func is_false(flag_key: String) -> EventCondition:
	return EventCondition.new(flag_key, Op.EQUAL, false)

static func eq(flag_key: String, val: Variant) -> EventCondition:
	return EventCondition.new(flag_key, Op.EQUAL, val)

static func gte(flag_key: String, val: Variant) -> EventCondition:
	return EventCondition.new(flag_key, Op.GREATER_EQUAL, val)

static func lte(flag_key: String, val: Variant) -> EventCondition:
	return EventCondition.new(flag_key, Op.LESS_EQUAL, val)
