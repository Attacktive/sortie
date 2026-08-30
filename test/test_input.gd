extends GutTest

## Drives the game with synthesized InputEvents pushed through the viewport, so every assertion here travels the real path: event -> viewport -> _unhandled_input or GUI focus -> cursor -> battle state machine.
##
## test_battle_flow.gd covers the same state machine by calling its handlers directly.
## That deliberately skips the layer this file exercises, and it is the layer where this project's bugs have actually lived — the dead-end action menu and the unreachable cancel were both wiring, not rules.

var _battle: Battle

func before_each() -> void:
	_battle = load("res://scenes/battle.tscn").instantiate()
	add_child_autofree(_battle)
	await get_tree().process_frame

## --- Sending input ---

## Buttons fire on release, not press, so a realistic tap is both halves.
func _tap(keycode: Key, times: int = 1) -> void:
	for i in times:
		for pressed in [true, false]:
			var event := InputEventKey.new()
			event.keycode = keycode
			event.physical_keycode = keycode
			event.pressed = pressed

			get_viewport().push_input(event)

		await get_tree().process_frame

## Where a cell sits in viewport coordinates, which is the space a real mouse event arrives in.
func _point_at(cell: Vector2i) -> Vector2:
	return Battle.MARGIN + GridGeometry.cell_center(cell)

func _move_mouse_to(cell: Vector2i) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _point_at(cell)
	event.global_position = event.position

	get_viewport().push_input(event)
	await get_tree().process_frame

func _click(cell: Vector2i, button: MouseButton) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = _point_at(cell)
		event.global_position = event.position

		get_viewport().push_input(event)

	await get_tree().process_frame

## Parks a unit somewhere useful without pretending the walk was played.
func _teleport(unit: BattleUnit, to: Vector2i) -> void:
	_battle._grid.move_unit(unit, to)
	_battle._views[unit].snap()

func _vanguard() -> BattleUnit:
	return _battle._grid.unit_at(Vector2i(0, 7))

## --- The cursor answers the keyboard ---

func test_arrow_keys_move_the_cursor() -> void:
	await _tap(KEY_RIGHT, 3)
	await _tap(KEY_DOWN, 2)

	assert_eq(_battle._cursor.cell, Vector2i(3, 2), "three right and two down from the origin")

func test_the_cursor_stops_at_the_board_edge() -> void:
	await _tap(KEY_LEFT, 4)
	await _tap(KEY_UP, 4)

	assert_eq(_battle._cursor.cell, Vector2i(0, 0), "walking off the top-left corner must clamp, not wrap or crash")

	await _tap(KEY_RIGHT, 20)
	await _tap(KEY_DOWN, 20)

	assert_eq(_battle._cursor.cell, _battle._grid.size - Vector2i.ONE, "and the same at the far corner")

func test_enter_selects_the_unit_under_the_cursor() -> void:
	await _tap(KEY_DOWN, 7)
	await _tap(KEY_ENTER)

	assert_eq(_battle._selected, _vanguard(), "the unit standing on the cursor's cell is the one selected")
	assert_eq(_battle._state, Battle.State.CHOOSING_MOVE)
	assert_gt(_battle._grid_view.move_cells.size(), 0, "and its range is on screen")

func test_enter_on_an_empty_cell_selects_nothing() -> void:
	await _tap(KEY_RIGHT, 4)
	await _tap(KEY_DOWN, 4)
	await _tap(KEY_ENTER)

	assert_null(_battle._selected)
	assert_eq(_battle._state, Battle.State.SELECTING_UNIT)

## --- The cursor answers the mouse ---

func test_moving_the_mouse_moves_the_cursor() -> void:
	await _move_mouse_to(Vector2i(6, 3))

	assert_eq(_battle._cursor.cell, Vector2i(6, 3), "the cursor follows the pointer's cell")

