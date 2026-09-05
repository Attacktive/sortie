class_name Field
extends Node2D
signal battle_requested(battle_id: String, restore_state: Dictionary)

## The walkable world: the map, what draws it, who walks on it, and the camera that follows them.

signal save_requested
signal load_requested
signal title_requested
## Bigger than the viewport on both axes, so the camera has something to do.
const MAP := [
	"##################",
	"#....F......F....#",
	"#..#............##",
	"#..#....####.....#",
	"#.......#..#.....#",
	"#..FF...#..#..F..#",
	"#.......####.....#",
	"#....#...........#",
	"##...#....F....###",
	"#................#",
	"#..F..........FF.#",
	"##################",
]

const START_CELL := Vector2i(2, 1)
const NPC_CELL := Vector2i(5, 1)
const PLAYER_SHEET := "res://assets/lpc/units/vanguard_walkcycle.png"
const NPC_SHEET := "res://assets/lpc/units/mage_walkcycle.png"
const RODERICK_CELL := Vector2i(8, 2)
const RODERICK_SHEET := "res://assets/lpc/units/brute_walkcycle.png"
## A node's position is the top-left corner of its sprite, so a camera sitting at the player's origin centers the screen on that corner and leaves the character down and to the right of it.
const CAMERA_OFFSET := Vector2(GridGeometry.CELL_SIZE, GridGeometry.CELL_SIZE) * 0.5

var world_state: WorldState = null
var trigger_registry: TriggerRegistry = null

var _map: FieldMap = null
var _view: FieldView = null
var _player: FieldPlayer = null
var _camera: Camera2D = null
var _npc: FieldNpc = null
var _roderick: FieldNpc = null
var _dialogue_box: DialogueBox = null
var _field_menu: FieldMenu = null
var _last_player_cell: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	if world_state == null:
		world_state = WorldState.new()
	if trigger_registry == null:
		trigger_registry = TriggerRegistry.new()

	_map = FieldMap.from_ascii(PackedStringArray(MAP))

	_build_view()
	_build_npc()
	_build_roderick()
	_build_player()
	_build_camera()
	_build_dialogue_box()
	_build_triggers()

	_last_player_cell = GridGeometry.position_to_cell(FieldBody.box_for_sprite(_player.position).get_center())

	## Dev affordance for visual verification harnesses; never instantiated during normal play.
	if OS.has_environment("SORTIE_SHOT"):
		add_child(load("res://scenes/screenshot_probe.gd").new())

func _build_view() -> void:
	_view = FieldView.new()
	_view.map = _map
	add_child(_view)

## Added after the view, because siblings draw in tree order and the ground must be drawn before the characters standing on it.
func _build_npc() -> void:
	_npc = FieldNpc.new()
	_npc.name = "FieldNpc"

	var default_dialogue := DialogueTree.from_dict({
		"start": "greet",
		"nodes": {
			"greet": {
				"speaker": "Mage",
				"text": "Greetings, traveler. If you walk east past the clearing, you will feel the mountain wind.",
				"choices": [
					{ "text": "I will explore.", "next": "explore" },
					{ "text": "Who are you?", "next": "who" }
				]
			},
			"explore": {
				"speaker": "Mage",
				"text": "Watch your step along the stone ruins.",
				"next": ""
			},
			"who": {
				"speaker": "Mage",
				"text": "I watch over these ruins.",
				"next": ""
			}
		}
	})

	var post_breeze_dialogue := DialogueTree.from_dict({
		"start": "greet2",
		"nodes": {
			"greet2": {
				"speaker": "Mage",
				"text": "You felt that chill from the east, didn't you? Something stirs in the forest.",
				"next": ""
			}
		}
	})

	_npc.setup(NPC_SHEET, "Mage", default_dialogue)
	_npc.conditional_dialogues = [
		{ "condition": EventCondition.is_true("felt_breeze"), "dialogue": post_breeze_dialogue }
	]
	_npc.position = GridGeometry.cell_to_position(NPC_CELL)
	add_child(_npc)


