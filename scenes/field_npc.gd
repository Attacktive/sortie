class_name FieldNpc
extends Node2D

## An interactive character placed on the field map.

var npc_name: String = ""
var dialogue: DialogueTree = null
var facing: Facing.Direction = Facing.Direction.DOWN
var conditional_dialogues: Array[Dictionary] = []

var _sheet: Texture2D = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func setup(sheet_path: String, p_name: String, p_dialogue: DialogueTree) -> void:
	_sheet = load(sheet_path)
	npc_name = p_name
	dialogue = p_dialogue
	queue_redraw()

func get_dialogue_for_state(state: WorldState) -> DialogueTree:
	if state != null:
		for entry in conditional_dialogues:
			var cond: EventCondition = entry.get("condition")
			if cond == null or cond.evaluate(state):
				return entry.get("dialogue")

	return dialogue

func get_collision_box() -> Rect2:
	return FieldBody.box_for_sprite(position)

func face_toward(target_pos: Vector2) -> void:
	facing = Facing.toward(target_pos - position)
	queue_redraw()

func _draw() -> void:
	if _sheet == null:
		return

	var cell := float(GridGeometry.CELL_SIZE)
	var source := Rect2(0.0, int(facing) * cell, cell, cell)

	draw_texture_rect_region(_sheet, Rect2(Vector2.ZERO, Vector2(cell, cell)), source)
