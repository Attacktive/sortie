class_name GridGeometry
extends RefCounted

const CELL_SIZE := 48

static func cell_to_position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE)

static func cell_center(cell: Vector2i) -> Vector2:
	return cell_to_position(cell) + Vector2(CELL_SIZE, CELL_SIZE) * 0.5

## floori rather than a cast, so cells left of and above the origin map correctly.
static func position_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))