func _build_roderick() -> void:
	_roderick = FieldNpc.new()
	_roderick.name = "SirRoderick"

	var briefing := DialogueTree.from_dict({
		"start": "briefing_dishonor",
		"nodes": {
			"briefing_dishonor": {
				"speaker": "Sir Roderick",
				"text": "Men, today Highspire faces its gravest dishonor.",
				"next": "briefing_catapult",
			},
			"briefing_catapult": {
				"speaker": "Sir Roderick",
				"text": "The enemy has assembled a catapult 80 paces out, and they are launching rotten produce into the royal herb garden.",
				"next": "briefing_sally",
			},
			"briefing_sally": {
				"speaker": "Sir Roderick",
				"text": "We sally out, dismantle the contraption, and preserve the King's rosemary!",
				"choices": [
					{"text": "[Sortie!]", "next": "action_sortie"},
					{"text": "[Prepare]", "next": "action_prepare"},
				],
			},
			"action_sortie": {
				"speaker": "Sir Roderick",
				"text": "Sound the charge!",
				"action": EventAction.start_battle("M01_CABBAGE"),
			},
			"action_prepare": {
				"speaker": "Sir Roderick",
				"text": "Hurry, Pip. Every second we tarry is another bruised turnip in His Majesty's parsley.",
			},
		},
	})

	var victory_debrief := DialogueTree.from_dict({
		"start": "post_victory",
		"nodes": {
			"post_victory": {
				"speaker": "Sir Roderick",
				"text": "Splendid work out there! The royal herb garden is safe. The scout reports the remaining cabbage hurled over the ramparts was surprisingly edible in soup.",
				"next": "post_tease",
			},
			"post_tease": {
				"speaker": "Sir Roderick",
				"text": "Catch your breath—word has it our ale shipment down south has run into trouble.",
			},
		},
	})

	_roderick.setup(RODERICK_SHEET, "Sir Roderick", briefing)
	_roderick.conditional_dialogues = [
		{
			"condition": EventCondition.is_true("mission_m01_completed"),
			"dialogue": victory_debrief,
		},
	]

	_roderick.position = GridGeometry.cell_to_position(RODERICK_CELL)
	add_child(_roderick)

func _build_player() -> void:
	_player = FieldPlayer.new()
	_player.name = "FieldPlayer"
	_player.map = _map
	_player.obstacle_provider = _get_obstacle_boxes
	_player.position = GridGeometry.cell_to_position(START_CELL)
	_player.setup(PLAYER_SHEET)
	add_child(_player)


func _get_obstacle_boxes() -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	for child in get_children():
		if child is FieldNpc:
			boxes.append(child.get_collision_box())

	return boxes







func _build_camera() -> void:
	var bounds := _map.pixel_size()

	_camera = Camera2D.new()
	_camera.position = CAMERA_OFFSET
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(bounds.x)
	_camera.limit_bottom = int(bounds.y)

	_player.add_child(_camera)
	_camera.make_current()


## Added last so dialogue UI draws above the map and characters.
func _build_dialogue_box() -> void:
	_dialogue_box = DialogueBox.new()
	_dialogue_box.name = "DialogueBox"
	_dialogue_box.finished.connect(_on_dialogue_finished)
	add_child(_dialogue_box)

func _process(_delta: float) -> void:
	if _player == null:
		return

	var current_cell := GridGeometry.position_to_cell(FieldBody.box_for_sprite(_player.position).get_center())
	if current_cell != _last_player_cell:
		_last_player_cell = current_cell
		_check_step_triggers(current_cell)

func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_box != null and _dialogue_box.visible:
		return
	if _field_menu != null and is_instance_valid(_field_menu) and _field_menu.visible:
		return

	if event.is_action_pressed("ui_accept"):
		_try_interact()
	elif event.is_action_pressed("ui_cancel"):
		_open_field_menu()
func _try_interact() -> void:
	if _player == null:
		return

	var probe := Interaction.probe_box(FieldBody.box_for_sprite(_player.position), _player.facing)

	if _npc != null and probe.intersects(_npc.get_collision_box()):
		_start_npc_dialogue(_npc)
		return

	if _roderick != null and probe.intersects(_roderick.get_collision_box()):
		_start_npc_dialogue(_roderick)
		return

	if _map != null and trigger_registry != null:
		var cells := _map.cells_in_box(probe)
		for cell in cells:
			var triggers := trigger_registry.get_triggers_at(cell, EventTrigger.TriggerType.INTERACT)
			for trig in triggers:
				if trig.can_fire(world_state):
					_execute_trigger(trig)
					return

func _check_step_triggers(cell: Vector2i) -> void:
	if trigger_registry == null or world_state == null:
		return

	var triggers := trigger_registry.get_triggers_at(cell, EventTrigger.TriggerType.STEP)
	for trig in triggers:
		if trig.can_fire(world_state):
			_execute_trigger(trig)

func _execute_trigger(trig: EventTrigger) -> void:
	trig.fired = true
	for action in trig.actions:
		_execute_action(action)

func _execute_action(action: EventAction) -> void:
	match action.type:
		EventAction.Type.SET_FLAG:
			world_state.set_flag(action.params.get("key"), action.params.get("value"))
		EventAction.Type.SHOW_DIALOGUE:
			var tree: DialogueTree = action.params.get("dialogue")
			if tree != null:
				_player.frozen = true
				_dialogue_box.start(DialogueRunner.new(tree, world_state))
		EventAction.Type.MODIFY_TILE:
			var cell: Vector2i = action.params.get("cell", Vector2i(-1, -1))
			var glyph: String = action.params.get("glyph", "")
			if _map != null and _map.is_in_bounds(cell):
				_map.set_glyph(cell, glyph)
				if _view != null:
					_view.refresh()
		EventAction.Type.START_BATTLE:
			var battle_id: String = action.params.get("battle_id", "default")
			if _player != null:
				_player.frozen = true
			var restore_state := {
				"cell": GridGeometry.position_to_cell(FieldBody.box_for_sprite(_player.position).get_center()),
				"facing": _player.facing,
			}
			battle_requested.emit(battle_id, restore_state)

