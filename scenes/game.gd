class_name Game
extends Node2D

## Top-level presentation coordinator for Sortie.
## Manages active child scene swaps between Title, Field, and Battle,
## while preserving persistent WorldState and field restore coordinates.

enum Mode { NONE, TITLE, FIELD, BATTLE }

var world_state: WorldState = null
var field_restore_state: Dictionary = {}
var current_mode: Mode = Mode.NONE
var save_manager: SaveManager = SaveManager.new()
var playtime_seconds: float = 0.0

var _scene_container: Node2D
var _transition: TransitionLayer
var _active_scene: Node = null
var _current_battle_id: String = ""
var _slot_menu: SaveSlotMenu = null
func _ready() -> void:
	if world_state == null:
		world_state = WorldState.new()
	if save_manager == null:
		save_manager = SaveManager.new()
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



func _process(delta: float) -> void:
	if current_mode == Mode.FIELD or current_mode == Mode.BATTLE:
		playtime_seconds += delta


func get_slot_menu() -> SaveSlotMenu:
	return _slot_menu
func get_active_scene() -> Node:
	return _active_scene

func show_title() -> void:
	current_mode = Mode.TITLE
	_switch_scene(Title.new(), func(title: Title) -> void:
		title.new_game_requested.connect(_on_title_new_game)
		title.load_game_requested.connect(_on_title_load_game)
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
		field.save_requested.connect(_on_field_save_requested)
		field.load_requested.connect(_on_field_load_requested)
		field.title_requested.connect(_on_field_title_requested)
		if not restore_data.is_empty():
			field.restore(restore_data)
	)

func start_battle(battle_id: String = "default", is_quick: bool = false) -> void:
	current_mode = Mode.BATTLE
	_current_battle_id = battle_id
	var battle := Battle.new()
	battle.mission_id = battle_id
	_switch_scene(battle, func(b: Battle) -> void:
		b.battle_completed.connect(_on_battle_completed)
		b.title_requested.connect(show_title)
		b.retry_requested.connect(func() -> void: pass)
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
			if _current_battle_id != "default" and _current_battle_id != "quick":
				var mission := MissionRegistry.get_mission(_current_battle_id)
				if mission != null and not mission.completion_flag.is_empty():
					world_state.set_flag(mission.completion_flag, true)
		if not field_restore_state.is_empty():
			if _transition != null:
				_transition.fade_out(0.25)
				await _transition.fade_out_completed
			show_field(field_restore_state)
			if _transition != null:
				_transition.fade_in(0.25)
		else:
			show_title()


func save_to_slot(slot_id: int) -> bool:
	if _active_scene == null or not (_active_scene is Field):
		return false

	var field: Field = _active_scene
	var field_state := field.capture_state()
	var save := SaveData.new()
	save.slot_id = slot_id
	save.timestamp = Time.get_datetime_string_from_system()
	save.playtime_seconds = playtime_seconds
	save.location_name = "Overworld"
	save.party_leader = "Vanguard"
	save.world_state_data = world_state.to_dict()
	save.field_state_data = field_state
	return save_manager.save_slot(save) == SaveManager.Result.OK


func load_from_slot(slot_id: int) -> bool:
	var data := save_manager.load_slot(slot_id)
	if data == null:
		return false

	playtime_seconds = data.playtime_seconds
	world_state = WorldState.from_dict(data.world_state_data)
	if _transition != null:
		_transition.fade_out(0.25)
		await _transition.fade_out_completed
	show_field(data.field_state_data)
	if _transition != null:
		_transition.fade_in(0.25)
		await _transition.fade_in_completed
	return true


func _open_slot_menu(mode: SaveSlotMenu.Mode) -> void:
	if _slot_menu != null and is_instance_valid(_slot_menu):
		_slot_menu.queue_free()

	_slot_menu = SaveSlotMenu.new()
	_slot_menu.setup(save_manager.get_slot_summaries(), mode)
	_slot_menu.slot_selected.connect(_on_slot_selected, CONNECT_DEFERRED)
	_slot_menu.cancelled.connect(_close_slot_menu, CONNECT_DEFERRED)
	add_child(_slot_menu)


func _close_slot_menu() -> void:
	if _slot_menu != null and is_instance_valid(_slot_menu):
		_slot_menu.queue_free()
		_slot_menu = null


func _on_slot_selected(slot_id: int, mode: SaveSlotMenu.Mode) -> void:
	if mode == SaveSlotMenu.Mode.SAVE:
		save_to_slot(slot_id)
		_close_slot_menu()
	elif mode == SaveSlotMenu.Mode.LOAD:
		_close_slot_menu()
		load_from_slot(slot_id)


func _on_field_save_requested() -> void:
	_open_slot_menu(SaveSlotMenu.Mode.SAVE)


func _on_field_load_requested() -> void:
	_open_slot_menu(SaveSlotMenu.Mode.LOAD)


func _on_field_title_requested() -> void:
	show_title()


func _on_title_load_game() -> void:
	_open_slot_menu(SaveSlotMenu.Mode.LOAD)
