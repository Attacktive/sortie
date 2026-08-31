extends GutTest

var _field: Field

func before_each() -> void:
	_field = Field.new()
	add_child_autofree(_field)
	await get_tree().process_frame

func test_stepping_on_trigger_cell_fires_action() -> void:
	var player: FieldPlayer = _field.get_node("FieldPlayer")

	## Place player at (2, 1), step trigger at (3, 1)
	player.position = GridGeometry.cell_to_position(Vector2i(2, 1))

	var action := EventAction.set_flag("stepped_zone", true)
	var trig := EventTrigger.new(EventTrigger.TriggerType.STEP, Vector2i(3, 1), null, [action], true)
	_field.trigger_registry.register_trigger(trig)

	assert_false(_field.world_state.has_flag("stepped_zone"))

	## Walk player east into (3, 1)
	player.position = GridGeometry.cell_to_position(Vector2i(3, 1))
	await get_tree().process_frame

	assert_true(_field.world_state.get_flag("stepped_zone"), "stepping onto trigger cell fires action")

func test_interacting_with_tile_trigger_modifies_map_and_sets_flag() -> void:
	var player: FieldPlayer = _field.get_node("FieldPlayer")
	var chest_cell := Vector2i(2, 2)

	_field._map.set_glyph(chest_cell, "C")
	var actions: Array[EventAction] = [
		EventAction.set_flag("chest_opened", true),
		EventAction.modify_tile(chest_cell, "O")
	]

	var trig := EventTrigger.new(EventTrigger.TriggerType.INTERACT, chest_cell, EventCondition.is_false("chest_opened"), actions, true)
	_field.trigger_registry.register_trigger(trig)

	## Position player north of chest at (2, 1), facing DOWN
	player.position = GridGeometry.cell_to_position(Vector2i(2, 1))
	player.facing = Facing.Direction.DOWN

	_field._try_interact()
	assert_true(_field.world_state.get_flag("chest_opened"))
	assert_eq(_field._map.glyph_at(chest_cell), "O")
