extends SceneTree

const LEVELS = preload("res://scripts/nivel/campana.gd").ESCENAS
var failures := 0
var capture_dir := ""

func _initialize():
	call_deferred("_run")

func _check(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)

func _settle():
	for frame in 6:
		await process_frame

func _capture(name: String):
	if capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Saved " + name)

func _board(level) -> Rect2:
	var origin := Vector2(0, level.FILAS_BLOQUEADAS * level.TAM_CELDA)
	var size: Vector2 = Vector2(level.ANCHO, level.ALTO - level.FILAS_BLOQUEADAS) * level.TAM_CELDA
	return level.suelo.get_global_transform_with_canvas() * Rect2(origin, size)

func _level(index: int):
	var level = load(LEVELS[index]).instantiate()
	root.add_child(level)
	level.set_process(false)
	level.set_physics_process(false)
	level.gestor_clima.set_process(false)
	return level

func _mouse(celda: Vector2i, level):
	_click_at(level.suelo.get_global_transform_with_canvas() * level.suelo.map_to_local(celda))

func _click_at(point: Vector2):
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		root.push_input(event, true)

func _key(code: Key):
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)

func _pad(button: JoyButton):
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		root.push_input(event, true)

func _assert_layout(level, preset: int, label: String):
	var hud = level.hud
	var viewport := root.get_visible_rect().grow(1.0)
	var board := _board(level)
	for panel in [hud.muelle, hud.barra]:
		var rect: Rect2 = panel.get_global_rect()
		_check(viewport.encloses(rect) and not rect.intersects(board), "%s keeps dock %s outside the board: %s vs %s" % [label, panel.name, rect, board])
	_check(viewport.encloses(board), label + " fits the playable board")
	var target := 66.0 * preset / 100.0
	for button in [hud.boton_ronda, hud.boton_guia, hud.boton_pausa, hud.boton_pala, hud.botones_ataque[0]]:
		var rect: Rect2 = button.get_global_rect()
		_check(rect.size.x >= target and rect.size.y >= target and viewport.encloses(rect), "%s fits the scaled target %s: %s" % [label, button.name, rect])
	_check(hud.boton_guia.get_theme_constant("icon_max_width") == roundi(0.45 * preset), label + " scales the action icons")
	_check(hud.label_mision.get_theme_font_size("font_size") >= roundi(0.28 * preset), label + " scales body text")

func _winter(level):
	var dry := [0, 0, 0]
	var posts := [0, 0, 0]
	var cells: Array = level._celdas_de(level.puntos_ruta)
	var unique := {}
	for cell: Vector2i in level.parcelas_secano:
		var nearest := 0
		for i in cells.size():
			if cell.distance_squared_to(cells[i]) < cell.distance_squared_to(cells[nearest]):
				nearest = i
		dry[mini(2, floori(3.0 * nearest / (cells.size() - 1)))] += 1
		_check(level._se_puede_plantar(cell, 0) and not unique.has(cell), "Winter dry plots are legal and unique")
		unique[cell] = true
	for cell: Vector2i in level.puestos_terra:
		var distance := cells.find(cell)
		_check(distance >= 0 and level._se_puede_plantar(cell, 3), "Terra has an on-route post")
		posts[mini(2, floori(3.0 * distance / (cells.size() - 1)))] += 1
		var start := distance * 64.0 - 64.0
		level._crear_espiritu("natura", "pequeno", start)
		var follower = level.ruta.get_child(level.ruta.get_child_count() - 1)
		_check(level._plantar(cell, 3), "Terra can occupy the post")
		_check(level._resolver_avance_terra(follower.get_child(0), start, start + 128.0) < start + 128.0, "Terra interrupts enemy movement at each post")
		level._quitar_arbol(cell)
		follower.free()
	_check(dry == [3, 4, 3] and posts == [1, 1, 1], "Winter is 3/4/3 with a Terra post per third")
	level._on_semilla_pulsada(3, false)
	_check(not level._celda_navegable(Vector2i(4, 8)) and not level._se_puede_plantar(Vector2i(4, 8), 3), "Terra cannot target or plant on unmarked road")
	level._deseleccionar()

func _warning_captures():
	var volcano = _level(4)
	volcano._plantar(Vector2i(5, 5), 0)
	volcano._iniciar_ronda()
	volcano.gestor_clima._anunciar("geiser")
	volcano.gestor_clima._anunciar("erupcion")
	volcano.gestor_clima.presentar_avisos(0.0)
	var text: String = volcano.hud.texto_avisos_clima.text
	_check(text.contains("Géiser 1.5 s") and text.contains("Erupción 2.0 s"), "Both volcano countdowns are visible together")
	await _settle()
	await _capture("volcano_warning")
	volcano.free()
	var winter = _level(5)
	winter._plantar(Vector2i(3, 4), 0)
	winter._plantar(Vector2i(11, 5), 5)
	winter._plantar(Vector2i(23, 9), 1)
	winter._plantar(Vector2i(24, 9), 3)
	winter._iniciar_ronda()
	winter.gestor_clima.calor_activo = true
	winter.gestor_clima.actualizar_proteccion()
	winter.gestor_clima._anunciar("ventisca")
	winter.gestor_clima.presentar_avisos(0.0)
	await _settle()
	await _capture("blizzard_warning")
	winter.free()

