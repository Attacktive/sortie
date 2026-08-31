class_name DialogueNode
extends RefCounted

## A single page of dialogue containing speaker, message text, and navigation links.

var id: String = ""
var speaker: String = ""
var text: String = ""
var next_id: String = ""
var choices: Array[DialogueChoice] = []

func _init(p_id: String = "", p_speaker: String = "", p_text: String = "", p_next_id: String = "") -> void:
	id = p_id
	speaker = p_speaker
	text = p_text
	next_id = p_next_id

func has_choices() -> bool:
	return not choices.is_empty()
