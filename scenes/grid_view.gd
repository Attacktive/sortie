class_name GridView
extends Node2D

const TERRAIN_COLORS := {
	Terrain.Type.PLAIN: Color("4a7a4a"),
	Terrain.Type.FOREST: Color("1f4a24"),
	Terrain.Type.WALL: Color("2b2b33"),
}

const GRID_LINE := Color(0.0, 0.0, 0.0, 0.25)
const MOVE_HIGHLIGHT := Color(0.30, 0.60, 1.0, 0.45)
const ATTACK_HIGHLIGHT := Color(1.0, 0.30, 0.30, 0.45)

## An inspected enemy's reach: everywhere it could strike, then everywhere it could stand.
## Deliberately dimmer than the player's own overlays, so the two never read as the same thing.
const THREAT_ATTACK_HIGHLIGHT := Color(0.85, 0.15, 0.15, 0.26)
const THREAT_MOVE_HIGHLIGHT := Color(0.95, 0.55, 0.12, 0.42)

var grid: BattleGrid = null
var move_cells: Array[Vector2i] = []
var attack_cells: Array[Vector2i] = []
var threat_move_cells: Array[Vector2i] = []
var threat_attack_cells: Array[Vector2i] = []

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	if grid == null:
		return

	for y in grid.size.y:
		for x in grid.size.x:
			var cell := Vector2i(x, y)
			var rect := Rect2(GridGeometry.cell_to_position(cell), Vector2.ONE * GridGeometry.CELL_SIZE)
			draw_rect(rect, TERRAIN_COLORS[grid.terrain_at(cell)])
			draw_rect(rect, GRID_LINE, false, 1.0)

	## Widest first, so the narrower overlays stay legible on top of it.
	_draw_highlights(threat_attack_cells, THREAT_ATTACK_HIGHLIGHT)
	_draw_highlights(threat_move_cells, THREAT_MOVE_HIGHLIGHT)
	_draw_highlights(move_cells, MOVE_HIGHLIGHT)
	_draw_highlights(attack_cells, ATTACK_HIGHLIGHT)

func _draw_highlights(cells: Array[Vector2i], color: Color) -> void:
	for cell in cells:
		draw_rect(Rect2(GridGeometry.cell_to_position(cell), Vector2.ONE * GridGeometry.CELL_SIZE), color)
