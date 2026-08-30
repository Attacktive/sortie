class_name Terrain
extends RefCounted

enum Type { PLAIN, FOREST, WALL }

const _MOVE_COST := {
	Type.PLAIN: 1,
	Type.FOREST: 2,
}

const _DEFENSE_BONUS := {
	Type.PLAIN: 0,
	Type.FOREST: 2,
}

const _EVASION_BONUS := {
	Type.PLAIN: 0.0,
	Type.FOREST: 0.2,
}

## Movement cost to enter a tile of this type.
## Impassable types have no meaningful cost; callers must check is_passable() first.
static func move_cost(type: Type) -> int:
	return _MOVE_COST.get(type, 1)

static func defense_bonus(type: Type) -> int:
	return _DEFENSE_BONUS.get(type, 0)

static func evasion_bonus(type: Type) -> float:
	return _EVASION_BONUS.get(type, 0.0)

static func is_passable(type: Type) -> bool:
	return type != Type.WALL
