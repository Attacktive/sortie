class_name EventTrigger
extends RefCounted

## Cell-bound trigger activated either by stepping onto the tile or by facing it and pressing interact.
## Evaluates an optional condition before firing its actions, and tracks whether one-shot triggers have already fired.

enum TriggerType { STEP, INTERACT }

var type: TriggerType = TriggerType.STEP
var cell: Vector2i = Vector2i.ZERO
var condition: EventCondition = null
var actions: Array[EventAction] = []
var once: bool = false
var fired: bool = false

func _init(p_type: TriggerType = TriggerType.STEP, p_cell: Vector2i = Vector2i.ZERO, p_cond: EventCondition = null, p_actions: Array[EventAction] = [], p_once: bool = false) -> void:
	type = p_type
	cell = p_cell
	condition = p_cond
	actions = p_actions
	once = p_once

func can_fire(state: WorldState) -> bool:
	if once and fired:
		return false

	if condition != null and not condition.evaluate(state):
		return false

	return true
