extends GutTest

## What is worth testing about a view is what it decides to draw.
## Whether those pixels actually landed is the screenshot probe's job in Task 8, and nothing headless can stand in for it.

func _view() -> FieldView:
	var view := FieldView.new()
	view.map = FieldMap.from_ascii(PackedStringArray(["..#.", ".FF.", "...."]))
	add_child_autofree(view)

	return view

func test_every_solid_glyph_has_art() -> void:
	for glyph in [FieldMap.WALL, FieldMap.TREE]:
		assert_true(FieldView.SOLID_TEXTURES.has(glyph), "glyph '%s' can be authored but has nothing to draw" % glyph)
		assert_true(ResourceLoader.exists(FieldView.SOLID_TEXTURES[glyph]), "glyph '%s' points at a texture that is not there" % glyph)

## Putting the view in the tree draws it for real, and GUT fails a test on any error raised while it runs, so this covers _draw as well as the layering.
func test_a_solid_tile_is_drawn_on_top_of_grass() -> void:
	var view := _view()
	await get_tree().process_frame

	var grass := view.layers_for(Vector2i(0, 0))
	var wall := view.layers_for(Vector2i(2, 0))
	var tree := view.layers_for(Vector2i(1, 1))

	assert_eq(grass.size(), 1, "walkable ground is grass and nothing else")
	assert_eq(wall.size(), 2, "a wall is grass with a wall on top of it, not a wall instead of grass")
	assert_true(GridView.PLAIN_VARIANTS.has(wall[0].resource_path), "the layer under a wall has to be grass, and grass is whichever variant the hash picked for that cell")
	assert_ne(wall[1], tree[1], "a tree that draws like a wall is a map you cannot read")
