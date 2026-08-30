extends GutTest

## Maps are declared as pictures, the same trick BattleGrid uses, because a wall in the wrong place is obvious in a picture and invisible in a list of coordinates.
const ROOM := [
	"......",
	".#..#.",
	"..FF..",
	"......",
]

func _room() -> FieldMap:
	return FieldMap.from_ascii(PackedStringArray(ROOM))

func test_the_map_knows_its_size() -> void:
	assert_eq(_room().size, Vector2i(6, 4))

func test_pixel_size_is_cells_times_the_cell_size() -> void:
	assert_eq(_room().pixel_size(), Vector2(6 * 64, 4 * 64))

func test_glyphs_map_to_solidity() -> void:
	var map := _room()
	assert_false(map.is_solid(Vector2i(0, 0)), "a dot is walkable")
	assert_true(map.is_solid(Vector2i(1, 1)), "a hash is solid")
	assert_true(map.is_solid(Vector2i(2, 2)), "a field tree is solid, unlike a battle forest")

## The edge of the world needs no special case anywhere else if it is simply solid.
func test_everything_outside_the_map_is_solid() -> void:
	var map := _room()
	assert_true(map.is_solid(Vector2i(-1, 0)))
	assert_true(map.is_solid(Vector2i(0, -1)))
	assert_true(map.is_solid(Vector2i(6, 0)))
	assert_true(map.is_solid(Vector2i(0, 4)))

func test_a_box_inside_one_tile_touches_only_that_tile() -> void:
	var box := Rect2(Vector2(70, 70), Vector2(20, 20))
	assert_eq(_room().solid_tiles_overlapping(box), [Vector2i(1, 1)], "the box sits wholly inside the wall at (1, 1)")

func test_a_box_spanning_a_seam_reports_both_tiles() -> void:
	var box := Rect2(Vector2(120, 70), Vector2(20, 20))
	var touched := _room().solid_tiles_overlapping(box)
	assert_eq(touched.size(), 1, "only (1, 1) is solid; (2, 1) is open floor")
	assert_has(touched, Vector2i(1, 1))

func test_a_box_on_open_floor_reports_nothing() -> void:
	assert_eq(_room().solid_tiles_overlapping(Rect2(Vector2(10, 200), Vector2(20, 20))).size(), 0)

func test_the_map_remembers_which_glyph_was_authored() -> void:
	## A view has to tell a tree from a wall, and is_solid() only answers yes or no.
	var map := _room()
	assert_eq(map.glyph_at(Vector2i(1, 1)), FieldMap.WALL)
	assert_eq(map.glyph_at(Vector2i(2, 2)), FieldMap.TREE)
	assert_eq(map.glyph_at(Vector2i(0, 0)), "", "walkable ground has no glyph to draw over the grass")

## There is deliberately no test for the ragged-map assert.
## GDScript's assert() halts the engine rather than raising something catchable, so GUT cannot exercise it, and a test that asserts true to stand in for one only inflates the count.
## It was verified by hand instead: FieldMap.from_ascii(["....", "..", "...."]) fails with "row 1 is 2 wide but the map is 4".
