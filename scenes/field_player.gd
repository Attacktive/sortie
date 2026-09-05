class_name FieldPlayer
extends Node2D

## The character you walk around the field.
##
## Holds no movement logic of its own: it turns held input into a velocity, asks FieldBody where that lands, and puts itself there.
## Everything about how collision behaves lives in core/ and is tested there against the rules rather than against a running game.

## Frame 0 of an LPC walk sheet is the idle pose, so the walk cycle loops from 1 and standing still rests on 0.
const WALK_LOOP_FIRST := 1

var map: FieldMap = null
var facing: Facing.Direction = Facing.Direction.DOWN
var frozen: bool = false
var obstacles: Array[Rect2] = []
var obstacle_provider: Callable = Callable()
var _sheet: Texture2D = null
var _frame: int = 0
var _elapsed: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func setup(sheet_path: String) -> void:
	_sheet = load(sheet_path)
	queue_redraw()

## No map means no world to collide against, which happens for the frame between building the player and handing it one.
func _process(delta: float) -> void:
	if map == null or frozen:
		_rest()
		return

	## Normalized, so a diagonal is not faster than an axis — and so an exact diagonal ties in Facing.from_motion, which is the tie it is written to keep the current facing through.
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	_step(direction, delta)
	_animate(direction, delta)

func _step(direction: Vector2, delta: float) -> void:
	if direction == Vector2.ZERO:
		return

	var active_obstacles := obstacles.duplicate()
	if obstacle_provider.is_valid():
		var extra: Array = obstacle_provider.call()
		for box in extra:
			if box is Rect2:
				active_obstacles.append(box)

	var box := FieldBody.box_for_sprite(position)
	var moved := FieldBody.move(box, direction * FieldBody.SPEED, delta, map, active_obstacles)
	position = FieldBody.sprite_position_for(moved)
	_face(Facing.from_motion(direction, facing))

## Turning has to invalidate the sprite the moment it happens.
## Leaving it to the next walk frame would draw you facing the old way for up to a full frame of the walk cycle, which at 11 fps is long enough to see every time you round a corner.
func _face(turned: Facing.Direction) -> void:
	if turned == facing:
		return

	facing = turned
	queue_redraw()

func _animate(direction: Vector2, delta: float) -> void:
	if direction == Vector2.ZERO:
		_rest()
		return

	_elapsed += delta

	var cycle := UnitView.WALK_FRAMES - WALK_LOOP_FIRST
	var frame := WALK_LOOP_FIRST + int(_elapsed * UnitView.WALK_FPS) % cycle
	if frame == _frame:
		return

	_frame = frame
	queue_redraw()

## Standing still is the idle pose, and the cycle starts over from the beginning next time rather than resuming mid-stride.
func _rest() -> void:
	_elapsed = 0.0

	if _frame == 0:
		return

	_frame = 0
	queue_redraw()

func _draw() -> void:
	if _sheet == null:
		return

	var cell := float(GridGeometry.CELL_SIZE)
	var source := Rect2(_frame * cell, int(facing) * cell, cell, cell)

	draw_texture_rect_region(_sheet, Rect2(Vector2.ZERO, Vector2(cell, cell)), source)
