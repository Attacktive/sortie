extends GutTest

var _layer: TransitionLayer = null

func before_each() -> void:
	_layer = TransitionLayer.new()
	add_child_autofree(_layer)
	await get_tree().process_frame

func test_fade_out_and_fade_in_signals_emit() -> void:
	watch_signals(_layer)

	_layer.fade_out(0.0, Color.BLACK)
	await get_tree().process_frame

	assert_signal_emitted(_layer, "fade_out_completed")
	assert_eq(_layer.get_color().a, 1.0)

	_layer.fade_in(0.0)
	await get_tree().process_frame

	assert_signal_emitted(_layer, "fade_in_completed")
	assert_eq(_layer.get_color().a, 0.0)

func test_battle_flash_calls_callback_on_black_and_restores_clear() -> void:
	var result := { "called": false, "alpha": -1.0 }

	var on_black := func() -> void:
		result.called = true
		result.alpha = _layer.get_color().a

	_layer.battle_flash(on_black, true)
	await get_tree().process_frame

	assert_true(result.called, "callback is invoked during battle flash")
	assert_eq(result.alpha, 1.0, "screen is fully black when callback is invoked")
	assert_eq(_layer.get_color().a, 0.0, "screen returns to clear after transition finishes")

func test_fade_out_accepts_custom_color() -> void:
	_layer.fade_out(0.0, Color.WHITE)
	await get_tree().process_frame

	assert_eq(_layer.get_color(), Color.WHITE)
