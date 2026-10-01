extends HSlider

@onready var label_porcentaje: Label = $"../SFXPorcentaje"

func _ready() -> void:
	var bus_idx = AudioServer.get_bus_index("SFX")
	value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	_actualizar_label()

func _on_value_changed(new_value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("SFX")

	if new_value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(new_value))

	_actualizar_label()
	Ajustes.guardar_ajustes()

func _actualizar_label() -> void:
	label_porcentaje.text = str(round(value * 100)) + "%"