## Regression: this read the global mouse state instead of the event's own position, so it could only ever be exercised by a human with a real pointer.
func test_the_pointer_cell_comes_from_the_event() -> void:
	await _move_mouse_to(Vector2i(2, 5))
	assert_eq(_battle._cursor.cell, Vector2i(2, 5))

	await _move_mouse_to(Vector2i(7, 1))
	assert_eq(_battle._cursor.cell, Vector2i(7, 1), "a second event must be read on its own terms, not as a repeat of the first")

func test_a_left_click_selects_the_unit_under_the_pointer() -> void:
	await _move_mouse_to(Vector2i(1, 7))
	await _click(Vector2i(1, 7), MOUSE_BUTTON_LEFT)

	assert_eq(_battle._selected, _battle._grid.unit_at(Vector2i(1, 7)), "clicking the Mage selects the Mage")
	assert_eq(_battle._state, Battle.State.CHOOSING_MOVE)

func test_a_right_click_backs_out() -> void:
	await _move_mouse_to(Vector2i(9, 1))
	await _click(Vector2i(9, 1), MOUSE_BUTTON_LEFT)
	assert_eq(_battle._state, Battle.State.INSPECTING, "clicking an enemy inspects it")

	await _click(Vector2i(9, 1), MOUSE_BUTTON_RIGHT)

	assert_eq(_battle._state, Battle.State.SELECTING_UNIT, "and a right click puts it back")
	assert_eq(_battle._grid_view.threat_move_cells.size(), 0, "with the threat overlay cleared")

## --- Escape is always available ---

func test_escape_abandons_a_selection() -> void:
	await _tap(KEY_DOWN, 7)
	await _tap(KEY_ENTER)
	await _tap(KEY_ESCAPE)

	assert_null(_battle._selected)
	assert_eq(_battle._state, Battle.State.SELECTING_UNIT)

## The action menu was once a dead end, partly because the cursor was fully deactivated and could no longer hear a cancel.
## It is now parked in cancel_only, which only means anything if a real key event still reaches it while a focused Button sits in front of it.
func test_escape_escapes_the_action_menu_past_the_focused_button() -> void:
	await _tap(KEY_DOWN, 7)
	await _tap(KEY_ENTER)

	var vanguard := _vanguard()
	_teleport(vanguard, Vector2i(0, 5))
	_battle._on_move_finished()
	await get_tree().process_frame

	assert_true(_battle._action_menu.visible, "the menu is open")
	assert_not_null(get_viewport().gui_get_focus_owner(), "and a button holds focus, which is what could swallow the key")

	await _tap(KEY_ESCAPE)

	assert_eq(_battle._state, Battle.State.CHOOSING_MOVE, "escape has to get through anyway")
	assert_eq(vanguard.cell, Vector2i(0, 7), "and the move is undone")
	assert_false(vanguard.has_acted, "backing out must not spend the unit")

func test_a_parked_cursor_ignores_movement_but_still_hears_escape() -> void:
	await _tap(KEY_DOWN, 7)
	await _tap(KEY_ENTER)

	_teleport(_vanguard(), Vector2i(0, 5))
	_battle._on_move_finished()
	await get_tree().process_frame

	var parked := _battle._cursor.cell
	await _tap(KEY_RIGHT, 3)

	assert_eq(_battle._cursor.cell, parked, "the cursor is not free to wander while the menu is open")

	await _tap(KEY_ESCAPE)

	assert_eq(_battle._state, Battle.State.CHOOSING_MOVE, "but escape is not blocked with it")

## --- The action menu takes the keyboard ---

## Puts the Vanguard next to the Raider and opens its menu, so Attack is live.
## Returns it, because _vanguard() looks up whoever is standing on the start cell and there is no longer anyone there.
func _open_menu_beside_an_enemy() -> BattleUnit:
	var vanguard := _vanguard()

	_teleport(vanguard, Vector2i(7, 0))
	_battle._try_select(Vector2i(7, 0))
	_battle._on_move_finished()
	await get_tree().process_frame

	return vanguard

