class_name EventAction
extends RefCounted

## An atomic operation executed when a trigger fires.

enum Type { SET_FLAG, SHOW_DIALOGUE, MODIFY_TILE }

var type: Type
var params: Dictionary = {}

func _init(p_type: Type = Type.SET_FLAG, p_params: Dictionary = {}) -> void:
	type = p_type
	params = p_params

static func set_flag(key: String, value: Variant) -> EventAction:
	return EventAction.new(Type.SET_FLAG, { "key": key, "value": value })

static func show_dialogue(tree: DialogueTree) -> EventAction:
	return EventAction.new(Type.SHOW_DIALOGUE, { "dialogue": tree })

static func modify_tile(cell: Vector2i, new_glyph: String) -> EventAction:
	return EventAction.new(Type.MODIFY_TILE, { "cell": cell, "glyph": new_glyph })
