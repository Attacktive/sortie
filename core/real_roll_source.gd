class_name RealRollSource
extends RollSource

var _rng := RandomNumberGenerator.new()
var _seed: int = 0

func _init(seed_value: int) -> void:
	_seed = seed_value
	_rng.seed = seed_value

## The seed is exposed so a battle can log it and be replayed exactly.
func seed_value() -> int:
	return _seed

func roll_unit() -> float:
	return _rng.randf()
