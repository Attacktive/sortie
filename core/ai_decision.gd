class_name AIDecision
extends RefCounted

## Where the unit should stand when it is done moving.
var move_to: Vector2i = Vector2i.ZERO

## Who to attack from move_to, or null to advance without attacking.
var target: BattleUnit = null
