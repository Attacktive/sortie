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

var _map: FieldMap = null
var _view: FieldView = null
var _player: FieldPlayer = null
var _camera: Camera2D = null
var _npc: FieldNpc = null
var _dialogue_box: DialogueBox = null

func _ready() -> void:
	_map = FieldMap.from_ascii(PackedStringArray(MAP))

	_build_view()
	_build_npc()
	_build_player()
	_build_camera()
	_build_dialogue_box()

	if OS.has_environment("SORTIE_SHOT"):
		add_child(load("res://scenes/screenshot_probe.gd").new())

func _build_view() -> void:
	_view = FieldView.new()
	_view.map = _map
	add_child(_view)

func _build_npc() -> void:
	_npc = FieldNpc.new()
	_npc.name = "FieldNpc"

	var dialogue := DialogueTree.from_dict({
		"start": "greet",
		"nodes": {
			"greet": {
				"speaker": "Mage",
				"text": "Greetings, traveler. Keep your blade sharp.",
				"next": ""
			}
		}
	})

	_npc.setup(NPC_SHEET, "Mage", dialogue)
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

func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_box != null and _dialogue_box.visible:
		return

	if event.is_action_pressed("ui_accept"):
		_try_interact()

func _try_interact() -> void:
	if _player == null or _npc == null:
		return

	var probe := Interaction.probe_box(FieldBody.box_for_sprite(_player.position), _player.facing)
	if probe.intersects(_npc.get_collision_box()):
		_start_npc_dialogue(_npc)

func _start_npc_dialogue(npc: FieldNpc) -> void:
	_player.frozen = true
	npc.face_toward(_player.position)

	var runner := DialogueRunner.new(npc.dialogue)
	_dialogue_box.start(runner)

func _on_dialogue_finished() -> void:
	if _player != null:
		_player.frozen = false
