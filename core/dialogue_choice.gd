class_name DialogueChoice
extends RefCounted

## A selectable branching option within a dialogue page.

var text: String = ""
var next_id: String = ""
var condition: EventCondition = null

func _init(p_text: String = "", p_next_id: String = "", p_cond: EventCondition = null) -> void:
	text = p_text
	next_id = p_next_id
	condition = p_cond
