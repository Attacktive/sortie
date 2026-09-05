class_name TriggerRegistry
extends RefCounted

## Registry of event triggers stored in a flat list and scanned linearly on lookup.
## Linear scan is sufficient while trigger counts remain small; replace with a spatial dictionary if trigger density grows.

var _triggers: Array[EventTrigger] = []

func register_trigger(trigger: EventTrigger) -> void:
	_triggers.append(trigger)

## Returns all triggers matching the specified cell and trigger type via linear scan.
func get_triggers_at(cell: Vector2i, type: EventTrigger.TriggerType) -> Array[EventTrigger]:
	var matches: Array[EventTrigger] = []
	for trigger in _triggers:
		if trigger.cell == cell and trigger.type == type:
			matches.append(trigger)

	return matches

func clear() -> void:
	_triggers.clear()
