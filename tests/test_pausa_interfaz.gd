extends SceneTree

var fallos := 0

func _initialize():
	call_deferred("_probar")

func _comprobar(condicion: bool, mensaje: String):
	if not condicion:
		fallos += 1
		push_error(mensaje)

func _tecla(codigo: Key):
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo
	evento.pressed = true
	root.push_input(evento, true)
	evento = evento.duplicate()
	evento.pressed = false
	root.push_input(evento, true)

func _mando(boton: JoyButton):
	var evento := InputEventJoypadButton.new()
	evento.button_index = boton
	evento.pressed = true
	root.push_input(evento, true)
	evento = evento.duplicate()
	evento.pressed = false
	root.push_input(evento, true)

func _clic(boton: Button):
	for pulsado in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.position = boton.get_global_rect().get_center()
		evento.pressed = pulsado
		root.push_input(evento, true)

func _probar_ajustes_volcan():
	for velocidad in [1, 2, 4, 8]:
		var nivel = load("res://escenas/escenas_niveles/nivel_4.tscn").instantiate()
		root.add_child(nivel)
		nivel.set_process(false)
		nivel.set_physics_process(false)
		nivel.gestor_clima.set_process(false)
		await process_frame
		await process_frame
		var celda := Vector2i(5, 5)
		_comprobar(nivel._plantar(celda, 0), "El volcán tiene una planta junto al géiser")
		var arbol: Arbol = nivel.arboles_plantados[celda]
		for i in [1, 2, 4, 8].find(velocidad):
			_tecla(KEY_V)
		nivel._on_ataque_pulsado(0, false)
		var cargas: Array = nivel.cargas.duplicate()
		_tecla(KEY_KP_ENTER)
		_comprobar(nivel.ronda_activa and nivel.cargas == cargas, "Enter numérico inicia sin lanzar el poder armado")
		var clima = nivel.gestor_clima
		clima._anunciar("geiser")
		clima.presentar_avisos(0.0)
		clima.presentar_avisos(0.6)
		var previo: Dictionary = clima.avisos.geiser.duplicate(true)
		var cola: Array = nivel.cola_bestias.duplicate()
		var tiempo: float = clima.tiempo
		var ronda: int = nivel.ronda
		match velocidad:
			1, 8: _clic(nivel.hud.boton_pausa)
			2: _tecla(KEY_ESCAPE)
			4: _mando(JOY_BUTTON_START)
		_comprobar(paused and Engine.time_scale == 1.0 and is_instance_valid(nivel.pausa), "La pausa detiene la partida y normaliza el reloj")
		if not is_instance_valid(nivel.pausa):
			nivel.free()
			continue
		var pausa = nivel.pausa
		await process_frame
		match velocidad:
			1, 8: _clic(pausa.boton_ajustes)
			2:
				pausa.boton_ajustes.grab_focus()
				_tecla(KEY_ENTER)
			4:
				pausa.boton_ajustes.grab_focus()
				_mando(JOY_BUTTON_A)
		_comprobar(is_instance_valid(pausa.ajustes), "Los ajustes se abren en plena ronda a %d×" % velocidad)
		if is_instance_valid(pausa.ajustes):
			var ajustes = pausa.ajustes
			await process_frame
			var preferencia: bool = ajustes.boton_numeros_dano.button_pressed
			_clic(ajustes.boton_numeros_dano)
			_comprobar(ajustes.boton_numeros_dano.button_pressed != preferencia, "Los controles de ajustes responden mientras la partida está pausada")
			_clic(ajustes.boton_numeros_dano)
			clima.actualizar(30.0)
			clima.presentar_avisos(30.0)
			match velocidad:
				1, 8: _clic(ajustes.boton_volver)
				2: _tecla(KEY_ESCAPE)
				4: _mando(JOY_BUTTON_B)
			_comprobar(paused and pausa.ajustes == null and root.gui_get_focus_owner() == pausa.boton_ajustes, "Volver restaura el foco de Ajustes")
		_comprobar(clima.avisos.geiser == previo and clima.tiempo == tiempo and nivel.cola_bestias == cola and nivel.ronda == ronda, "Pausa conserva el aviso, el reloj y la ronda")
		await process_frame
		match velocidad:
			1, 8: _clic(pausa.boton_continuar)
			2: _tecla(KEY_ESCAPE)
			4: _mando(JOY_BUTTON_B)
		_comprobar(not paused and Engine.time_scale == float(velocidad) and clima.avisos.geiser == previo, "Reanudar restaura la velocidad y el aviso exactos")
		clima.actualizar(2.0)
		clima.presentar_avisos(0.89)
		clima.actualizar(0.0)
		_comprobar(arbol.vida == 100, "El géiser espera todo el tiempo visible restante")
		clima.presentar_avisos(0.02)
		clima.actualizar(0.0)
		clima.actualizar(0.0)
		_comprobar(arbol.vida == 75 and not clima.avisos.has("geiser"), "El géiser reanudado impacta una sola vez")
		paused = false
		nivel.free()

