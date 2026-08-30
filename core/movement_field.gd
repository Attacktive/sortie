class_name MovementField
extends RefCounted

## Accumulated movement cost for every cell the unit can pass through.
var costs: Dictionary[Vector2i, int] = {}

## Predecessor map, for reconstructing a path backward from any reached cell.
var previous: Dictionary[Vector2i, Vector2i] = {}

## Cells the unit may actually finish its move on.
## A cell can be in costs but not landable, which is how allies stay passable.
var landable: Dictionary[Vector2i, bool] = {}

var origin: Vector2i = Vector2i.ZERO

func can_reach(cell: Vector2i) -> bool:
	return landable.has(cell)

func cost_to(cell: Vector2i) -> int:
	if not landable.has(cell):
		return -1

	return costs[cell]

func reachable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in landable.keys():
		result.append(cell)

	return result

## Steps from the origin to the target, excluding the origin itself.
## Empty when the target cannot be reached.
func path_to(cell: Vector2i) -> Array[Vector2i]:
	if not landable.has(cell):
		return [] as Array[Vector2i]

	var reversed: Array[Vector2i] = []
	var current := cell
	while current != origin:
		reversed.append(current)
		current = previous[current]

	reversed.reverse()

	return reversed
