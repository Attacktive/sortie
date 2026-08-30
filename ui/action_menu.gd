class_name ActionMenu
extends VBoxContainer

signal attack_chosen
signal wait_chosen

var _attack_button: Button
var _wait_button: Button

func _ready() -> void:
	_attack_button = Button.new()
	_attack_button.text = "Attack"
	_attack_button.pressed.connect(func() -> void: attack_chosen.emit())
	add_child(_attack_button)

	_wait_button = Button.new()
	_wait_button.text = "Wait"
	_wait_button.pressed.connect(func() -> void: wait_chosen.emit())
	add_child(_wait_button)

	hide()

## Attack is disabled rather than hidden, so the menu never changes shape under the player's cursor.
func open(at: Vector2, can_attack: bool) -> void:
	position = at
	_attack_button.disabled = not can_attack
	show()

	if can_attack:
		_attack_button.grab_focus()
	else:
		_wait_button.grab_focus()

func close() -> void:
	hide()
