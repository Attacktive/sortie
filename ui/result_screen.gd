class_name ResultScreen
extends CenterContainer

## End-of-battle result overlay presenting Victory or Defeat.
## Offers Continue upon victory, or Retry and Return to Title upon defeat.

signal continue_requested
signal retry_requested
signal title_requested
signal restart_requested

var _box: VBoxContainer
var _label: Label
var _buttons_box: VBoxContainer

func _ready() -> void:
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 24)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_box)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 48)
	_box.add_child(_label)

	_buttons_box = VBoxContainer.new()
	_buttons_box.add_theme_constant_override("separation", 12)
	_buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(_buttons_box)

	hide()

func show_result(victory: bool) -> void:
	if _buttons_box == null:
		return

	for child in _buttons_box.get_children():
		_buttons_box.remove_child(child)
		child.queue_free()

	if victory:
		_label.text = "Victory"
		_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

		var btn_continue := Button.new()
		btn_continue.text = "Continue"
		btn_continue.pressed.connect(func() -> void:
			continue_requested.emit()
			restart_requested.emit()
		)
		_buttons_box.add_child(btn_continue)
		btn_continue.grab_focus()
	else:
		_label.text = "Defeat"
		_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))

		var btn_retry := Button.new()
		btn_retry.text = "Retry Battle"
		btn_retry.pressed.connect(func() -> void:
			retry_requested.emit()
			restart_requested.emit()
		)
		_buttons_box.add_child(btn_retry)

		var btn_title := Button.new()
		btn_title.text = "Return to Title"
		btn_title.pressed.connect(func() -> void:
			title_requested.emit()
		)
		_buttons_box.add_child(btn_title)
		btn_retry.grab_focus()

	show()
