extends Node2D

const MARGIN := Vector2(40, 40)

var _grid: BattleGrid
var _grid_view: GridView
var _cursor: Cursor

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

	_cursor = Cursor.new()
	_cursor.bounds = _grid.size
	_grid_view.add_child(_cursor)

	_cursor.moved.connect(_on_cursor_moved)
	_grid_view.refresh()

	if OS.has_environment("SORTIE_SHOT"):
		add_child(load("res://scenes/screenshot_probe.gd").new())

## Temporary until Task 14: proves input reaches the cursor and redraws land.
func _on_cursor_moved(cell: Vector2i) -> void:
	_grid_view.move_cells = [cell] as Array[Vector2i]
	_grid_view.refresh()
	_cursor.queue_redraw()
