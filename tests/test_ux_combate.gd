extends SceneTree

const NIVEL := "res://escenas/escenas_niveles/nivel_4.tscn"
const AJUSTES := "res://escenas/escenas_menu/settings_menu.tscn"
var fallos := 0

func _initialize():
	call_deferred("_run")

func _comprobar(condicion: bool, mensaje: String):
	if not condicion:
		fallos += 1
		push_error(mensaje)

func _clic(punto: Vector2):
	var evento := InputEventMouseButton.new()
	evento.position = punto
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = true
	root.push_input(evento, true)
	evento = evento.duplicate()
	evento.pressed = false
	root.push_input(evento, true)

func _bestia(nivel, tipo: String):
	nivel._crear_espiritu(tipo, "pequeno", 5 * nivel.TAM_CELDA)
	var bestia = nivel.ruta.get_child(-1).get_child(0)
	bestia.set_physics_process(false)
	return bestia

func _run():
	var ajustes = root.get_node("Ajustes")
	var original: ConfigFile = ajustes.config
	ajustes.config = ConfigFile.new()
	_comprobar(ajustes.numeros_dano_activos(), "Legacy settings use the damage number default")
	ajustes.config.set_value("interfaz", "numeros_dano", "invalid")
	_comprobar(ajustes.numeros_dano_activos(), "Malformed damage number settings use the default")
	var nivel = load(NIVEL).instantiate()
	root.add_child(nivel)
	nivel.set_process(false)
	nivel.set_physics_process(false)
	var objetivo := Vector2i(5, 5)
	var cobertura := Vector2i(7, 5)
	var punto: Vector2 = nivel.suelo.map_to_local(objetivo)
	_comprobar(nivel._plantar(objetivo, 0) and nivel._plantar(cobertura, 1), "Plant Natura and Flamma in legal plots")
	var arbol: Arbol = nivel.arboles_plantados[objetivo]
	_comprobar(arbol.indicadores.is_visible_in_tree() and arbol.obtener_nivel() == 1 and arbol.vida == arbol.vida_maxima, "A full-health tree has a visible level and health badge")
	var frio = _bestia(nivel, "glacies")
	var electricidad = _bestia(nivel, "electricitas")
	var toxico = _bestia(nivel, "venenum")
	nivel._actualizar_auras_bestias(0.25)
	_comprobar(arbol.obtener_iconos_combate() == ["escudo", "rayo", "veneno"] and arbol.vida == 100, "Live aura symbols distinguish protection and exposure before electrical damage ticks")
	nivel._actualizar_auras_bestias(0.75)
	_comprobar(arbol.vida == 99 and nivel.numeros_dano.impactos.back().texto == "−1", "Electricitas health loss shows a real damage number")
	nivel.ronda_activa = true
	nivel.gestor_clima.emitir_geiseres()
	nivel.ronda_activa = false
	_comprobar(arbol.vida == 74 and arbol.obtener_iconos_combate().has("geiser"), "A geyser pulse updates the health badge and temporary buff icon")
	arbol.actualizar_clima(7.0)
	_comprobar(not arbol.obtener_iconos_combate().has("geiser"), "The geyser icon expires with its buff")
	nivel._quitar_arbol(cobertura)
	nivel._actualizar_auras_bestias(0.0)
	_comprobar(not arbol.obtener_iconos_combate().has("escudo") and arbol.obtener_iconos_combate().has("hielo"), "Losing Flamma removes the shield and reveals the cold aura")
	frio.get_parent().queue_free()
	electricidad.get_parent().queue_free()
	toxico.get_parent().queue_free()
	nivel._actualizar_auras_bestias(0.0)
	_comprobar(arbol.obtener_iconos_combate().is_empty(), "Dead or deleted aura sources stop showing effects immediately")

	nivel.gotas = 2
	nivel._actualizar_gotas_hud()
	await process_frame
	_clic(nivel.suelo.get_global_transform_with_canvas() * punto)
	await process_frame
	var hud = nivel.hud
	_comprobar(not hud.label_entrantes.visible and hud.panel_mejora.visible and arbol.rango_visible, "Selection and range work with debug off")
	_comprobar(hud.titulo_torre.text.contains("Nv. 1") and hud.resumen_torre.text.contains("74 / 100 HP"), "The card shows current level and exact current and max HP")
	_comprobar(hud.boton_mejorar.text == "Mejorar 2 gotas" and hud.boton_mejorar.tooltip_text.contains("Mejorar por 2 gotas"), "The nearby button shows the charged price and action hint")
	_clic(hud.boton_mejorar.get_global_rect().get_center())
	_comprobar(nivel.gotas == 0 and arbol.obtener_nivel() == 2 and hud.resumen_torre.text.contains("200 / 200 HP"), "One click buys one level and refreshes HP")
	_comprobar(hud.panel_mejora.visible and hud.boton_mejorar.disabled, "The card stays open and cannot buy an unaffordable upgrade")
	_clic(hud.boton_mejorar.get_global_rect().get_center())
	_comprobar(nivel.gotas == 0 and arbol.obtener_nivel() == 2, "Clicking a disabled upgrade does not spend water or place anything")
	nivel._recoger_gotas(3)
	var gatillo := InputEventJoypadMotion.new()
	gatillo.axis = JOY_AXIS_TRIGGER_RIGHT
	gatillo.axis_value = 1.0
	root.push_input(gatillo, true)
	_comprobar(nivel.gotas == 0 and arbol.obtener_nivel() == 3 and hud.boton_mejorar.disabled, "The controller shortcut buys the last level using the same card and price")
	gatillo = gatillo.duplicate()
	gatillo.axis_value = 0.0
	root.push_input(gatillo, true)
	nivel._abrir_pausa()
	_comprobar(not hud.panel_mejora.visible and not arbol.rango_visible, "Pause hides the card and range")
	nivel.pausa._continuar()
	await process_frame
	nivel._actualizar_inspeccion()
	_comprobar(hud.panel_mejora.visible and arbol.rango_visible, "Resuming restores the existing selection")
	nivel._on_semilla_pulsada(0, false)
	nivel._confirmar(punto)
	_comprobar(not hud.panel_mejora.visible and hud.panel_aviso.visible and hud.aviso_colocacion.text == "Casilla ocupada", "Planting clears the card and reports an occupied tile")
	nivel._confirmar(nivel.suelo.map_to_local(cobertura))
	_comprobar(hud.aviso_colocacion.text.begins_with("Faltan gotas") and nivel.seleccion_tipo == "semilla" and nivel.gotas == 0, "The player can retry a failed placement without losing the seed selection")
	hud.reloj_aviso.timeout.emit()
	_comprobar(not hud.panel_aviso.visible, "Placement feedback goes away automatically")
	nivel._deseleccionar()

	nivel.limitar_plantado = false
	for celda in [Vector2i(29, 16), nivel.celda_pozo + Vector2i.LEFT]:
		_comprobar(nivel._plantar(celda, 0), "Plant geometry fixture on dry terrain")
		nivel.celda_torre_seleccionada = celda
		nivel._actualizar_inspeccion()
		var tarjeta: Rect2 = hud.panel_mejora.get_global_rect()
		_comprobar(hud.espacio_camara().encloses(tarjeta), "Card stays inside the playable viewport at board edges")
		_comprobar(not hud.punto_sobre_hud(nivel.pozo.get_global_transform_with_canvas().origin), "The tower card does not block the well")

	nivel.numeros_dano.limpiar()
	var flamma = _bestia(nivel, "flamma")
	flamma.aplicar_ataque_elemental("aqua", 30)
	_comprobar(nivel.numeros_dano.impactos.back().texto == "−60", "Spell numbers use modified damage")
	flamma.recibir_dano(5)
	_comprobar(nivel.numeros_dano.impactos.size() == 1 and nivel.numeros_dano.impactos[0].texto == "−65", "Nearly simultaneous hits on the same target display once")
	nivel.numeros_dano.limpiar()
	var agua = _bestia(nivel, "aqua")
	agua.aplicar_ataque_elemental("flamma", 20)
	_comprobar(nivel.numeros_dano.impactos.is_empty(), "Immunities do not show damage")
	for i in 4:
		agua.recibir_dano(0.25, false)
	_comprobar(nivel.numeros_dano.impactos.is_empty(), "Fractional damage waits for one combined number")
	nivel.numeros_dano._process(0.46)
	_comprobar(nivel.numeros_dano.impactos.size() == 1 and nivel.numeros_dano.impactos[0].texto == "−1", "Damage over time displays a readable sum")
	nivel.numeros_dano._process(0.15)
	agua.recibir_dano(999)
	_comprobar(nivel.numeros_dano.impactos.back().texto == "−199", "Lethal numbers show HP lost without overkill")
	nivel.numeros_dano._process(1.0)
	_comprobar(nivel.numeros_dano.impactos.is_empty() and not nivel.numeros_dano.is_processing(), "Numbers expire and stop updating")

	var opciones = load(AJUSTES).instantiate()
	root.add_child(opciones)
	_comprobar(opciones.boton_numeros_dano.button_pressed, "Settings show the effective default")
	arbol.recibir_dano(1)
	opciones.boton_numeros_dano.button_pressed = false
	_comprobar(not nivel.numeros_dano.activo and nivel.numeros_dano.impactos.is_empty(), "Disabling damage numbers clears current numbers")
	arbol.recibir_dano(1)
	_comprobar(nivel.numeros_dano.impactos.is_empty(), "Damage still applies with numbers off")
	var guardado := ConfigFile.new()
	_comprobar(guardado.load("user://ajustes.cfg") == OK and guardado.get_value("interfaz", "numeros_dano", true) == false, "The new preference persists in the settings file")
	opciones.boton_numeros_dano.button_pressed = true
	arbol.recibir_dano(1)
	_comprobar(nivel.numeros_dano.impactos.size() == 1, "Turning numbers back on displays new hits")
	opciones.free()
	nivel.free()
	ajustes.config = original
	await process_frame
	print("Combat UX checks: %s" % ("PASS" if fallos == 0 else "%d FAILED" % fallos))
	quit(0 if fallos == 0 else 1)
