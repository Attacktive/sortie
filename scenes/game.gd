class_name Game
extends Node2D

## Top-level presentation coordinator for Sortie.
## Manages active child scene swaps between Title, Field, and Battle,
## while preserving persistent WorldState and field restore coordinates.

enum Mode { NONE, TITLE, FIELD, BATTLE }

var world_state: WorldState = null
var field_restore_state: Dictionary = {}
var current_mode: Mode = Mode.NONE

var _scene_container: Node2D
var _transition: TransitionLayer
var _active_scene: Node = null
var _current_battle_id: String = ""

func _ready() -> void:
	world_state = WorldState.new()

	_scene_container = Node2D.new()
	_scene_container.name = "SceneContainer"
	add_child(_scene_container)

	_transition = TransitionLayer.new()
	_transition.name = "TransitionLayer"
	add_child(_transition)

	show_title()

	## Dev affordance for visual verification harnesses; never instantiated during normal play.
	if OS.has_environment("SORTIE_SHOT"):
		add_child(load("res://scenes/screenshot_probe.gd").new())

func get_active_scene() -> Node:
	return _active_scene

func show_title() -> void:
	current_mode = Mode.TITLE
	_switch_scene(Title.new(), func(title: Title) -> void:
		title.new_game_requested.connect(_on_title_new_game)
		title.quick_battle_requested.connect(_on_title_quick_battle)
		title.quit_requested.connect(_on_title_quit)
	)

func start_new_game() -> void:
	world_state = WorldState.new()
	field_restore_state.clear()
	show_field()

func show_field(restore_data: Dictionary = {}) -> void:
	current_mode = Mode.FIELD
	_switch_scene(Field.new(), func(field: Field) -> void:
		field.world_state = world_state
		field.battle_requested.connect(_on_field_battle_requested)
		if not restore_data.is_empty():
			field.restore(restore_data)
	)

func start_battle(battle_id: String = "default", is_quick: bool = false) -> void:
	current_mode = Mode.BATTLE
	_current_battle_id = battle_id
	_switch_scene(Battle.new(), func(battle: Battle) -> void:
		battle.battle_completed.connect(_on_battle_completed)
		battle.title_requested.connect(show_title)
		battle.retry_requested.connect(func() -> void: pass)
	)

func _switch_scene(new_scene: Node, setup_fn: Callable = Callable()) -> void:
	if _scene_container == null:
		_scene_container = Node2D.new()
		_scene_container.name = "SceneContainer"
		add_child(_scene_container)

	for child in _scene_container.get_children():
		_scene_container.remove_child(child)
		child.queue_free()

	_active_scene = new_scene
	_scene_container.add_child(new_scene)

	if setup_fn.is_valid():
		setup_fn.call(new_scene)

func _on_title_new_game() -> void:
	if _transition != null:
		_transition.fade_out(0.25)
		await _transition.fade_out_completed
	start_new_game()
	if _transition != null:
		_transition.fade_in(0.25)

func _on_title_quick_battle() -> void:
	if _transition != null:
		_transition.fade_out(0.25)
		await _transition.fade_out_completed
	start_battle("quick", true)
	if _transition != null:
		_transition.fade_in(0.25)

func _on_title_quit() -> void:
	get_tree().quit()

func _on_field_battle_requested(battle_id: String, restore_state: Dictionary) -> void:
	field_restore_state = restore_state
	if _transition != null:
		_transition.battle_flash(func() -> void:
			start_battle(battle_id, false)
		)
	else:
		start_battle(battle_id, false)

func _on_battle_completed(victory: bool) -> void:
	if victory:
		if not _current_battle_id.is_empty():
			world_state.set_flag("defeated_" + _current_battle_id, true)
		if not field_restore_state.is_empty():
			if _transition != null:
				_transition.fade_out(0.25)
				await _transition.fade_out_completed
			show_field(field_restore_state)
			if _transition != null:
				_transition.fade_in(0.25)
		else:
			show_title()
