class_name DialogueNode
extends RefCounted

## Single page of dialogue with speaker identity, message text, and outbound links.
## Transitions linearly via next_id if choices is empty, or pauses for player selection when choices are present.

var id: String = ""
var speaker: String = ""
var text: String = ""
var next_id: String = ""
var choices: Array[DialogueChoice] = []
var action: EventAction = null

func _init(p_id: String = "", p_speaker: String = "", p_text: String = "", p_next_id: String = "", p_action: EventAction = null) -> void:
	id = p_id
	speaker = p_speaker
	text = p_text
	next_id = p_next_id
	action = p_action


func has_choices() -> bool:
	return not choices.is_empty()
