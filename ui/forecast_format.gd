class_name ForecastFormat
extends RefCounted

## Floats are stored in [0.0, 1.0] everywhere in core.
## They become percentages here, at the UI edge, and nowhere else.
static func percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)

static func damage(forecast: AttackForecast) -> String:
	if forecast.min_damage == forecast.max_damage:
		return str(forecast.min_damage)

	return "%d-%d" % [forecast.min_damage, forecast.max_damage]

static func line(forecast: AttackForecast) -> String:
	return "Deals %s   Hit %s   Crit %s" % [damage(forecast), percent(forecast.hit_chance), percent(forecast.crit_chance)]
