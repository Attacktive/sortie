extends GutTest

## _draw() picks a sheet row with int(facing), so the enum's integer values are the LPC row order itself, not an arbitrary listing.
## Reordering it would silently turn every character the wrong way.
func test_the_values_are_the_lpc_row_order() -> void:
	assert_eq(int(Facing.Direction.UP), 0, "row 0 of an LPC sheet faces away from the camera")
	assert_eq(int(Facing.Direction.LEFT), 1, "row 1 of an LPC sheet faces left")
	assert_eq(int(Facing.Direction.DOWN), 2, "row 2 of an LPC sheet faces the camera")
	assert_eq(int(Facing.Direction.RIGHT), 3, "row 3 of an LPC sheet faces right")

func test_motion_picks_the_dominant_axis() -> void:
	assert_eq(Facing.from_motion(Vector2(1, 0), Facing.Direction.UP), Facing.Direction.RIGHT, "walking east faces right")
	assert_eq(Facing.from_motion(Vector2(-1, 0), Facing.Direction.UP), Facing.Direction.LEFT, "walking west faces left")
	assert_eq(Facing.from_motion(Vector2(0, -1), Facing.Direction.RIGHT), Facing.Direction.UP, "walking north faces up")
	assert_eq(Facing.from_motion(Vector2(0, 1), Facing.Direction.RIGHT), Facing.Direction.DOWN, "walking south faces down")

func test_a_shallow_diagonal_still_has_a_dominant_axis() -> void:
	assert_eq(Facing.from_motion(Vector2(10, 3), Facing.Direction.UP), Facing.Direction.RIGHT, "mostly east is east")
	assert_eq(Facing.from_motion(Vector2(3, -10), Facing.Direction.RIGHT), Facing.Direction.UP, "mostly north is north")

## Adding a direction is not changing your mind, so a tie leaves the character facing where they already were.
func test_an_exact_diagonal_keeps_the_current_facing() -> void:
	assert_eq(Facing.from_motion(Vector2(1, 1), Facing.Direction.RIGHT), Facing.Direction.RIGHT)
	assert_eq(Facing.from_motion(Vector2(1, 1), Facing.Direction.UP), Facing.Direction.UP)
	assert_eq(Facing.from_motion(Vector2(-1, 1).normalized(), Facing.Direction.LEFT), Facing.Direction.LEFT, "normalized input must tie too")

func test_standing_still_does_not_turn_you_around() -> void:
	assert_eq(Facing.from_motion(Vector2.ZERO, Facing.Direction.LEFT), Facing.Direction.LEFT)

## Aiming is a different question from moving, and a range-2 Mage can target a cell diagonally.
func test_aiming_resolves_a_diagonal_vertically() -> void:
	assert_eq(Facing.toward(Vector2(1, 1)), Facing.Direction.DOWN, "a tie aims vertically, as face_toward always has")
	assert_eq(Facing.toward(Vector2(1, -1)), Facing.Direction.UP)
	assert_eq(Facing.toward(Vector2(2, 1)), Facing.Direction.RIGHT, "a dominant axis still wins")
