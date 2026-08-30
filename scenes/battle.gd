class_name Battle
extends Node2D

enum State { SELECTING_UNIT, INSPECTING, CHOOSING_MOVE, CHOOSING_ACTION, CHOOSING_TARGET, ANIMATING, ENEMY_TURN, RESOLVED }

const MARGIN := Vector2(40, 40)
const ENEMY_STEP_DELAY := 0.35

var _grid: BattleGrid
var _turns: TurnOrder
var _rolls: RealRollSource
var _state: State = State.SELECTING_UNIT

var _grid_view: GridView
var _cursor: Cursor
var _action_menu: ActionMenu
var _forecast_panel: ForecastPanel
var _result_screen: ResultScreen
var _views: Dictionary[BattleUnit, UnitView] = {}

var _selected: BattleUnit = null
var _field: MovementField = null

## Where the selected unit stood before it moved, so a cancel can put it back.
var _origin_cell: Vector2i = Vector2i.ZERO

func _ready() -> void:
	_start_battle()

func _start_battle() -> void:
	var seed_value := int(Time.get_unix_time_from_system())
	_rolls = RealRollSource.new(seed_value)
	print("Sortie battle seed: %d" % seed_value)

	_grid = Scenario.build_grid()
	_turns = TurnOrder.new(_grid)
	_build_views()
	_enter_unit_selection()

	if OS.has_environment("SORTIE_SHOT"):
		add_child(load("res://scenes/screenshot_probe.gd").new())

func _build_views() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	_views.clear()

	_grid_view = GridView.new()
	_grid_view.grid = _grid
	_grid_view.position = MARGIN
	add_child(_grid_view)

	for unit in Scenario.populate(_grid):
		var view := UnitView.new()
		view.setup(unit)
		_grid_view.add_child(view)
		_views[unit] = view

	_cursor = Cursor.new()
	_cursor.bounds = _grid.size
	_grid_view.add_child(_cursor)
	_cursor.moved.connect(_on_cursor_moved)
	_cursor.confirmed.connect(_on_cursor_confirmed)
	_cursor.canceled.connect(_on_cancel)

	var layer := CanvasLayer.new()
	add_child(layer)

	_action_menu = ActionMenu.new()
	layer.add_child(_action_menu)
	_action_menu.attack_chosen.connect(_on_attack_chosen)
	_action_menu.wait_chosen.connect(_on_wait_chosen)

	_forecast_panel = ForecastPanel.new()
	_forecast_panel.position = Vector2(40, 8)
	layer.add_child(_forecast_panel)

	_result_screen = ResultScreen.new()
	_result_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_result_screen)
	_result_screen.restart_requested.connect(_start_battle)

	_refresh_all()

func _refresh_all() -> void:
	for view in _views.values():
		view.refresh()

	_grid_view.refresh()

## --- Player turn ---

func _enter_unit_selection() -> void:
	_state = State.SELECTING_UNIT
	_selected = null
	_field = null
	_grid_view.move_cells.clear()
	_grid_view.attack_cells.clear()
	_clear_threat()
	_forecast_panel.clear()
	_action_menu.close()
	_cursor.cancel_only = false
	_cursor.cancel_only = false
	_cursor.active = true
	_refresh_all()

	if _turns.should_end_turn():
		_end_player_turn()

func _on_cursor_moved(cell: Vector2i) -> void:
	_cursor.queue_redraw()

	if _state != State.CHOOSING_TARGET:
		return

	var target := _grid.unit_at(cell)
	if target == null or target.team() == UnitData.Team.PLAYER or not target.is_alive():
		_forecast_panel.clear()
		return

	_forecast_panel.show_forecast(Combat.forecast(_grid, _selected, target))

func _on_cursor_confirmed(cell: Vector2i) -> void:
	match _state:
		State.SELECTING_UNIT:
			_try_select(cell)
		State.INSPECTING:
			_clear_threat()
			_try_select(cell)
		State.CHOOSING_MOVE:
			_try_move(cell)
		State.CHOOSING_TARGET:
			_try_attack(cell)

func _try_select(cell: Vector2i) -> void:
	var unit := _grid.unit_at(cell)
	if unit == null or not unit.is_alive():
		return

	if unit.team() == UnitData.Team.ENEMY:
		_inspect(unit)
		return

	if unit.has_acted:
		return

	_selected = unit
	_origin_cell = unit.cell
	_field = Movement.field(_grid, unit)
	_grid_view.move_cells = _field.reachable_cells()
	_grid_view.refresh()
	_state = State.CHOOSING_MOVE

## Shows where an enemy could walk, and everywhere it could strike from there.
## Purely informational — it selects nothing and spends nothing.
func _inspect(unit: BattleUnit) -> void:
	_grid_view.move_cells.clear()
	_grid_view.threat_move_cells = Movement.field(_grid, unit).reachable_cells()
	_grid_view.threat_attack_cells = Movement.threat_cells(_grid, unit)
	_grid_view.refresh()
	_state = State.INSPECTING

