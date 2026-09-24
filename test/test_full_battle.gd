extends GutTest

## A battle that cannot resolve in this many rounds is stuck, not merely long.
const MAX_ROUNDS := 80

## Plays one unit's turn the way battle.gd does, minus the animation.
func _act(grid: BattleGrid, unit: BattleUnit, rolls: RollSource) -> void:
	var decision := EnemyAI.decide(grid, unit)

	if decision.move_to != unit.cell:
		grid.move_unit(unit, decision.move_to)

	if decision.target != null:
		Combat.exchange(grid, unit, decision.target, rolls)

		for participant in [decision.target, unit]:
			if not participant.is_alive():
				grid.remove_unit(participant)

	unit.has_acted = true

## Rounds consumed by the most recent _play(), for tuning measurements.
var _last_rounds: int = 0

## Runs the default scenario to completion with both sides on autopilot.
func _play(seed_value: int) -> TurnOrder:
	var grid := Scenario.build_grid()
	Scenario.populate(grid)

	return _play_grid(grid, seed_value)

## Runs a narrative mission through the same headless battle path.
func _play_mission(mission: MissionData, seed_value: int) -> TurnOrder:
	var grid := MissionRegistry.build_battle_grid(mission)
	if grid == null:
		return null

	var units := MissionRegistry.populate_units(grid, mission)
	if units.size() != mission.player_roster.size() + mission.enemy_roster.size():
		return null

	return _play_grid(grid, seed_value)

func _play_grid(grid: BattleGrid, seed_value: int) -> TurnOrder:
	var turns := TurnOrder.new(grid)
	var rolls := RealRollSource.new(seed_value)
	var rounds := 0

	while not turns.is_over() and rounds < MAX_ROUNDS:
		rounds += 1

		for unit in turns.units_awaiting_orders():
			if not unit.is_alive():
				continue

			_act(grid, unit, rolls)
			turns.check_resolution()

			if turns.is_over():
				break

		turns.end_turn()

	_last_rounds = rounds

	return turns

func _sweep(mission: MissionData = null) -> Dictionary:
	var victories := 0
	var defeats := 0
	var unresolved := 0
	var total_rounds := 0
	var longest := 0

	for seed_value in range(1, 41):
		var turns: TurnOrder
		if mission == null:
			turns = _play(seed_value)
		else:
			turns = _play_mission(mission, seed_value)

		if turns == null:
			unresolved += 1
			continue

		total_rounds += _last_rounds
		longest = maxi(longest, _last_rounds)

		match turns.phase:
			TurnOrder.Phase.VICTORY:
				victories += 1
			TurnOrder.Phase.DEFEAT:
				defeats += 1
			_:
				unresolved += 1

	return {
		"victories": victories,
		"defeats": defeats,
		"unresolved": unresolved,
		"total_rounds": total_rounds,
		"longest": longest,
	}


func _print_sweep(label: String, tally: Dictionary) -> void:
	gut.p("%s: %d victories, %d defeats, %d unresolved" % [label, tally["victories"], tally["defeats"], tally["unresolved"]])
	gut.p("rounds: %.1f average, %d longest" % [tally["total_rounds"] / 40.0, tally["longest"]])


func test_a_full_battle_reaches_a_resolution() -> void:
	var turns := _play(20260830)

	assert_true(turns.is_over(), "the battle never resolved within %d rounds" % MAX_ROUNDS)


func test_both_endings_are_reachable_across_seeds() -> void:
	var tally := _sweep()
	_print_sweep("40 auto-battles", tally)

	assert_eq(tally["unresolved"], 0, "every battle must terminate")
	assert_gt(tally["victories"], 0, "victory must be reachable")
	assert_gt(tally["defeats"], 0, "defeat must be reachable")


func test_m01_cabbage_via_mission_harness() -> void:
	var mission := MissionRegistry.get_mission("M01_CABBAGE")
	assert_not_null(mission)
	if mission == null:
		return

	var tally := _sweep(mission)
	_print_sweep("M01_CABBAGE", tally)

	assert_eq(tally["unresolved"], 0, "every M01 battle must terminate")
	assert_gt(tally["victories"], 0, "M01 victory must be reachable")


func test_act_one_missions_balance_bands() -> void:
	var cases := [
		{
			"mission_id": "M02_ALE_RUN",
			"min_victories": 24,
			"max_victories": 34,
		},
		{
			"mission_id": "M03_SILVER_SPOONS",
			"min_victories": 24,
			"max_victories": 34,
		},
		{
			"mission_id": "M04_FIELD_OVEN",
			"min_victories": 24,
			"max_victories": 34,
		},
		{
			"mission_id": "M05_SPICE_WARS",
			"min_victories": 18,
			"max_victories": 28,
		},
	]

	for case in cases:
		var mission_id := str(case.get("mission_id", ""))
		var mission := MissionRegistry.get_mission(mission_id)
		assert_not_null(mission)
		if mission == null:
			continue

		var tally := _sweep(mission)
		_print_sweep(mission_id, tally)

		var min_victories := int(case.get("min_victories", 0))
		var max_victories := int(case.get("max_victories", 40))
		assert_eq(tally["unresolved"], 0, "%s must resolve all 40 seeds" % mission_id)
		assert_gt(tally["victories"], 0, "%s victory must be reachable" % mission_id)
		assert_gt(tally["defeats"], 0, "%s defeat must be reachable" % mission_id)
		assert_true(
			tally["victories"] >= min_victories and tally["victories"] <= max_victories,
			"%s must land within %d..%d victories, got %d" % [mission_id, min_victories, max_victories, tally["victories"]]
		)


func test_the_same_seed_replays_identically() -> void:
	var first := _play(777)
	var second := _play(777)

	assert_eq(first.phase, second.phase, "a seeded battle must be reproducible")
