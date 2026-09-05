extends GutTest

## A room with a wall across the middle of the second row.
## Tiles are 64px, so tile (2, 1) spans x 128..192, y 64..128.
const ROOM := [
	"......",
	"..#...",
	"......",
	"......",
]

func _room() -> FieldMap:
	return FieldMap.from_ascii(PackedStringArray(ROOM))

## A feet box placed with its top-left at this pixel position.
func _box_at(position: Vector2) -> Rect2:
	return Rect2(position, FieldBody.BOX_SIZE)

func test_open_ground_moves_you_exactly_where_you_asked() -> void:
	var moved := FieldBody.move(_box_at(Vector2(10, 200)), Vector2(100, 0), 0.1, _room())
	assert_almost_eq(moved.position.x, 20.0, 0.001, "100 px/s for 0.1s is 10 px")
	assert_almost_eq(moved.position.y, 200.0, 0.001)

func test_walking_east_into_a_wall_stops_flush_against_it() -> void:
	## Wall tile (2, 1) starts at x = 128. A box ending there is touching it.
	var box := _box_at(Vector2(100, 80))
	var moved := FieldBody.move(box, Vector2(1000, 0), 1.0, _room())
	assert_almost_eq(moved.end.x, 128.0, 0.001, "the box stops with its right edge on the wall's left edge")

func test_walking_west_into_a_wall_stops_flush_against_it() -> void:
	var box := _box_at(Vector2(200, 80))
	var moved := FieldBody.move(box, Vector2(-1000, 0), 1.0, _room())
	assert_almost_eq(moved.position.x, 192.0, 0.001, "the wall's right edge")

func test_walking_south_into_a_wall_stops_flush_against_it() -> void:
	var box := _box_at(Vector2(140, 10))
	var moved := FieldBody.move(box, Vector2(0, 1000), 1.0, _room())
	assert_almost_eq(moved.end.y, 64.0, 0.001, "the wall's top edge")

func test_walking_north_into_a_wall_stops_flush_against_it() -> void:
	var box := _box_at(Vector2(140, 150))
	var moved := FieldBody.move(box, Vector2(0, -1000), 1.0, _room())
	assert_almost_eq(moved.position.y, 128.0, 0.001, "the wall's bottom edge")

## The point of resolving one axis at a time: being blocked on one must never block the other.
## The motion is kept short deliberately. Slide far enough and the box clears the wall's eastern edge and is free to head north again, which is correct but tests something else.
func test_a_diagonal_into_a_wall_slides_along_it() -> void:
	var box := _box_at(Vector2(140, 150))
	var moved := FieldBody.move(box, Vector2(100, -100), 0.3, _room())

	assert_almost_eq(moved.position.y, 128.0, 0.001, "northward movement is stopped by the wall's bottom edge")
	assert_almost_eq(moved.position.x, 170.0, 0.001, "but the full 30 px of eastward movement survives, which is the slide")

func test_the_map_edge_stops_you_like_any_other_wall() -> void:
	var moved := FieldBody.move(_box_at(Vector2(10, 200)), Vector2(-1000, 0), 1.0, _room())
	assert_almost_eq(moved.position.x, 0.0, 0.001, "you cannot walk out of the world")

func test_moving_away_from_a_wall_you_are_touching_works() -> void:
	## Regression: a box flush against a wall must not count that wall as blocking its retreat.
	var flush := Rect2(Vector2(128.0 - FieldBody.BOX_SIZE.x, 80), FieldBody.BOX_SIZE)
	var moved := FieldBody.move(flush, Vector2(-100, 0), 0.1, _room())
	assert_lt(moved.position.x, flush.position.x, "walking away from a wall you are touching has to move you")

