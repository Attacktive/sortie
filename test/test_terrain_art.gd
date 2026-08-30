extends GutTest

func test_every_terrain_type_has_a_texture() -> void:
	for type in [Terrain.Type.PLAIN, Terrain.Type.FOREST, Terrain.Type.WALL]:
		var path: String = GridView.TERRAIN_TEXTURES[type]
		assert_true(ResourceLoader.exists(path), "terrain %d points at a missing texture: %s" % [type, path])

func test_the_tiles_scale_to_the_cell_by_a_whole_number() -> void:
	var texture: Texture2D = load(GridView.TERRAIN_TEXTURES[Terrain.Type.PLAIN])
	var source := texture.get_width()

	assert_eq(GridGeometry.CELL_SIZE % source, 0, "a %dpx tile in a %dpx cell would blur" % [source, GridGeometry.CELL_SIZE])
