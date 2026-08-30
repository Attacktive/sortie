class_name UnitView
extends Node2D

signal walk_finished

const STEP_SECONDS := 0.12
const HP_BAR_HEIGHT := 4.0
const HP_BAR_INSET := 5.0
const SPENT_MODULATE := Color(0.55, 0.55, 0.55, 1.0)

var unit: BattleUnit = null

var _sprite: Texture2D = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func setup(battle_unit: BattleUnit) -> void:
	unit = battle_unit
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if battle_unit.data.sprite != "":
		_sprite = load(battle_unit.data.sprite)

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

	var cell := Vector2.ONE * GridGeometry.CELL_SIZE
	if _sprite != null:
		draw_texture_rect(_sprite, Rect2(Vector2.ZERO, cell), false)

	_draw_health_bar()

## Sits along the bottom edge of the cell, under the sprite's feet.
func _draw_health_bar() -> void:
	var ratio := clampf(float(unit.hp) / float(unit.data.max_hp), 0.0, 1.0)
	var width := GridGeometry.CELL_SIZE - HP_BAR_INSET * 2.0
	var top := Vector2(HP_BAR_INSET, GridGeometry.CELL_SIZE - HP_BAR_INSET - HP_BAR_HEIGHT)

	draw_rect(Rect2(top - Vector2.ONE, Vector2(width, HP_BAR_HEIGHT) + Vector2.ONE * 2.0), Color(0.06, 0.04, 0.06))
	draw_rect(Rect2(top, Vector2(width, HP_BAR_HEIGHT)), Color(0.35, 0.10, 0.12))
	draw_rect(Rect2(top, Vector2(width * ratio, HP_BAR_HEIGHT)), _health_color(ratio))

## Green while healthy, amber when hurt, red when nearly dead — readable at a glance.
static func _health_color(ratio: float) -> Color:
	if ratio > 0.6:
		return Color(0.35, 0.85, 0.35)

	if ratio > 0.3:
		return Color(0.95, 0.75, 0.20)

	return Color(0.90, 0.25, 0.25)
