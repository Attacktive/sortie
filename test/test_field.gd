extends GutTest

## The scene is where the pieces meet, so what is worth testing here is the wiring between them and nothing about the pieces themselves.
## Every rule they follow is already covered in test_field_map.gd, test_field_body.gd, test_field_view.gd and test_field_player.gd.

var _field: Field

func before_each() -> void:
	_field = load("res://scenes/field.tscn").instantiate()
	add_child_autofree(_field)
	await get_tree().process_frame

func test_everything_is_looking_at_the_same_map() -> void:
	assert_not_null(_field._player, "there is nobody to walk around as")
	assert_same(_field._player.map, _field._view.map, "drawing one map while colliding against another is a world where the walls are decorative")

func test_the_player_starts_somewhere_walkable() -> void:
	assert_false(_field._player.map.is_solid(Field.START_CELL), "spawning inside a wall is the one placement the player cannot walk out of")

## The viewport is smaller than any map worth walking around, so the camera is required rather than decorative.
func test_the_camera_is_limited_to_the_map() -> void:
	var bounds := _field._player.map.pixel_size()

	assert_eq(_field._camera.limit_left, 0)
	assert_eq(_field._camera.limit_top, 0)
	assert_eq(_field._camera.limit_right, int(bounds.x), "the camera has to stop at the map's edge rather than show the void past it")
	assert_eq(_field._camera.limit_bottom, int(bounds.y))

func test_the_camera_follows_the_player() -> void:
	assert_eq(_field._camera.get_parent(), _field._player, "a camera that does not move with the player is not following anything")

## Half a cell over, because a node's position is the sprite's top-left corner and centering on that frames the character down and to the right of where they actually are.
func test_the_camera_is_centered_on_the_character() -> void:
	var center := _field._player.position + Vector2.ONE * (GridGeometry.CELL_SIZE * 0.5)

	assert_eq(_field._camera.global_position, center, "the camera centers on the character, not on the corner of the tile they are standing in")

## Later siblings draw over earlier ones, and a character behind the ground is a character nobody can see.
func test_the_character_draws_over_the_ground() -> void:
	assert_gt(_field._player.get_index(), _field._view.get_index(), "the ground goes down before the person standing on it")


func test_player_collides_with_npcs_and_cannot_walk_through_them() -> void:
	var roderick: FieldNpc = _field._roderick
	var target_box := roderick.get_collision_box()
	_field._player.position = FieldBody.sprite_position_for(Rect2(target_box.position.x - FieldBody.BOX_SIZE.x - 30.0, target_box.position.y, FieldBody.BOX_SIZE.x, FieldBody.BOX_SIZE.y))

	_field._player._step(Vector2.RIGHT, 1.0)

	var player_box := FieldBody.box_for_sprite(_field._player.position)
	assert_almost_eq(player_box.end.x, target_box.position.x, 0.001, "player stops flush against Roderick's collision box")

	_field._player.facing = Facing.Direction.RIGHT
	_field._try_interact()
	assert_true(_field._dialogue_box.visible, "interacting with NPC while flush against them opens dialogue")


func test_y_sort_is_enabled_for_depth_sorting() -> void:
	assert_true(_field.y_sort_enabled, "field root node has y_sort_enabled for 2.5D depth sorting")
