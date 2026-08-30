class_name DamageNumber
extends Label

const RISE := 30.0
const SECONDS := 0.8
const NORMAL_SIZE := 21
const CRIT_SIZE := 32

const MISS_COLOR := Color(0.82, 0.82, 0.88)
const HIT_COLOR := Color(1.0, 0.96, 0.94)
const CRIT_COLOR := Color(1.0, 0.84, 0.24)

## What the player reads. Pure, so it is tested rather than eyeballed.
static func text_for(result: AttackResult) -> String:
	if not result.hit:
		return "Miss"

	return str(result.damage)

static func color_for(result: AttackResult) -> Color:
	if not result.hit:
		return MISS_COLOR

	if result.crit:
		return CRIT_COLOR

	return HIT_COLOR

## Crits are bigger as well as gold, so they read even in peripheral vision.
static func size_for(result: AttackResult) -> int:
	if result.hit and result.crit:
		return CRIT_SIZE

	return NORMAL_SIZE

static func spawn(parent: Node, at: Vector2, result: AttackResult) -> DamageNumber:
	var number := DamageNumber.new()
	number.text = text_for(result)
	number.add_theme_color_override("font_color", color_for(result))
	number.add_theme_font_size_override("font_size", size_for(result))
	number.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.06))
	number.add_theme_constant_override("outline_size", 5)
	number.position = at
	number.z_index = 100
	parent.add_child(number)
	number.play()

	return number

func play() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE, SECONDS).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, SECONDS).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
