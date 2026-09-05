class_name DialogueChoice
extends RefCounted

## Selectable branching option within a dialogue page.
## Stores display text, target node identifier, and an optional condition guard required for the choice to be offered.

var text: String = ""
var next_id: String = ""
var condition: EventCondition = null

func _init(p_text: String = "", p_next_id: String = "", p_cond: EventCondition = null) -> void:
	text = p_text
	next_id = p_next_id
	condition = p_cond
