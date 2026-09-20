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


const M02_MAP := [
	"F.F....F.F",
	"..##..##..",
	"..........",
	"..F....F..",
	"..........",
	"F.##..##.F",
	"..........",
	"..........",
]


static func get_mission(mission_id: String) -> MissionData:
	if mission_id == "M01_CABBAGE":
		return _build_m01_cabbage()
	if mission_id == "M02_ALE_RUN":
		return _build_m02_ale_run()

	return null


static func build_battle_grid(mission: MissionData) -> BattleGrid:
	if mission == null:
		_push_mission_error(null, "cannot build a battle grid from a null mission")
		return null

	return BattleGrid.from_ascii(mission.map_ascii)


static func populate_units(grid: BattleGrid, mission: MissionData) -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []
	if mission == null:
		_push_mission_error(null, "cannot populate units from a null mission")
		return units
	if grid == null:
		_push_mission_error(mission, "cannot populate units without a battle grid")
		return units

	var occupied: Dictionary[Vector2i, bool] = {}
	if not _validate_spawns(grid, mission, mission.player_roster, mission.player_spawns, "player", occupied):
		return units
	if not _validate_spawns(grid, mission, mission.enemy_roster, mission.enemy_spawns, "enemy", occupied):
		return units

	for i in mission.player_roster.size():
		var unit := BattleUnit.new(mission.player_roster[i], mission.player_spawns[i])
		grid.place_unit(unit, mission.player_spawns[i])
		units.append(unit)

	for i in mission.enemy_roster.size():
		var unit := BattleUnit.new(mission.enemy_roster[i], mission.enemy_spawns[i])
		grid.place_unit(unit, mission.enemy_spawns[i])
		units.append(unit)

	return units


static func _validate_spawns(
	grid: BattleGrid,
	mission: MissionData,
	roster: Array[UnitData],
	spawns: Array[Vector2i],
	team_label: String,
	occupied: Dictionary[Vector2i, bool]
) -> bool:
	if roster.size() != spawns.size():
		return _push_mission_error(mission, "%s roster has %d units but %d spawn cells" % [team_label, roster.size(), spawns.size()])

	for cell in spawns:
		if not grid.is_in_bounds(cell):
			return _push_mission_error(mission, "%s spawn %s is out of bounds" % [team_label, cell])
		if not Terrain.is_passable(grid.terrain_at(cell)):
			return _push_mission_error(mission, "%s spawn %s is on impassable terrain" % [team_label, cell])
		if occupied.has(cell):
			return _push_mission_error(mission, "spawn %s is used more than once" % cell)
		if grid.unit_at(cell) != null:
			return _push_mission_error(mission, "spawn %s is already occupied" % cell)

		occupied[cell] = true

	return true


static func _push_mission_error(mission: MissionData, detail: String) -> bool:
	var mission_id := "<null>"
	if mission != null and not mission.mission_id.is_empty():
		mission_id = mission.mission_id

	push_error("Mission %s: %s" % [mission_id, detail])
	return false


static func _get_player_roster() -> Array[UnitData]:
	return [
		_make_unit(
			"Vanguard",
			24,
			9,
			4,
			0.90,
			0.05,
			0.05,
			3,
			1,
			UnitData.Team.PLAYER,
			"vanguard"
		),
		_make_unit(
			"Scout",
			14,
			6,
			0,
			0.90,
			0.25,
			0.10,
			5,
			1,
			UnitData.Team.PLAYER,
			"scout"
		),
		_make_unit(
			"Brute",
			26,
			10,
			3,
			0.85,
			0.00,
			0.05,
			3,
			1,
			UnitData.Team.PLAYER,
			"brute"
		),
		_make_unit(
			"Raider",
			18,
			8,
			1,
			0.90,
			0.10,
			0.15,
			4,
			1,
			UnitData.Team.PLAYER,
			"raider"
		),
	]


