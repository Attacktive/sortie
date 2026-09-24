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
const BARNABY_CELL := Vector2i(5, 1)
const PLAYER_SHEET := "res://assets/lpc/units/vanguard_walkcycle.png"
const BARNABY_SHEET := "res://assets/lpc/units/mage_walkcycle.png"
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
var _npcs: Array[FieldNpc] = []
var _dialogue_box: DialogueBox = null
var _field_menu: FieldMenu = null
var _last_player_cell: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	y_sort_enabled = true

	if world_state == null:
		world_state = WorldState.new()
	if trigger_registry == null:
		trigger_registry = TriggerRegistry.new()

	_map = FieldMap.from_ascii(PackedStringArray(MAP))

	_build_view()
	_build_barnaby()
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
func _build_barnaby() -> void:
	var barnaby := FieldNpc.new()
	barnaby.name = "Barnaby"

	var barnaby_dialogue := DialogueTree.from_dict({
		"start": "barnaby_pressure",
		"nodes": {
			"barnaby_pressure": {
				"speaker": "Barnaby",
				"text": "The barometric pressure is plummeting, which is dreadful for my arthritis.",
				"next": "barnaby_scry",
			},
			"barnaby_scry": {
				"speaker": "Barnaby",
				"text": "I am attempting to scry the kingdom's weather, if this infernal siege would just quiet down.",
				"next": "barnaby_eastern_wind",
			},
			"barnaby_eastern_wind": {
				"speaker": "Barnaby",
				"text": "The eastern wind brings the scent of treason, and lightly toasted garlic.",
			},
		},
	})

	barnaby.setup(BARNABY_SHEET, "Barnaby", barnaby_dialogue)
	barnaby.position = GridGeometry.cell_to_position(BARNABY_CELL)
	register_npc(barnaby)

