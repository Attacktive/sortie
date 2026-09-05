class_name Title
extends Node2D

## Root presentation scene for the Title screen.
## Hosts the TitleMenu and forwards navigation signals to the coordinator.

signal new_game_requested
signal quick_battle_requested
signal quit_requested

var _menu: TitleMenu

func _ready() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.09, 1.0)
	canvas.add_child(bg)

	_menu = TitleMenu.new()
	_menu.name = "TitleMenu"
	_menu.new_game_requested.connect(func() -> void: new_game_requested.emit())
	_menu.quick_battle_requested.connect(func() -> void: quick_battle_requested.emit())
	_menu.quit_requested.connect(func() -> void: quit_requested.emit())
	canvas.add_child(_menu)
