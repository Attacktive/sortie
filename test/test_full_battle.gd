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

## Runs the scenario to completion with both sides on autopilot.
func _play(seed_value: int) -> TurnOrder:
	var grid := Scenario.build_grid()
	Scenario.populate(grid)
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

func test_a_full_battle_reaches_a_resolution() -> void:
	var turns := _play(20260830)

	assert_true(turns.is_over(), "the battle never resolved within %d rounds" % MAX_ROUNDS)

func test_both_endings_are_reachable_across_seeds() -> void:
	var victories := 0
	var defeats := 0
	var unresolved := 0
	var total_rounds := 0
	var longest := 0

	for seed_value in range(1, 41):
		var turns := _play(seed_value)
		total_rounds += _last_rounds
		longest = maxi(longest, _last_rounds)

		match turns.phase:
			TurnOrder.Phase.VICTORY:
				victories += 1
			TurnOrder.Phase.DEFEAT:
				defeats += 1
			_:
				unresolved += 1

	gut.p("40 auto-battles: %d victories, %d defeats, %d unresolved" % [victories, defeats, unresolved])
	gut.p("rounds: %.1f average, %d longest" % [total_rounds / 40.0, longest])

	assert_eq(unresolved, 0, "every battle must terminate")
	assert_gt(victories, 0, "victory must be reachable")
	assert_gt(defeats, 0, "defeat must be reachable")

func test_the_same_seed_replays_identically() -> void:
	var first := _play(777)
	var second := _play(777)

	assert_eq(first.phase, second.phase, "a seeded battle must be reproducible")
