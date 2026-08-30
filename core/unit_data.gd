class_name UnitData
extends Resource

enum Team { PLAYER, ENEMY }

@export var unit_name: String = "Unit"
@export var max_hp: int = 10
@export var attack: int = 5
@export var defense: int = 0

## Chance to land a hit before the defender's evasion is subtracted, in [0.0, 1.0].
@export_range(0.0, 1.0) var accuracy: float = 0.9
@export_range(0.0, 1.0) var evasion: float = 0.0
@export_range(0.0, 1.0) var crit_rate: float = 0.0

## Movement budget in accumulated terrain cost, not in tiles.
@export var move_range: int = 3

## Attack reach in Manhattan distance.
@export var attack_range: int = 1
@export var team: Team = Team.PLAYER

## LPC animation sheets, as Strings rather than Texture2D so core stays free of scene types.
## Walk is 9 frames by 4 directions; slash is 6 by 4. Row order is up, left, down, right.
@export_file("*.png") var sprite_walk: String = ""
@export_file("*.png") var sprite_slash: String = ""
