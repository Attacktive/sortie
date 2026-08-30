class_name UnitView
extends Node2D

signal walk_finished
signal attack_connected
signal attack_finished

## LPC sheet row order. Do not reorder: these are indices into the spritesheet.
enum Facing { UP, LEFT, DOWN, RIGHT }

const WALK_FRAMES := 9
const SLASH_FRAMES := 6
const WALK_FPS := 11.0
const SLASH_FPS := 14.0

## Seconds to cross one cell. Tuned so the walk cycle reads as steps rather than a slide.
const STEP_SECONDS := 0.18

## The frame where the blade actually lands, so damage lands with it.
const SLASH_IMPACT_FRAME := 3

const HP_BAR_HEIGHT := 4.0
const HP_BAR_WIDTH := 40.0
const SPENT_MODULATE := Color(0.55, 0.55, 0.60, 1.0)
const FLASH_COLOR := Color(6.0, 6.0, 6.0, 1.0)
const FLASH_SECONDS := 0.09
const DEATH_SECONDS := 0.45

var unit: BattleUnit = null

var _walk: Texture2D = null
var _slash: Texture2D = null
var _sheet: Texture2D = null
var _facing: Facing = Facing.DOWN
var _frame: int = 0
var _frame_count: int = 1
var _elapsed: float = 0.0
var _fps: float = 0.0
var _playing: bool = false
var _flashing: bool = false
var _dying: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func setup(battle_unit: BattleUnit) -> void:
	unit = battle_unit
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_walk = load(battle_unit.data.sprite_walk)
	_slash = load(battle_unit.data.sprite_slash)
	_rest()
	snap()

## Places the view at the unit's cell with no animation.
func snap() -> void:
	position = GridGeometry.cell_to_position(unit.cell)
	refresh()

func refresh() -> void:
	if unit == null:
		return

	if not _flashing:
		modulate = SPENT_MODULATE if unit.has_acted else Color.WHITE

	## Stay visible through the death animation; hiding on the impact refresh
	## would cut the fade off before it started.
	visible = unit.is_alive() or _dying
	queue_redraw()

## Standing still is frame 0 of the walk cycle — LPC draws it as an idle pose.
func _rest() -> void:
	_sheet = _walk
	_frame = 0
	_frame_count = WALK_FRAMES
	_playing = false
	queue_redraw()

func _process(delta: float) -> void:
	if not _playing:
		return

	_elapsed += delta
	var frame := int(_elapsed * _fps)
	if frame == _frame:
		return

	_frame = mini(frame, _frame_count - 1)
	queue_redraw()

func face_toward(cell: Vector2i) -> void:
	var delta := cell - unit.cell
	if delta == Vector2i.ZERO:
		return

	if absi(delta.x) > absi(delta.y):
		_facing = Facing.RIGHT if delta.x > 0 else Facing.LEFT
	else:
		_facing = Facing.DOWN if delta.y > 0 else Facing.UP

	queue_redraw()

## Walks one cell at a time along the path, turning to face each step.
## An empty path still emits, so callers never special-case standing still.
func walk_path(path: Array[Vector2i]) -> void:
	if path.is_empty():
		walk_finished.emit()
		return

	_sheet = _walk
	_frame_count = WALK_FRAMES
	_fps = WALK_FPS
	_elapsed = 0.0
	_playing = true

	var tween := create_tween()
	var from := unit.cell

	for cell in path:
		var step := cell - from
		var facing := _facing_for(step)
		tween.tween_callback(func() -> void: _face(facing))
		tween.tween_property(self, "position", GridGeometry.cell_to_position(cell), STEP_SECONDS)
		from = cell

	tween.finished.connect(func() -> void:
		_rest()
		walk_finished.emit()
	)

## Swings at a target: emits attack_connected on the impact frame so damage
## lands with the blade, then attack_finished when the swing completes.
func play_attack(target_cell: Vector2i) -> void:
	face_toward(target_cell)

	_sheet = _slash
	_frame_count = SLASH_FRAMES
	_fps = SLASH_FPS
	_elapsed = 0.0
	_frame = 0
	_playing = true
	queue_redraw()

	var tween := create_tween()
	tween.tween_interval(SLASH_IMPACT_FRAME / SLASH_FPS)
	tween.tween_callback(func() -> void: attack_connected.emit())
	tween.tween_interval((SLASH_FRAMES - SLASH_IMPACT_FRAME) / SLASH_FPS)
	tween.tween_callback(func() -> void:
		_rest()
		attack_finished.emit()
	)

## A brief white blowout on being hit. Uses modulate above 1.0, which the
## renderer clips to white, so it reads as a flash rather than a tint.
func flash() -> void:
	_flashing = true
	modulate = FLASH_COLOR

	var tween := create_tween()
	tween.tween_interval(FLASH_SECONDS)
	tween.tween_callback(func() -> void:
		_flashing = false
		refresh()
	)

## Fades and sinks rather than vanishing between frames.
func play_death() -> void:
	_dying = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, DEATH_SECONDS)
	tween.tween_property(self, "position:y", position.y + 10.0, DEATH_SECONDS)
	tween.chain().tween_callback(func() -> void:
		_dying = false
		visible = false
	)

func _face(facing: Facing) -> void:
	_facing = facing
	queue_redraw()

static func _facing_for(step: Vector2i) -> Facing:
	if step.x > 0:
		return Facing.RIGHT

	if step.x < 0:
		return Facing.LEFT

	if step.y < 0:
		return Facing.UP

	return Facing.DOWN

func _draw() -> void:
	if unit == null or _sheet == null:
		return

	var cell := float(GridGeometry.CELL_SIZE)
	var source := Rect2(_frame * cell, int(_facing) * cell, cell, cell)
	draw_texture_rect_region(_sheet, Rect2(Vector2.ZERO, Vector2(cell, cell)), source)

	_draw_health_bar()

## Centred under the sprite's feet, narrower than the cell so neighbours stay distinct.
func _draw_health_bar() -> void:
	var ratio := clampf(float(unit.hp) / float(unit.data.max_hp), 0.0, 1.0)
	var left := (GridGeometry.CELL_SIZE - HP_BAR_WIDTH) * 0.5
	var top := Vector2(left, GridGeometry.CELL_SIZE - HP_BAR_HEIGHT - 3.0)

	draw_rect(Rect2(top - Vector2.ONE, Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT) + Vector2.ONE * 2.0), Color(0.05, 0.04, 0.06, 0.85))
	draw_rect(Rect2(top, Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT)), _health_color(ratio))

## Green while healthy, amber when hurt, red when nearly dead — readable at a glance.
static func _health_color(ratio: float) -> Color:
	if ratio > 0.6:
		return Color(0.35, 0.85, 0.35)

	if ratio > 0.3:
		return Color(0.95, 0.75, 0.20)

	return Color(0.90, 0.25, 0.25)
