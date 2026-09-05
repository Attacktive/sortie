class_name EventCondition
extends RefCounted

## Boolean guard over WorldState flags and variables.
## Supports equality and ordering comparisons without requiring world state to pre-populate every flag default.

enum Op { EQUAL, NOT_EQUAL, LESS_THAN, LESS_EQUAL, GREATER_THAN, GREATER_EQUAL }

var key: String = ""
var op: Op = Op.EQUAL
var target_value: Variant = null

func _init(p_key: String = "", p_op: Op = Op.EQUAL, p_val: Variant = null) -> void:
	key = p_key
	op = p_op
	target_value = p_val

## Evaluates this condition against the provided world state.
## An unset flag (null) evaluates as false for boolean equality comparisons, so flags default to false without explicit initialization.
## Numeric order comparisons require an explicit non-null value in world state and evaluate to false if unset.
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

## Deserializes an EventCondition from a dictionary specification.
static func from_dict(dict: Dictionary) -> EventCondition:
	var flag: String = str(dict.get("flag", dict.get("key", "")))
	var raw_op = dict.get("op", Op.EQUAL)
	var op: Op = Op.EQUAL
	if raw_op is Op:
		op = raw_op
	elif raw_op is int:
		op = raw_op as Op
	elif raw_op is String:
		match raw_op:
			"==": op = Op.EQUAL
			"!=": op = Op.NOT_EQUAL
			"<": op = Op.LESS_THAN
			"<=": op = Op.LESS_EQUAL
			">": op = Op.GREATER_THAN
			">=": op = Op.GREATER_EQUAL

	var val: Variant = dict.get("value", dict.get("target_value", true))
	return EventCondition.new(flag, op, val)
