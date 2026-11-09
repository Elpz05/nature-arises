extends SceneTree

const CAMPANA = preload("res://scripts/nivel/campana.gd")
const MENU := "res://escenas/escenas_menu/menu.tscn"
const CAPITULOS := {"bestias": 7, "arboles": 7, "poderes": 7}
var fallos := 0

func _initialize():
	call_deferred("_run")

func _comprobar(condicion: bool, mensaje: String):
	if not condicion:
		fallos += 1
		push_error(mensaje)

func _click(boton: Button):
	var evento := InputEventMouseButton.new()
	evento.position = boton.get_global_rect().get_center()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = true
	root.push_input(evento, true)
	evento = evento.duplicate()
	evento.pressed = false
	root.push_input(evento, true)

func _mando(accion: String):
	for evento in InputMap.action_get_events(accion):
		if evento is InputEventJoypadButton:
			var pulsacion: InputEventJoypadButton = evento.duplicate()
			pulsacion.pressed = true
			root.push_input(pulsacion, true)
			pulsacion = pulsacion.duplicate()
			pulsacion.pressed = false
			root.push_input(pulsacion, true)
			return
	_comprobar(false, "Falta el botón de mando para " + accion)

func _texto(padre: Node) -> String:
	var salida := ""
	for hijo in padre.get_children():
		if hijo is Label:
			salida += hijo.text + "\n"
		salida += _texto(hijo)
	return salida

