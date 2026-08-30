class_name ScriptedRollSource
extends RollSource

var _rolls: Array[float] = []
var _index: int = 0

func _init(rolls: Array[float]) -> void:
	_rolls = rolls

func roll_unit() -> float:
	assert(_index < _rolls.size(), "ScriptedRollSource over-drawn: %d rolls queued, draw %d requested" % [_rolls.size(), _index + 1])

	var value := _rolls[_index]
	_index += 1

	return value

## How many rolls have been consumed, so tests can assert that a miss draws exactly one.
func drawn() -> int:
	return _index
