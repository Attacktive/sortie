class_name TransitionLayer
extends CanvasLayer

## Full-screen color overlay executing screen fades and battle flash transitions.
## Supports zero-duration transitions under headless test runs to eliminate timer overhead.

signal fade_out_completed
signal fade_in_completed

var _rect: ColorRect
var _tween: Tween

func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

func get_color() -> Color:
	if _rect == null:
		return Color.TRANSPARENT

	return _rect.color

func fade_out(duration: float = 0.25, color: Color = Color.BLACK) -> void:
	if _rect == null:
		return

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_rect.color = Color(color.r, color.g, color.b, 0.0)
	if duration <= 0.0 or DisplayServer.get_name() == "headless":
		_rect.color = Color(color.r, color.g, color.b, 1.0)
		fade_out_completed.emit.call_deferred()
		return

	_tween = create_tween()
	_tween.tween_property(_rect, "color:a", 1.0, duration)
	_tween.finished.connect(func() -> void: fade_out_completed.emit())

func fade_in(duration: float = 0.25) -> void:
	if _rect == null:
		return

	if _tween != null and _tween.is_valid():
		_tween.kill()

	if duration <= 0.0 or DisplayServer.get_name() == "headless":
		_rect.color = Color(_rect.color.r, _rect.color.g, _rect.color.b, 0.0)
		fade_in_completed.emit.call_deferred()
		return

	_tween = create_tween()
	_tween.tween_property(_rect, "color:a", 0.0, duration)
	_tween.finished.connect(func() -> void: fade_in_completed.emit())

## Executes the classic 3-beat JRPG battle flash sequence before swapping scenes on full black.
## Flash white -> normal -> flash white -> fade black -> invoke callback -> fade in from black.
func battle_flash(callback_on_black: Callable, test_instant: bool = false) -> void:
	if _rect == null:
		return

	if _tween != null and _tween.is_valid():
		_tween.kill()

	if test_instant or DisplayServer.get_name() == "headless":
		_rect.color = Color.BLACK
		if not callback_on_black.is_null():
			callback_on_black.call()
		_rect.color = Color(0, 0, 0, 0)
		return
	_rect.color = Color(1, 1, 1, 0)
	_tween = create_tween()
	_tween.tween_property(_rect, "color:a", 1.0, 0.06)
	_tween.tween_property(_rect, "color:a", 0.0, 0.06)
	_tween.tween_property(_rect, "color:a", 1.0, 0.06)
	_tween.tween_callback(func() -> void: _rect.color = Color(0, 0, 0, 0))
	_tween.tween_property(_rect, "color:a", 1.0, 0.25)
	_tween.tween_callback(func() -> void:
		if callback_on_black.is_valid():
			callback_on_black.call()
	)
	_tween.tween_property(_rect, "color:a", 0.0, 0.25)
