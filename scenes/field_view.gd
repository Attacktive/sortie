class_name FieldView
extends Node2D

## Draws a FieldMap.
##
## Reuses the battle's terrain art, including its per-cell grass hash, so a field big enough to walk around does not read as a checkerboard.
## Field-specific art is sub-project 6; until then the two modes are literally looking at the same tiles.

## Only the solid glyphs. Walkable ground is not in here because it is not one texture: it is whichever grass variant the hash picks for that cell.
const SOLID_TEXTURES := {
	FieldMap.WALL: "res://assets/lpc/terrain/wall.png",
	FieldMap.TREE: "res://assets/lpc/terrain/forest.png",
}

var map: FieldMap = null

var _solids: Dictionary[String, Texture2D] = {}
var _plains: Array[Texture2D] = []

func _ready() -> void:
	## Integer upscaling of 16px art into a 64px cell; anything but NEAREST turns it to mush.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	for glyph in SOLID_TEXTURES:
		_solids[glyph] = load(SOLID_TEXTURES[glyph])

	for path in GridView.PLAIN_VARIANTS:
		_plains.append(load(path))

	queue_redraw()

## Everything that goes on one cell, bottom first.
## Grass always, then the solid tile over it rather than instead of it, so a tree keeps its transparent edges.
##
## This is the whole of what the view decides; _draw only puts it on screen. Keeping the decision out here is what lets a headless test see it.
func layers_for(cell: Vector2i) -> Array[Texture2D]:
	var layers: Array[Texture2D] = [_plains[GridView.plain_variant_for(cell)]]

	if map.is_solid(cell):
		layers.append(_texture_for(cell))

	return layers

func _draw() -> void:
	if map == null:
		return

	var size := float(GridGeometry.CELL_SIZE)

	for y in map.size.y:
		for x in map.size.x:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * size, Vector2(size, size))

			for layer in layers_for(cell):
				draw_texture_rect(layer, rect, false)

## An unrecognized glyph draws as a wall: a tile you can see and cannot walk through is a bug, but a tile you cannot see and cannot walk through is a haunting. 👻
func _texture_for(cell: Vector2i) -> Texture2D:
	var glyph := map.glyph_at(cell)
	if _solids.has(glyph):
		return _solids[glyph]

	return _solids[FieldMap.WALL]
