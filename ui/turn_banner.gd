class_name TurnBanner
extends Label

const HOLD_SECONDS := 0.55
const FADE_SECONDS := 0.25

func _ready() -> void:
	add_theme_font_size_override("font_size", 40)
	add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.05))
	add_theme_constant_override("outline_size", 8)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	position.y = 120.0
	modulate.a = 0.0

## Fades a phase name in and out. Never blocks input — it is a label, not a modal.
func announce(message: String, color: Color) -> void:
	text = message
	add_theme_color_override("font_color", color)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
