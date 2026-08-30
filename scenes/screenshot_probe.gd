extends Node

## Temporary verification harness: optionally drives a selection, renders a few
## frames, saves the viewport, and quits. Gated entirely on environment variables,
## so it never runs during normal play.
func _ready() -> void:
	if OS.has_environment("SORTIE_SELECT"):
		var parts := OS.get_environment("SORTIE_SELECT").split(",")
		get_parent().call("_try_select", Vector2i(int(parts[0]), int(parts[1])))

	if OS.has_environment("SORTIE_MOVE"):
		var target := OS.get_environment("SORTIE_MOVE").split(",")
		var battle := get_parent()
		var unit: BattleUnit = battle.get("_selected")
		battle.get("_grid").move_unit(unit, Vector2i(int(target[0]), int(target[1])))
		battle.get("_views")[unit].snap()
		battle.call("_on_move_finished")

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	image.save_png(OS.get_environment("SORTIE_SHOT"))
	get_tree().quit()
