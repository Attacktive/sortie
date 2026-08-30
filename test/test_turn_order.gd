extends GutTest

var _grid: BattleGrid

func _spawn(cell: Vector2i, team: UnitData.Team) -> BattleUnit:
	var data := UnitData.new()
	data.max_hp = 10
	data.team = team
	var unit := BattleUnit.new(data, cell)
	_grid.place_unit(unit, cell)

	return unit

func before_each() -> void:
	_grid = BattleGrid.from_ascii(PackedStringArray([
		"....",
		"....",
	]))

func test_battle_opens_on_the_player_turn() -> void:
	_spawn(Vector2i(0, 0), UnitData.Team.PLAYER)
	_spawn(Vector2i(3, 0), UnitData.Team.ENEMY)
	var turns := TurnOrder.new(_grid)

	assert_eq(turns.phase, TurnOrder.Phase.PLAYER_TURN)
	assert_eq(turns.active_team(), UnitData.Team.PLAYER)
	assert_false(turns.is_over())

func test_the_turn_ends_once_every_unit_has_acted() -> void:
	var first := _spawn(Vector2i(0, 0), UnitData.Team.PLAYER)
	var second := _spawn(Vector2i(1, 0), UnitData.Team.PLAYER)
	_spawn(Vector2i(3, 0), UnitData.Team.ENEMY)
	var turns := TurnOrder.new(_grid)

	assert_eq(turns.units_awaiting_orders().size(), 2)
	assert_false(turns.should_end_turn())

	first.has_acted = true
	assert_eq(turns.units_awaiting_orders().size(), 1)
	assert_false(turns.should_end_turn())

	second.has_acted = true
	assert_true(turns.should_end_turn())

func test_a_dead_unit_does_not_hold_up_the_turn() -> void:
	var alive := _spawn(Vector2i(0, 0), UnitData.Team.PLAYER)
	var doomed := _spawn(Vector2i(1, 0), UnitData.Team.PLAYER)
	_spawn(Vector2i(3, 0), UnitData.Team.ENEMY)
	var turns := TurnOrder.new(_grid)

	alive.has_acted = true
	doomed.hp = 0

	assert_true(turns.should_end_turn(), "the dead are not awaiting orders")

func test_ending_a_turn_hands_over_and_clears_spent_flags() -> void:
	var player := _spawn(Vector2i(0, 0), UnitData.Team.PLAYER)
	var enemy := _spawn(Vector2i(3, 0), UnitData.Team.ENEMY)
	var turns := TurnOrder.new(_grid)

	player.has_acted = true
	enemy.has_acted = true
	turns.end_turn()

	assert_eq(turns.phase, TurnOrder.Phase.ENEMY_TURN)
	assert_eq(turns.active_team(), UnitData.Team.ENEMY)
	assert_false(enemy.has_acted, "the incoming team is refreshed")
	assert_true(player.has_acted, "the outgoing team stays spent until its next turn")

	turns.end_turn()

	assert_eq(turns.phase, TurnOrder.Phase.PLAYER_TURN)
	assert_false(player.has_acted)

func test_wiping_out_the_enemy_is_victory() -> void:
	_spawn(Vector2i(0, 0), UnitData.Team.PLAYER)
	var enemy := _spawn(Vector2i(3, 0), UnitData.Team.ENEMY)
	var turns := TurnOrder.new(_grid)

	enemy.hp = 0
	turns.check_resolution()

	assert_eq(turns.phase, TurnOrder.Phase.VICTORY)
	assert_true(turns.is_over())

func test_losing_every_unit_is_defeat() -> void:
	var player := _spawn(Vector2i(0, 0), UnitData.Team.PLAYER)
	_spawn(Vector2i(3, 0), UnitData.Team.ENEMY)
	var turns := TurnOrder.new(_grid)

	player.hp = 0
	turns.check_resolution()

	assert_eq(turns.phase, TurnOrder.Phase.DEFEAT)
	assert_true(turns.is_over())

func test_a_resolved_battle_does_not_hand_over_turns() -> void:
	_spawn(Vector2i(0, 0), UnitData.Team.PLAYER)
	var enemy := _spawn(Vector2i(3, 0), UnitData.Team.ENEMY)
	var turns := TurnOrder.new(_grid)

	enemy.hp = 0
	turns.check_resolution()
	turns.end_turn()

	assert_eq(turns.phase, TurnOrder.Phase.VICTORY, "victory is terminal")
