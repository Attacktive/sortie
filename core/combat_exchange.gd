class_name CombatExchange
extends RefCounted

var attack: AttackResult

## Null when the defender died or could not reach the attacker.
var counter: AttackResult = null
