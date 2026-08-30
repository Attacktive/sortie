class_name Movement
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
]

static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## Floods outward from the unit's cell, bounded by its movement budget.
## One pass yields both the reachable set and the path to every cell in it.
## Dijkstra rather than breadth-first, because forest costs 2 and a plain detour can be cheaper than crossing it.
static func field(grid: BattleGrid, unit: BattleUnit) -> MovementField:
	var result := MovementField.new()
	result.origin = unit.cell
	result.costs[unit.cell] = 0
	result.landable[unit.cell] = true

	var budget := unit.data.move_range
	var visited: Dictionary[Vector2i, bool] = {}

	while true:
		var next_cell: Variant = _cheapest_unvisited(result.costs, visited)
		if next_cell == null:
			break

		var current: Vector2i = next_cell
		visited[current] = true

		for direction in DIRECTIONS:
			var neighbor: Vector2i = current + direction
			var terrain := grid.terrain_at(neighbor)
			if not Terrain.is_passable(terrain):
				continue

			var blocker := grid.unit_at(neighbor)
			if blocker != null and blocker.team() != unit.team():
				continue

			var cost: int = result.costs[current] + Terrain.move_cost(terrain)
			if cost > budget:
				continue

			if result.costs.has(neighbor) and result.costs[neighbor] <= cost:
				continue

			result.costs[neighbor] = cost
			result.previous[neighbor] = current
			visited.erase(neighbor)

			if blocker == null:
				result.landable[neighbor] = true
			else:
				result.landable.erase(neighbor)

	return result

## Returns null when every discovered cell has already been expanded.
static func _cheapest_unvisited(costs: Dictionary, visited: Dictionary) -> Variant:
	var best: Variant = null
	var best_cost := 0

	for cell in costs.keys():
		if visited.has(cell):
			continue

		var cost: int = costs[cell]
		if best == null or cost < best_cost:
			best = cell
			best_cost = cost

	return best

## Every in-bounds cell within Manhattan distance of the origin, excluding the origin.
static func attackable_cells(grid: BattleGrid, from_cell: Vector2i, attack_range: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for dy in range(-attack_range, attack_range + 1):
		for dx in range(-attack_range, attack_range + 1):
			var offset := Vector2i(dx, dy)
			if offset == Vector2i.ZERO:
				continue

			if absi(dx) + absi(dy) > attack_range:
				continue

			var cell: Vector2i = from_cell + offset
			if grid.is_in_bounds(cell):
				result.append(cell)

	return result
