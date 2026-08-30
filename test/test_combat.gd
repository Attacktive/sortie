extends GutTest

func _duel(row: String) -> Array:
	var attacker_data := UnitData.new()
	attacker_data.max_hp = 20
	attacker_data.attack = 10
	attacker_data.accuracy = 0.9
	attacker_data.crit_rate = 0.2
	attacker_data.attack_range = 1
	attacker_data.team = UnitData.Team.PLAYER

	var defender_data := UnitData.new()
	defender_data.max_hp = 20
	defender_data.attack = 4
	defender_data.defense = 2
	defender_data.evasion = 0.1
	defender_data.crit_rate = 0.0
	defender_data.attack_range = 1
	defender_data.team = UnitData.Team.ENEMY

	var grid := BattleGrid.from_ascii(PackedStringArray([row]))
	var attacker := BattleUnit.new(attacker_data, Vector2i(0, 0))
	var defender := BattleUnit.new(defender_data, Vector2i(1, 0))
	grid.place_unit(attacker, Vector2i(0, 0))
	grid.place_unit(defender, Vector2i(1, 0))

	return [grid, attacker, defender]

func test_a_miss_deals_nothing_and_draws_exactly_one_roll() -> void:
	var duel := _duel("..")
	var rolls := ScriptedRollSource.new([0.85] as Array[float])

	var result := Combat.resolve(duel[0], duel[1], duel[2], rolls)

	assert_false(result.hit, "0.85 is not below the hit chance of 0.8")
	assert_eq(result.damage, 0)
	assert_eq(duel[2].hp, 20, "a miss leaves the defender untouched")
	assert_eq(rolls.drawn(), 1, "a miss must not draw the crit or variance rolls")

func test_a_hit_draws_exactly_three_rolls() -> void:
	var duel := _duel("..")
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5] as Array[float])

	Combat.resolve(duel[0], duel[1], duel[2], rolls)

	assert_eq(rolls.drawn(), 3, "hit, crit, variance")

func test_a_plain_hit_deals_raw_damage_at_mid_variance() -> void:
	var duel := _duel("..")
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5] as Array[float])

	var result := Combat.resolve(duel[0], duel[1], duel[2], rolls)

	assert_true(result.hit)
	assert_false(result.crit, "0.99 is not below the crit rate of 0.2")
	assert_eq(result.damage, 8, "attack 10 minus defense 2, at variance 1.0")
	assert_eq(duel[2].hp, 12)

func test_a_crit_triples_the_damage() -> void:
	var duel := _duel("..")
	var rolls := ScriptedRollSource.new([0.0, 0.0, 0.5] as Array[float])

	var result := Combat.resolve(duel[0], duel[1], duel[2], rolls)

	assert_true(result.crit)
	assert_eq(result.damage, 24, "8 tripled")

func test_the_crit_threshold_is_exclusive() -> void:
	var below := _duel("..")
	var at := _duel("..")

	var below_result := Combat.resolve(below[0], below[1], below[2], ScriptedRollSource.new([0.0, 0.1999, 0.5] as Array[float]))
	var at_result := Combat.resolve(at[0], at[1], at[2], ScriptedRollSource.new([0.0, 0.2, 0.5] as Array[float]))

	assert_true(below_result.crit, "0.1999 is below the crit rate of 0.2")
	assert_false(at_result.crit, "0.2 is not below 0.2")

func test_variance_reaches_both_bounds() -> void:
	var low := _duel("..")
	var high := _duel("..")

	var low_result := Combat.resolve(low[0], low[1], low[2], ScriptedRollSource.new([0.0, 0.99, 0.0] as Array[float]))
	var high_result := Combat.resolve(high[0], high[1], high[2], ScriptedRollSource.new([0.0, 0.99, 0.99999] as Array[float]))

	assert_eq(low_result.damage, 7, "raw 8 at 0.9 variance")
	assert_eq(high_result.damage, 9, "raw 8 at nearly 1.1 variance")

func test_a_hit_chance_of_one_always_connects() -> void:
	var duel := _duel("..")
	duel[1].data.accuracy = 1.0
	duel[2].data.evasion = 0.0
	var rolls := ScriptedRollSource.new([0.99999, 0.99, 0.5] as Array[float])

	assert_true(Combat.resolve(duel[0], duel[1], duel[2], rolls).hit, "roll_unit() never reaches 1.0")

func test_a_hit_chance_of_zero_never_connects() -> void:
	var duel := _duel("..")
	duel[1].data.accuracy = 0.0
	duel[2].data.evasion = 0.0
	var rolls := ScriptedRollSource.new([0.0] as Array[float])

	assert_false(Combat.resolve(duel[0], duel[1], duel[2], rolls).hit, "roll_unit() is never below 0.0")

func test_the_damage_floor_applies_before_the_crit_multiplier() -> void:
	var duel := _duel("..")
	duel[1].data.attack = 3
	duel[2].data.defense = 10
	var rolls := ScriptedRollSource.new([0.0, 0.0, 0.5] as Array[float])

	var result := Combat.resolve(duel[0], duel[1], duel[2], rolls)

	assert_true(result.crit)
	assert_eq(result.damage, 3, "the floor of 1, tripled — not a floored 1")

func test_forest_reduces_damage_through_defense() -> void:
	var duel := _duel(".F")
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5] as Array[float])

	assert_eq(Combat.resolve(duel[0], duel[1], duel[2], rolls).damage, 6, "attack 10 minus defense 2 plus forest 2")

func test_hp_never_falls_below_zero_and_a_kill_is_reported() -> void:
	var duel := _duel("..")
	duel[2].hp = 3
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5] as Array[float])

	var result := Combat.resolve(duel[0], duel[1], duel[2], rolls)

	assert_eq(duel[2].hp, 0, "8 damage against 3 hp stops at zero")
	assert_true(result.killed)
	assert_false(duel[2].is_alive())
