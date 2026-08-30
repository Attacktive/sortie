class_name BattleGrid
extends RefCounted

const _ASCII_TERRAIN := {
	".": Terrain.Type.PLAIN,
	"F": Terrain.Type.FOREST,
	"#": Terrain.Type.WALL,
}

var size: Vector2i = Vector2i.ZERO

var _terrain: Dictionary[Vector2i, Terrain.Type] = {}
var _units: Dictionary[Vector2i, BattleUnit] = {}

## Builds a grid from a picture of it: "." plain, "F" forest, "#" wall.
## Every row must be the same length.
static func from_ascii(rows: PackedStringArray) -> BattleGrid:
	assert(rows.size() > 0, "from_ascii needs at least one row")

	var grid := BattleGrid.new()
	var width := rows[0].length()
	grid.size = Vector2i(width, rows.size())

	for y in rows.size():
		assert(rows[y].length() == width, "row %d is %d wide, expected %d" % [y, rows[y].length(), width])

		for x in width:
			var symbol := rows[y][x]
			assert(_ASCII_TERRAIN.has(symbol), "unknown terrain symbol '%s' at (%d, %d)" % [symbol, x, y])
			grid._terrain[Vector2i(x, y)] = _ASCII_TERRAIN[symbol]

	return grid

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y

## Out-of-bounds cells read as WALL so movement is naturally bounded without extra checks.
func terrain_at(cell: Vector2i) -> Terrain.Type:
	if not is_in_bounds(cell):
		return Terrain.Type.WALL

	return _terrain.get(cell, Terrain.Type.PLAIN)

func unit_at(cell: Vector2i) -> BattleUnit:
	return _units.get(cell, null)

func place_unit(unit: BattleUnit, cell: Vector2i) -> void:
	assert(is_in_bounds(cell), "cannot place a unit out of bounds at %s" % cell)
	assert(unit_at(cell) == null, "cell %s is already occupied" % cell)

	_units[cell] = unit
	unit.cell = cell

func move_unit(unit: BattleUnit, to: Vector2i) -> void:
	assert(_units.get(unit.cell, null) == unit, "unit is not registered at its own cell %s" % unit.cell)
	assert(unit_at(to) == null, "cannot move onto occupied cell %s" % to)

	_units.erase(unit.cell)
	_units[to] = unit
	unit.cell = to

func remove_unit(unit: BattleUnit) -> void:
	_units.erase(unit.cell)

func living_units_of_team(team: UnitData.Team) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in _units.values():
		if unit.team() == team and unit.is_alive():
			result.append(unit)

	return result
