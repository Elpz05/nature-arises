extends SceneTree

var fallos := 0

func _initialize():
	call_deferred("_probar")

func _comprobar(condicion: bool, mensaje: String):
	if not condicion:
		fallos += 1
		push_error(mensaje)

func _clic(boton: Button):
	for pulsado in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.position = boton.get_global_rect().get_center()
		evento.pressed = pulsado
		root.push_input(evento, true)

func _probar():
	root.size = Vector2i(1920, 1080)
	var guardado = root.get_node("Guardado")
	var slot: int = guardado.slot_actual
	var codice: ConfigFile = guardado._codice
	var ruta: String = guardado._ruta_codice
	var temporal := OS.get_environment("TEMP").path_join("codice-ui-%d.cfg" % OS.get_process_id())
	guardado.slot_actual = -1
	guardado._codice = ConfigFile.new()
	guardado._ruta_codice = temporal
	var nivel = load("res://escenas/escenas_niveles/nivel_0.tscn").instantiate()
	root.add_child(nivel)
	await process_frame
	await process_frame
	var hud = nivel.hud
	var bloqueada: Button = hud.botones_semilla[1]
	_comprobar(bloqueada.disabled and bloqueada.get_node("Candado").visible and not bloqueada.get_node("Arte").visible, "La barra oculta el sprite de una semilla bloqueada")
	_comprobar(hud.botones_ataque[1].get_node("Candado").visible and not hud.botones_ataque[1].get_node("Arte").visible, "La barra oculta el icono de un poder bloqueado")
	for boton: Button in [hud.botones_semilla[0], hud.botones_ataque[0], hud.boton_pala]:
		_clic(boton)
		await process_frame
		await process_frame
		_comprobar(hud.boton_cerrar_seleccion.visible and hud.boton_cerrar_seleccion.text == "× Cerrar", "Seleccionar una herramienta muestra un cierre")
		var fin: Vector2 = nivel.suelo.get_global_transform_with_canvas() * Vector2(0, 17 * 64)
		_comprobar(hud.barra.get_global_rect().position.y >= fin.y, "El cierre deja visible la última fila")
		nivel.arrastrando = true
		var agua: int = nivel.gotas
		var cargas: Array = nivel.cargas.duplicate()
		_clic(hud.boton_cerrar_seleccion)
		_comprobar(nivel.seleccion_tipo.is_empty() and not nivel.arrastrando and nivel.datos_rango_colocacion.is_empty(), "El cierre cancela la selección, el arrastre y el alcance")
		_comprobar(root.gui_get_focus_owner() == boton and nivel.gotas == agua and nivel.cargas == cargas, "El cierre devuelve el foco sin confirmar el tablero")

	nivel._on_semilla_pulsada(0, false)
	var atras := InputEventKey.new()
	atras.physical_keycode = KEY_BACKSPACE
	atras.pressed = true
	root.push_input(atras, true)
	_comprobar(nivel.seleccion_tipo.is_empty() and root.gui_get_focus_owner() == hud.botones_semilla[0], "Atrás en teclado cierra y devuelve el foco")
	nivel._on_pala_pulsada(false)
	var mando := InputEventJoypadButton.new()
	mando.button_index = JOY_BUTTON_B
	mando.pressed = true
	root.push_input(mando, true)
	_comprobar(nivel.seleccion_tipo.is_empty() and root.gui_get_focus_owner() == hud.boton_pala, "Atrás en mando cierra y devuelve el foco")

	var celda: Vector2i = nivel.parcelas_secano[0]
	nivel._plantar(celda, 0)
	nivel.celda_torre_seleccionada = celda
	await process_frame
	await process_frame
	_clic(hud.boton_cerrar_ficha)
	_comprobar(not hud.panel_mejora.visible and nivel.cursor_tablero == celda and not nivel.arboles_plantados[celda].rango_visible, "La ficha cierra el alcance y devuelve el foco al tablero")

	_clic(hud.boton_velocidad)
	_comprobar(Engine.time_scale == 2.0 and hud.boton_velocidad.text.begins_with("2×"), "El botón acelera la partida")
	var atajo := InputEventKey.new()
	atajo.physical_keycode = KEY_I
	atajo.pressed = true
	root.push_input(atajo, true)
	_comprobar(is_instance_valid(nivel.guia) and paused and Engine.time_scale == 1.0, "El atajo abre el Códice y deja su interfaz a velocidad normal")
	var guia = nivel.guia
	guia._mostrar_capitulo("bestias")
	_comprobar(guia._botones_ficha[0].text == "Bloqueado" and guia.detalle.get_child(0) is Label, "El Códice oculta el retrato de una bestia desconocida")
	root.push_input(atajo, true)
	_comprobar(not paused and Engine.time_scale == 2.0, "Cerrar el Códice recupera la velocidad de partida")
	nivel._crear_espiritu("natura")
	var prioridad := InputEventJoypadButton.new()
	prioridad.button_index = JOY_BUTTON_RIGHT_STICK
	prioridad.pressed = true
	root.push_input(prioridad, true)
	_comprobar(is_instance_valid(nivel.guia), "El stick derecho abre el Códice sin una ficha de torre activa")
	nivel.guia._mostrar_capitulo("bestias")
	_comprobar(nivel.guia._botones_ficha[0].text == "Natura", "La entrada se revela al encontrar la bestia")
	nivel.guia._cerrar()
	var espacio := InputEventKey.new()
	espacio.physical_keycode = KEY_SPACE
	espacio.pressed = true
	root.push_input(espacio, true)
	_comprobar(nivel.ronda_activa, "Espacio inicia una ronda desde el tablero")
	nivel.free()
	_comprobar(Engine.time_scale == 1.0, "Salir del nivel restablece la velocidad normal")
	guardado._codice = codice
	guardado._ruta_codice = ruta
	guardado.slot_actual = slot
	DirAccess.remove_absolute(temporal)
	print("Tools and Codex checks: %s" % ("PASS" if fallos == 0 else "%d FAILED" % fallos))
	quit(0 if fallos == 0 else 1)