func _clear_threat() -> void:
	_grid_view.threat_move_cells.clear()
	_grid_view.threat_attack_cells.clear()

func _try_move(cell: Vector2i) -> void:
	if not _field.can_reach(cell):
		return

	var path := _field.path_to(cell)
	_grid_view.move_cells.clear()
	_grid_view.refresh()

	## Confirming on the unit's own cell means "stay here" — moving onto yourself
	## would trip the grid's occupancy assert, so skip straight to the action menu.
	if cell == _selected.cell:
		_on_move_finished()
		return

	_grid.move_unit(_selected, cell)
	_state = State.ANIMATING
	_cursor.active = false

	var view: UnitView = _views[_selected]
	view.walk_finished.connect(_on_move_finished, CONNECT_ONE_SHOT)
	view.walk_path(path)

func _on_move_finished() -> void:
	_state = State.CHOOSING_ACTION
	_cursor.active = false
	_cursor.cancel_only = true

	var anchor := GridGeometry.cell_to_position(_selected.cell) + MARGIN + Vector2(GridGeometry.CELL_SIZE + 6, 0)
	_action_menu.open(anchor, not _targets_in_range().is_empty())

func _targets_in_range() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for cell in Movement.attackable_cells(_grid, _selected.cell, _selected.data.attack_range):
		var occupant := _grid.unit_at(cell)
		if occupant != null and occupant.is_alive() and occupant.team() == UnitData.Team.ENEMY:
			result.append(occupant)

	return result

func _on_attack_chosen() -> void:
	_action_menu.close()
	_state = State.CHOOSING_TARGET
	_cursor.active = true

	var cells: Array[Vector2i] = []
	for target in _targets_in_range():
		cells.append(target.cell)

	_grid_view.attack_cells = cells
	_grid_view.refresh()

func _on_wait_chosen() -> void:
	_action_menu.close()
	_cursor.cancel_only = false
	_selected.has_acted = true
	_enter_unit_selection()

func _try_attack(cell: Vector2i) -> void:
	var target := _grid.unit_at(cell)
	if target == null or target.team() != UnitData.Team.ENEMY or not target.is_alive():
		return

	if Movement.manhattan(_selected.cell, cell) > _selected.data.attack_range:
		return

	Combat.exchange(_grid, _selected, target, _rolls)
	_selected.has_acted = true
	_cleanup_dead()
	_turns.check_resolution()
	_refresh_all()

	if _finish_if_resolved():
		return

	_enter_unit_selection()

## Cancel backs out one step rather than abandoning the whole action.
func _on_cancel() -> void:
	match _state:
		State.INSPECTING:
			_clear_threat()
			_grid_view.refresh()
			_state = State.SELECTING_UNIT
		State.CHOOSING_MOVE:
			_enter_unit_selection()
		State.CHOOSING_ACTION:
			_undo_move()
		State.CHOOSING_TARGET:
			_grid_view.attack_cells.clear()
			_forecast_panel.clear()
			_grid_view.refresh()
			_on_move_finished()

## Puts the unit back where it started and reopens its movement range.
## Committing a move must never be a one-way door.
func _undo_move() -> void:
	_action_menu.close()
	_cursor.cancel_only = false
	_cursor.active = true

	if _selected.cell != _origin_cell:
		_grid.move_unit(_selected, _origin_cell)
		_views[_selected].snap()

	_field = Movement.field(_grid, _selected)
	_grid_view.move_cells = _field.reachable_cells()
	_grid_view.refresh()
	_cursor.cell = _selected.cell
	_state = State.CHOOSING_MOVE

func _cleanup_dead() -> void:
	for unit in _views.keys():
		if not unit.is_alive():
			_grid.remove_unit(unit)

func _finish_if_resolved() -> bool:
	if not _turns.is_over():
		return false

	_state = State.RESOLVED
	_cursor.active = false
	_result_screen.show_result(_turns.phase == TurnOrder.Phase.VICTORY)

	return true

## --- Enemy turn ---

func _end_player_turn() -> void:
	_turns.end_turn()
	_state = State.ENEMY_TURN
	_cursor.active = false
	_run_enemy_turn()

func _run_enemy_turn() -> void:
	for unit in _turns.units_awaiting_orders():
		if not unit.is_alive():
			continue

		await _take_enemy_action(unit)

		if _turns.is_over():
			_finish_if_resolved()
			return

	_turns.end_turn()
	_enter_unit_selection()

func _take_enemy_action(unit: BattleUnit) -> void:
	var decision := EnemyAI.decide(_grid, unit)
	var field := Movement.field(_grid, unit)
	var path := field.path_to(decision.move_to)

	if decision.move_to != unit.cell:
		_grid.move_unit(unit, decision.move_to)
		var view: UnitView = _views[unit]
		view.walk_path(path)
		await view.walk_finished

	if decision.target != null:
		Combat.exchange(_grid, unit, decision.target, _rolls)
		_cleanup_dead()
		_turns.check_resolution()

	unit.has_acted = true
	_refresh_all()

	await get_tree().create_timer(ENEMY_STEP_DELAY).timeout
