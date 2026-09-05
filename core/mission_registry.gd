class_name MissionRegistry
extends RefCounted

## Static factory and repository of narrative sortie missions.

const M01_MAP := [
	"..F....F..",
	".##....##.",
	"..........",
	"...####...",
	"...####...",
	"..........",
	".##....##.",
	"..F....F..",
]


static func get_mission(mission_id: String) -> MissionData:
	if mission_id == "M01_CABBAGE":
		return _build_m01_cabbage()

	return null


static func _build_m01_cabbage() -> MissionData:
	var mission := MissionData.new()
	mission.mission_id = "M01_CABBAGE"
	mission.title = "The Cabbage Trajectory"
	mission.map_ascii = PackedStringArray(M01_MAP)

	mission.player_roster = [
		_make_unit("Vanguard", 24, 9, 4, 0.90, 0.05, 0.05, 3, 1, UnitData.Team.PLAYER, "vanguard"),
		_make_unit("Scout", 14, 6, 0, 0.90, 0.25, 0.10, 5, 1, UnitData.Team.PLAYER, "scout"),
		_make_unit("Brute", 26, 10, 3, 0.85, 0.00, 0.05, 3, 1, UnitData.Team.PLAYER, "brute"),
		_make_unit("Raider", 18, 8, 1, 0.90, 0.10, 0.15, 4, 1, UnitData.Team.PLAYER, "raider"),
	]
	mission.player_spawns = [
		Vector2i(0, 6),
		Vector2i(1, 7),
		Vector2i(0, 7),
		Vector2i(1, 6),
	]

	mission.enemy_roster = [
		_make_unit("Siege Vanguard", 22, 8, 3, 0.90, 0.05, 0.05, 3, 1, UnitData.Team.ENEMY, "vanguard"),
		_make_unit("Catapult Guard", 24, 9, 2, 0.85, 0.00, 0.05, 3, 1, UnitData.Team.ENEMY, "brute"),
		_make_unit("Slinger", 14, 6, 0, 0.90, 0.25, 0.10, 5, 1, UnitData.Team.ENEMY, "scout"),
		_make_unit("Artillery Raider", 16, 7, 1, 0.90, 0.10, 0.15, 4, 1, UnitData.Team.ENEMY, "raider"),
	]
	mission.enemy_spawns = [
		Vector2i(8, 2),
		Vector2i(9, 3),
		Vector2i(8, 5),
		Vector2i(9, 4),
	]

	mission.turn_dialogue_triggers[1] = DialogueTree.from_dict({
		"start": "pip_wonder",
		"nodes": {
			"pip_wonder": {
				"speaker": "Scout",
				"text": "Couldn't we just... close the windows? Why are we risking our lives for vegetables?",
				"next": "vanguard_chivalry",
			},
			"vanguard_chivalry": {
				"speaker": "Vanguard",
				"text": "Because chivalry does not flinch before foul brassicas, Pip! Forward!",
			},
		},
	})

	var catapult_zone := Rect2i(Vector2i(7, 2), Vector2i(3, 4))
	mission.area_dialogue_triggers[catapult_zone] = DialogueTree.from_dict({
		"start": "brute_dismantle",
		"nodes": {
			"brute_dismantle": {
				"speaker": "Brute",
				"text": "Excuse me, friends. I am going to gently dismantle your siege weapon now. Please step back so no one gets wood splinters.",
			},
		},
	})

	mission.victory_debrief = DialogueTree.from_dict({
		"start": "wrecked",
		"nodes": {
			"wrecked": {
				"speaker": "Raider",
				"text": "Catapult wrecked, boss. Also, I found twelve silver coins in their tool chest.",
				"next": "fee",
			},
			"fee": {
				"speaker": "Raider",
				"text": "Consider it an environmental hazard fee.",
			},
		},
	})

	mission.defeat_debrief = DialogueTree.from_dict({
		"start": "retreat",
		"nodes": {
			"retreat": {
				"speaker": "Vanguard",
				"text": "A glorious tactical withdrawal from incoming cruciferous projectiles! Fall back and regroup!",
			},
		},
	})

	mission.completion_flag = "mission_m01_completed"
	return mission


static func _make_unit(
	unit_name: String,
	max_hp: int,
	attack: int,
	defense: int,
	accuracy: float,
	evasion: float,
	crit_rate: float,
	move_range: int,
	attack_range: int,
	team: UnitData.Team,
	art: String
) -> UnitData:
	var data := UnitData.new()
	data.unit_name = unit_name
	data.max_hp = max_hp
	data.attack = attack
	data.defense = defense
	data.accuracy = accuracy
	data.evasion = evasion
	data.crit_rate = crit_rate
	data.move_range = move_range
	data.attack_range = attack_range
	data.team = team
	data.sprite_walk = "res://assets/lpc/units/%s_walkcycle.png" % art
	data.sprite_slash = "res://assets/lpc/units/%s_slash.png" % art

	return data