func _run():
	var guardado = root.get_node("Guardado")
	var slot: int = guardado.slot_actual
	guardado.slot_actual = -1
	change_scene_to_file(MENU)
	await scene_changed
	await process_frame
	var menu := current_scene.get_node("VBoxContainer")
	_click(menu.boton_guia)
	var guia = current_scene.get_node_or_null("GuiaJuego")
	_comprobar(guia != null and not menu.visible and not paused, "El menú abre la guía sin pausar el árbol")
	if guia == null:
		quit(1)
		return
	_comprobar(guia.pestana_actual == "jugar" and not guia._capitulos.has("nivel"), "Desde el menú se abre el tutorial general")
	_mando("Derecha")
	_mando("Confirmar")
	_comprobar(guia.pestana_actual == "bestias", "El mando puede cambiar de capítulo")
	_mando("Abajo")
	_mando("Abajo")
	_comprobar(guia.ficha_actual == 1 and _texto(guia.detalle).contains("Renace una vez"), "El mando puede recorrer las fichas")
	for id in CAPITULOS:
		guia._botones_pestana[id].pressed.emit()
		_comprobar(guia.indice.get_child_count() == CAPITULOS[id], "Siete fichas en " + id)
		for i in CAPITULOS[id]:
			guia.indice.get_child(i).pressed.emit()
			_comprobar(guia.ficha_actual == i and _texto(guia.detalle).length() > 100, "Se muestra la ficha %d de %s" % [i, id])
	guia._botones_pestana["arboles"].pressed.emit()
	guia.indice.get_child(2).pressed.emit()
	_comprobar(_texto(guia.detalle).contains("Plantar 6 · Mejora a nivel 2: 4 · Mejora a nivel 3: 6"), "La ficha Aqua usa los costes actuales")
	guia._botones_pestana["poderes"].pressed.emit()
	guia.indice.get_child(5).pressed.emit()
	_comprobar(_texto(guia.detalle).contains("1 carga cada 6 s"), "Glacies muestra su recarga")
	guia.indice.get_child(6).pressed.emit()
	_comprobar(_texto(guia.detalle).contains("1 carga cada 10 s"), "Venenum muestra su recarga")
	guia._botones_pestana["jugar"].pressed.emit()
	for i in [1, 3, 4, 5]:
		guia.indice.get_child(i).pressed.emit()
		await process_frame
		await process_frame
		var primera_fila := guia.detalle.get_child(1) as HBoxContainer
		_comprobar(primera_fila != null and primera_fila.get_child_count() == 2, "Cada leyenda incluye el símbolo junto a su descripción")
		var barra: VScrollBar = guia.lectura.get_v_scroll_bar()
		_comprobar(barra.max_value <= barra.page + 1.0, "La leyenda completa cabe en la ficha")
	_mando("Atras")
	await process_frame
	_comprobar(menu.visible and root.gui_get_focus_owner() == menu.boton_guia, "Atrás devuelve al menú y restaura el foco")

	for i in CAMPANA.ESCENAS.size():
		change_scene_to_file(CAMPANA.ESCENAS[i])
		await scene_changed
		await process_frame
		var nivel = current_scene
		guia = nivel.guia
		_comprobar(guia != null and paused and not nivel.ronda_activa, "El nivel %d abre su briefing antes de la ronda" % [i + 1])
		if guia == null:
			quit(1)
			return
		var texto := _texto(guia.detalle)
		_comprobar(guia.pestana_actual == "nivel" and texto.contains(CAMPANA.ETAPAS[i].nombre) and guia.detalle.get_child_count() >= 4,
			"El nivel %d muestra información y consejos propios" % [i + 1])
		var barra: VScrollBar = guia.lectura.get_v_scroll_bar()
		_comprobar(barra.max_value <= barra.page + 1.0, "Se puede leer todo el briefing del nivel %d con mando" % [i + 1])
		_comprobar(nivel.hud.label_estado_basico.text.contains(CAMPANA.ETAPAS[i].nombre), "El HUD normal identifica el nivel")
		if nivel.clima == "volcan":
			for fragmento in ["Géiseres · cada 10 s", "25 HP", "25% durante 7 s", "incluidas las diagonales", "Erupción · cada 25 s", "Flamma"]:
				_comprobar(texto.contains(fragmento), "La lección volcánica explica " + fragmento)
		if i == CAMPANA.ESCENAS.size() - 1:
			_mando("Abajo")
			_mando("Abajo")
			_comprobar(_texto(guia.detalle).contains(nivel.consejos_ronda[0]), "El consejo de la ronda es accesible con mando")
		_mando("Atras")
		_comprobar(not paused and nivel.guia == null, "Cerrar el briefing devuelve al tablero")

	change_scene_to_file(CAMPANA.ESCENAS[4])
	await scene_changed
	await process_frame
	var volcan = current_scene
	_comprobar(volcan.guia == null and not paused, "Reintentar no abre de nuevo el briefing")
	volcan._iniciar_ronda()
	_click(volcan.hud.boton_guia)
	_comprobar(volcan.guia != null and paused and volcan.ronda_activa, "El botón del HUD abre la guía a mitad de ronda")
	var tiempo: float = volcan.gestor_clima.tiempo
	var gotas: int = volcan.gotas
	volcan._actualizar_recursos(100.0)
	await process_frame
	_comprobar(is_equal_approx(volcan.gestor_clima.tiempo, tiempo) and volcan.gotas == gotas, "El reloj del clima y la economía se congelan")
	if volcan.guia != null:
		_mando("Atras")
		_comprobar(not paused and volcan.ronda_activa, "Cerrar la guía del HUD reanuda la misma ronda")

	_mando("Pausa")
	_comprobar(volcan.pausa != null and paused, "El mando abre Pausa")
	if volcan.pausa != null:
		_mando("Abajo")
		_mando("Confirmar")
		_comprobar(volcan.guia != null and not volcan.pausa.visible, "Se puede abrir la guía desde Pausa con el mando")
		if volcan.guia != null:
			_mando("Atras")
			_comprobar(volcan.guia == null and volcan.pausa.visible and paused, "Cerrar la guía de Pausa conserva la pausa")
			_comprobar(root.gui_get_focus_owner() == volcan.pausa.boton_guia, "Se restaura el foco al botón Guía de campo")
		_mando("Atras")
		_comprobar(not paused and volcan.ronda_activa, "La siguiente pulsación vuelve al tablero")
	guardado.slot_actual = slot
	await process_frame
	print("Field guide checks: %s" % ("PASS" if fallos == 0 else "%d FAILED" % fallos))
	quit(0 if fallos == 0 else 1)
