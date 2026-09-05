extends GutTest

const TEST_DIR := "user://test_game_flow_saves"

var _game: Game = null


func before_each() -> void:
	_clean_test_dir()
	_game = Game.new()
	add_child_autofree(_game)
	_game.save_manager.base_dir = TEST_DIR
	await get_tree().process_frame


func after_each() -> void:
	_clean_test_dir()


func _clean_test_dir() -> void:
	if DirAccess.dir_exists_absolute(TEST_DIR):
		var dir := DirAccess.open(TEST_DIR)
		if dir != null:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while not file_name.is_empty():
				if not dir.current_is_dir():
					dir.remove(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(TEST_DIR)


func test_game_playtime_accumulates_during_field_mode() -> void:
	_game.start_new_game()
	await get_tree().process_frame
	assert_eq(_game.current_mode, Game.Mode.FIELD)

	_game._process(1.5)
	assert_gt(_game.playtime_seconds, 1.0)


func test_game_save_to_slot_writes_complete_save_data() -> void:
	_game.start_new_game()
	await get_tree().process_frame

	var field: Field = _game.get_active_scene()
	var player: FieldPlayer = field.get_node("FieldPlayer")
	player.position = GridGeometry.cell_to_position(Vector2i(6, 3))
	player.facing = Facing.Direction.LEFT
	field.get_map().set_glyph(Vector2i(3, 2), ".")
	_game.world_state.set_flag("test_flag", 42)

	var success := _game.save_to_slot(1)
	assert_true(success)

	var file_path := _game.save_manager.get_slot_path(1)
	assert_true(FileAccess.file_exists(file_path))

	var data := _game.save_manager.load_slot(1)
	assert_not_null(data)
	assert_eq(data.slot_id, 1)
	assert_eq(int(data.world_state_data.get("test_flag")), 42)
	assert_eq(data.field_state_data.get("cell"), Vector2i(6, 3))
	assert_eq(data.field_state_data.get("facing"), Facing.Direction.LEFT)


func test_game_load_from_slot_restores_world_flags_player_cell_and_tiles() -> void:
	_game.start_new_game()
	await get_tree().process_frame

	var field: Field = _game.get_active_scene()
	var player: FieldPlayer = field.get_node("FieldPlayer")
	player.position = GridGeometry.cell_to_position(Vector2i(7, 5))
	player.facing = Facing.Direction.UP
	field.get_map().set_glyph(Vector2i(3, 2), ".")
	_game.world_state.set_flag("story_progress", "chapter_1")
	_game.save_to_slot(2)

	_game.show_title()
	await get_tree().process_frame
	assert_eq(_game.current_mode, Game.Mode.TITLE)
	_game.load_from_slot(2)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_game.current_mode, Game.Mode.FIELD)

	var loaded_field: Field = _game.get_active_scene()
	var loaded_player: FieldPlayer = loaded_field.get_node("FieldPlayer")
	assert_eq(loaded_player.position, GridGeometry.cell_to_position(Vector2i(7, 5)))
	assert_eq(loaded_player.facing, Facing.Direction.UP)
	assert_eq(_game.world_state.get_flag("story_progress"), "chapter_1")
	assert_eq(loaded_field.get_map().glyph_at(Vector2i(3, 2)), ".")
	assert_false(loaded_field.get_map().is_solid(Vector2i(3, 2)))


func test_title_screen_load_slot_transitions_to_field() -> void:
	_game.start_new_game()
	await get_tree().process_frame

	var field: Field = _game.get_active_scene()
	var player: FieldPlayer = field.get_node("FieldPlayer")
	player.position = GridGeometry.cell_to_position(Vector2i(4, 2))
	_game.save_to_slot(1)

	_game.show_title()
	await get_tree().process_frame

	var title: Title = _game.get_active_scene()
	title.load_game_requested.emit()

	var slot_menu: SaveSlotMenu = _game.get_slot_menu()
	assert_not_null(slot_menu, "slot menu opened from title load request")
	assert_eq(slot_menu.mode, SaveSlotMenu.Mode.LOAD)

	slot_menu.slot_selected.emit(1, SaveSlotMenu.Mode.LOAD)
	await get_tree().process_frame
	assert_eq(_game.current_mode, Game.Mode.FIELD)
