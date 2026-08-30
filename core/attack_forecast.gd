class_name AttackForecast
extends RefCounted

## Probability the attack connects, in [0.0, 1.0].
var hit_chance: float = 0.0

## Probability of a critical hit, given that the attack connects.
var crit_chance: float = 0.0

## Non-critical damage range produced by variance.
var min_damage: int = 0
var max_damage: int = 0

## What a maximum-variance critical hit would deal, for display.
var crit_damage: int = 0
