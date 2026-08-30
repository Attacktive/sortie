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