func _start_npc_dialogue(npc: FieldNpc) -> void:
	_player.frozen = true
	npc.face_toward(_player.position)

	var dialogue_tree := npc.get_dialogue_for_state(world_state)
	var runner := DialogueRunner.new(dialogue_tree, world_state)
	_dialogue_box.start(runner)

func _on_dialogue_finished() -> void:
	if _player != null:
		_player.frozen = false

	if _dialogue_box != null:
		var last: DialogueNode = _dialogue_box.get_last_node()
		if last != null and last.action != null:
			_execute_action(last.action)

func get_map() -> FieldMap:
	return _map


func get_field_menu() -> FieldMenu:
	return _field_menu


func _open_field_menu() -> void:
	if _field_menu != null and is_instance_valid(_field_menu):
		return

	if _player != null:
		_player.frozen = true

	_field_menu = FieldMenu.new()
	_field_menu.save_requested.connect(_on_field_menu_save)
	_field_menu.load_requested.connect(_on_field_menu_load)
	_field_menu.title_requested.connect(_on_field_menu_title)
	_field_menu.resume_requested.connect(_close_field_menu)
	add_child(_field_menu)


func _close_field_menu() -> void:
	if _field_menu != null and is_instance_valid(_field_menu):
		_field_menu.queue_free()
		_field_menu = null

	if _player != null:
		_player.frozen = false


func _on_field_menu_save() -> void:
	save_requested.emit()


func _on_field_menu_load() -> void:
	load_requested.emit()


func _on_field_menu_title() -> void:
	title_requested.emit()


## Captures field state snapshot (player cell, facing, modified tiles) for save/load.
func capture_state() -> Dictionary:
	var modified_tiles: Dictionary = {}
	if _map != null:
		modified_tiles = _map.get_modified_tiles()

	var cell := START_CELL
	var facing := Facing.Direction.DOWN
	if _player != null:
		cell = GridGeometry.position_to_cell(_player.position)
		facing = _player.facing

	return {
		"cell": cell,
		"facing": facing,
		"modified_tiles": modified_tiles,
	}


## Restores player position and facing direction when returning from battle or loading.
func restore(restore_state: Dictionary) -> void:
	if _player == null or restore_state.is_empty():
		return

	var cell: Vector2i = restore_state.get("cell", START_CELL)
	_player.position = GridGeometry.cell_to_position(cell)
	_player.facing = restore_state.get("facing", Facing.Direction.DOWN)
	_player.frozen = false
	_last_player_cell = cell

	var modified_tiles: Dictionary = restore_state.get("modified_tiles", {})
	if _map != null and not modified_tiles.is_empty():
		for mod_cell in modified_tiles:
			var target_cell: Vector2i = Vector2i.ZERO
			if mod_cell is Vector2i:
				target_cell = mod_cell
			elif mod_cell is Array and mod_cell.size() >= 2:
				target_cell = Vector2i(int(mod_cell[0]), int(mod_cell[1]))
			elif mod_cell is String:
				var str_cell: String = mod_cell
				var parts := str_cell.replace("(", "").replace(")", "").split(",")
				if parts.size() >= 2:
					target_cell = Vector2i(int(parts[0]), int(parts[1]))
			_map.set_glyph(target_cell, str(modified_tiles[mod_cell]))
		if _view != null:
			_view.refresh()

	if _camera != null and _map != null:
		var bounds := _map.pixel_size()
		_camera.limit_left = 0
		_camera.limit_top = 0
		_camera.limit_right = int(bounds.x)
		_camera.limit_bottom = int(bounds.y)
		_camera.position = CAMERA_OFFSET
		_camera.reset_smoothing()
func _build_triggers() -> void:
	var step_dialogue := DialogueTree.from_dict({
		"start": "breeze",
		"nodes": {
			"breeze": {
				"speaker": "World",
				"text": "A cold mountain breeze rustles the trees to the east.",
				"next": ""
			}
		}
	})

	var flag_action := EventAction.set_flag("felt_breeze", true)
	var dialogue_action := EventAction.show_dialogue(step_dialogue)
	var step_trig := EventTrigger.new(
		EventTrigger.TriggerType.STEP,
		Vector2i(8, 1),
		EventCondition.is_false("felt_breeze"),
		[flag_action, dialogue_action],
		true
	)
	trigger_registry.register_trigger(step_trig)
