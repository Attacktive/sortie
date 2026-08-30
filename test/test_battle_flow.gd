extends GutTest

## Exercises the view-side state machine, which is where the input traps live.
## The rules underneath are covered elsewhere; this covers the wiring.

var _battle: Battle

func before_each() -> void:
	_battle = load("res://scenes/battle.tscn").instantiate()
	add_child_autofree(_battle)
	await get_tree().process_frame

func _vanguard() -> BattleUnit:
	return _battle._grid.unit_at(Vector2i(0, 7))

## Reaches CHOOSING_ACTION without waiting on the walk tween.
func _move_and_open_menu(unit: BattleUnit, to: Vector2i) -> void:
	_battle._try_select(unit.cell)
	_battle._grid.move_unit(unit, to)
	_battle._on_move_finished()

func test_the_action_menu_is_escapable() -> void:
	_move_and_open_menu(_vanguard(), Vector2i(0, 5))

	assert_eq(_battle._state, Battle.State.CHOOSING_ACTION)
	assert_true(_battle._cursor.cancel_only, "a cancel must still reach the cursor, or the state is a dead end")

func test_cancelling_the_action_menu_puts_the_unit_back() -> void:
	var vanguard := _vanguard()
	_move_and_open_menu(vanguard, Vector2i(0, 5))

	_battle._on_cancel()

	assert_eq(vanguard.cell, Vector2i(0, 7), "the move is undone, not merely re-openable")
	assert_eq(_battle._grid.unit_at(Vector2i(0, 7)), vanguard, "and the grid agrees")
	assert_null(_battle._grid.unit_at(Vector2i(0, 5)), "the walked-to cell is vacated")
	assert_eq(_battle._state, Battle.State.CHOOSING_MOVE, "back to choosing where to go")
	assert_false(vanguard.has_acted, "cancelling must not spend the unit")

func test_cancelling_restores_the_movement_overlay() -> void:
	_move_and_open_menu(_vanguard(), Vector2i(0, 5))
	_battle._on_cancel()

	assert_gt(_battle._grid_view.move_cells.size(), 0, "the range highlight comes back")

func test_selecting_an_enemy_shows_its_reach_without_selecting_it() -> void:
	_battle._try_select(Vector2i(9, 1))

	assert_eq(_battle._state, Battle.State.INSPECTING)
	assert_null(_battle._selected, "inspecting must not commit the player to anything")
	assert_gt(_battle._grid_view.threat_move_cells.size(), 0, "where it can walk")
	assert_gt(_battle._grid_view.threat_attack_cells.size(), 0, "where it could strike from there")

func test_the_threat_overlay_clears_on_cancel() -> void:
	_battle._try_select(Vector2i(9, 1))
	_battle._on_cancel()

	assert_eq(_battle._grid_view.threat_move_cells.size(), 0)
	assert_eq(_battle._grid_view.threat_attack_cells.size(), 0)
	assert_eq(_battle._state, Battle.State.SELECTING_UNIT)

func test_a_spent_unit_cannot_be_selected_again() -> void:
	var vanguard := _vanguard()
	vanguard.has_acted = true

	_battle._try_select(Vector2i(0, 7))

	assert_null(_battle._selected)
	assert_eq(_battle._state, Battle.State.SELECTING_UNIT)
