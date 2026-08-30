extends GutTest

func test_scripted_returns_queued_rolls_in_order() -> void:
	var rolls := ScriptedRollSource.new([0.1, 0.5, 0.9] as Array[float])

	assert_almost_eq(rolls.roll_unit(), 0.1, 0.0001)
	assert_almost_eq(rolls.roll_unit(), 0.5, 0.0001)
	assert_almost_eq(rolls.roll_unit(), 0.9, 0.0001)

func test_scripted_counts_what_was_drawn() -> void:
	var rolls := ScriptedRollSource.new([0.1, 0.5] as Array[float])
	assert_eq(rolls.drawn(), 0)

	rolls.roll_unit()
	assert_eq(rolls.drawn(), 1)

func test_real_source_stays_in_the_half_open_unit_interval() -> void:
	var rolls := RealRollSource.new(12345)

	for i in 500:
		var value := rolls.roll_unit()
		assert_true(value >= 0.0, "roll %f dropped below 0.0" % value)
		assert_true(value < 1.0, "roll %f reached or exceeded 1.0" % value)

func test_same_seed_replays_the_same_sequence() -> void:
	var first := RealRollSource.new(999)
	var second := RealRollSource.new(999)

	for i in 20:
		assert_almost_eq(first.roll_unit(), second.roll_unit(), 0.0000001)

func test_different_seeds_diverge() -> void:
	var first := RealRollSource.new(1)
	var second := RealRollSource.new(2)
	var same := true

	for i in 20:
		if not is_equal_approx(first.roll_unit(), second.roll_unit()):
			same = false

	assert_false(same, "two different seeds produced an identical sequence")
