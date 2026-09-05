class_name TitleMenu
extends CenterContainer

## Keyboard-navigable title menu offering New Game, Quick Battle, and Quit.
## Emits request signals on selection, leaving scene swaps to the coordinator.

signal new_game_requested
signal quick_battle_requested
signal quit_requested

const TITLE_FONT_SIZE := 48
const OPTION_FONT_SIZE := 18

const TITLE_COLOR := Color(1.0, 0.85, 0.3)
const UNSELECTED_COLOR := Color(0.75, 0.8, 0.85)
const SELECTED_COLOR := Color(1.0, 0.9, 0.5)

const CURSOR_PREFIX := " > "
const INDENT_PREFIX := "   "

const OPTIONS := [
	"New Game",
	"Quick Battle",
	"Quit"
]

var _selected_index: int = 0
var _labels: Array[Label] = []

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 36)
	root_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(root_box)

	var title_label := Label.new()
	title_label.text = "SORTIE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title_label.add_theme_color_override("font_color", TITLE_COLOR)
	root_box.add_child(title_label)

	var menu_box := VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 10)
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_box.add_child(menu_box)

	_labels.clear()
	for i in OPTIONS.size():
		var label := Label.new()
		label.add_theme_font_size_override("font_size", OPTION_FONT_SIZE)
		_style_option(label, i == _selected_index, OPTIONS[i])
		menu_box.add_child(label)
		_labels.append(label)

func get_option_count() -> int:
	return _labels.size()

func get_selected_index() -> int:
	return _selected_index

func handle_input_action(action: String) -> void:
	if action == "ui_down":
		_selected_index = (_selected_index + 1) % OPTIONS.size()
		_refresh_highlight()
	elif action == "ui_up":
		_selected_index = (_selected_index - 1 + OPTIONS.size()) % OPTIONS.size()
		_refresh_highlight()
	elif action == "ui_accept":
		_activate_selection()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event.is_action_pressed("ui_down"):
		handle_input_action("ui_down")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		handle_input_action("ui_up")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		handle_input_action("ui_accept")
		get_viewport().set_input_as_handled()

func _refresh_highlight() -> void:
	for i in _labels.size():
		_style_option(_labels[i], i == _selected_index, OPTIONS[i])

func _style_option(label: Label, is_selected: bool, text: String) -> void:
	if is_selected:
		label.text = CURSOR_PREFIX + text
		label.add_theme_color_override("font_color", SELECTED_COLOR)
	else:
		label.text = INDENT_PREFIX + text
		label.add_theme_color_override("font_color", UNSELECTED_COLOR)

func _activate_selection() -> void:
	match _selected_index:
		0:
			new_game_requested.emit()
		1:
			quick_battle_requested.emit()
		2:
			quit_requested.emit()
