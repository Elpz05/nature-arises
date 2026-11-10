extends Node

const BASE_BOTON := 66.0
const BASE_ICONO := 45

func _ready():
	Ajustes.escala_ui_cambiada.connect(_actualizar)
	_actualizar(Ajustes.escala_ui())

func _actualizar(porcentaje: int):
	aplicar(get_parent(), porcentaje)

static func aplicar(nodo: Node, porcentaje: int) -> void:
	var factor := porcentaje / 100.0
	if nodo is Control:
		var control := nodo as Control
		if not control.has_meta("minimo_ui_adaptativo"):
			if not control.has_meta("minimo_ui_base"):
				var minimo := control.custom_minimum_size
				if control is BaseButton:
					minimo = minimo.max(Vector2.ONE * BASE_BOTON)
				control.set_meta("minimo_ui_base", minimo)
			var minimo_base: Vector2 = control.get_meta("minimo_ui_base")
			control.custom_minimum_size = (minimo_base * factor).ceil()
		if control is Label or control is Button:
			_aplicar_texto(control, factor)
	for hijo in nodo.get_children():
		aplicar(hijo, porcentaje)

static func _aplicar_texto(control: Control, factor: float):
	if not control.has_meta("fuente_ui_base"):
		var tamano := control.get_theme_font_size("font_size")
		if control is Label and control.label_settings != null:
			control.label_settings = control.label_settings.duplicate()
			tamano = control.label_settings.font_size
		var minimo := 28 if control is Label else 30
		control.set_meta("fuente_ui_base", maxi(tamano, minimo) if not control.has_meta("texto_secundario") else tamano)
	var escalado := roundi(float(control.get_meta("fuente_ui_base")) * factor)
	if control is Label and control.label_settings != null:
		control.label_settings.font_size = escalado
	else:
		control.add_theme_font_size_override("font_size", escalado)
	if control is Button:
		control.add_theme_constant_override("icon_max_width", roundi(BASE_ICONO * factor))
		control.expand_icon = true
