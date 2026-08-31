class_name DialogueBox
extends CanvasLayer

## Presentation layer rendering speaker, text, and selectable choices.

signal finished
signal choice_selected(index: int)

var _runner: DialogueRunner = null
var _selected_choice: int = 0

var _panel: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _choices_container: VBoxContainer
var _choice_labels: Array[Label] = []

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.05
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.68
	_panel.anchor_bottom = 0.95
	add_child(_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	_panel.add_child(layout)

	_speaker_label = Label.new()
	_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	layout.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_text_label)

	_choices_container = VBoxContainer.new()
	layout.add_child(_choices_container)

func start(runner: DialogueRunner) -> void:
	_runner = runner
	_selected_choice = 0
	visible = true
	_refresh()

func _refresh() -> void:
	if _runner == null or _runner.is_finished():
		visible = false
		finished.emit()
		return

	var node := _runner.current_node()
	if node == null:
		visible = false
		finished.emit()
		return

	_speaker_label.text = node.speaker
	_text_label.text = node.text
	_clear_choices()

	if node.has_choices():
		_selected_choice = clampi(_selected_choice, 0, node.choices.size() - 1)
		for i in node.choices.size():
			var choice := node.choices[i]
			var label := Label.new()
			var prefix := " > " if i == _selected_choice else "   "
			label.text = prefix + choice.text
			_choices_container.add_child(label)
			_choice_labels.append(label)

func _clear_choices() -> void:
	for child in _choices_container.get_children():
		child.queue_free()
	_choice_labels.clear()

func handle_input_action(action: String) -> void:
	if not visible or _runner == null:
		return

	var node := _runner.current_node()
	if node == null:
		return

	if node.has_choices():
		if action == "ui_down":
			_selected_choice = (_selected_choice + 1) % node.choices.size()
			_update_choice_highlight()
		elif action == "ui_up":
			_selected_choice = (_selected_choice - 1 + node.choices.size()) % node.choices.size()
			_update_choice_highlight()
		elif action == "ui_accept":
			var idx := _selected_choice
			_runner.select_choice(idx)
			choice_selected.emit(idx)
			_selected_choice = 0
			_refresh()
	else:
		if action == "ui_accept":
			_runner.advance()
			_refresh()

func _update_choice_highlight() -> void:
	var node := _runner.current_node()
	if node == null or not node.has_choices():
		return

	for i in _choice_labels.size():
		var choice := node.choices[i]
		var prefix := " > " if i == _selected_choice else "   "
		_choice_labels[i].text = prefix + choice.text

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
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

func get_speaker() -> String:
	return _speaker_label.text

func get_text() -> String:
	return _text_label.text

func get_choice_count() -> int:
	return _choice_labels.size()

func get_selected_choice_index() -> int:
	return _selected_choice
