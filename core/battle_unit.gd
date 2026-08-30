class_name BattleUnit
extends RefCounted

var data: UnitData
var hp: int
var cell: Vector2i
var has_acted: bool = false

func _init(unit_data: UnitData, start_cell: Vector2i) -> void:
	data = unit_data
	hp = unit_data.max_hp
	cell = start_cell

func is_alive() -> bool:
	return hp > 0

func team() -> UnitData.Team:
	return data.team
