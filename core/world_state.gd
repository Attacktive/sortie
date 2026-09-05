class_name WorldState
extends RefCounted

## Persistent story and environment state container.
## Backed by a plain dictionary so save/load serialization via to_dict/from_dict is trivial and core domain logic stays decoupled from disk I/O.

var _flags: Dictionary = {}

func set_flag(key: String, value: Variant) -> void:
	_flags[key] = value

func get_flag(key: String, default_value: Variant = null) -> Variant:
	return _flags.get(key, default_value)

func has_flag(key: String) -> bool:
	return _flags.has(key)

func clear() -> void:
	_flags.clear()

## Deep-duplicates internal state for save serialization or snapshotting.
func to_dict() -> Dictionary:
	return _flags.duplicate(true)

## Reconstructs a WorldState instance from a deserialized save dictionary.
static func from_dict(dict: Dictionary) -> WorldState:
	var state := WorldState.new()
	state._flags = dict.duplicate(true)
	return state
