extends GutTest

var _field: Field

func before_each() -> void:
	_field = Field.new()
	add_child_autofree(_field)
	await get_tree().process_frame

func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func test_facing_npc_and_pressing_accept_opens_dialogue_and_freezes_player() -> void:
	var player: FieldPlayer = _field.get_node("FieldPlayer")
	var npc: FieldNpc = _field.get_node("FieldNpc")

	assert_not_null(player)
	assert_not_null(npc)

	## Position player directly south of NPC, facing UP
	player.position = npc.position + Vector2(0.0, 32.0)
	player.facing = Facing.Direction.UP

	## Press ui_accept
	_key(KEY_ENTER, true)
	await get_tree().process_frame
	_key(KEY_ENTER, false)
	await get_tree().process_frame

	var dialogue_box: DialogueBox = _field.get_node("DialogueBox")
	assert_true(dialogue_box.visible, "dialogue box opens on interaction")
	assert_true(player.frozen, "player freezes while dialogue is active")
	assert_eq(npc.facing, Facing.Direction.DOWN, "NPC turns to face the player")

	## Advance and finish dialogue
	_key(KEY_ENTER, true)
	await get_tree().process_frame
	_key(KEY_ENTER, false)
	await get_tree().process_frame

	assert_false(dialogue_box.visible, "dialogue closes after last page")
	assert_false(player.frozen, "player unfreezes after dialogue closes")
