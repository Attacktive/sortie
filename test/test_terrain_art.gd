extends GutTest

func test_every_terrain_type_has_a_texture() -> void:
	for type in [Terrain.Type.PLAIN, Terrain.Type.FOREST, Terrain.Type.WALL]:
		var path: String = GridView.TERRAIN_TEXTURES[type]
		assert_true(ResourceLoader.exists(path), "terrain %d points at a missing texture: %s" % [type, path])

func test_every_grass_variant_exists() -> void:
	for path in GridView.PLAIN_VARIANTS:
		assert_true(ResourceLoader.exists(path), "missing grass variant: %s" % path)

func test_terrain_tiles_are_exactly_one_cell() -> void:
	for type in [Terrain.Type.PLAIN, Terrain.Type.FOREST, Terrain.Type.WALL]:
		var texture: Texture2D = load(GridView.TERRAIN_TEXTURES[type])
		assert_eq(texture.get_width(), GridGeometry.CELL_SIZE, "terrain %d would be scaled" % type)
		assert_eq(texture.get_height(), GridGeometry.CELL_SIZE, "terrain %d would be scaled" % type)

## Sheets are frame grids, so what must divide evenly is the frame, not the sheet.
func test_animation_sheets_are_whole_numbers_of_cells() -> void:
	var grid := Scenario.build_grid()
	var cell := GridGeometry.CELL_SIZE

	for unit in Scenario.populate(grid):
		var walk: Texture2D = load(unit.data.sprite_walk)
		assert_eq(walk.get_width(), UnitView.WALK_FRAMES * cell, "%s walk sheet is not %d frames wide" % [unit.data.unit_name, UnitView.WALK_FRAMES])
		assert_eq(walk.get_height(), 4 * cell, "%s walk sheet is not four directions tall" % unit.data.unit_name)

		var slash: Texture2D = load(unit.data.sprite_slash)
		assert_eq(slash.get_width(), UnitView.SLASH_FRAMES * cell, "%s slash sheet is not %d frames wide" % [unit.data.unit_name, UnitView.SLASH_FRAMES])
		assert_eq(slash.get_height(), 4 * cell, "%s slash sheet is not four directions tall" % unit.data.unit_name)

func test_the_impact_frame_falls_inside_the_swing() -> void:
	assert_true(UnitView.SLASH_IMPACT_FRAME > 0, "damage landing on frame 0 would precede the swing")
	assert_true(UnitView.SLASH_IMPACT_FRAME < UnitView.SLASH_FRAMES, "the impact frame must exist in the sheet")

func test_grass_variation_is_deterministic_and_in_range() -> void:
	for x in 12:
		for y in 12:
			var first := GridView.plain_variant_for(Vector2i(x, y))
			assert_eq(first, GridView.plain_variant_for(Vector2i(x, y)), "same cell must always pick the same variant")
			assert_true(first >= 0 and first < GridView.PLAIN_VARIANTS.size(), "variant %d is out of range" % first)

func test_neighbouring_cells_do_not_all_share_a_variant() -> void:
	var seen: Dictionary[int, bool] = {}

	for x in 8:
		for y in 8:
			seen[GridView.plain_variant_for(Vector2i(x, y))] = true

	assert_gt(seen.size(), 1, "an 8x8 patch that picks a single variant is not varying at all")
