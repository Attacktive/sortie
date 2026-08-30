extends GutTest

func _result(hit: bool, crit: bool, damage: int) -> AttackResult:
	var result := AttackResult.new()
	result.hit = hit
	result.crit = crit
	result.damage = damage

	return result

func test_a_miss_says_so() -> void:
	assert_eq(DamageNumber.text_for(_result(false, false, 0)), "Miss")

func test_a_hit_shows_its_damage() -> void:
	assert_eq(DamageNumber.text_for(_result(true, false, 7)), "7")

func test_a_crit_shows_the_full_damage_not_the_base() -> void:
	assert_eq(DamageNumber.text_for(_result(true, true, 24)), "24")

func test_crits_are_gold_and_larger() -> void:
	var crit := _result(true, true, 24)
	var plain := _result(true, false, 8)

	assert_eq(DamageNumber.color_for(crit), DamageNumber.CRIT_COLOR)
	assert_gt(DamageNumber.size_for(crit), DamageNumber.size_for(plain), "a crit must be visibly bigger")

func test_a_miss_is_neither_gold_nor_enlarged() -> void:
	var miss := _result(false, true, 0)

	assert_eq(DamageNumber.color_for(miss), DamageNumber.MISS_COLOR, "a stale crit flag must not colour a miss")
	assert_eq(DamageNumber.size_for(miss), DamageNumber.NORMAL_SIZE)
