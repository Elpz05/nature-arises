extends SceneTree

var failures := 0

func _initialize():
	call_deferred("_run")

func _check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func _level(index: int):
	var level = load("res://escenas/escenas_niveles/nivel_%d.tscn" % index).instantiate()
	root.add_child(level)
	level.set_process(false)
	level.set_physics_process(false)
	return level

func _click(point: Vector2):
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _pad(button: int):
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)

func _trigger(value: float, axis: JoyAxis = JOY_AXIS_TRIGGER_LEFT):
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	root.push_input(event, true)

func _check_challenge():
	var level = _level(2)
	level.ronda = 3
	level._actualizar_ronda_hud()
	await process_frame
	await process_frame
	var hud = level.hud
	_check(hud.panel_preparacion.visible and not hud.panel_combate.visible, "The briefing is visible in the normal HUD")
	_check(hud.label_amenazas.text.contains("Aqua ×4: atraviesa Terra") and hud.label_amenazas.text.contains("Terra ×2"), "The briefing identifies the actual major threats")
	_check(hud.label_preparacion.text.contains("6 bestias") and hud.label_preparacion.text.contains("+2 gotas al superar") and hud.label_preparacion.text.contains("+3 gotas extra") and hud.label_preparacion.text.contains("Aqua mediano ×1"), "The briefing previews the normal reward, extra reward and exact reinforcements")
	_check(hud.panel_preparacion.get_global_rect().end.y <= 192.0 and hud.barra.get_global_rect().end.y <= hud.panel_estado.position.y, "The new UI fits in the reserved rows")
	_check(hud.label_tipos_ola.visible and hud.label_tipos_ola.text.contains("Aqua ×4") and hud.label_tipos_ola.text.contains("Terra ×2"), "Type counts appear next to the start button")
	_check(not level.desafio_elegido, "Each challenge defaults to off")
	_click(hud.boton_desafio.get_global_rect().get_center())
	_check(level.desafio_elegido and hud.label_preparacion.text.contains("8 bestias"), "The mouse button previews the selected challenge roster")
	_trigger(0.65)
	_trigger(0.95)
	_check(not level.desafio_elegido, "A held controller trigger toggles the challenge just once")
	_trigger(0.0)
	await process_frame
	_trigger(0.8)
	_trigger(0.0)
	_check(level.desafio_elegido, "A new controller trigger press toggles again")
	var money: int = level.gotas
	_click(hud.boton_ronda.get_global_rect().get_center())
	_check(level.ronda_activa and not hud.panel_preparacion.visible and not hud.boton_desafio.visible, "Starting locks the variant and hides preparation")
	level._alternar_desafio()
	level._terminar_ronda()
	_check(level.desafio_elegido and level.gotas == money and level.ronda == 3, "A running challenge cannot change or pay out early")
	var spawned := PackedStringArray()
	while not level.cola_bestias.is_empty():
		level._process(level.intervalos_spawn[2])
		var enemies: Array = level._bestias_vivas()
		var enemy = enemies[-1]
		spawned.append(enemy.tipo + ":" + enemy.tamano)
		if not level.cola_bestias.is_empty():
			enemy.get_parent().free()
	_check(spawned == PackedStringArray(["terra:mediano", "terra:mediano", "aqua:pequeno", "aqua:pequeno", "aqua:pequeno", "aqua:pequeno", "terra:mediano", "aqua:mediano"]), "Real spawns keep the authored Terra front, Aqua pack, and previewed reinforcements")
	level._terminar_ronda()
	_check(level.gotas == money, "The reward waits for the final live enemy")
	level._bestias_vivas()[0].get_parent().free()
	level._process(0.0)
	level._terminar_ronda()
	_check(level.ronda == 4 and level.gotas == money + 5 and not level.desafio_elegido and hud.label_preparacion.text.contains("Desafío superado"), "A cleared challenge credits two regular drops plus three bonus drops exactly once")
	level.free()
	level = _level(2)
	level.ronda = 3
	level._alternar_desafio()
	level._iniciar_ronda()
	money = level.gotas
	level._on_espiritu_llego(level.arbol_meta.vida)
	_check(level.terminado and level.gotas == money, "Defeat awards no water")
	paused = false
	level.free()

