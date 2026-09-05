class_name SaveSlotMenu
extends CanvasLayer

## Reusable 10-slot selector overlay for saving and loading game progress.
## Handles keyboard navigation, playtime formatting, and overwrite confirmations.

enum Mode { SAVE, LOAD }

signal slot_selected(slot_id: int, mode: Mode)
signal cancelled

const TITLE_FONT_SIZE := 24
const PROMPT_FONT_SIZE := 14
const OPTION_FONT_SIZE := 14

const TITLE_COLOR := Color(1.0, 0.85, 0.3)
const PROMPT_COLOR := Color(0.85, 0.6, 0.4)
const UNSELECTED_COLOR := Color(0.75, 0.8, 0.85)
const SELECTED_COLOR := Color(1.0, 0.9, 0.5)
const DISABLED_COLOR := Color(0.4, 0.4, 0.4)

const CURSOR_PREFIX := " > "
const INDENT_PREFIX := "   "

var mode: Mode = Mode.SAVE
var selected_index: int = 0

var _summaries: Array[Dictionary] = []
var _confirming_overwrite: bool = false

var _title_label: Label = null
var _prompt_label: Label = null
var _slot_labels: Array[Label] = []


func _ready() -> void:
	layer = 60
	_build_ui()


func setup(summaries: Array[Dictionary], initial_mode: Mode) -> void:
	_summaries = summaries.duplicate(true)
	mode = initial_mode
	selected_index = 0
	_confirming_overwrite = false
	_refresh_display()


func get_slot_count() -> int:
	return _slot_labels.size()


func get_slot_label_text(index: int) -> String:
	if index < 0 or index >= _slot_labels.size():
		return ""
	return _slot_labels[index].text


func is_confirming_overwrite() -> bool:
	return _confirming_overwrite


func handle_input_action(action: String) -> void:
	if _confirming_overwrite:
		if action == "ui_accept":
			_confirming_overwrite = false
			slot_selected.emit(selected_index + 1, mode)
		elif action == "ui_cancel":
			_confirming_overwrite = false
			_refresh_display()
		return

	if action == "ui_up":
		if _summaries.is_empty():
			return
		selected_index = (selected_index - 1 + _summaries.size()) % _summaries.size()
		_refresh_display()
	elif action == "ui_down":
		if _summaries.is_empty():
			return
		selected_index = (selected_index + 1) % _summaries.size()
		_refresh_display()
	elif action == "ui_accept":
		_on_slot_activated()
	elif action == "ui_cancel":
		cancelled.emit()


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


func _on_slot_activated() -> void:
	if selected_index < 0 or selected_index >= _summaries.size():
		return

	var summary: Dictionary = _summaries[selected_index]
	var is_empty: bool = summary.get("is_empty", true)

	if mode == Mode.LOAD:
		if is_empty:
			return
		slot_selected.emit(selected_index + 1, mode)
	elif mode == Mode.SAVE:
		if not is_empty:
			_confirming_overwrite = true
			_refresh_display()
		else:
			slot_selected.emit(selected_index + 1, mode)


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.05, 0.08, 0.85)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_box := VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 12)
	main_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(main_box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	main_box.add_child(_title_label)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", PROMPT_FONT_SIZE)
	_prompt_label.add_theme_color_override("font_color", PROMPT_COLOR)
	main_box.add_child(_prompt_label)

	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 6)
	main_box.add_child(list_box)

	_slot_labels.clear()
	for i in range(1, 11):
		var label := Label.new()
		label.add_theme_font_size_override("font_size", OPTION_FONT_SIZE)
		list_box.add_child(label)
		_slot_labels.append(label)

	_refresh_display()


func _refresh_display() -> void:
	if _title_label == null:
		return

	if mode == Mode.SAVE:
		_title_label.text = "SAVE GAME"
	else:
		_title_label.text = "LOAD GAME"

	if _confirming_overwrite:
		_prompt_label.text = "Overwrite Slot %02d? (Enter: Yes / Escape: No)" % (selected_index + 1)
	else:
		_prompt_label.text = "Select a slot"

	for i in _slot_labels.size():
		var label: Label = _slot_labels[i]
		var is_selected := (i == selected_index)
		var prefix := CURSOR_PREFIX if is_selected else INDENT_PREFIX
		var text := ""

		var summary := {}
		if i < _summaries.size():
			summary = _summaries[i]

		var is_empty: bool = summary.get("is_empty", true)
		if is_empty:
			text = prefix + "Slot %02d: [Empty]" % (i + 1)
			if mode == Mode.LOAD:
				label.add_theme_color_override("font_color", DISABLED_COLOR)
			else:
				label.add_theme_color_override("font_color", SELECTED_COLOR if is_selected else UNSELECTED_COLOR)
		else:
			var loc: String = summary.get("location_name", "Unknown")
			var playtime: float = summary.get("playtime_seconds", 0.0)
			var time_str: String = format_playtime(playtime)
			var date_str: String = summary.get("timestamp", "")
			text = prefix + "Slot %02d: %s — %s — %s" % [i + 1, loc, time_str, date_str]
			label.add_theme_color_override("font_color", SELECTED_COLOR if is_selected else UNSELECTED_COLOR)

		label.text = text


static func format_playtime(total_seconds: float) -> String:
	var secs := int(total_seconds)
	var hours := secs / 3600
	var minutes := (secs % 3600) / 60
	var seconds := secs % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]