static func _build_m01_cabbage() -> MissionData:
	var mission := MissionData.new()
	mission.mission_id = "M01_CABBAGE"
	mission.title = "The Cabbage Trajectory"
	mission.map_ascii = PackedStringArray(M01_MAP)

	mission.player_roster = _get_player_roster()
	mission.player_spawns = [
		Vector2i(0, 6),
		Vector2i(1, 7),
		Vector2i(0, 7),
		Vector2i(1, 5),
	]

	mission.enemy_roster = [
		_make_unit(
			"Siege Vanguard",
			22,
			8,
			3,
			0.90,
			0.05,
			0.05,
			3,
			1,
			UnitData.Team.ENEMY,
			"vanguard"
		),
		_make_unit(
			"Catapult Guard",
			24,
			9,
			2,
			0.85,
			0.00,
			0.05,
			3,
			1,
			UnitData.Team.ENEMY,
			"brute"
		),
		_make_unit(
			"Slinger",
			14,
			6,
			0,
			0.90,
			0.25,
			0.10,
			5,
			1,
			UnitData.Team.ENEMY,
			"scout"
		),
		_make_unit(
			"Artillery Raider",
			16,
			7,
			1,
			0.90,
			0.10,
			0.15,
			4,
			1,
			UnitData.Team.ENEMY,
			"raider"
		),
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


static func _build_m02_ale_run() -> MissionData:
	var mission := MissionData.new()
	mission.mission_id = "M02_ALE_RUN"
	mission.title = "The Seasonal Ale Run"
	mission.map_ascii = PackedStringArray(M02_MAP)

	mission.player_roster = _get_player_roster()
	mission.player_spawns = [
		Vector2i(4, 7),
		Vector2i(5, 7),
		Vector2i(3, 7),
		Vector2i(6, 7),
	]

	mission.enemy_roster = [
		_make_unit(
			"Agile Thug",
			16,
			8,
			1,
			0.90,
			0.30,
			0.10,
			5,
			1,
			UnitData.Team.ENEMY,
			"skirmisher"
		),
		_make_unit(
			"Agile Rogue",
			16,
			8,
			1,
			0.90,
			0.30,
			0.10,
			5,
			1,
			UnitData.Team.ENEMY,
			"skirmisher"
		),
		_make_unit(
			"Thirsty Bruiser",
			26,
			9,
			2,
			0.85,
			0.00,
			0.05,
			3,
			1,
			UnitData.Team.ENEMY,
			"brute"
		),
		_make_unit(
			"Keg Thief",
			18,
			7,
			1,
			0.90,
			0.10,
			0.15,
			4,
			2,
			UnitData.Team.ENEMY,
			"raider"
		),
	]
	mission.enemy_spawns = [
		Vector2i(3, 2),
		Vector2i(6, 2),
		Vector2i(4, 0),
		Vector2i(5, 0),
	]

	mission.turn_dialogue_triggers[1] = DialogueTree.from_dict({
		"start": "m02_scout_water",
		"nodes": {
			"m02_scout_water": {
				"speaker": "Scout",
				"text": "We are risking our necks for beer? Can't the guards just drink water for one night?",
				"next": "m02_vanguard_fermentation",
			},
			"m02_vanguard_fermentation": {
				"speaker": "Vanguard",
				"text": "Morale is the armor of the soul, Pip! We fight for the King's fermentation!",
			},
		},
	})

	var ale_gap := Rect2i(Vector2i(4, 1), Vector2i(2, 1))
	mission.area_dialogue_triggers[ale_gap] = DialogueTree.from_dict({
		"start": "m02_brute_beverages",
		"nodes": {
			"m02_brute_beverages": {
				"speaker": "Brute",
				"text": "Pardon my intrusion, gentlemen. I am going to have to ask you to step away from the beverages.",
			},
		},
	})

	mission.victory_debrief = DialogueTree.from_dict({
		"start": "m02_raider_kegs",
		"nodes": {
			"m02_raider_kegs": {
				"speaker": "Raider",
				"text": "Kegs are secure, boss. And I found fourteen silver coins taped to the bottom of this barrel.",
				"next": "m02_raider_fee",
			},
			"m02_raider_fee": {
				"speaker": "Raider",
				"text": "Consider it a liquid asset recovery fee.",
			},
		},
	})

	mission.defeat_debrief = DialogueTree.from_dict({
		"start": "m02_vanguard_retreat",
		"nodes": {
			"m02_vanguard_retreat": {
				"speaker": "Vanguard",
				"text": "A tactical withdrawal! We must regroup before the stout goes completely flat!",
			},
		},
	})

	mission.completion_flag = "mission_m02_completed"
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
