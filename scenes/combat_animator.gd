class_name CombatAnimator
extends Node

signal finished

const PLAYER_COLOR := Color(0.55, 0.78, 1.0)
const ENEMY_COLOR := Color(1.0, 0.48, 0.42)

## Replays an already-resolved exchange. The rules ran synchronously and the
## model is already final; this only shows what happened, in order, with the
## health bar dropping on the frame the blade lands.
func play(exchange: CombatExchange, attacker: UnitView, defender: UnitView) -> void:
	await _swing(attacker, defender, exchange.attack)

	if exchange.counter != null:
		await _swing(defender, attacker, exchange.counter)

	finished.emit()

func _swing(actor: UnitView, target: UnitView, result: AttackResult) -> void:
	actor.play_attack(target.unit.cell)
	await actor.attack_connected

	if result.hit:
		target.flash()

	DamageNumber.spawn(get_parent(), target.position + Vector2(GridGeometry.CELL_SIZE * 0.5, 4.0), result)
	target.refresh()

	await actor.attack_finished

	if result.killed:
		target.play_death()
		await get_tree().create_timer(UnitView.DEATH_SECONDS).timeout
