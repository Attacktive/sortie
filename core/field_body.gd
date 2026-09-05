class_name FieldBody
extends RefCounted

## Movement and collision for a body walking around a FieldMap.
##
## Pure, and free of the scene tree on purpose. The obvious Godot answer is CharacterBody2D and move_and_slide(), which would put this behavior inside the physics server where no headless test can see it. A top-down world with rectangular obstacles does not need any of what that buys, so the rules stay here with the rest of the rules.

## The collision box is the character's feet, not the sprite.
## A full-sprite box holds a character a whole tile away from anything above them; a feet box lets the head overlap the tile above, so you can stand behind a tree instead of being fenced off from it.
const BOX_SIZE := Vector2(32.0, 20.0)

## Where the box sits inside the 64x64 sprite: (64 - 32) / 2 across, 64 - 20 down.
## This is the only conversion between box space and sprite space in the codebase.
const BOX_OFFSET := Vector2(16.0, 44.0)

## 1.875 tiles per second (120 px/s). Tuned for a brisker walk feel.
const SPEED := 120.0

## No single step may cross more than half a tile, so a swept box can never skip over one.
const MAX_STEP := GridGeometry.CELL_SIZE * 0.5

static func box_for_sprite(sprite_position: Vector2) -> Rect2:
	return Rect2(sprite_position + BOX_OFFSET, BOX_SIZE)

static func sprite_position_for(box: Rect2) -> Vector2:
	return box.position - BOX_OFFSET

## Where the box ends up after moving at this velocity for this long.
## Resolves X fully, then Y. That ordering is the design: being blocked on one axis must never block the other, which is what makes a character slide along a wall instead of stopping dead against it.
##
## The move is cut into sub-steps no longer than half a tile, because a sweep only inspects where the box lands and not what it passed over.
## At the design speed a frame moves 1.6 px and this never engages; it is here for the frame that hitches, where one step could otherwise carry the box clean through a wall.
static func move(box: Rect2, velocity: Vector2, delta: float, map: FieldMap, obstacles: Array[Rect2] = []) -> Rect2:
	var motion := velocity * delta
	var longest := maxf(absf(motion.x), absf(motion.y))
	var steps := maxi(1, ceili(longest / MAX_STEP))
	var slice := motion / float(steps)

	var moved := box

	for i in steps:
		moved = _sweep(moved, Vector2(slice.x, 0.0), map, obstacles)
		moved = _sweep(moved, Vector2(0.0, slice.y), map, obstacles)

	return moved


## One axis, one step. `motion` has exactly one non-zero component.
static func _sweep(box: Rect2, motion: Vector2, map: FieldMap, obstacles: Array[Rect2] = []) -> Rect2:
	if motion == Vector2.ZERO:
		return box

	var moved := Rect2(box.position + motion, box.size)
	if map != null:
		var blockers := map.solid_tiles_overlapping(moved)
		var cell := float(GridGeometry.CELL_SIZE)

		for tile in blockers:
			var solid := Rect2(Vector2(tile) * cell, Vector2(cell, cell))

			if motion.x > 0.0:
				moved.position.x = minf(moved.position.x, solid.position.x - box.size.x)
			elif motion.x < 0.0:
				moved.position.x = maxf(moved.position.x, solid.end.x)
			elif motion.y > 0.0:
				moved.position.y = minf(moved.position.y, solid.position.y - box.size.y)
			else:
				moved.position.y = maxf(moved.position.y, solid.end.y)

	for obstacle in obstacles:
		if not moved.intersects(obstacle):
			continue

		if motion.x > 0.0 and box.position.x < obstacle.position.x:
			moved.position.x = minf(moved.position.x, obstacle.position.x - box.size.x)
		elif motion.x < 0.0 and box.end.x > obstacle.end.x:
			moved.position.x = maxf(moved.position.x, obstacle.end.x)
		elif motion.y > 0.0 and box.position.y < obstacle.position.y:
			moved.position.y = minf(moved.position.y, obstacle.position.y - box.size.y)
		elif motion.y < 0.0 and box.end.y > obstacle.end.y:
			moved.position.y = maxf(moved.position.y, obstacle.end.y)

	return moved
