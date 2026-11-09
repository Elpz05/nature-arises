extends SceneTree

var fallos := 0

func _initialize():
	call_deferred("_probar")

func _comprobar(condicion: bool, mensaje: String):
	if not condicion:
		fallos += 1
		push_error(mensaje)

func _probar():
	root.size = Vector2i(1920, 1080)
	var controles = root.get_node("ControlesManager")
	var eventos_originales := {}
	for accion in controles.acciones_configurables:
		eventos_originales[accion] = InputMap.action_get_events(accion)
		InputMap.action_erase_events(accion)
		for evento: InputEvent in controles.valores_por_defecto[accion]:
			InputMap.action_add_event(accion, evento)
	var guardado = root.get_node("Guardado")
	var slot: int = guardado.slot_actual
	guardado.slot_actual = -1
	var nivel = load("res://escenas/escenas_niveles/nivel_0.tscn").instantiate()
	root.add_child(nivel)
	nivel.set_process(false)
	nivel.set_physics_process(false)
	await process_frame
	var hud = nivel.hud
	var ficha: HBoxContainer = hud._fila_retratos.get_child(0)
	var imagen := ficha.get_child(0) as TextureRect
	_comprobar(hud.previa_ronda.visible and imagen.texture != null, "La previa usa el sprite de la bestia")
	_comprobar(ficha.get_child(1).text == "×4", "La primera ronda muestra cuatro Natura")
	_comprobar(root.get_visible_rect().encloses(hud.previa_ronda.get_global_rect()), "La previa queda dentro de la pantalla")

	nivel.ronda = 3
	nivel._actualizar_ronda_hud()
	var total: int = nivel._plan_de_ronda(3, true).size()
	nivel._alternar_desafio()
	_comprobar(hud._fila_retratos.get_child(0).get_child(1).text == "×%d" % total, "El desafío actualiza la cantidad de la previa")

	var izquierda := Vector2i(2, 4)
	var derecha := Vector2i(8, 4)
	nivel.parcelas_secano.assign([izquierda, derecha])
	nivel.usar_cursor_tablero = true
	nivel.seleccion_tipo = "semilla"
	nivel.seleccion_indice = 0
	nivel.cursor_tablero = izquierda
	nivel._mover_cursor(Vector2i.RIGHT)
	_comprobar(nivel.cursor_tablero == derecha, "El cursor salta el terreno vacío hasta la siguiente parcela")
	_comprobar(nivel._plantar(izquierda, 0), "La parcela se puede plantar")
	nivel._mover_cursor(Vector2i.LEFT)
	_comprobar(nivel.cursor_tablero == derecha, "Una parcela ocupada no es destino para semillas")
	nivel._on_pala_pulsada(false)
	nivel._ajustar_cursor()
	_comprobar(nivel.cursor_tablero == izquierda, "La pala lleva el cursor a una torre")
	nivel._on_ataque_pulsado(0, false)
	nivel._ajustar_cursor()
	_comprobar(nivel._es_camino(nivel.cursor_tablero), "Un poder lleva el cursor al camino")

	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_SPACE
	tecla.pressed = true
	nivel._input(tecla)
	_comprobar(nivel.ronda_activa and not hud.previa_ronda.visible, "Espacio inicia la ronda y oculta la previa")
	nivel.free()

	nivel = load("res://escenas/escenas_niveles/nivel_0.tscn").instantiate()
	root.add_child(nivel)
	var mando := InputEventJoypadButton.new()
	mando.button_index = JOY_BUTTON_BACK
	mando.pressed = true
	nivel._input(mando)
	_comprobar(nivel.ronda_activa and nivel.hud._pistas_mando.visible, "Atrás/Select del mando inicia la ronda y muestra indicaciones")
	nivel.free()
	var perfil := ConfigFile.new()
	perfil.set_value("controles", "Confirmar", [tecla])
	controles._aplicar_perfil(perfil)
	controles._sincronizar_ui()
	_comprobar(InputMap.event_is_action(tecla, "Iniciar Ronda") and not InputMap.event_is_action(tecla, "Confirmar"), "El perfil antiguo reserva Espacio para iniciar")
	_comprobar(InputMap.event_is_action(mando, "Iniciar Ronda"), "El perfil antiguo conserva el atajo de mando libre")
	for accion in eventos_originales:
		InputMap.action_erase_events(accion)
		for evento: InputEvent in eventos_originales[accion]:
			InputMap.action_add_event(accion, evento)
	controles._sincronizar_ui()
	guardado.slot_actual = slot
	print("Cursor and wave preview checks: %s" % ("PASS" if fallos == 0 else "%d FAILED" % fallos))
	quit(0 if fallos == 0 else 1)
