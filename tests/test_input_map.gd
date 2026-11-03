extends SceneTree

# Rebinds only in memory; does not write controls or save files.
var failures := 0

func _initialize():
	call_deferred("_run")

func _check(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)

func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func _button(index: MouseButton, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	return event

func _bind(action: String, event: InputEvent):
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)

func _pad(index: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	return event

func _action(action: String):
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event, true)

func _click(index: MouseButton, screen: Vector2):
	for down in [true, false]:
		var event := _button(index, down)
		event.position = screen
		root.push_input(event, true)

func _run():
	var snapshot := {}
	for action in InputMap.get_actions():
		snapshot[action] = InputMap.action_get_events(action).duplicate(true)
	var manager = root.get_node("ControlesManager")
	for entry in [["Casilla Planta 0", KEY_T], ["Casilla Planta 1", KEY_Y], ["Casilla Planta 2", KEY_U], ["Elemento Natura", KEY_H], ["Elemento Electricitas", KEY_J], ["Pala", KEY_V], ["Iniciar Ronda", KEY_B], ["Pausa", KEY_P], ["Confirmar", KEY_K], ["Atras", KEY_BACKSPACE]]:
		_bind(entry[0], _key(entry[1]))
	_bind("Clic Izquierdo", _button(MOUSE_BUTTON_RIGHT))
	var ctrl_t := _key(KEY_T)
	ctrl_t.ctrl_pressed = true
	InputMap.action_add_event("Casilla Planta 1", ctrl_t)
	_bind("Clic Derecho", _button(MOUSE_BUTTON_MIDDLE))
	InputMap.action_add_event("Confirmar", _pad(JOY_BUTTON_A))
	_bind("Cambiar Casilla Derecha", _pad(JOY_BUTTON_RIGHT_SHOULDER))
	_bind("Alternar Elemento o Planta", _pad(JOY_BUTTON_Y))
	manager._sincronizar_ui()
	_check(InputMap.event_is_action(_key(KEY_K), "ui_accept"), "Menu confirmation must follow Confirmar")
	var physical_a := _key(KEY_F1)
	var physical_b := _key(KEY_F2)
	physical_a.keycode = 0
	physical_b.keycode = 0
	_check(not manager.eventos_equivalentes(physical_a, physical_b), "Different physical keys must not be reported as conflicts")
	var save = root.get_node("Guardado")
	var original_slot: int = save.slot_actual
	save.slot_actual = -1
	for index in 2:
		var level = load("res://escenas/escenas_niveles/nivel_%d.tscn" % index).instantiate()
		root.add_child(level)
		level.set_process(false)
		await process_frame
		level.gotas = 100
		level.hud.SEMILLAS_ACTIVAS = [0, 1, 2]
		level.hud.ATAQUES_ACTIVOS = [0, 4]
		level.hud.actualizar_gotas(100)
		manager.controles_cambiados.emit()
		await process_frame
		_check(root.get_visible_rect().encloses(level.hud.barra.get_global_rect()), "Binding hints must fit in the toolbar")
		_check(level.hud.botones_semilla[0].text.contains("[T]"), "HUD hints must display current plant bindings")
		_check(level.hud.boton_pala.text.contains("[V]"), "Shovel hints must not hardcode Q")
		root.push_input(_key(KEY_F1), true)
		_check(level.seleccion_tipo == "", "Removed plant binding must stop selecting")
		root.push_input(_key(KEY_T), true)
		_check(level.seleccion_tipo == "semilla" and level.seleccion_indice == 0, "Remapped physical plant key must select")
		root.push_input(ctrl_t, true)
		_check(level.seleccion_indice == 1, "Modifier bindings must not trigger the unmodified key's action")
		root.push_input(_key(KEY_T), true)
		root.push_input(_key(KEY_V, true, true), true)
		_check(level.seleccion_tipo == "semilla", "Key echo must not trigger another tool")
		root.push_input(_key(KEY_Q), true)
		_check(level.seleccion_tipo == "semilla", "Old shovel key must stop working")
		root.push_input(_key(KEY_V), true)
		_check(level.seleccion_tipo == "pala", "Remapped shovel key must work")
		root.push_input(_key(KEY_BACKSPACE), true)
		_check(level.seleccion_tipo == "", "Atras must cancel selection before opening pause")
		root.push_input(_key(KEY_J), true)
		_check(level.seleccion_tipo == "ataque" and level.seleccion_indice == 4, "Electricitas must have a working selection action")
		root.push_input(_key(KEY_T), true)
		var row := 4 if index == 0 else 3
		var cell := Vector2i(0, row)
		var screen: Vector2 = level.suelo.get_global_transform_with_canvas() * level.suelo.map_to_local(cell)
		_click(MOUSE_BUTTON_LEFT, screen)
		_check(level.arboles_plantados.is_empty(), "Removed mouse binding must not place towers")
		_click(MOUSE_BUTTON_RIGHT, screen)
		_check(level.arboles_plantados.has(cell), "Remapped mouse confirmation must place once")
		_check(level.gotas == 99, "Mouse press/release must not duplicate placement")
		level.usar_cursor_tablero = true
		level.cursor_tablero = Vector2i(1, row)
		root.push_input(_key(KEY_U), true)
		root.push_input(_key(KEY_K), true)
		_check(level.arboles_plantados.has(Vector2i(1, row)), "Keyboard confirmation must place at the grid cursor")
		level.usar_cursor_tablero = false
		var drag_money: int = level.gotas
		_click(MOUSE_BUTTON_MIDDLE, screen)
		var press := _button(MOUSE_BUTTON_RIGHT)
		press.position = level.hud.botones_semilla[1].get_global_rect().get_center()
		root.push_input(press, true)
		_check(level.seleccion_tipo == "semilla" and level.seleccion_indice == 1 and level.arrastrando, "Remapped mouse press must select a HUD plant for dragging")
		var release := _button(MOUSE_BUTTON_RIGHT, false)
		release.position = level.suelo.get_global_transform_with_canvas() * level.suelo.map_to_local(Vector2i(4, row))
		root.push_input(release, true)
		_check(level.arboles_plantados.has(Vector2i(4, row)) and level.gotas == drag_money - 3, "Remapped drag release must plant and charge once")
		level.usar_cursor_tablero = true
		level.cursor_tablero = Vector2i(2, row)
		root.push_input(_key(KEY_Y), true)
		root.push_input(_pad(JOY_BUTTON_A), true)
		root.push_input(_pad(JOY_BUTTON_A, false), true)
		_check(level.arboles_plantados.has(Vector2i(2, row)), "Joypad confirmation must place at the grid cursor")
		level.cursor_tablero = Vector2i(1, row)
		Input.action_press("Derecha", 0.1)
		level._process(0.01)
		_check(level.cursor_tablero == Vector2i(1, row), "Analog input below the configured deadzone must not move the cursor")
		Input.action_release("Derecha")
		Input.action_press("Derecha")
		level._process(0.01)
		_check(level.cursor_tablero == Vector2i(2, row), "Directional actions must move the grid cursor")
		level._process(0.1)
		_check(level.cursor_tablero == Vector2i(2, row), "Held movement must respect repeat delay")
		level._process(0.25)
		_check(level.cursor_tablero == Vector2i(3, row), "Held movement must repeat after the delay")
		Input.action_release("Derecha")
		level._process(0.0)
		level.cargas[0] = 0
		level.hud.actualizar_ataque(0, 0, 2)
		level.hud.actualizar_ataque(4, 0, 2)
		root.push_input(_key(KEY_T), true)
		var before_count: int = level.arboles_plantados.size()
		_action("Usar Elemento")
		_check(level.arboles_plantados.size() == before_count and level.seleccion_tipo == "semilla", "Using an exhausted ability must not confirm a selected plant")
		level.cargas[0] = 2
		level.hud.actualizar_ataque(0, 2, 2)
		level.hud.actualizar_ataque(4, 2, 2)
		root.push_input(_key(KEY_T), true)
		root.push_input(_pad(JOY_BUTTON_RIGHT_SHOULDER), true)
		_check(level.seleccion_indice == 1, "Cycling must select the next unlocked plant")
		root.push_input(_pad(JOY_BUTTON_Y), true)
		_check(level.seleccion_tipo == "ataque", "Group toggle must select an available ability")
		var charges: int = level.cargas[0]
		_action("Usar Elemento")
		_check(level.cargas[0] == charges - 1, "Usar Elemento must cast at the cursor")
		root.push_input(_key(KEY_B), true)
		_check(level.ronda_activa, "Remapped wave action must start the wave")
		level.pozo._generar_gota()
		var drop = level.pozo.gotas.get_child(0)
		var money: int = level.gotas
		root.push_input(_key(KEY_H), true)
		charges = level.cargas[0]
		_click(MOUSE_BUTTON_LEFT, drop.get_global_transform_with_canvas().origin)
		_check(level.gotas == money, "Removed mouse binding must not collect drops")
		_click(MOUSE_BUTTON_RIGHT, drop.get_global_transform_with_canvas().origin)
		_check(level.gotas == money + 1 and level.cargas[0] == charges, "Remapped pickup must not also cast an ability")
		level.pozo._generar_gota()
		for item in level.pozo.gotas.get_children():
			if not item.procesada:
				level.cursor_tablero = level.suelo.local_to_map(level.suelo.to_local(item.global_position))
				break
		level.usar_cursor_tablero = true
		root.push_input(_key(KEY_K), true)
		_check(level.gotas == money + 2, "Grid-cursor confirmation must collect off-center drops in the target cell")
		root.push_input(_key(KEY_T), true)
		root.push_input(_key(KEY_P), true)
		_check(paused and is_instance_valid(level.pausa), "Pausa must open even when a tool is selected")
		_check(root.gui_get_focus_owner() == level.pausa.boton_continuar, "Pause menu must focus a controller-accessible button")
		_bind("Pausa", _key(KEY_O))
		root.push_input(_key(KEY_P), true)
		_check(paused, "Old pause key must not close the menu after remapping")
		root.push_input(_key(KEY_O), true)
		await process_frame
		_check(not paused and level.pausa == null, "New pause binding must also resume")
		root.push_input(_key(KEY_O), true)
		root.push_input(_key(KEY_K), true)
		root.push_input(_key(KEY_K, false), true)
		await process_frame
		_check(not paused, "Native menu buttons must activate through remapped Confirmar/ui_accept")
		_bind("Pausa", _key(KEY_P))
		level.free()
	save.slot_actual = original_slot
	for action in snapshot:
		InputMap.action_erase_events(action)
		for event in snapshot[action]:
			InputMap.action_add_event(action, event)
	await process_frame
	print("InputMap checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
