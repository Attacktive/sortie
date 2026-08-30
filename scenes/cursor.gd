class_name Cursor
extends Node2D

signal moved(cell: Vector2i)
signal confirmed(cell: Vector2i)
signal canceled

const OUTLINE := Color("ffd75e")

const _DIRECTIONS := {
	"ui_up": Vector2i(0, -1),
	"ui_down": Vector2i(0, 1),
	"ui_left": Vector2i(-1, 0),
	"ui_right": Vector2i(1, 0),
}

var cell: Vector2i = Vector2i.ZERO
var bounds: Vector2i = Vector2i.ONE
var active: bool = true

func _process(_delta: float) -> void:
	position = GridGeometry.cell_to_position(cell)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2.ONE * GridGeometry.CELL_SIZE), OUTLINE, false, 3.0)

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if event is InputEventMouseMotion:
		_move_to(GridGeometry.position_to_cell(get_local_mouse_position() + position))
		return

	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		confirmed.emit(cell)
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		canceled.emit()
		return

	for action in _DIRECTIONS:
		if event.is_action_pressed(action):
			_move_to(cell + _DIRECTIONS[action])
			return

func _move_to(target: Vector2i) -> void:
	var clamped := Vector2i(clampi(target.x, 0, bounds.x - 1), clampi(target.y, 0, bounds.y - 1))
	if clamped == cell:
		return

	cell = clamped
	moved.emit(cell)
