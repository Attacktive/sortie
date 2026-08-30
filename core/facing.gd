class_name Facing
extends RefCounted

## LPC sheet row order. Do not reorder: these are indices into the spritesheet.
enum Direction { UP, LEFT, DOWN, RIGHT }

## Which way a character walking along this vector should face.
## An exact diagonal keeps the current facing, because adding a direction is not the same as changing your mind, and neither is stopping.
static func from_motion(direction: Vector2, current: Direction) -> Direction:
	if absf(direction.x) > absf(direction.y):
		if direction.x > 0.0:
			return Direction.RIGHT

		return Direction.LEFT

	if absf(direction.y) > absf(direction.x):
		if direction.y > 0.0:
			return Direction.DOWN

		return Direction.UP

	return current

## Which way a character aiming at this offset should face.
## A tie resolves vertically, which is what battle characters have always done when a diagonal target is in range.
static func toward(offset: Vector2) -> Direction:
	if absf(offset.x) > absf(offset.y):
		if offset.x > 0.0:
			return Direction.RIGHT

		return Direction.LEFT

	if offset.y > 0.0:
		return Direction.DOWN

	return Direction.UP
