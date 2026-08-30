extends GutTest

func _attacker_data() -> UnitData:
	var data := UnitData.new()
	data.max_hp = 20
	data.attack = 10
	data.defense = 0
	data.accuracy = 0.9
	data.evasion = 0.0
	data.crit_rate = 0.2
	data.attack_range = 1
	data.team = UnitData.Team.PLAYER

	return data

func _defender_data() -> UnitData:
	var data := UnitData.new()
	data.max_hp = 20
	data.attack = 4
	data.defense = 2
	data.accuracy = 0.8
	data.evasion = 0.1
	data.crit_rate = 0.0
	data.attack_range = 1
	data.team = UnitData.Team.ENEMY

	return data

## Two adjacent units on a one-row map whose terrain the caller chooses.
func _duel(row: String) -> Array:
	var grid := BattleGrid.from_ascii(PackedStringArray([row]))
	var attacker := BattleUnit.new(_attacker_data(), Vector2i(0, 0))
	var defender := BattleUnit.new(_defender_data(), Vector2i(1, 0))
	grid.place_unit(attacker, Vector2i(0, 0))
	grid.place_unit(defender, Vector2i(1, 0))

	return [grid, attacker, defender]

func test_hit_chance_subtracts_evasion() -> void:
	var duel := _duel("..")
	var forecast := Combat.forecast(duel[0], duel[1], duel[2])

	assert_almost_eq(forecast.hit_chance, 0.8, 0.0001, "0.9 accuracy minus 0.1 evasion")

func test_forest_lowers_hit_chance_and_damage_together() -> void:
	var duel := _duel(".F")
	var forecast := Combat.forecast(duel[0], duel[1], duel[2])

	assert_almost_eq(forecast.hit_chance, 0.6, 0.0001, "0.9 - (0.1 evasion + 0.2 forest)")
	assert_eq(forecast.min_damage, 5, "raw 6 at 0.9 variance rounds to 5")
	assert_eq(forecast.max_damage, 7, "raw 6 at 1.1 variance rounds to 7")

func test_damage_bounds_come_from_variance() -> void:
	var duel := _duel("..")
	var forecast := Combat.forecast(duel[0], duel[1], duel[2])

	assert_eq(forecast.min_damage, 7, "raw 8 at 0.9 variance rounds to 7")
	assert_eq(forecast.max_damage, 9, "raw 8 at 1.1 variance rounds to 9")

func test_crit_damage_is_the_maximum_tripled() -> void:
	var duel := _duel("..")
	var forecast := Combat.forecast(duel[0], duel[1], duel[2])

	assert_eq(forecast.crit_damage, 27, "9 maximum times the crit multiplier of 3")

func test_hit_chance_clamps_at_both_ends() -> void:
	var duel := _duel("..")
	var attacker: BattleUnit = duel[1]
	var defender: BattleUnit = duel[2]

	attacker.data.accuracy = 0.05
	defender.data.evasion = 0.9
	assert_almost_eq(Combat.forecast(duel[0], attacker, defender).hit_chance, 0.0, 0.0001, "never negative")

	attacker.data.accuracy = 1.0
	defender.data.evasion = 0.0
	assert_almost_eq(Combat.forecast(duel[0], attacker, defender).hit_chance, 1.0, 0.0001, "never above one")

func test_damage_never_forecasts_below_one() -> void:
	var duel := _duel("..")
	var attacker: BattleUnit = duel[1]
	var defender: BattleUnit = duel[2]
	attacker.data.attack = 3
	defender.data.defense = 10

	var forecast := Combat.forecast(duel[0], attacker, defender)
	assert_eq(forecast.min_damage, 1, "heavy armor still takes a scratch")
	assert_eq(forecast.max_damage, 1)

func test_forecast_mutates_nothing() -> void:
	var duel := _duel("..")
	var defender: BattleUnit = duel[2]
	var hp_before := defender.hp
	var cell_before := defender.cell

	Combat.forecast(duel[0], duel[1], defender)

	assert_eq(defender.hp, hp_before, "forecasting must not damage anyone")
	assert_eq(defender.cell, cell_before)
