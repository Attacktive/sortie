class_name ForecastPanel
extends PanelContainer

var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	add_child(_label)
	hide()

func show_forecast(forecast: AttackForecast) -> void:
	_label.text = ForecastFormat.line(forecast)
	show()

func clear() -> void:
	hide()