func _menus():
	for ruta in ["menu", "file_menu"]:
		var menu = load("res://escenas/escenas_menu/%s.tscn" % ruta).instantiate()
		root.add_child(menu)
		await _settle()
		await create_timer(0.15).timeout
		var rects: Array[Rect2] = []
		for button in menu.find_children("*", "Button"):
			if button.is_visible_in_tree():
				var bounds: Rect2 = button.get_global_rect()
				_check(root.get_visible_rect().encloses(bounds) and button.size.y >= 99, "%s fits %s at 150%%" % [ruta, button.name])
				_check(not rects.any(func(rect: Rect2): return rect.intersects(bounds)), "%s keeps %s separate at 150%%" % [ruta, button.name])
				rects.append(bounds)
		await _capture(ruta + "_150")
		menu.free()

func _run():
	var settings = root.get_node("Ajustes")
	var args := OS.get_cmdline_user_args()
	if "--verify-preset" in args:
		_check(settings.escala_ui() == 150, "150% persists across process restart")
		print("P1 preset reload: %s" % ("PASS" if failures == 0 else "FAILED"))
		quit(0 if failures == 0 else 1)
		return
	var original: ConfigFile = settings.config
	settings.config = ConfigFile.new()
	_check(settings.escala_ui() == 100, "Existing profiles default to 100%")
	for arg in args:
		if arg.begins_with("--capture="):
			capture_dir = arg.trim_prefix("--capture=")
	for preset in [100, 125, 150]:
		settings.config.set_value("interfaz", "escala_ui", preset)
		for index in ([2, 5, 6] if "--spot" in args else range(8)):
			var level = _level(index)
			await _settle()
			var label := "Level %d at %d%%" % [index + 1, preset]
			_assert_layout(level, preset, label)
			var before := _board(level)
			_check(level.hud.previa_ronda.visible and not level.hud.previa_ronda.get_global_rect().intersects(before), label + " docks the preview")
			await _capture("level_%02d_%d" % [index + 1, preset])
			level.hud.boton_ola.pressed.emit()
			await _settle()
			_assert_layout(level, preset, label + " expanded")
			_check(level.hud.panel_ola.visible and not level.hud.panel_ola.get_global_rect().intersects(_board(level)), label + " docks expanded details")
			level.hud.boton_ola.pressed.emit()
			await _settle()
			_check(before.is_equal_approx(_board(level)), label + " restores board geometry after closing details")
			if index == 5 and preset == 100:
				_winter(level)
			var cell: Vector2i = level.parcelas_secano[0]
			level._on_semilla_pulsada(0, false)
			_mouse(cell, level)
			_check(level.arboles_plantados.has(cell), label + " keeps mouse placement aligned with the board")
			if index == 5:
				_key(KEY_I)
				await _settle()
				var guia = level.guia
				_check(is_instance_valid(guia), label + " opens the Codex with I")
				if is_instance_valid(guia):
					var tab: Button = guia._botones_pestana.arboles
					_check(tab.size.y >= 66.0 * preset / 100.0 and root.get_visible_rect().encloses(tab.get_global_rect()), label + " fits scaled Codex buttons")
					await _capture("codex_%d" % preset)
					_pad(JOY_BUTTON_DPAD_RIGHT)
					_check(root.gui_get_focus_owner() == guia._botones_pestana.jugar, label + " moves Codex focus with the controller")
					_pad(JOY_BUTTON_A)
					_check(guia.pestana_actual == "jugar", label + " opens the focused Codex tab")
					_key(KEY_I)
			if preset == 150 and index in [2, 5, 6]:
				level.ronda = 3
				level._actualizar_ronda_hud()
				level._alternar_desafio()
				level.hud.boton_ola.pressed.emit()
				_pad(JOY_BUTTON_A)
				await _settle()
				_assert_layout(level, preset, label + " controller challenge with details")
				if index == 5:
					var cell_inspect := Vector2i(15, 8)
					level._plantar(cell_inspect, 6)
					level.celda_torre_seleccionada = cell_inspect
					level._actualizar_inspeccion()
					await _settle()
					level._actualizar_inspeccion()
					var hud = level.hud
					_check(hud._espacio_tablero().grow(1.0).encloses(hud.panel_mejora.get_global_rect()), "Scaled inspection stays clear of both docks with Details open")
					_click_at(hud.boton_cerrar_ficha.get_global_rect().get_center())
					_check(not hud.panel_mejora.visible, "Inspection Close works at 150%")
			level.free()
			await process_frame
	settings.config.set_value("interfaz", "escala_ui", 100)
	if "--spot" not in args:
		await _warning_captures()
		var level = _level(4)
		level._iniciar_ronda()
		level._abrir_pausa()
		level.pausa._abrir_ajustes()
		var options = level.pausa.ajustes
		options.selector_escala.item_selected.emit(2)
		await _settle()
		_check(paused and settings.escala_ui() == 150 and level.hud.boton_pausa.custom_minimum_size.y == 99.0, "Settings applies the preset live to a paused match")
		await _capture("settings_150")
		options._on_volver_pressed()
		level.pausa._continuar()
		level.free()
		await _menus()
	settings.config = original
	await process_frame
	print("P1 layout and UI checks at %s: %s" % [root.size, "PASS" if failures == 0 else "%d FAILED" % failures])
	quit(0 if failures == 0 else 1)
