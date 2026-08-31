extends GutTest

func test_set_glyph_updates_solidity_and_glyph() -> void:
	var map := FieldMap.from_ascii(PackedStringArray([
		"...",
		".#.",
		"..."
	]))

	assert_true(map.is_solid(Vector2i(1, 1)))
	assert_eq(map.glyph_at(Vector2i(1, 1)), "#")

	## Replace wall with floor
	map.set_glyph(Vector2i(1, 1), ".")
	assert_false(map.is_solid(Vector2i(1, 1)))
	assert_eq(map.glyph_at(Vector2i(1, 1)), ".")
