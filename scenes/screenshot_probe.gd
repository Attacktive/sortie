extends Node

## Temporary verification harness: renders a few frames, saves the viewport, quits.
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png(OS.get_environment("SORTIE_SHOT"))
	get_tree().quit()
