class_name Field
extends Node2D

## The walkable world: the map, what draws it, who walks on it, and the camera that follows them.

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

const CAMERA_OFFSET := Vector2(GridGeometry.CELL_SIZE, GridGeometry.CELL_SIZE) * 0.5

var world_state: WorldState = null
var trigger_registry: TriggerRegistry = null

var _map: FieldMap = null
var _view: FieldView = null
var _player: FieldPlayer = null
var _camera: Camera2D = null
var _npc: FieldNpc = null
var _dialogue_box: DialogueBox = null
var _last_player_cell: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	world_state = WorldState.new()
	trigger_registry = TriggerRegistry.new()

	_map = FieldMap.from_ascii(PackedStringArray(MAP))

	_build_view()
	_build_npc()
	_build_player()
	_build_camera()
	_build_dialogue_box()
	_build_triggers()
	_last_player_cell = GridGeometry.position_to_cell(_player.position + FieldBody.BOX_OFFSET)

	if OS.has_environment("SORTIE_SHOT"):
		add_child(load("res://scenes/screenshot_probe.gd").new())

func _build_view() -> void:
	_view = FieldView.new()
	_view.map = _map
	add_child(_view)

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

func _build_player() -> void:
	_player = FieldPlayer.new()
	_player.name = "FieldPlayer"
	_player.map = _map
	_player.position = GridGeometry.cell_to_position(START_CELL)
	_player.setup(PLAYER_SHEET)
	add_child(_player)

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

func _build_dialogue_box() -> void:
	_dialogue_box = DialogueBox.new()
	_dialogue_box.name = "DialogueBox"
	_dialogue_box.finished.connect(_on_dialogue_finished)
	add_child(_dialogue_box)

func _process(_delta: float) -> void:
	if _player == null:
		return

	var current_cell := GridGeometry.position_to_cell(_player.position + FieldBody.BOX_OFFSET)
	if current_cell != _last_player_cell:
		_last_player_cell = current_cell
		_check_step_triggers(current_cell)

func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_box != null and _dialogue_box.visible:
		return

	if event.is_action_pressed("ui_accept"):
		_try_interact()

func _try_interact() -> void:
	if _player == null:
		return

	var probe := Interaction.probe_box(FieldBody.box_for_sprite(_player.position), _player.facing)

	if _npc != null and probe.intersects(_npc.get_collision_box()):
		_start_npc_dialogue(_npc)
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
				_dialogue_box.start(DialogueRunner.new(tree))
		EventAction.Type.MODIFY_TILE:
			var cell: Vector2i = action.params.get("cell", Vector2i(-1, -1))
			var glyph: String = action.params.get("glyph", "")
			if _map != null and _map.is_in_bounds(cell):
				_map.set_glyph(cell, glyph)
				if _view != null:
					_view.refresh()

func _start_npc_dialogue(npc: FieldNpc) -> void:
	_player.frozen = true
	npc.face_toward(_player.position)

	var dialogue_tree := npc.get_dialogue_for_state(world_state)
	var runner := DialogueRunner.new(dialogue_tree)
	_dialogue_box.start(runner)

func _on_dialogue_finished() -> void:
	if _player != null:
		_player.frozen = false

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
