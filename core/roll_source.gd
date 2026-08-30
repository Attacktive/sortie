class_name RollSource
extends RefCounted

## Returns a float in [0.0, 1.0).
## The interval is half-open on purpose: a chance of 1.0 always succeeds and a chance of 0.0 never does,
## with no fencepost handling at either end.
func roll_unit() -> float:
	return 0.0
