class_name DialogueChoice
extends RefCounted

## A selectable branching option within a dialogue page.

var text: String = ""
var next_id: String = ""

func _init(p_text: String = "", p_next_id: String = "") -> void:
	text = p_text
	next_id = p_next_id