func test_enter_activates_the_focused_attack_button() -> void:
	await _open_menu_beside_an_enemy()

	assert_eq(get_viewport().gui_get_focus_owner(), _battle._action_menu._attack_button, "Attack takes focus when there is something to hit")

	await _tap(KEY_ENTER)

	assert_eq(_battle._state, Battle.State.CHOOSING_TARGET, "and Enter presses it")
	assert_false(_battle._action_menu.visible, "the menu gets out of the way")

func test_the_arrow_keys_walk_the_menu() -> void:
	var vanguard: BattleUnit = await _open_menu_beside_an_enemy()
	await _tap(KEY_DOWN)

	assert_eq(get_viewport().gui_get_focus_owner(), _battle._action_menu._wait_button, "down moves focus to Wait")

	await _tap(KEY_ENTER)

	assert_true(vanguard.has_acted, "and Enter spends the unit on it")
	assert_eq(_battle._state, Battle.State.SELECTING_UNIT)

## With nothing in reach, Attack is disabled rather than hidden, so focus has to start on Wait or the menu opens onto a button that cannot be pressed.
func test_the_menu_opens_on_wait_when_there_is_nothing_to_attack() -> void:
	var vanguard := _vanguard()

	await _tap(KEY_DOWN, 7)
	await _tap(KEY_ENTER)

	_teleport(vanguard, Vector2i(0, 5))
	_battle._on_move_finished()
	await get_tree().process_frame

	assert_true(_battle._action_menu._attack_button.disabled, "there is no enemy within reach of (0, 5)")
	assert_eq(get_viewport().gui_get_focus_owner(), _battle._action_menu._wait_button)

	await _tap(KEY_ENTER)

	assert_true(vanguard.has_acted)

## --- End to end ---

## Nothing in this test touches the battle's own methods.
## If the keyboard were unwired at any point along the chain, this is what would notice.
func test_a_whole_turn_can_be_played_on_the_keyboard_alone() -> void:
	var vanguard := _vanguard()

	await _tap(KEY_DOWN, 7)
	await _tap(KEY_ENTER)
	assert_eq(_battle._state, Battle.State.CHOOSING_MOVE, "selected")

	await _tap(KEY_UP, 2)
	await _tap(KEY_ENTER)

	## Bounded rather than a bare await: if the keypress never reached _try_move there is no walk coming, and a test that hangs in CI is worse than one that fails.
	assert_true(await wait_for_signal(_battle._views[vanguard].walk_finished, 2.0), "confirming a destination has to start a walk")
	await get_tree().process_frame

	assert_eq(vanguard.cell, Vector2i(0, 5), "it walked where it was sent")
	assert_eq(_battle._state, Battle.State.CHOOSING_ACTION, "and its menu came up")

	await _tap(KEY_ENTER)

	assert_true(vanguard.has_acted, "Wait ends its turn")
	assert_eq(_battle._state, Battle.State.SELECTING_UNIT, "and the board is live again")

## The whole chain, from a keypress to a resolved exchange.
func test_an_attack_can_be_ordered_from_the_keyboard() -> void:
	## Hit, no crit, mid variance — twice, because the Raider counters.
	_battle._rolls = ScriptedRollSource.new([0.0, 0.99, 0.5, 0.0, 0.99, 0.5])

	var raider := _battle._grid.unit_at(Vector2i(8, 0))
	var before := raider.hp

	var vanguard: BattleUnit = await _open_menu_beside_an_enemy()
	await _tap(KEY_ENTER)

	await _tap(KEY_RIGHT, 8)
	assert_eq(_battle._cursor.cell, Vector2i(8, 0), "the cursor is over the Raider")

	await _tap(KEY_ENTER)
	assert_true(await wait_for_signal(_battle._animator.finished, 5.0), "confirming a target has to start an exchange")

	## _try_attack is still unwinding when that signal fires; letting it finish keeps the scene from being torn down under a live coroutine.
	await get_tree().process_frame
	await get_tree().process_frame

	assert_lt(raider.hp, before, "a keypress took hit points off an enemy")
	assert_true(vanguard.has_acted, "and spent the attacker")
