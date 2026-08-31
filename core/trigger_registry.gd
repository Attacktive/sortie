class_name TriggerRegistry
extends RefCounted

## Spatial index of triggers by cell coordinate and trigger type.

var _triggers: Array[EventTrigger] = []

func register_trigger(trigger: EventTrigger) -> void:
	_triggers.append(trigger)

func get_triggers_at(cell: Vector2i, type: EventTrigger.TriggerType) -> Array[EventTrigger]:
	var matches: Array[EventTrigger] = []
	for trigger in _triggers:
		if trigger.cell == cell and trigger.type == type:
			matches.append(trigger)

	return matches

func clear() -> void:
	_triggers.clear()