func _build_roderick() -> void:
	var roderick := FieldNpc.new()
	roderick.name = "SirRoderick"

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

	var m02_briefing := DialogueTree.from_dict({
		"start": "m02_briefing_ale",
		"nodes": {
			"m02_briefing_ale": {
				"speaker": "Sir Roderick",
				"text": "Splendid work out there! The royal herb garden is safe. The scout reports the remaining cabbage hurled over the ramparts was surprisingly edible in soup.",
				"next": "m02_briefing_shipment",
			},
			"m02_briefing_shipment": {
				"speaker": "Sir Roderick",
				"text": "Catch your breath—word has it our ale shipment down south has run into trouble.",
				"next": "m02_briefing_morale",
			},
			"m02_briefing_morale": {
				"speaker": "Sir Roderick",
				"text": "A kingdom cannot march on parched throats. The morale of the entire garrison is at stake!",
				"next": "m02_briefing_sortie",
			},
			"m02_briefing_sortie": {
				"speaker": "Sir Roderick",
				"text": "Sortie immediately and retrieve those barrels.",
				"choices": [
					{"text": "[Sortie!]", "next": "m02_action_sortie"},
					{"text": "[Prepare]", "next": "m02_action_prepare"},
				],
			},
			"m02_action_sortie": {
				"speaker": "Sir Roderick",
				"text": "Sound the charge!",
				"action": EventAction.start_battle("M02_ALE_RUN"),
			},
			"m02_action_prepare": {
				"speaker": "Sir Roderick",
				"text": "Hurry, Pip. A warm stout is a crime against the crown.",
			},
		},
	})

	var m03_briefing := DialogueTree.from_dict({
		"start": "m03_briefing_cutlery",
		"nodes": {
			"m03_briefing_cutlery": {
				"speaker": "Sir Roderick",
				"text": "The ale flows, and morale is secure. However, a tragedy has struck the royal scullery!",
				"next": "m03_briefing_line",
			},
			"m03_briefing_line": {
				"speaker": "Sir Roderick",
				"text": "Men, the Gastronomic Brotherhood has crossed a line that cannot be uncrossed.",
				"next": "m03_briefing_malakor",
			},
			"m03_briefing_malakor": {
				"speaker": "Sir Roderick",
				"text": "Their leader, General Malakor, personally ordered the theft of the royal dining forks.",
				"next": "m03_briefing_sortie",
			},
			"m03_briefing_sortie": {
				"speaker": "Sir Roderick",
				"text": "How is the King expected to enjoy his evening roast? With his hands? Sortie and recover the silver!",
				"choices": [
					{"text": "[Sortie!]", "next": "m03_action_sortie"},
					{"text": "[Prepare]", "next": "m03_action_prepare"},
				],
			},
			"m03_action_sortie": {
				"speaker": "Sir Roderick",
				"text": "Sound the charge!",
				"action": EventAction.start_battle("M03_SILVER_SPOONS"),
			},
			"m03_action_prepare": {
				"speaker": "Sir Roderick",
				"text": "Hurry, Pip. Every second we tarry is another scratch on the royal silver.",
			},
		},
	})

	var m04_briefing := DialogueTree.from_dict({
		"start": "m04_briefing_oven",
		"nodes": {
			"m04_briefing_oven": {
				"speaker": "Sir Roderick",
				"text": "The forks are polished and returned to their velvet case. But smell the air, Pip!",
				"next": "m04_briefing_enemy_oven",
			},
			"m04_briefing_enemy_oven": {
				"speaker": "Sir Roderick",
				"text": "The enemy has erected a tactical field oven just beyond the perimeter.",
				"next": "m04_briefing_yeast",
			},
			"m04_briefing_yeast": {
				"speaker": "Sir Roderick",
				"text": "The sheer volume of their yeast production threatens to overshadow the King's pastry monopoly.",
				"next": "m04_briefing_sortie",
			},
			"m04_briefing_sortie": {
				"speaker": "Sir Roderick",
				"text": "Sortie to the ridge and dismantle that blasphemous bakery!",
				"choices": [
					{"text": "[Sortie!]", "next": "m04_action_sortie"},
					{"text": "[Prepare]", "next": "m04_action_prepare"},
				],
			},
			"m04_action_sortie": {
				"speaker": "Sir Roderick",
				"text": "Sound the charge!",
				"action": EventAction.start_battle("M04_FIELD_OVEN"),
			},
			"m04_action_prepare": {
				"speaker": "Sir Roderick",
				"text": "Hurry, Pip. If their croissants finish baking, Highspire is doomed.",
			},
		},
	})

	var m05_briefing := DialogueTree.from_dict({
		"start": "m05_briefing_paprika",
		"nodes": {
			"m05_briefing_paprika": {
				"speaker": "Sir Roderick",
				"text": "The rogue oven is cold, and the King's pastry monopoly is safe.",
				"next": "m05_briefing_malakor",
			},
			"m05_briefing_malakor": {
				"speaker": "Sir Roderick",
				"text": "But General Malakor himself is massing forces to breach the royal paprika reserves!",
				"next": "m05_briefing_recipe",
			},
			"m05_briefing_recipe": {
				"speaker": "Sir Roderick",
				"text": "If he breaches the doors and takes the paprika, the Rosemary Mutton recipe is compromised.",
				"next": "m05_briefing_sortie",
			},
			"m05_briefing_sortie": {
				"speaker": "Sir Roderick",
				"text": "Sortie out there and end this culinary nightmare once and for all!",
				"choices": [
					{"text": "[Sortie!]", "next": "m05_action_sortie"},
					{"text": "[Prepare]", "next": "m05_action_prepare"},
				],
			},
			"m05_action_sortie": {
				"speaker": "Sir Roderick",
				"text": "Sound the charge!",
				"action": EventAction.start_battle("M05_SPICE_WARS"),
			},
			"m05_action_prepare": {
				"speaker": "Sir Roderick",
				"text": "Hurry, Pip. The fate of the kingdom's flavor rests on your shoulders.",
			},
		},
	})

	var terminal_dialogue := DialogueTree.from_dict({
		"start": "terminal_paprika_safe",
		"nodes": {
			"terminal_paprika_safe": {
				"speaker": "Sir Roderick",
				"text": "The paprika is safe, and Malakor has been routed! You have saved the realm's palate!",
				"next": "terminal_feast",
			},
			"terminal_feast": {
				"speaker": "Sir Roderick",
				"text": "Tonight, Highspire feasts in total victory. Dismissed, men!",
			},
		},
	})

	roderick.setup(RODERICK_SHEET, "Sir Roderick", briefing)
	roderick.conditional_dialogues = [
		{
			"condition": EventCondition.is_true("mission_m05_completed"),
			"dialogue": terminal_dialogue,
		},
		{
			"condition": EventCondition.is_true("mission_m04_completed"),
			"dialogue": m05_briefing,
		},
		{
			"condition": EventCondition.is_true("mission_m03_completed"),
			"dialogue": m04_briefing,
		},
		{
			"condition": EventCondition.is_true("mission_m02_completed"),
			"dialogue": m03_briefing,
		},
		{
			"condition": EventCondition.is_true("mission_m01_completed"),
			"dialogue": m02_briefing,
		},
	]

	roderick.position = GridGeometry.cell_to_position(RODERICK_CELL)
	register_npc(roderick)

func _build_player() -> void:
	_player = FieldPlayer.new()
	_player.name = "FieldPlayer"
	_player.map = _map
	_player.obstacle_provider = _get_obstacle_boxes
	_player.position = GridGeometry.cell_to_position(START_CELL)
	_player.setup(PLAYER_SHEET)
	add_child(_player)


func register_npc(npc: FieldNpc) -> void:
	if npc == null or _npcs.has(npc):
		return

	var parent := npc.get_parent()
	if parent != null and parent != self:
		push_error("Field NPC %s already belongs to another parent" % npc.name)
		return

	_npcs.append(npc)
	if parent == null:
		add_child(npc)
		if _player != null:
			move_child(npc, _player.get_index())

	npc.tree_exiting.connect(_unregister_npc.bind(npc), CONNECT_ONE_SHOT)


func get_npc(npc_name: String) -> FieldNpc:
	for npc in _npcs:
		if is_instance_valid(npc) and npc.npc_name == npc_name:
			return npc

	return null


func _unregister_npc(npc: FieldNpc) -> void:
	_npcs.erase(npc)


func _get_obstacle_boxes() -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	for npc in _npcs:
		if is_instance_valid(npc):
			boxes.append(npc.get_collision_box())

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

	for npc in _npcs:
		if is_instance_valid(npc) and probe.intersects(npc.get_collision_box()):
			_start_npc_dialogue(npc)
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
