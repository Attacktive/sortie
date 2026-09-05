extends GutTest

var _game: Game = null

func before_each() -> void:
	_game = Game.new()
	add_child_autofree(_game)
	await get_tree().process_frame

func test_game_initializes_at_title_screen() -> void:
	assert_eq(_game.current_mode, Game.Mode.TITLE)
	assert_true(_game.get_active_scene() is Title)

func test_new_game_starts_field_with_fresh_state() -> void:
	_game.start_new_game()
	await get_tree().process_frame

	assert_eq(_game.current_mode, Game.Mode.FIELD)
	assert_true(_game.get_active_scene() is Field)
	assert_not_null(_game.world_state)

func test_quick_battle_transitions_to_battle() -> void:
	_game.start_battle("quick", true)
	await get_tree().process_frame

	assert_eq(_game.current_mode, Game.Mode.BATTLE)
	assert_true(_game.get_active_scene() is Battle)

func test_field_battle_handoff_and_victory_restoration() -> void:
	_game.start_new_game()
	await get_tree().process_frame

	var field: Field = _game.get_active_scene()
	var player: FieldPlayer = field.get_node("FieldPlayer")
	player.position = GridGeometry.cell_to_position(Vector2i(5, 3))
	player.facing = Facing.Direction.UP

	## Trigger encounter
	var restore_data := {
		"cell": Vector2i(5, 3),
		"facing": Facing.Direction.UP
	}
	_game._on_field_battle_requested("forest_skirmish", restore_data)
	await get_tree().process_frame

	assert_eq(_game.current_mode, Game.Mode.BATTLE)
	assert_true(_game.get_active_scene() is Battle)
	assert_eq(_game.field_restore_state.get("cell"), Vector2i(5, 3))

	## Simulate victory
	_game._on_battle_completed(true)
	await get_tree().process_frame

	assert_eq(_game.current_mode, Game.Mode.FIELD)
	assert_true(_game.get_active_scene() is Field)
	var restored_field: Field = _game.get_active_scene()
	var restored_player: FieldPlayer = restored_field.get_node("FieldPlayer")
	assert_eq(restored_player.position, GridGeometry.cell_to_position(Vector2i(5, 3)))
	assert_eq(restored_player.facing, Facing.Direction.UP)
	assert_true(_game.world_state.get_flag("defeated_forest_skirmish"))

func test_defeat_return_to_title() -> void:
	_game.start_battle("boss", false)
	await get_tree().process_frame
	assert_eq(_game.current_mode, Game.Mode.BATTLE)

	_game.show_title()
	await get_tree().process_frame

	assert_eq(_game.current_mode, Game.Mode.TITLE)
	assert_true(_game.get_active_scene() is Title)
