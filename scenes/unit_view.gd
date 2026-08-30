class_name UnitView
extends Node2D

signal walk_finished

const STEP_SECONDS := 0.12
const BODY_INSET := 8.0
const HP_BAR_HEIGHT := 5.0
const SPENT_MODULATE := Color(0.55, 0.55, 0.55, 1.0)

var unit: BattleUnit = null

func setup(battle_unit: BattleUnit) -> void:
	unit = battle_unit
	snap()

## Places the view at the unit's cell with no animation.
func snap() -> void:
	position = GridGeometry.cell_to_position(unit.cell)
	refresh()

func refresh() -> void:
	if unit == null:
		return

	modulate = Color.WHITE
	if unit.has_acted:
		modulate = SPENT_MODULATE

	visible = unit.is_alive()
	queue_redraw()

## Slides the view one cell at a time along the path, then reports completion.
## An empty path still emits, so callers never have to special-case standing still.
func walk_path(path: Array[Vector2i]) -> void:
	if path.is_empty():
		walk_finished.emit()
		return

	var tween := create_tween()
	for cell in path:
		tween.tween_property(self, "position", GridGeometry.cell_to_position(cell), STEP_SECONDS)

	tween.finished.connect(func() -> void:
		walk_finished.emit()
	)

func _draw() -> void:
	if unit == null:
		return

	var body_size := GridGeometry.CELL_SIZE - BODY_INSET * 2.0
	draw_rect(Rect2(Vector2.ONE * BODY_INSET, Vector2.ONE * body_size), unit.data.color)

	var ratio := clampf(float(unit.hp) / float(unit.data.max_hp), 0.0, 1.0)
	var bar_top := Vector2(BODY_INSET, GridGeometry.CELL_SIZE - BODY_INSET - HP_BAR_HEIGHT)
	draw_rect(Rect2(bar_top, Vector2(body_size, HP_BAR_HEIGHT)), Color(0.1, 0.05, 0.05))
	draw_rect(Rect2(bar_top, Vector2(body_size * ratio, HP_BAR_HEIGHT)), Color(0.35, 0.85, 0.35))
