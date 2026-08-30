class_name AttackResult
extends RefCounted

var hit: bool = false
var crit: bool = false
var damage: int = 0

## True when this attack reduced the defender to zero hp.
var killed: bool = false