func _probar():
	root.size = Vector2i(1920, 1080)
	var controles = root.get_node("ControlesManager")
	var originales := {}
	for accion in ["Confirmar", "Confirmar tablero", "Derecha", "Abajo", "Atras", "Pausa"]:
		originales[accion] = InputMap.action_get_events(accion)
		InputMap.action_erase_events(accion)
		for evento: InputEvent in controles.valores_por_defecto[accion]:
			InputMap.action_add_event(accion, evento)
	controles._sincronizar_ui()
	var nivel = load("res://escenas/escenas_niveles/nivel_0.tscn").instantiate()
	root.add_child(nivel)
	nivel.set_process(false)
	nivel.set_physics_process(false)
	await process_frame
	await process_frame
	var hud = nivel.hud
	var semilla: Button = hud.botones_semilla[0]
	var imagen := semilla.get_node("Arte") as TextureRect
	_comprobar(imagen.texture != null and semilla.text.is_empty(), "Las semillas se identifican por su sprite")
	_comprobar(hud.label_gotas.get_theme_font("font").resource_path.ends_with("PixelOperator-Bold.ttf"), "El HUD usa la fuente compartida")
	var borde_tablero: Vector2 = nivel.suelo.get_global_transform_with_canvas() * Vector2(0, 17 * 64)
	_comprobar(borde_tablero.y <= hud.barra.get_global_rect().position.y, "La barra ampliada deja visible toda la última fila")

	var inicio := Vector2i(2, 4)
	var recto := Vector2i(8, 4)
	var diagonal := Vector2i(3, 5)
	nivel.parcelas_secano.assign([inicio, recto, diagonal])
	nivel.cursor_tablero = inicio
	nivel._on_semilla_pulsada(0, false)
	_tecla(KEY_RIGHT)
	_comprobar(nivel.cursor_tablero == recto, "Una pulsación salta los huecos sin abandonar la fila")
	_tecla(KEY_DOWN)
	_comprobar(nivel.cursor_tablero == diagonal, "Sin destino recto el cursor pasa a la siguiente fila útil")
	_tecla(KEY_E)
	_comprobar(nivel.arboles_plantados.has(diagonal) and not nivel.ronda_activa, "E confirma una semilla seleccionada")
	nivel._on_semilla_pulsada(0, false)
	nivel.cursor_tablero = recto
	_tecla(KEY_ENTER)
	_comprobar(nivel.ronda_activa and not nivel.arboles_plantados.has(recto), "Enter inicia la ronda sin plantar aunque haya una semilla seleccionada")
	var cola: Array = nivel.cola_bestias.duplicate()
	_tecla(KEY_KP_ENTER)
	_tecla(KEY_SPACE)
	_comprobar(nivel.cola_bestias == cola and not nivel.arboles_plantados.has(recto), "Los atajos durante la ronda no reinician la cola ni confirman casillas")

	nivel._abrir_pausa()
	var pausa = nivel.pausa
	pausa.boton_ajustes.grab_focus()
	_mando(JOY_BUTTON_A)
	_comprobar(paused and is_instance_valid(pausa.ajustes), "El mando abre los ajustes durante una ronda")
	if is_instance_valid(pausa.ajustes):
		var ajustes = pausa.ajustes
		_comprobar(ajustes.boton_numeros_dano.toggled.get_connections().size() > 0, "Los ajustes muestran la opción de daño real")
		_mando(JOY_BUTTON_B)
		_comprobar(paused and pausa.ajustes == null and pausa.panel_principal.visible, "Atrás vuelve a la pausa")
		_comprobar(root.gui_get_focus_owner() == pausa.boton_ajustes, "El foco vuelve al botón Ajustes")
		_mando(JOY_BUTTON_B)
		_comprobar(not paused and nivel.ronda_activa and nivel.arboles_plantados.has(diagonal), "Se reanuda la misma ronda y se conservan las torres")
	nivel.free()
	await _probar_ajustes_volcan()
	for accion in originales:
		InputMap.action_erase_events(accion)
		for evento: InputEvent in originales[accion]:
			InputMap.action_add_event(accion, evento)
	controles._sincronizar_ui()
	await process_frame
	print("Pause and HUD checks: %s" % ("PASS" if fallos == 0 else "%d FAILED" % fallos))
	quit(0 if fallos == 0 else 1)
