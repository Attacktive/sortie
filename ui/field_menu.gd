class_name FieldMenu
extends CanvasLayer

## In-game field pause system menu.
## Provides access to Save, Load, Title, and Resume options while walking the field.

signal save_requested
signal load_requested
signal title_requested
signal resume_requested

const TITLE_FONT_SIZE := 20
const OPTION_FONT_SIZE := 16

const TITLE_COLOR := Color(1.0, 0.85, 0.3)
const UNSELECTED_COLOR := Color(0.75, 0.8, 0.85)
const SELECTED_COLOR := Color(1.0, 0.9, 0.5)

const CURSOR_PREFIX := " > "
const INDENT_PREFIX := "   "

const OPTIONS := [
	"Save",
	"Load",
	"Title",
	"Resume"
]

var selected_index: int = 0
var _labels: Array[Label] = []


func _ready() -> void:
	layer = 55
	_build_ui()


func get_option_count() -> int:
	return _labels.size()


func get_option_text(index: int) -> String:
	if index < 0 or index >= _labels.size():
		return ""
	return _labels[index].text


func handle_input_action(action: String) -> void:
	if action == "ui_up":
		selected_index = (selected_index - 1 + OPTIONS.size()) % OPTIONS.size()
		_refresh_display()
	elif action == "ui_down":
		selected_index = (selected_index + 1) % OPTIONS.size()
		_refresh_display()
	elif action == "ui_accept":
		_activate_option()
	elif action == "ui_cancel":
		resume_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	var action := ""
	if event.is_action_pressed("ui_up"):
		action = "ui_up"
	elif event.is_action_pressed("ui_down"):
		action = "ui_down"
	elif event.is_action_pressed("ui_accept"):
		action = "ui_accept"
	elif event.is_action_pressed("ui_cancel"):
		action = "ui_cancel"

	if not action.is_empty():
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()

		handle_input_action(action)


func _activate_option() -> void:
	match selected_index:
		0:
			save_requested.emit()
		1:
			load_requested.emit()
		2:
			title_requested.emit()
		3:
			resume_requested.emit()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.05, 0.08, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.35, 0.4, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 32.0
	style.content_margin_right = 32.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	var title := Label.new()
	title.text = "SYSTEM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	box.add_child(title)

	var menu_box := VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 8)
	box.add_child(menu_box)

	_labels.clear()
	for i in OPTIONS.size():
		var label := Label.new()
		label.add_theme_font_size_override("font_size", OPTION_FONT_SIZE)
		menu_box.add_child(label)
		_labels.append(label)

	_refresh_display()


func _refresh_display() -> void:
	for i in _labels.size():
		var label: Label = _labels[i]
		var is_selected := (i == selected_index)
		var prefix := CURSOR_PREFIX if is_selected else INDENT_PREFIX
		label.text = prefix + OPTIONS[i]
		label.add_theme_color_override("font_color", SELECTED_COLOR if is_selected else UNSELECTED_COLOR)
