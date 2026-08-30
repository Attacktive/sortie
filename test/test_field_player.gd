extends GutTest

## Real input, driven through Input rather than the viewport: Input.get_vector reads held action state and only parse_input_event updates it.
## push_input delivers a one-shot, which would leave get_vector reading zero on the very next frame.
##
## The collision rules underneath are covered exhaustively by test_field_body.gd. What is covered here is the wiring, which is the layer this project's bugs have actually lived in.

const ROOM := [
	"......",
	"......",
	"......",
	"......",
]

## A wall down column 2, so walking east from the left edge meets it whatever row you are standing in.
const CORRIDOR := [
	"..#...",
	"..#...",
	"..#...",
	"..#...",
]

const ARROWS := [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]

var _player: FieldPlayer

func before_each() -> void:
	_player = FieldPlayer.new()
	_player.map = FieldMap.from_ascii(PackedStringArray(ROOM))
	_player.setup("res://assets/lpc/units/vanguard_walkcycle.png")
	_player.position = Vector2(100, 100)
	add_child_autofree(_player)
	await get_tree().process_frame

## Held keys are global device state, so a test that ended without releasing one would walk the next test's character into a wall.
func after_each() -> void:
	for keycode in ARROWS:
		_release(keycode)

func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed

	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _hold(keycode: Key) -> void:
	_key(keycode, true)

func _release(keycode: Key) -> void:
	_key(keycode, false)

func _hold_for_frames(keycode: Key, frames: int) -> void:
	_hold(keycode)

	for i in frames:
		await get_tree().process_frame

	_release(keycode)
	await get_tree().process_frame

## Walks until the character stops making progress, however many frames that takes, and reports how many it took.
## A fixed frame count would be a bet on how fast the machine running the test is: 120 frames covers 81 px here and the wall below is 80 px away, so a machine one percent faster would never reach it and the assertion would pass without ever touching a wall.
func _walk_until_settled(keycode: Key) -> int:
	const BUDGET := 1200

	_hold(keycode)

	var frames := BUDGET

	for i in BUDGET:
		var before := _player.position
		await get_tree().process_frame

		if _player.position == before:
			frames = i + 1
			break

	_release(keycode)
	await get_tree().process_frame

	return frames

func test_holding_right_moves_the_character_east() -> void:
	var before := _player.position.x
	await _hold_for_frames(KEY_RIGHT, 10)

	assert_gt(_player.position.x, before, "holding a direction has to actually move you")
	assert_eq(_player.facing, Facing.Direction.RIGHT, "and turn you to face the way you are going")

func test_holding_up_moves_the_character_north() -> void:
	var before := _player.position.y
	await _hold_for_frames(KEY_UP, 10)

	assert_lt(_player.position.y, before, "up the screen is negative y")
	assert_eq(_player.facing, Facing.Direction.UP)

func test_releasing_everything_stops_the_character() -> void:
	await _hold_for_frames(KEY_RIGHT, 5)
	var settled := _player.position

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_player.position, settled, "a released key must not leave you coasting")

## Letting go is not a change of mind. A character who snaps back to facing the camera the instant you stop reads as a twitch.
func test_letting_go_does_not_turn_you_around() -> void:
	await _hold_for_frames(KEY_RIGHT, 10)

	assert_eq(_player.facing, Facing.Direction.RIGHT, "you go on facing the way you were walking")

## Exact, not merely "did not pass through", because the exact number is the one that proves the sprite-to-box conversion was applied.
## Feed FieldBody the sprite position instead of the collision box and the character still stops at the wall, just sixteen pixels into it.
func test_a_wall_stops_the_character_with_its_feet_against_it() -> void:
	_player.map = FieldMap.from_ascii(PackedStringArray(CORRIDOR))
	_player.position = Vector2(0, 100)

	var frames := await _walk_until_settled(KEY_RIGHT)
	var flush := 2.0 * GridGeometry.CELL_SIZE - FieldBody.BOX_SIZE.x - FieldBody.BOX_OFFSET.x

	assert_almost_eq(_player.position.x, flush, 0.001, "walking east into a wall has to settle with the feet touching it; this settled after %d frames" % frames)

func test_stopping_returns_to_the_idle_frame() -> void:
	await _hold_for_frames(KEY_RIGHT, 20)

	assert_eq(_player._frame, 0, "frame 0 of an LPC walk sheet is the idle pose, and standing still rests on it")

## Read while still walking, because _hold_for_frames lets go at the end and letting go is what puts the idle frame back.
func test_walking_advances_past_the_idle_frame() -> void:
	_hold(KEY_RIGHT)
	await get_tree().process_frame
	await get_tree().process_frame

	var walking := _player._frame
	_release(KEY_RIGHT)

	assert_gt(walking, 0, "a walk cycle that never leaves frame 0 is not animating")

## Task 7 builds the player and hands it a map on separate lines, so there is at least one frame where it has none.
func test_a_player_without_a_map_stands_still() -> void:
	_player.map = null
	var before := _player.position

	await _hold_for_frames(KEY_RIGHT, 10)

	assert_eq(_player.position, before, "a player waiting for its map has to stand still rather than fall through the world")
