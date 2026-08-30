class_name Field
extends Node2D

## The walkable world: the map, what draws it, who walks on it, and the camera that follows them.
##
## Deliberately thin. There are no NPCs, no events and no way into a battle, because those are later sub-projects and this one only has to prove you can walk around.

## Bigger than the viewport on both axes, so the camera has something to do.
const MAP := [
	"##################",
	"#....F......F....#",
	"#..#............##",
	"#..#....####.....#",
	"#.......#..#.....#",
	"#..FF...#..#..F..#",
	"#.......####.....#",
	"#....#...........#",
	"##...#....F....###",
	"#................#",
	"#..F..........FF.#",
	"##################",
]

const START_CELL := Vector2i(2, 1)
const PLAYER_SHEET := "res://assets/lpc/units/vanguard_walkcycle.png"

## A node's position is the top-left corner of its sprite, so a camera sitting at the player's origin centers the screen on that corner and leaves the character down and to the right of it.
const CAMERA_OFFSET := Vector2(GridGeometry.CELL_SIZE, GridGeometry.CELL_SIZE) * 0.5

var _map: FieldMap = null
var _view: FieldView = null
var _player: FieldPlayer = null
var _camera: Camera2D = null

func _ready() -> void:
	_map = FieldMap.from_ascii(PackedStringArray(MAP))

	_build_view()
	_build_player()
	_build_camera()

func _build_view() -> void:
	_view = FieldView.new()
	_view.map = _map
	add_child(_view)

## Added after the view, because siblings draw in order and the ground has to go down before the person standing on it.
func _build_player() -> void:
	_player = FieldPlayer.new()
	_player.map = _map
	_player.position = GridGeometry.cell_to_position(START_CELL)
	_player.setup(PLAYER_SHEET)
	add_child(_player)

## Parented to the player, so following costs nothing and can never lag a frame behind.
## The limits are the map's own bounds: past them there is no world, only whatever the last frame left in the buffer.
func _build_camera() -> void:
	var bounds := _map.pixel_size()

	_camera = Camera2D.new()
	_camera.position = CAMERA_OFFSET
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(bounds.x)
	_camera.limit_bottom = int(bounds.y)

	_player.add_child(_camera)
	_camera.make_current()
