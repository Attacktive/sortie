class_name TurnOrder
extends RefCounted

enum Phase { PLAYER_TURN, ENEMY_TURN, VICTORY, DEFEAT }

var phase: Phase = Phase.PLAYER_TURN

var _grid: BattleGrid

func _init(grid: BattleGrid) -> void:
	_grid = grid

func is_over() -> bool:
	return phase == Phase.VICTORY or phase == Phase.DEFEAT

func active_team() -> UnitData.Team:
	if phase == Phase.ENEMY_TURN:
		return UnitData.Team.ENEMY

	return UnitData.Team.PLAYER

## Living units on the active team that have not yet spent their action.
func units_awaiting_orders() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in _grid.living_units_of_team(active_team()):
		if not unit.has_acted:
			result.append(unit)

	return result

func should_end_turn() -> bool:
	return units_awaiting_orders().is_empty()

## Hands the turn to the other team and refreshes the incoming side.
## A resolved battle is terminal, so this becomes a no-op once someone has won.
func end_turn() -> void:
	if is_over():
		return

	if phase == Phase.PLAYER_TURN:
		phase = Phase.ENEMY_TURN
	else:
		phase = Phase.PLAYER_TURN

	for unit in _grid.living_units_of_team(active_team()):
		unit.has_acted = false

## Called after every attack. Victory takes precedence over defeat in a mutual wipe.
func check_resolution() -> void:
	if is_over():
		return

	if _grid.living_units_of_team(UnitData.Team.ENEMY).is_empty():
		phase = Phase.VICTORY
		return

	if _grid.living_units_of_team(UnitData.Team.PLAYER).is_empty():
		phase = Phase.DEFEAT
