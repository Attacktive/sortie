class_name Combat
extends RefCounted

const CRIT_MULTIPLIER := 3

## Damage swing as a fraction either side of raw damage.
## Set to 0.0 to remove variance entirely without touching any logic.
const DAMAGE_VARIANCE := 0.1

## Predicts an attack without rolling for it or mutating anything.
## This is what the player reads, so it must never lie and never consume a roll.
static func forecast(grid: BattleGrid, attacker: BattleUnit, defender: BattleUnit) -> AttackForecast:
	var result := AttackForecast.new()
	var terrain := grid.terrain_at(defender.cell)

	result.hit_chance = clampf(attacker.data.accuracy - (defender.data.evasion + Terrain.evasion_bonus(terrain)), 0.0, 1.0)
	result.crit_chance = attacker.data.crit_rate

	var raw := _raw_damage(grid, attacker, defender)
	result.min_damage = _apply_variance(raw, 1.0 - DAMAGE_VARIANCE)
	result.max_damage = _apply_variance(raw, 1.0 + DAMAGE_VARIANCE)
	result.crit_damage = result.max_damage * CRIT_MULTIPLIER

	return result

## Damage before variance and before the critical multiplier.
## Both terrain bonuses are read from the defender's cell.
static func _raw_damage(grid: BattleGrid, attacker: BattleUnit, defender: BattleUnit) -> int:
	var terrain := grid.terrain_at(defender.cell)

	return attacker.data.attack - (defender.data.defense + Terrain.defense_bonus(terrain))

## The floor of 1 lands here, before any critical multiplier, so a crit is always a clean 3x of the hit.
static func _apply_variance(raw: int, variance: float) -> int:
	return maxi(1, roundi(raw * variance))

## Resolves one attack, drawing from rolls in a fixed order: hit, then crit, then variance.
## Rolls are consumed conditionally — a miss draws exactly one.
## This order is part of the contract: changing it invalidates every saved seed.
static func resolve(grid: BattleGrid, attacker: BattleUnit, defender: BattleUnit, rolls: RollSource) -> AttackResult:
	var result := AttackResult.new()
	var prediction := forecast(grid, attacker, defender)

	result.hit = rolls.roll_unit() < prediction.hit_chance
	if not result.hit:
		return result

	result.crit = rolls.roll_unit() < prediction.crit_chance

	var variance := 1.0 - DAMAGE_VARIANCE + rolls.roll_unit() * 2.0 * DAMAGE_VARIANCE
	var base := _apply_variance(_raw_damage(grid, attacker, defender), variance)

	var multiplier := 1
	if result.crit:
		multiplier = CRIT_MULTIPLIER

	result.damage = base * multiplier
	defender.hp = maxi(0, defender.hp - result.damage)
	result.killed = not defender.is_alive()

	return result

## One full trade: the attack, then a counterattack if the defender survives and can reach back.
## The counter is a complete independent attack — its own hit, crit, and variance rolls.
static func exchange(grid: BattleGrid, attacker: BattleUnit, defender: BattleUnit, rolls: RollSource) -> CombatExchange:
	var result := CombatExchange.new()
	result.attack = resolve(grid, attacker, defender, rolls)

	if _can_counter(defender, attacker):
		result.counter = resolve(grid, defender, attacker, rolls)

	return result

static func _can_counter(defender: BattleUnit, attacker: BattleUnit) -> bool:
	if not defender.is_alive():
		return false

	return Movement.manhattan(defender.cell, attacker.cell) <= defender.data.attack_range
