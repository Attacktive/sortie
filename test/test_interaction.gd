extends GutTest

func test_probe_box_extends_in_facing_direction() -> void:
	var box := Rect2(100.0, 100.0, 32.0, 20.0)
	var reach := 16.0

	var up := Interaction.probe_box(box, Facing.Direction.UP, reach)
	assert_eq(up.position, Vector2(100.0, 84.0))
	assert_eq(up.size, Vector2(32.0, 16.0))

	var down := Interaction.probe_box(box, Facing.Direction.DOWN, reach)
	assert_eq(down.position, Vector2(100.0, 120.0))
	assert_eq(down.size, Vector2(32.0, 16.0))

	var left := Interaction.probe_box(box, Facing.Direction.LEFT, reach)
	assert_eq(left.position, Vector2(84.0, 100.0))
	assert_eq(left.size, Vector2(16.0, 20.0))

	var right := Interaction.probe_box(box, Facing.Direction.RIGHT, reach)
	assert_eq(right.position, Vector2(132.0, 100.0))
	assert_eq(right.size, Vector2(16.0, 20.0))

func test_interaction_intersects_adjacent_target() -> void:
	var player_box := Rect2(100.0, 100.0, 32.0, 20.0)
	var target_box := Rect2(100.0, 70.0, 32.0, 20.0)

	var probe_up := Interaction.probe_box(player_box, Facing.Direction.UP)
	var probe_down := Interaction.probe_box(player_box, Facing.Direction.DOWN)

	assert_true(probe_up.intersects(target_box), "facing target reaches it")
	assert_false(probe_down.intersects(target_box), "facing away does not reach it")
