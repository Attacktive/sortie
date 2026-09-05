class_name DialogueBox
extends CanvasLayer

## Full-width dialogue overlay anchored to the bottom of the viewport.
## Consumes UI accept and directional navigation while visible, restoring field input only once dialogue finishes.

signal finished
signal choice_selected(index: int)

const SPEAKER_FONT_SIZE := 16

## The choices deliberately match the body text rather than sitting a size below it, so a choice reads as part of the page it is on rather than as a control bolted underneath.
const BODY_FONT_SIZE := 15

const SPEAKER_COLOR := Color(1.0, 0.85, 0.3)
const CHOICE_COLOR := Color(0.75, 0.8, 0.85)
const SELECTED_CHOICE_COLOR := Color(1.0, 0.9, 0.5)

## Both three characters wide, so every choice's text starts at the same x and the cursor moving down the list does not shove the lines sideways.
const CHOICE_CURSOR := " > "
const CHOICE_INDENT := "   "

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

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.12, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(0.35, 0.4, 0.5, 0.95)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18.0
	style.content_margin_top = 14.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	_panel.add_child(layout)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", SPEAKER_FONT_SIZE)
	_speaker_label.add_theme_color_override("font_color", SPEAKER_COLOR)
	layout.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_text_label)

	_choices_container = VBoxContainer.new()
	_choices_container.add_theme_constant_override("separation", 4)
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

	var choices := _runner.get_available_choices()
	if not choices.is_empty():
		_selected_choice = clampi(_selected_choice, 0, choices.size() - 1)
		for i in choices.size():
			var label := Label.new()
			label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
			_style_choice(label, choices[i], i == _selected_choice)

			_choices_container.add_child(label)
			_choice_labels.append(label)
## Removed before being freed, because a queue_free'd node stays in the tree until the end of the frame and the replacements go in during this one: freeing alone lays out both pages' choices at once.
func _clear_choices() -> void:
	for child in _choices_container.get_children():
		_choices_container.remove_child(child)
		child.queue_free()

	_choice_labels.clear()

func handle_input_action(action: String) -> void:
	if not visible or _runner == null:
		return

	var node := _runner.current_node()
	if node == null:
		return

	var choices := _runner.get_available_choices()
	if not choices.is_empty():
		if action == "ui_down":
			_selected_choice = (_selected_choice + 1) % choices.size()
			_update_choice_highlight()
		elif action == "ui_up":
			_selected_choice = (_selected_choice - 1 + choices.size()) % choices.size()
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
	if _runner == null:
		return

	var choices := _runner.get_available_choices()
	if choices.is_empty():
		return

	for i in _choice_labels.size():
		_style_choice(_choice_labels[i], choices[i], i == _selected_choice)

## The one place a choice's cursor and color are decided, called both when the list is built and when the selection moves through it.
func _style_choice(label: Label, choice: DialogueChoice, is_selected: bool) -> void:
	if is_selected:
		label.text = CHOICE_CURSOR + choice.text
		label.add_theme_color_override("font_color", SELECTED_CHOICE_COLOR)
		return

	label.text = CHOICE_INDENT + choice.text
	label.add_theme_color_override("font_color", CHOICE_COLOR)

## Marks accepted and directional inputs as handled while active, preventing field movement or interactions underneath.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	var action := ""
	if event.is_action_pressed("ui_down"):
		action = "ui_down"
	elif event.is_action_pressed("ui_up"):
		action = "ui_up"
	elif event.is_action_pressed("ui_accept"):
		action = "ui_accept"

	if not action.is_empty():
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()

		handle_input_action(action)

func get_speaker() -> String:
	return _speaker_label.text

func get_text() -> String:
	return _text_label.text

func get_choice_count() -> int:
	return _choice_labels.size()

func get_selected_choice_index() -> int:
	return _selected_choice


func get_last_node() -> DialogueNode:
	if _runner == null:
		return null

	return _runner.last_node
