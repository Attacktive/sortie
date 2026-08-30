extends Node2D

const MARGIN := Vector2(40, 40)

var _grid: BattleGrid
var _grid_view: GridView
var _cursor: Cursor
var _views: Dictionary[BattleUnit, UnitView] = {}

func _ready() -> void:
	_grid = BattleGrid.from_ascii(PackedStringArray([
		"..F....F..",
		"..........",
		".#......#.",
		"..........",
	]))

	_grid_view = GridView.new()
	_grid_view.grid = _grid
	_grid_view.position = MARGIN
	add_child(_grid_view)

	_spawn(_make("Blue", 20, Color("4d7fd4"), UnitData.Team.PLAYER), Vector2i(0, 0))
	var wounded := _spawn(_make("Red", 20, Color("c1443f"), UnitData.Team.ENEMY), Vector2i(6, 3))
	wounded.hp = 7

	_cursor = Cursor.new()
	_cursor.bounds = _grid.size
	_grid_view.add_child(_cursor)

	_cursor.moved.connect(_on_cursor_moved)
	_cursor.confirmed.connect(_on_cursor_confirmed)
	_grid_view.refresh()

	if OS.has_environment("SORTIE_SHOT"):
		add_child(load("res://scenes/screenshot_probe.gd").new())

func _make(unit_name: String, max_hp: int, color: Color, team: UnitData.Team) -> UnitData:
	var data := UnitData.new()
	data.unit_name = unit_name
	data.max_hp = max_hp
	data.move_range = 4
	data.attack_range = 1
	data.team = team
	data.color = color

	return data

func _spawn(data: UnitData, cell: Vector2i) -> BattleUnit:
	var unit := BattleUnit.new(data, cell)
	_grid.place_unit(unit, cell)

	var view := UnitView.new()
	view.setup(unit)
	_grid_view.add_child(view)
	_views[unit] = view

	return unit

## Temporary until Task 14: highlights the selected unit's reachable tiles.
func _on_cursor_moved(cell: Vector2i) -> void:
	_cursor.queue_redraw()

## Temporary until Task 14: walks the first unit to any reachable cell.
func _on_cursor_confirmed(cell: Vector2i) -> void:
	var unit: BattleUnit = _views.keys()[0]
	var field := Movement.field(_grid, unit)
	if not field.can_reach(cell):
		return

	var path := field.path_to(cell)
	_grid.move_unit(unit, cell)
	_views[unit].walk_path(path)
