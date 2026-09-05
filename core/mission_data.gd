class_name MissionData
extends RefCounted

## Pure domain representation of a narrative combat mission/sortie.

var mission_id: String = ""
var title: String = ""
var map_ascii: PackedStringArray = []
var player_roster: Array[UnitData] = []
var enemy_roster: Array[UnitData] = []
var player_spawns: Array[Vector2i] = []
var enemy_spawns: Array[Vector2i] = []

## Turn number (int) -> DialogueTree played at player turn start.
var turn_dialogue_triggers: Dictionary = {}

## Rect2i bounds -> DialogueTree played when a player unit enters.
var area_dialogue_triggers: Dictionary = {}

## Dialogue played immediately upon battle victory before ResultScreen.
var victory_debrief: DialogueTree = null

## Dialogue played immediately upon battle defeat before ResultScreen.
var defeat_debrief: DialogueTree = null

## WorldState flag set to true upon victorious completion.
var completion_flag: String = "mission_m01_completed"
