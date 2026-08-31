extends GutTest

var _npc: FieldNpc

func before_each() -> void:
	_npc = FieldNpc.new()
	_npc.setup("res://assets/lpc/units/mage_walkcycle.png", "Elder", DialogueTree.new())
	_npc.position = Vector2(200.0, 200.0)
	add_child_autofree(_npc)
	await get_tree().process_frame

func test_npc_collision_box_matches_feet_box() -> void:
	var box := _npc.get_collision_box()
	assert_eq(box.position, Vector2(200.0, 200.0) + FieldBody.BOX_OFFSET)
	assert_eq(box.size, FieldBody.BOX_SIZE)

func test_npc_faces_player_on_interaction() -> void:
	_npc.facing = Facing.Direction.DOWN

	## Player is north of NPC (y < 200)
	_npc.face_toward(Vector2(200.0, 100.0))
	assert_eq(_npc.facing, Facing.Direction.UP)

	## Player is east of NPC (x > 200)
	_npc.face_toward(Vector2(300.0, 200.0))
	assert_eq(_npc.facing, Facing.Direction.RIGHT)
