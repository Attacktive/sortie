class_name WorldState
extends RefCounted

## Key-value story state container supporting boolean flags, integer counts, and string states.

var _flags: Dictionary = {}

func set_flag(key: String, value: Variant) -> void:
	_flags[key] = value

func get_flag(key: String, default_value: Variant = null) -> Variant:
	return _flags.get(key, default_value)

func has_flag(key: String) -> bool:
	return _flags.has(key)

func clear() -> void:
	_flags.clear()

func to_dict() -> Dictionary:
	return _flags.duplicate(true)

static func from_dict(dict: Dictionary) -> WorldState:
	var state := WorldState.new()
	state._flags = dict.duplicate(true)
	return state
