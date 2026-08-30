class_name Scenario
extends RefCounted

const MAP := [
	"..F....F..",
	"..........",
	".#......#.",
	"..........",
	"..........",
	".#......#.",
	"..........",
	"..F....F..",
]

static func build_grid() -> BattleGrid:
	return BattleGrid.from_ascii(PackedStringArray(MAP))

## Places both armies and returns them in spawn order.
static func populate(grid: BattleGrid) -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []

	units.append(_spawn(grid, Vector2i(0, 7), _make("Vanguard", 24, 9, 4, 0.90, 0.05, 0.05, 3, 1, UnitData.Team.PLAYER, Color("4d7fd4"))))
	units.append(_spawn(grid, Vector2i(1, 7), _make("Archer", 16, 8, 1, 0.85, 0.10, 0.15, 3, 2, UnitData.Team.PLAYER, Color("6fb3e0"))))
	units.append(_spawn(grid, Vector2i(0, 6), _make("Skirmisher", 18, 7, 2, 0.95, 0.20, 0.25, 5, 1, UnitData.Team.PLAYER, Color("9ad4f0"))))

	units.append(_spawn(grid, Vector2i(9, 0), _make("Brute", 26, 10, 3, 0.85, 0.00, 0.05, 3, 1, UnitData.Team.ENEMY, Color("c1443f"))))
	units.append(_spawn(grid, Vector2i(8, 0), _make("Raider", 18, 8, 1, 0.90, 0.10, 0.15, 4, 1, UnitData.Team.ENEMY, Color("d97148"))))
	units.append(_spawn(grid, Vector2i(9, 1), _make("Scout", 14, 6, 0, 0.90, 0.25, 0.10, 5, 1, UnitData.Team.ENEMY, Color("e0a05a"))))

	return units

static func _spawn(grid: BattleGrid, cell: Vector2i, data: UnitData) -> BattleUnit:
	var unit := BattleUnit.new(data, cell)
	grid.place_unit(unit, cell)

	return unit

static func _make(
	unit_name: String,
	max_hp: int,
	attack: int,
	defense: int,
	accuracy: float,
	evasion: float,
	crit_rate: float,
	move_range: int,
	attack_range: int,
	team: UnitData.Team,
	color: Color
) -> UnitData:
	var data := UnitData.new()
	data.unit_name = unit_name
	data.max_hp = max_hp
	data.attack = attack
	data.defense = defense
	data.accuracy = accuracy
	data.evasion = evasion
	data.crit_rate = crit_rate
	data.move_range = move_range
	data.attack_range = attack_range
	data.team = team
	data.color = color

	return data