func _check_priority():
	var level = _level(7)
	var cell := Vector2i(21, 8)
	_check(level._plantar(cell, 6), "Venenum fits a legal plot covering both routes")
	var tower = level.arboles_plantados[cell]
	tower.temporizador.stop()
	level.ronda = 3
	level._actualizar_ronda_hud()
	_check(level.hud.label_amenazas.text.contains("Electricitas ×3: toma el atajo"), "Finale briefing calls out the electric branch")
	level._iniciar_ronda()
	_check(level.cola_bestias.slice(0, 2) == ["terra:mediano", "terra:mediano"] and level.cola_bestias.slice(-3) == ["electricitas:mediano", "electricitas:mediano", "electricitas:mediano"], "The slower pack spawns ahead of electric runners")
	var shortcut: Path2D = level._ruta_para_tipo("electricitas")
	level._crear_espiritu("electricitas", "pequeno", level._distancias_por_ruta[shortcut][Vector2i(18, 9)])
	level._crear_espiritu("terra", "grande", level._distancias_por_ruta[level.ruta][Vector2i(21, 7)])
	var runner = shortcut.get_child(0).get_child(0)
	var durable = level.ruta.get_child(0).get_child(0)
	runner.set_physics_process(false)
	durable.set_physics_process(false)
	await physics_frame
	await physics_frame
	await physics_frame
	_check(tower.enemigos_en_rango.has(runner) and tower.enemigos_en_rango.has(durable), "Both targets are inside the actual Area2D")
	tower._disparar()
	var shot = level.arboles.get_child(level.arboles.get_child_count() - 1)
	_check(shot != tower and shot.objetivo == runner, "Default fire uses shortest remaining route distance")
	if shot != tower:
		shot.free()
	var money: int = level.gotas
	_pad(JOY_BUTTON_RIGHT_STICK)
	_check(tower.prioridad == Arbol.Prioridad.CERCA_META and level.seleccion_tipo.is_empty() and level.gotas == money, "Priority with no selected tree leaves play unchanged")
	_click(level.suelo.get_global_transform_with_canvas() * level.suelo.map_to_local(cell))
	await process_frame
	await process_frame
	var prioridad: Button = level.hud.boton_prioridad
	_check(prioridad.is_visible_in_tree() and level.hud.panel_mejora.get_global_rect().encloses(prioridad.get_global_rect()), "Priority lives in the selected tree card")
	_click(prioridad.get_global_rect().get_center())
	_check(tower.prioridad == Arbol.Prioridad.MAYOR_VIDA and level.gotas == money and tower.tamano == "pequeno", "Changing priority with the mouse never upgrades the tree")
	_check(prioridad.text.contains("Mayor vida") and level.celda_torre_seleccionada == cell, "Priority updates the open card immediately")
	tower._disparar()
	shot = level.arboles.get_child(level.arboles.get_child_count() - 1)
	_check(shot != tower and shot.objetivo == durable, "Highest HP changes the actual projectile target")
	if shot != tower:
		shot.free()
	var vida_durable: float = durable.vida
	durable.vida = runner.vida
	_check(tower._elegir_objetivo() == runner, "Equal HP uses remaining route distance as the tiebreaker")
	durable.vida = vida_durable
	var enlaces := InputMap.action_get_events("Cambiar Prioridad")
	for enlace in enlaces:
		if enlace is InputEventKey:
			InputMap.action_erase_event("Cambiar Prioridad", enlace)
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_P
	InputMap.action_add_event("Cambiar Prioridad", tecla)
	tecla = tecla.duplicate()
	tecla.pressed = true
	root.push_input(tecla, true)
	_check(tower.prioridad == Arbol.Prioridad.CERCA_META and level.gotas == money, "A remapped priority key changes mode once")
	tower._disparar()
	shot = level.arboles.get_child(level.arboles.get_child_count() - 1)
	_check(shot != tower and shot.objetivo == runner, "The remapped key changes the projectile target back to the runner")
	if shot != tower:
		shot.free()
	InputMap.action_erase_events("Cambiar Prioridad")
	for enlace in enlaces:
		InputMap.action_add_event("Cambiar Prioridad", enlace)
	level.cursor_tablero = cell
	_pad(JOY_BUTTON_RIGHT_STICK)
	_check(tower.prioridad == Arbol.Prioridad.MAYOR_VIDA and level.gotas == money, "Controller targeting cycles the same per-tree setting")
	tower._disparar()
	shot = level.arboles.get_child(level.arboles.get_child_count() - 1)
	_check(shot != tower and shot.objetivo == durable, "The controller changes the actual projectile target")
	if shot != tower:
		shot.free()
	level.gotas = 50
	level._actualizar_gotas_hud()
	_pad(JOY_BUTTON_A)
	_check(level.gotas == 50 and tower.tamano == "pequeno", "Controller confirmation selects without upgrading")
	_trigger(0.7, JOY_AXIS_TRIGGER_RIGHT)
	_trigger(0.95, JOY_AXIS_TRIGGER_RIGHT)
	_check(level.gotas == 38 and tower.tamano == "mediano", "A held upgrade trigger charges exactly once")
	_trigger(0.0, JOY_AXIS_TRIGGER_RIGHT)
	_trigger(0.9, JOY_AXIS_TRIGGER_RIGHT)
	_trigger(0.0, JOY_AXIS_TRIGGER_RIGHT)
	_check(level.gotas == 24 and tower.tamano == "grande", "A fresh upgrade trigger press buys the next level")
	_check(tower.prioridad == Arbol.Prioridad.MAYOR_VIDA, "Upgrades preserve the selected tree's priority")
	for fixture in [[Vector2i(8, 5), 2], [Vector2i(18, 9), 3]]:
		_check(level._plantar(fixture[0], fixture[1]), "Place a utility tree on its legal plot")
		_click(level.suelo.get_global_transform_with_canvas() * level.suelo.map_to_local(fixture[0]))
		_pad(JOY_BUTTON_RIGHT_STICK)
		_check(not prioridad.visible and tower.prioridad == Arbol.Prioridad.MAYOR_VIDA and level.gotas == 24, "Utility trees have no priority action")
	level.free()

func _run():
	var save = root.get_node("Guardado")
	var settings = root.get_node("Ajustes")
	var controls = root.get_node("ControlesManager")
	var old_bindings := {}
	for action in controls.acciones_configurables:
		old_bindings[action] = InputMap.action_get_events(action)
		InputMap.action_erase_events(action)
		for event in controls.valores_por_defecto[action]:
			InputMap.action_add_event(action, event)
	var old_config: ConfigFile = settings.config
	var old_slot: int = save.slot_actual
	settings.config = ConfigFile.new()
	save.slot_actual = -1
	await _check_challenge()
	await _check_priority()
	var volcano = _level(4)
	volcano.ronda = 2
	volcano._iniciar_ronda()
	_check(volcano.cola_bestias == ["terra:pequeno", "terra:pequeno", "terra:pequeno", "glacies:mediano", "glacies:mediano"], "The volcano sends the Terra front line before the Glacies aura group")
	volcano.free()
	for action in old_bindings:
		InputMap.action_erase_events(action)
		for event in old_bindings[action]:
			InputMap.action_add_event(action, event)
	settings.config = old_config
	save.slot_actual = old_slot
	print("Wave tactics checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
