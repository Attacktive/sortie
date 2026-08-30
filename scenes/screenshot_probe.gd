extends Node

## Temporary verification harness. Optionally drives the battle into a specific
## state, waits, saves the viewport, and quits. Gated entirely on environment
## variables, so it never runs during normal play.
func _ready() -> void:
	var battle := get_parent()

	if OS.has_environment("SORTIE_SELECT"):
		var parts := OS.get_environment("SORTIE_SELECT").split(",")
		battle.call("_try_select", Vector2i(int(parts[0]), int(parts[1])))

	if OS.has_environment("SORTIE_ATTACK"):
		_stage_attack(battle, OS.get_environment("SORTIE_ATTACK").split(","))

	var wait := float(OS.get_environment("SORTIE_WAIT")) if OS.has_environment("SORTIE_WAIT") else 0.0
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	else:
		for i in 3:
			await get_tree().process_frame

	get_viewport().get_texture().get_image().save_png(OS.get_environment("SORTIE_SHOT"))
	get_tree().quit()

## "ax,ay,tx,ty": teleport the attacker beside the target, then swing.
func _stage_attack(battle: Node, parts: PackedStringArray) -> void:
	var grid = battle.get("_grid")
	var attacker = grid.unit_at(Vector2i(int(parts[0]), int(parts[1])))
	var target_cell := Vector2i(int(parts[2]), int(parts[3]))
	var beside := target_cell + Vector2i(-1, 0)

	grid.move_unit(attacker, beside)
	battle.get("_views")[attacker].snap()
	battle.call("_try_select", beside)
	battle.set("_state", 4)
	battle.call("_try_attack", target_cell)
