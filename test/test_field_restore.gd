extends GutTest

var _field: Field = null

func before_each() -> void:
	_field = Field.new()
	add_child_autofree(_field)
	await get_tree().process_frame

func test_start_battle_action_freezes_player_and_emits_battle_requested() -> void:
	watch_signals(_field)

	var player: FieldPlayer = _field.get_node("FieldPlayer")
	player.position = GridGeometry.cell_to_position(Vector2i(2, 1))
	player.facing = Facing.Direction.UP
	await get_tree().process_frame

	var action := EventAction.start_battle("boss_encounter")
	_field._execute_action(action)

	assert_signal_emitted(_field, "battle_requested")
	var params = get_signal_parameters(_field, "battle_requested")
	assert_eq(params[0], "boss_encounter")
	assert_eq(params[1].get("cell"), Vector2i(2, 1))
	assert_eq(params[1].get("facing"), Facing.Direction.UP)
	assert_true(player.frozen, "player is frozen during battle transition")

func test_restore_repositions_player_and_resets_facing() -> void:
	var player: FieldPlayer = _field.get_node("FieldPlayer")
	player.frozen = true

	var restore_data := {
		"cell": Vector2i(7, 4),
		"facing": Facing.Direction.RIGHT
	}

	_field.restore(restore_data)

	assert_eq(player.position, GridGeometry.cell_to_position(Vector2i(7, 4)))
	assert_eq(player.facing, Facing.Direction.RIGHT)
	assert_false(player.frozen, "player is unfrozen after restoration")


func test_field_capture_state_returns_coordinates_facing_and_modified_tiles() -> void:
	var player: FieldPlayer = _field.get_node("FieldPlayer")
	player.position = GridGeometry.cell_to_position(Vector2i(5, 3))
	player.facing = Facing.Direction.LEFT
	_field.get_map().set_glyph(Vector2i(3, 1), ".")

	var state := _field.capture_state()
	assert_eq(state.get("cell"), Vector2i(5, 3))
	assert_eq(state.get("facing"), Facing.Direction.LEFT)
	var modified: Dictionary = state.get("modified_tiles", {})
	assert_eq(modified.get(Vector2i(3, 1)), ".")


func test_field_restore_reapplies_modified_tiles_and_refreshes_view() -> void:
	assert_eq(_field.get_map().glyph_at(Vector2i(3, 2)), "#")
	assert_true(_field.get_map().is_solid(Vector2i(3, 2)))

	var restore_data := {
		"cell": Vector2i(2, 2),
		"facing": Facing.Direction.DOWN,
		"modified_tiles": {
			Vector2i(3, 2): "."
		}
	}

	_field.restore(restore_data)
	assert_eq(_field.get_map().glyph_at(Vector2i(3, 2)), ".")
	assert_false(_field.get_map().is_solid(Vector2i(3, 2)))
