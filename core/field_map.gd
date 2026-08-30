class_name FieldMap
extends RefCounted

## The walkable world. Built from ASCII so a map reads as a picture in tests and in content.
##
## A tree is solid here even though a battle forest is enterable: the battle asks "can a unit stand on this", the field asks "can a body pass through it", and those are different questions about the same art.

const WALKABLE := "."
const WALL := "#"
const TREE := "F"

var size: Vector2i = Vector2i.ZERO

## The authored glyph per non-walkable cell, not merely a bool, because a view has to tell a tree from a wall.
var _glyphs: Dictionary[Vector2i, String] = {}

static func from_ascii(rows: PackedStringArray) -> FieldMap:
	var map := FieldMap.new()
	map.size = Vector2i(rows[0].length(), rows.size())

	for y in rows.size():
		var row := rows[y]
		assert(row.length() == map.size.x, "row %d is %d wide but the map is %d; a ragged map has holes in it" % [y, row.length(), map.size.x])

		for x in row.length():
			if row[x] != WALKABLE:
				map._glyphs[Vector2i(x, y)] = row[x]

	return map

## Outside the map counts as solid, so the edge of the world needs no special case anywhere else.
func is_solid(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return true

	return _glyphs.has(cell)

## What was authored at this cell. Empty outside the map, or on walkable ground.
func glyph_at(cell: Vector2i) -> String:
	if not _glyphs.has(cell):
		return ""

	return _glyphs[cell]

func pixel_size() -> Vector2:
	return Vector2(size) * float(GridGeometry.CELL_SIZE)

## Every solid tile the box touches. The caller resolves against these; this only reports them.
func solid_tiles_overlapping(box: Rect2) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var cell := float(GridGeometry.CELL_SIZE)

	var first := Vector2i(floori(box.position.x / cell), floori(box.position.y / cell))
	var last := Vector2i(floori((box.end.x - 0.001) / cell), floori((box.end.y - 0.001) / cell))

	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var candidate := Vector2i(x, y)
			if is_solid(candidate):
				found.append(candidate)

	return found
