class_name EnemyAI
extends RefCounted

## Large enough that any guaranteed kill outranks any amount of chip damage.
const KILL_BONUS := 1000.0

## Chooses where one enemy unit should stand and who it should hit.
## Scoring is fully deterministic; the only randomness in a turn is in the attacks that follow.
static func decide(grid: BattleGrid, unit: BattleUnit) -> AIDecision:
	var decision := AIDecision.new()
	decision.move_to = unit.cell

	var field := Movement.field(grid, unit)
	var targets := grid.living_units_of_team(UnitData.Team.PLAYER)
	var best_score := -1.0

	for cell in _sorted(field.reachable_cells()):
		for target in targets:
			if Movement.manhattan(cell, target.cell) > unit.data.attack_range:
				continue

			var candidate := score(grid, unit, target)
			if candidate > best_score:
				best_score = candidate
				decision.move_to = cell
				decision.target = target

	if decision.target != null:
		return decision

	decision.move_to = _advance_toward_nearest(grid, unit, field, targets)

	return decision

## Expected damage from one attack, plus a bonus for a kill that needs no luck.
static func score(grid: BattleGrid, attacker: BattleUnit, defender: BattleUnit) -> float:
	var prediction := Combat.forecast(grid, attacker, defender)
	var average := (prediction.min_damage + prediction.max_damage) / 2.0
	var expected := prediction.hit_chance * average * (1.0 + prediction.crit_chance * (Combat.CRIT_MULTIPLIER - 1))

	if prediction.max_damage >= defender.hp:
		expected += KILL_BONUS

	return expected

## Walks as far along the cheapest route to the nearest target as the budget allows.
## Returns the unit's own cell when no route exists at all.
static func _advance_toward_nearest(grid: BattleGrid, unit: BattleUnit, field: MovementField, targets: Array[BattleUnit]) -> Vector2i:
	var approach := AStarGrid2D.new()
	approach.region = Rect2i(Vector2i.ZERO, grid.size)
	approach.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	approach.update()

	for y in grid.size.y:
		for x in grid.size.x:
			var cell := Vector2i(x, y)
			var blocker := grid.unit_at(cell)
			var blocked := not Terrain.is_passable(grid.terrain_at(cell))
			if blocker != null and blocker != unit and blocker.team() != unit.team():
				blocked = true

			approach.set_point_solid(cell, blocked)

	var best_cell := unit.cell
	var best_distance := -1

	for target in _sorted_units(targets):
		## The target's own cell was marked solid along with every other opposing unit,
		## and A* cannot path onto a solid cell — so clear the destination for its own search.
		approach.set_point_solid(target.cell, false)
		var route := approach.get_id_path(unit.cell, target.cell)
		approach.set_point_solid(target.cell, true)

		if route.size() < 2:
			continue

		for index in range(route.size() - 1, 0, -1):
			var step: Vector2i = route[index]
			if not field.can_reach(step):
				continue

			var remaining := Movement.manhattan(step, target.cell)
			if best_distance < 0 or remaining < best_distance:
				best_distance = remaining
				best_cell = step

			break

	return best_cell

## Row-major order, so ties resolve the same way on every run.
static func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result := cells.duplicate()
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y

		return a.x < b.x
	)

	return result

static func _sorted_units(units: Array[BattleUnit]) -> Array[BattleUnit]:
	var result := units.duplicate()
	result.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.cell.y != b.cell.y:
			return a.cell.y < b.cell.y

		return a.cell.x < b.cell.x
	)

	return result
