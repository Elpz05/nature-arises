extends Node

enum Tipo { TECLADO_MOUSE, MANDO }

var acciones_configurables := ["Clic Izquierdo", 
"Clic Derecho", "Pausa", "Elemento Natura", 
"Elemento Flamma", "Elemento Aqua", "Elemento Terra", 
"Elemento Glacies", "Elemento Venenum",
"Casilla Planta 0", "Casilla Planta 1", 
"Casilla Planta 2", "Casilla Planta 3", 
"Casilla Planta 4", "Casilla Planta 5", 
"Casilla Planta 6", "Izquierda", "Derecha", "Arriba",
"Abajo", "Confirmar", "Atras", "Usar Elemento", 
"Cambiar Casilla Izquierda", "Cambiar Casilla Derecha",
"Alternar Elemento o Planta"]

var valores_por_defecto: Dictionary = {}

func _ready() -> void:
	guardar_valores_por_defecto()
	cargar_controles()

func guardar_valores_por_defecto() -> void:
	for accion in acciones_configurables:
		valores_por_defecto[accion] = InputMap.action_get_events(accion).duplicate(true)

func es_del_tipo(evento: InputEvent, tipo: Tipo) -> bool:
	if tipo == Tipo.TECLADO_MOUSE:
		return evento is InputEventKey or evento is InputEventMouseButton
	return evento is InputEventJoypadButton or evento is InputEventJoypadMotion

func texto_actual(accion: String, tipo: Tipo) -> String:
	for e in InputMap.action_get_events(accion):
		if es_del_tipo(e, tipo):
			return e.as_text()
	return "Sin asignar"

func borrar_eventos_del_tipo(accion: String, tipo: Tipo) -> void:
	for e in InputMap.action_get_events(accion):
		if es_del_tipo(e, tipo):
			InputMap.action_erase_event(accion, e)

func restablecer_todo() -> void:
	for accion in acciones_configurables:
		InputMap.action_erase_events(accion)
		for e in valores_por_defecto[accion]:
			InputMap.action_add_event(accion, e)
	guardar_controles()

func guardar_controles() -> void:
	var config := ConfigFile.new()
	for accion in acciones_configurables:
		config.set_value("controles", accion, InputMap.action_get_events(accion))
	config.save("user://controles.cfg")

func cargar_controles() -> void:
	var config := ConfigFile.new()
	if config.load("user://controles.cfg") != OK:
		return
	for accion in acciones_configurables:
		var eventos = config.get_value("controles", accion, null)
		if eventos is Array:
			InputMap.action_erase_events(accion)
			for e in eventos:
				if e is InputEvent:
					InputMap.action_add_event(accion, e)

func buscar_conflicto(evento: InputEvent, accion_actual: String, tipo: Tipo) -> String:
	for accion in acciones_configurables:
		if accion == accion_actual:
			continue
		for e in InputMap.action_get_events(accion):
			if not es_del_tipo(e, tipo):
				continue
			if eventos_equivalentes(e, evento):
				return accion
	return ""

func eventos_equivalentes(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.keycode == b.keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and sign(a.axis_value) == sign(b.axis_value)
	return false