## Spec section 9: move() never asserts, because content mistakes will place a body inside a wall and a trapped player is worse than a slightly wrong one.
func test_a_body_starting_inside_a_wall_is_not_trapped() -> void:
	var stuck := Rect2(Vector2(140, 80), FieldBody.BOX_SIZE)
	assert_gt(_room().solid_tiles_overlapping(stuck).size(), 0, "this box really does start inside the wall")

	var moved := FieldBody.move(stuck, Vector2(0, 400), 1.0, _room())

	assert_ne(moved.position, stuck.position, "a body inside a wall has to be able to get out of it")
	assert_eq(_room().solid_tiles_overlapping(moved).size(), 0, "and end up somewhere it is not inside one")

func test_zero_velocity_changes_nothing() -> void:
	var box := _box_at(Vector2(10, 200))
	assert_eq(FieldBody.move(box, Vector2.ZERO, 0.1, _room()), box)

func test_the_same_inputs_always_produce_the_same_result() -> void:
	var box := _box_at(Vector2(100, 80))
	var first := FieldBody.move(box, Vector2(300, -120), 0.25, _room())
	var second := FieldBody.move(box, Vector2(300, -120), 0.25, _room())
	assert_eq(first, second, "movement is a pure function; a replay must reproduce a path exactly")

## At the design speed a frame moves 1.6 px and this is unreachable.
## It is here for the frame that hitches -- a delta spike, a breakpoint, a laptop waking from sleep -- where one step could carry the box clean through a wall.
## That bug is invisible in normal play and unreproducible when reported, so it gets a guard rather than a promise.
func test_a_hitched_frame_cannot_tunnel_through_a_wall() -> void:
	var box := _box_at(Vector2(100, 80))
	var moved := FieldBody.move(box, Vector2(5000, 0), 1.0, _room())

	assert_almost_eq(moved.end.x, 128.0, 0.001, "5000 px in one step still stops at the wall")

func test_sub_stepping_does_not_change_an_ordinary_move() -> void:
	var box := _box_at(Vector2(10, 200))
	var moved := FieldBody.move(box, Vector2(96, 0), 1.0 / 60.0, _room())
	assert_almost_eq(moved.position.x, 10.0 + 96.0 / 60.0, 0.001, "a normal frame is one step and lands exactly where the arithmetic says")


func test_walking_into_an_obstacle_stops_flush_against_it() -> void:
	var box := _box_at(Vector2(50, 100))
	var obstacle := Rect2(100.0, 100.0, 32.0, 20.0)
	var obstacles: Array[Rect2] = [obstacle]

	var moved := FieldBody.move(box, Vector2(500, 0), 0.5, _room(), obstacles)
	assert_almost_eq(moved.end.x, 100.0, 0.001, "movement stops flush against the obstacle")


func test_a_diagonal_into_an_obstacle_slides_along_it() -> void:
	var obstacle := Rect2(100.0, 100.0, 32.0, 20.0)
	var obstacles: Array[Rect2] = [obstacle]
	var flush := Rect2(100.0 - FieldBody.BOX_SIZE.x, 100.0, FieldBody.BOX_SIZE.x, FieldBody.BOX_SIZE.y)

	var moved := FieldBody.move(flush, Vector2(100, 100), 0.2, _room(), obstacles)
	assert_almost_eq(moved.position.x, flush.position.x, 0.001, "eastward movement is blocked by the obstacle")
	assert_gt(moved.position.y, flush.position.y, "southward movement slides freely")


func test_walking_away_from_an_obstacle_you_are_touching_works() -> void:
	var obstacle := Rect2(100.0, 100.0, 32.0, 20.0)
	var obstacles: Array[Rect2] = [obstacle]
	var flush := Rect2(100.0 - FieldBody.BOX_SIZE.x, 100.0, FieldBody.BOX_SIZE.x, FieldBody.BOX_SIZE.y)

	var moved := FieldBody.move(flush, Vector2(-100, 0), 0.2, _room(), obstacles)
	assert_lt(moved.position.x, flush.position.x, "walking away from an obstacle you are touching has to move you")
