extends GutTest

## Attacker at (0,0), defender placed at the given cell, on a wide-open row.
func _setup(defender_cell: Vector2i, attacker_range: int, defender_range: int) -> Array:
	var attacker_data := UnitData.new()
	attacker_data.max_hp = 20
	attacker_data.attack = 10
	attacker_data.accuracy = 0.9
	attacker_data.crit_rate = 0.0
	attacker_data.attack_range = attacker_range
	attacker_data.team = UnitData.Team.PLAYER

	var defender_data := UnitData.new()
	defender_data.max_hp = 20
	defender_data.attack = 6
	defender_data.defense = 2
	defender_data.evasion = 0.0
	defender_data.crit_rate = 0.0
	defender_data.attack_range = defender_range
	defender_data.team = UnitData.Team.ENEMY

	var grid := BattleGrid.from_ascii(PackedStringArray(["....."]))
	var attacker := BattleUnit.new(attacker_data, Vector2i(0, 0))
	var defender := BattleUnit.new(defender_data, defender_cell)
	grid.place_unit(attacker, Vector2i(0, 0))
	grid.place_unit(defender, defender_cell)

	return [grid, attacker, defender]

func test_a_surviving_defender_in_range_counters() -> void:
	var setup := _setup(Vector2i(1, 0), 1, 1)
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5, 0.0, 0.99, 0.5] as Array[float])

	var exchange := Combat.exchange(setup[0], setup[1], setup[2], rolls)

	assert_true(exchange.attack.hit)
	assert_not_null(exchange.counter, "an adjacent survivor strikes back")
	assert_true(exchange.counter.hit)
	assert_eq(exchange.counter.damage, 6, "defender attack 6 minus attacker defense 0")
	assert_eq(setup[1].hp, 14)
	assert_eq(rolls.drawn(), 6, "three rolls each")

func test_a_dead_defender_does_not_counter() -> void:
	var setup := _setup(Vector2i(1, 0), 1, 1)
	setup[2].hp = 2
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5] as Array[float])

	var exchange := Combat.exchange(setup[0], setup[1], setup[2], rolls)

	assert_true(exchange.attack.killed)
	assert_null(exchange.counter, "the dead do not retaliate")
	assert_eq(rolls.drawn(), 3, "no counter rolls are drawn")

func test_a_defender_out_of_its_own_range_does_not_counter() -> void:
	var setup := _setup(Vector2i(2, 0), 2, 1)
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5] as Array[float])

	var exchange := Combat.exchange(setup[0], setup[1], setup[2], rolls)

	assert_true(exchange.attack.hit)
	assert_null(exchange.counter, "reach 1 cannot answer an attack from two tiles away")
	assert_eq(rolls.drawn(), 3)

func test_a_missed_attack_still_draws_a_counter() -> void:
	var setup := _setup(Vector2i(1, 0), 1, 1)
	var rolls := ScriptedRollSource.new([0.95, 0.0, 0.99, 0.5] as Array[float])

	var exchange := Combat.exchange(setup[0], setup[1], setup[2], rolls)

	assert_false(exchange.attack.hit, "0.95 misses against a hit chance of 0.9")
	assert_not_null(exchange.counter, "whiffing does not protect you")
	assert_true(exchange.counter.hit)
	assert_eq(rolls.drawn(), 4, "one for the miss, three for the counter")

func test_the_counter_rolls_its_own_crit() -> void:
	var setup := _setup(Vector2i(1, 0), 1, 1)
	setup[2].data.crit_rate = 0.5
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5, 0.0, 0.1, 0.5] as Array[float])

	var exchange := Combat.exchange(setup[0], setup[1], setup[2], rolls)

	assert_false(exchange.attack.crit)
	assert_true(exchange.counter.crit, "the counter draws independently")
	assert_eq(exchange.counter.damage, 18, "6 tripled")
