class_name ResultScreen
extends CenterContainer

signal restart_requested

var _label: Label

func _ready() -> void:
	var box := VBoxContainer.new()
	add_child(box)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 48)
	box.add_child(_label)

	var button := Button.new()
	button.text = "Again"
	button.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(button)

	hide()

func show_result(victory: bool) -> void:
	if victory:
		_label.text = "Victory"
	else:
		_label.text = "Defeat"

	show()
