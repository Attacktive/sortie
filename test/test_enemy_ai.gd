extends GutTest

func _enemy_data(move_range: int, attack: int) -> UnitData:
	var data := UnitData.new()
	data.max_hp = 20
	data.attack = attack
	data.defense = 0
	data.accuracy = 1.0
	data.evasion = 0.0
	data.crit_rate = 0.0
	data.move_range = move_range
	data.attack_range = 1
	data.team = UnitData.Team.ENEMY

	return data

func _player_data(max_hp: int, defense: int) -> UnitData:
	var data := UnitData.new()
	data.max_hp = max_hp
	data.attack = 5
	data.defense = defense
	data.accuracy = 1.0
	data.evasion = 0.0
	data.crit_rate = 0.0
	data.move_range = 3
	data.attack_range = 1
	data.team = UnitData.Team.PLAYER

	return data

func _spawn(grid: BattleGrid, data: UnitData, cell: Vector2i) -> BattleUnit:
	var unit := BattleUnit.new(data, cell)
	grid.place_unit(unit, cell)

	return unit

func test_it_closes_and_attacks_an_adjacent_reachable_target() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray(["....."]))
	var enemy := _spawn(grid, _enemy_data(3, 8), Vector2i(0, 0))
	var player := _spawn(grid, _player_data(20, 0), Vector2i(3, 0))

	var decision := EnemyAI.decide(grid, enemy)

	assert_eq(decision.target, player, "it commits to the only target it can reach")
	assert_eq(decision.move_to, Vector2i(2, 0), "it stops adjacent, not on top of them")

func test_it_prefers_the_target_it_can_hurt_most() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".....",
		".....",
	]))
	var enemy := _spawn(grid, _enemy_data(4, 10), Vector2i(0, 0))
	var armored := _spawn(grid, _player_data(20, 8), Vector2i(2, 0))
	var soft := _spawn(grid, _player_data(20, 0), Vector2i(2, 1))

	var decision := EnemyAI.decide(grid, enemy)

	assert_eq(decision.target, soft, "10 damage beats 2")
	assert_ne(decision.target, armored)

func test_a_guaranteed_kill_outranks_raw_damage() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".....",
		".....",
	]))
	var enemy := _spawn(grid, _enemy_data(4, 10), Vector2i(0, 0))
	var healthy := _spawn(grid, _player_data(20, 0), Vector2i(2, 0))
	var wounded := _spawn(grid, _player_data(20, 6), Vector2i(2, 1))
	wounded.hp = 3

	var decision := EnemyAI.decide(grid, enemy)

	assert_eq(decision.target, wounded, "a certain kill for 4 beats a scratch for 10")
	assert_ne(decision.target, healthy)

func test_it_advances_when_nothing_is_in_reach() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray(["........"]))
	var enemy := _spawn(grid, _enemy_data(2, 8), Vector2i(0, 0))
	_spawn(grid, _player_data(20, 0), Vector2i(7, 0))

	var decision := EnemyAI.decide(grid, enemy)

	assert_null(decision.target, "nothing is attackable this turn")
	assert_eq(decision.move_to, Vector2i(2, 0), "it spends its full budget closing the distance")

func test_it_routes_around_walls_when_advancing() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".#..",
		"....",
	]))
	var enemy := _spawn(grid, _enemy_data(2, 8), Vector2i(0, 0))
	_spawn(grid, _player_data(20, 0), Vector2i(3, 0))

	var decision := EnemyAI.decide(grid, enemy)

	assert_null(decision.target)
	assert_eq(decision.move_to, Vector2i(1, 1), "down and across, since the wall blocks the direct line")

func test_it_holds_position_when_it_cannot_close_at_all() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".#.",
	]))
	var enemy := _spawn(grid, _enemy_data(3, 8), Vector2i(0, 0))
	_spawn(grid, _player_data(20, 0), Vector2i(2, 0))

	var decision := EnemyAI.decide(grid, enemy)

	assert_null(decision.target)
	assert_eq(decision.move_to, Vector2i(0, 0), "walled off entirely, so it stays put")

func test_ties_break_deterministically() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		"...",
		"...",
		"...",
	]))
	var enemy := _spawn(grid, _enemy_data(3, 8), Vector2i(1, 1))
	_spawn(grid, _player_data(20, 0), Vector2i(1, 0))
	_spawn(grid, _player_data(20, 0), Vector2i(1, 2))

	var first := EnemyAI.decide(grid, enemy)
	var second := EnemyAI.decide(grid, enemy)

	assert_eq(first.move_to, second.move_to, "the same board yields the same decision")
	assert_eq(first.target, second.target)
