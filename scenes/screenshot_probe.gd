extends Node

## Verification harness. Optionally drives the scene into a specific state,
## waits, saves the viewport, and quits. Gated entirely on environment variables,
## so it never runs during normal play.
##
## Serves both the battle and the field. The battle knobs stage a turn; the field
## knob holds a direction, because a walk cycle only exists while someone walks.
##
## Animations are the one thing a static reading of the code cannot confirm, and
## this is how every visual claim in the project was checked instead of asserted.

## The direction being held, if any. Pressed again every frame; see _process.
var _held: String = ""

func _ready() -> void:
	var host := get_parent()

	if OS.has_environment("SORTIE_SELECT"):
		var parts := OS.get_environment("SORTIE_SELECT").split(",")
		host.call("_try_select", Vector2i(int(parts[0]), int(parts[1])))

	if OS.has_environment("SORTIE_ATTACK"):
		_stage_attack(host, OS.get_environment("SORTIE_ATTACK").split(","))

	if OS.has_environment("SORTIE_WALK"):
		_stage_walk(host, OS.get_environment("SORTIE_WALK").split(","))

	if OS.has_environment("SORTIE_FIELD_WALK"):
		_hold_direction(OS.get_environment("SORTIE_FIELD_WALK"))

	if OS.has_environment("SORTIE_FIELD_TURN"):
		_turn_after(OS.get_environment("SORTIE_FIELD_TURN").split(","))

	if OS.has_environment("SORTIE_FIELD_INTERACT"):
		_stage_field_interact(host)

	if OS.has_environment("SORTIE_FIELD_TRIGGER"):
		_stage_field_trigger(host)

	if OS.has_environment("SORTIE_TITLE_SELECT"):
		await get_tree().process_frame
		var menu: TitleMenu = host.find_child("TitleMenu", true, false)
		if menu != null:
			menu.handle_input_action(OS.get_environment("SORTIE_TITLE_SELECT"))
	var wait := float(OS.get_environment("SORTIE_WAIT")) if OS.has_environment("SORTIE_WAIT") else 0.0
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	else:
		for i in 3:
			await get_tree().process_frame

	## A short SORTIE_WAIT can elapse before anything has been drawn, which saves a
	## blank image and quietly proves nothing. Waiting for a completed draw first
	## guarantees the capture holds a real frame.
	await RenderingServer.frame_post_draw

	if not _held.is_empty():
		_report(host.get("_player"))

	get_viewport().get_texture().get_image().save_png(OS.get_environment("SORTIE_SHOT"))
	get_tree().quit()

## "right", "up", "left" or "down": holds that direction down, so a capture lands mid-stride.
## Pair with SORTIE_WAIT to choose which frame of the walk cycle is caught.
##
## An InputEventAction rather than a key, because the action is what FieldPlayer reads and a keycode would only be a longer way of saying the same thing.
## It goes through Input.parse_input_event for the reason test_field_player.gd documents: get_vector reads held action state, and push_input delivers a one-shot that is gone by the next frame.
func _hold_direction(direction: String) -> void:
	var action := "ui_%s" % direction

	## A capture tool that quietly does nothing is worse than none — that lesson is already in the handoff, written by an all-black PNG reported as a pass.
	if not InputMap.has_action(action):
		push_error("SORTIE_FIELD_WALK=%s is not a direction; expected right, up, left or down" % direction)
		return

	_held = action
	_press()

## Turns partway through: "<direction>,<seconds>".
## Deliberately not awaited by the caller — it runs alongside the capture's own wait, so SORTIE_WAIT picks which frame after the turn is caught.
##
## This is what settles the one claim in field mode that no test can reach: turning is supposed to redraw the sprite on the turn itself rather than on the next walk frame.
## The walk cycle runs at 11 fps and the game at roughly 140, so there are about a dozen rendered frames between one walk frame and the next — which is exactly the window a stale facing would be visible in, and exactly the window to capture.
func _turn_after(parts: PackedStringArray) -> void:
	await get_tree().create_timer(float(parts[1])).timeout

	var release := InputEventAction.new()
	release.action = _held
	release.pressed = false
	Input.parse_input_event(release)

	_hold_direction(parts[0])

## Pressed again every frame rather than once, because Godot releases every held action when the window loses focus, and a window launched from a terminal may never have had it.
## Holding once was measured across three runs at the same speed: the character travelled the full distance, then 14 px, then nothing at all, with nothing different but the timing of a focus event.
func _process(_delta: float) -> void:
	if _held.is_empty():
		return

	_press()

## The player reads Input before this node does, since it is the earlier sibling, so pressing only from _process would cost a frame at the start of every capture.
func _press() -> void:
	var event := InputEventAction.new()
	event.action = _held
	event.pressed = true

	Input.parse_input_event(event)
	Input.flush_buffered_events()

## What the capture actually caught, printed beside it. A verification tool that says nothing about its own state is how an all-black PNG once passed for a verification.
func _report(player: Node) -> void:
	var vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	print("SORTIE_FIELD_WALK %s: vector=%s position=%s frame=%d facing=%d" % [_held, vector, player.position, player._frame, player.facing])

## "ax,ay,tx,ty": teleport the attacker beside the target, then swing.
func _stage_attack(battle: Node, parts: PackedStringArray) -> void:
	var grid = battle.get("_grid")
	var attacker = grid.unit_at(Vector2i(int(parts[0]), int(parts[1])))
	var target_cell := Vector2i(int(parts[2]), int(parts[3]))
	var beside := target_cell + Vector2i(-1, 0)

	grid.move_unit(attacker, beside)
	battle.get("_views")[attacker].snap()
	battle.call("_try_select", beside)
	battle.set("_state", 4)
	battle.call("_try_attack", target_cell)

## "sx,sy,dx,dy": select the unit standing on the first cell and send it walking
## to the second. Pair with SORTIE_WAIT to land the capture mid-stride; the walk
## takes UnitView.STEP_SECONDS per cell, so a five-cell path runs 0.9 seconds.
func _stage_walk(battle: Node, parts: PackedStringArray) -> void:
	battle.call("_try_select", Vector2i(int(parts[0]), int(parts[1])))
	battle.call("_try_move", Vector2i(int(parts[2]), int(parts[3])))

## Positions the player directly west of the NPC facing right, and triggers interaction.
func _stage_field_interact(field: Node) -> void:
	var player: FieldPlayer = field.get("_player")
	var npc: FieldNpc = field.get("_npc")
	if player != null and npc != null:
		player.position = npc.position - Vector2(GridGeometry.CELL_SIZE * 0.5, 0.0)
		player.facing = Facing.Direction.RIGHT
		field.call("_try_interact")

## Registers a step trigger and places player on it to verify event trigger execution.
func _stage_field_trigger(field: Node) -> void:
	var registry: TriggerRegistry = field.get("trigger_registry")
	var player: FieldPlayer = field.get("_player")
	if registry != null and player != null:
		var target_cell := Vector2i(3, 1)
		var action := EventAction.set_flag("probe_triggered", true)
		var trigger := EventTrigger.new(EventTrigger.TriggerType.STEP, target_cell, null, [action], true)
		registry.register_trigger(trigger)
		player.position = GridGeometry.cell_to_position(target_cell)
