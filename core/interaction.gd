class_name Interaction
extends RefCounted

## Pure geometry determining interaction reach from a collision box and facing direction.

const DEFAULT_REACH := 16.0

static func probe_box(box: Rect2, facing: Facing.Direction, reach: float = DEFAULT_REACH) -> Rect2:
	if facing == Facing.Direction.UP:
		return Rect2(box.position.x, box.position.y - reach, box.size.x, reach)

	if facing == Facing.Direction.DOWN:
		return Rect2(box.position.x, box.end.y, box.size.x, reach)

	if facing == Facing.Direction.LEFT:
		return Rect2(box.position.x - reach, box.position.y, reach, box.size.y)

	return Rect2(box.end.x, box.position.y, reach, box.size.y)
