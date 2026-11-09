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

func _probar():
	root.size = Vector2i(1920, 1080)
	var controles = root.get_node("ControlesManager")
	var originales := {}
	for accion in ["Confirmar", "Derecha", "Abajo", "Atras", "Pausa"]:
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
	_tecla(KEY_ENTER)
	_comprobar(nivel.arboles_plantados.has(diagonal) and not nivel.ronda_activa, "Enter confirma una semilla seleccionada")
	_tecla(KEY_ENTER)
	_comprobar(nivel.ronda_activa and not nivel.hud.panel_mejora.visible, "Enter inicia la ronda aunque el cursor esté sobre la torre")

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
	for accion in originales:
		InputMap.action_erase_events(accion)
		for evento: InputEvent in originales[accion]:
			InputMap.action_add_event(accion, evento)
	controles._sincronizar_ui()
	nivel.queue_free()
	print("Pause and HUD checks: %s" % ("PASS" if fallos == 0 else "%d FAILED" % fallos))
	quit(0 if fallos == 0 else 1)
