extends GutTest

func _make_data(max_hp: int) -> UnitData:
	var data := UnitData.new()
	data.unit_name = "Tester"
	data.max_hp = max_hp
	data.attack = 5
	data.defense = 1
	data.accuracy = 0.9
	data.evasion = 0.1
	data.crit_rate = 0.0
	data.move_range = 3
	data.attack_range = 1
	data.team = UnitData.Team.PLAYER

	return data

func test_unit_starts_at_full_health_on_its_cell() -> void:
	var unit := BattleUnit.new(_make_data(12), Vector2i(2, 3))
	assert_eq(unit.hp, 12)
	assert_eq(unit.cell, Vector2i(2, 3))
	assert_false(unit.has_acted)
	assert_true(unit.is_alive())

func test_unit_is_dead_at_zero_hp() -> void:
	var unit := BattleUnit.new(_make_data(12), Vector2i.ZERO)
	unit.hp = 0
	assert_false(unit.is_alive())

func test_unit_reports_its_team() -> void:
	var unit := BattleUnit.new(_make_data(12), Vector2i.ZERO)
	assert_eq(unit.team(), UnitData.Team.PLAYER)
