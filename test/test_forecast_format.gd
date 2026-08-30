extends GutTest

func _forecast(hit: float, crit: float, low: int, high: int) -> AttackForecast:
	var forecast := AttackForecast.new()
	forecast.hit_chance = hit
	forecast.crit_chance = crit
	forecast.min_damage = low
	forecast.max_damage = high
	forecast.crit_damage = high * Combat.CRIT_MULTIPLIER

	return forecast

func test_percentages_round_to_whole_numbers() -> void:
	assert_eq(ForecastFormat.percent(0.85), "85%")
	assert_eq(ForecastFormat.percent(1.0), "100%")
	assert_eq(ForecastFormat.percent(0.0), "0%")
	assert_eq(ForecastFormat.percent(0.855), "86%", "rounds rather than truncates")

func test_a_damage_range_shows_both_ends() -> void:
	assert_eq(ForecastFormat.damage(_forecast(0.8, 0.2, 6, 8)), "6-8")

func test_a_single_damage_value_does_not_repeat_itself() -> void:
	assert_eq(ForecastFormat.damage(_forecast(0.8, 0.2, 1, 1)), "1", "not '1-1'")

func test_the_full_line_reads_as_the_spec_describes() -> void:
	assert_eq(ForecastFormat.line(_forecast(0.85, 0.21, 6, 8)), "Deals 6-8   Hit 85%   Crit 21%")

func test_a_guaranteed_hit_reads_as_one_hundred_percent() -> void:
	assert_eq(ForecastFormat.line(_forecast(1.0, 0.0, 9, 9)), "Deals 9   Hit 100%   Crit 0%")
